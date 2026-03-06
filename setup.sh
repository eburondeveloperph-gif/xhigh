#!/usr/bin/env bash
set -euo pipefail

BOLD="\033[1m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

MODEL="${XHIGH_MODEL:-eburonmax/eburon-xhigh-hidden:latest}"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
ROOT_DIR=""
CONFIG_DIR="$HOME/.config/opencode"
INSTALL_DIR=""
PLATFORM="$(uname -s)"
BOOTSTRAP_DIR=""
ASSET_BASE_URL="${XHIGH_ASSET_BASE_URL:-https://raw.githubusercontent.com/eburondeveloperph-gif/xhigh/main}"

if [ -n "$SCRIPT_PATH" ] && [ -e "$SCRIPT_PATH" ]; then
  ROOT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
fi

step() { echo -e "${CYAN}${BOLD}==>${RESET} $1"; }
ok() { echo -e "${GREEN}${BOLD}✔${RESET} $1"; }
warn() { echo -e "${YELLOW}${BOLD}!${RESET} $1"; }
fail() { echo -e "${RED}${BOLD}x${RESET} $1"; exit 1; }

cleanup() {
  if [ -n "$BOOTSTRAP_DIR" ] && [ -d "$BOOTSTRAP_DIR" ]; then
    rm -rf "$BOOTSTRAP_DIR"
  fi
}

trap cleanup EXIT

pick_install_dir() {
  local candidate test_file
  for candidate in "$HOME/.local/bin" "$HOME/bin" "/usr/local/bin" "/opt/homebrew/bin"; do
    if [ -d "$candidate" ] || mkdir -p "$candidate" 2>/dev/null; then
      test_file="$candidate/.xhigh-write-test.$$"
      if touch "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        printf '%s\n' "$candidate"
        return 0
      fi
    fi
  done
  return 1
}

download_asset() {
  local path destination
  path="$1"
  destination="$2"
  mkdir -p "$(dirname "$destination")"
  curl -fsSL "$ASSET_BASE_URL/$path" -o "$destination"
}

ensure_repo_files() {
  if [ -n "$ROOT_DIR" ] && [ -f "$ROOT_DIR/config/opencode.json" ] && [ -f "$ROOT_DIR/bin/codemax" ]; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to bootstrap XHigh files"
  BOOTSTRAP_DIR="$(mktemp -d)"
  step "Downloading XHigh assets"

  download_asset "bin/codemax" "$BOOTSTRAP_DIR/bin/codemax"
  download_asset "bin/xhigh" "$BOOTSTRAP_DIR/bin/xhigh"
  download_asset "bin/eburon-xhigh" "$BOOTSTRAP_DIR/bin/eburon-xhigh"
  download_asset "config/opencode.json" "$BOOTSTRAP_DIR/config/opencode.json"
  download_asset "config/tui.json" "$BOOTSTRAP_DIR/config/tui.json"

  chmod +x "$BOOTSTRAP_DIR/bin/codemax" "$BOOTSTRAP_DIR/bin/xhigh" "$BOOTSTRAP_DIR/bin/eburon-xhigh"
  ROOT_DIR="$BOOTSTRAP_DIR"
  ok "XHigh assets downloaded"
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1 || [ -x "$HOME/.opencode/bin/opencode" ]; then
    ok "OpenCode already installed"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to install OpenCode"
  step "Installing OpenCode"
  curl -fsSL https://opencode.ai/install | bash

  if command -v opencode >/dev/null 2>&1 || [ -x "$HOME/.opencode/bin/opencode" ]; then
    ok "OpenCode installed"
    return 0
  fi

  fail "OpenCode install completed but no opencode binary was found"
}

install_ollama() {
  if command -v ollama >/dev/null 2>&1; then
    ok "Ollama present: $(ollama --version 2>/dev/null | head -1)"
    return 0
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to install Ollama"
  step "Installing Ollama"

  case "$PLATFORM" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        brew install --cask ollama
      else
        curl -fsSL https://ollama.com/install.sh | sh
      fi
      ;;
    Linux)
      curl -fsSL https://ollama.com/install.sh | sh
      ;;
    *)
      fail "Unsupported platform: $PLATFORM"
      ;;
  esac

  command -v ollama >/dev/null 2>&1 || fail "Ollama install completed but no ollama binary was found"
  ok "Ollama installed: $(ollama --version 2>/dev/null | head -1)"
}

ensure_ollama_running() {
  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    ok "Ollama reachable at http://127.0.0.1:11434"
    return 0
  fi

  if [ "$PLATFORM" = "Darwin" ] && command -v open >/dev/null 2>&1; then
    warn "Ollama is installed but not reachable. Trying to launch the Ollama app."
    open -a Ollama >/dev/null 2>&1 || true
    sleep 5
    if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
      ok "Ollama app started"
      return 0
    fi
  fi

  warn "Trying to start 'ollama serve' in background."
  nohup ollama serve >/tmp/xhigh-ollama.log 2>&1 &
  sleep 3

  if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
    ok "Ollama started in background"
    return 0
  fi

  fail "Ollama is not reachable on http://127.0.0.1:11434. Start it, then rerun setup.sh."
}

ensure_model() {
  if ollama list 2>/dev/null | grep -q "^${MODEL}[[:space:]]"; then
    ok "Model ${MODEL} already present"
    return 0
  fi

  step "Pulling ${MODEL}"
  ollama pull "$MODEL"
  ok "Model ${MODEL} ready"
}

install_config() {
  step "Installing OpenCode config"
  mkdir -p "$CONFIG_DIR"

  if [ -f "$CONFIG_DIR/opencode.json" ]; then
    cp "$CONFIG_DIR/opencode.json" "$CONFIG_DIR/opencode.json.bak.$(date +%Y%m%d%H%M%S)"
  fi

  if [ -f "$CONFIG_DIR/tui.json" ]; then
    cp "$CONFIG_DIR/tui.json" "$CONFIG_DIR/tui.json.bak.$(date +%Y%m%d%H%M%S)"
  fi

  cp "$ROOT_DIR/config/opencode.json" "$CONFIG_DIR/opencode.json"
  cp "$ROOT_DIR/config/tui.json" "$CONFIG_DIR/tui.json"
  ok "Config installed to $CONFIG_DIR"
}

install_launchers() {
  local wrapper_name
  INSTALL_DIR="$(pick_install_dir)" || fail "Could not find a writable bin directory"

  step "Installing launcher commands into $INSTALL_DIR"
  for wrapper_name in codemax xhigh eburon-xhigh; do
    cp "$ROOT_DIR/bin/$wrapper_name" "$INSTALL_DIR/$wrapper_name"
    chmod +x "$INSTALL_DIR/$wrapper_name"
  done

  ok "Installed commands: codemax, xhigh, eburon-xhigh"

  case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *)
      warn "$INSTALL_DIR is not in PATH"
      echo "Add this to your shell profile:"
      echo "export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac
}

start_tui() {
  local launcher
  launcher="$ROOT_DIR/bin/codemax"
  if [ -n "$INSTALL_DIR" ] && [ -x "$INSTALL_DIR/codemax" ]; then
    launcher="$INSTALL_DIR/codemax"
  fi

  echo ""
  ok "Setup complete"
  echo "Starting XHigh TUI..."
  if [ -t 0 ] && [ -t 1 ]; then
    exec "$launcher"
  fi

  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    exec "$launcher" </dev/tty >/dev/tty 2>&1
  fi

  warn "No interactive TTY available to launch the TUI automatically."
  echo "Run: $launcher"
}

echo ""
echo "XHigh setup"
echo ""

ensure_repo_files
install_opencode
install_ollama
ensure_ollama_running
ensure_model
install_config
install_launchers
start_tui
