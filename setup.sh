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
REPO_ARCHIVE_URL="${XHIGH_REPO_ARCHIVE_URL:-https://github.com/eburondeveloperph-gif/xhigh/archive/refs/heads/main.tar.gz}"
OPENCODE_BINARY=""
BUN_BIN_DIR="${BUN_INSTALL:-$HOME/.bun}/bin"
PATH="$BUN_BIN_DIR:$PATH"
REQUIRED_BUN_VERSION=""

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

version_gte() {
  local current required i
  local current_parts required_parts
  current="$1"
  required="$2"
  IFS=. read -r -a current_parts <<< "$current"
  IFS=. read -r -a required_parts <<< "$required"
  for i in 0 1 2; do
    local c="${current_parts[$i]:-0}"
    local r="${required_parts[$i]:-0}"
    if ((10#$c > 10#$r)); then
      return 0
    fi
    if ((10#$c < 10#$r)); then
      return 1
    fi
  done
  return 0
}

current_bun_version() {
  bun --version 2>/dev/null | head -n 1
}

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

ensure_repo_files() {
  if [ -n "$ROOT_DIR" ] && [ -f "$ROOT_DIR/config/opencode.json" ] && [ -f "$ROOT_DIR/bin/codemax" ] && [ -d "$ROOT_DIR/vendor/opencode/packages/opencode" ]; then
    return 0
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to bootstrap XHigh files"
  command -v tar >/dev/null 2>&1 || fail "tar is required to bootstrap XHigh files"
  BOOTSTRAP_DIR="$(mktemp -d)"
  step "Downloading XHigh repository"
  curl -fsSL "$REPO_ARCHIVE_URL" | tar -xzf - -C "$BOOTSTRAP_DIR" --strip-components=1

  ROOT_DIR="$BOOTSTRAP_DIR"
  ok "XHigh repository downloaded"
}

ensure_bun() {
  local current_version upgraded=0

  if [ -z "$REQUIRED_BUN_VERSION" ] && [ -f "$ROOT_DIR/vendor/opencode/package.json" ]; then
    REQUIRED_BUN_VERSION="$(sed -n 's/.*"packageManager":[[:space:]]*"bun@\([^"]*\)".*/\1/p' "$ROOT_DIR/vendor/opencode/package.json" | head -n 1)"
  fi
  REQUIRED_BUN_VERSION="${REQUIRED_BUN_VERSION:-1.3.10}"

  if command -v bun >/dev/null 2>&1; then
    current_version="$(current_bun_version)"
    if version_gte "$current_version" "$REQUIRED_BUN_VERSION"; then
      ok "Bun present: $current_version"
      return 0
    fi
    warn "Bun $current_version is too old. Upgrading to >= $REQUIRED_BUN_VERSION."

    if bun upgrade >/dev/null 2>&1; then
      hash -r
      current_version="$(current_bun_version)"
      if version_gte "$current_version" "$REQUIRED_BUN_VERSION"; then
        ok "Bun upgraded in place: $current_version"
        return 0
      fi
      warn "bun upgrade completed but still resolved to $current_version"
      upgraded=1
    else
      warn "bun upgrade failed. Falling back to the Bun installer."
    fi
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required to install Bun"
  if [ "$upgraded" -eq 1 ]; then
    step "Reinstalling Bun >= $REQUIRED_BUN_VERSION"
  else
    step "Installing Bun >= $REQUIRED_BUN_VERSION"
  fi
  curl -fsSL https://bun.sh/install | bash
  export PATH="$BUN_BIN_DIR:$PATH"
  hash -r

  command -v bun >/dev/null 2>&1 || fail "Bun install completed but no bun binary was found"
  current_version="$(current_bun_version)"
  if ! version_gte "$current_version" "$REQUIRED_BUN_VERSION"; then
    fail "Bun upgrade completed but the installed version is still below $REQUIRED_BUN_VERSION (current: $current_version)"
  fi
  ok "Bun installed: $current_version"
}

build_vendored_opencode() {
  local build_root models_json opencode_version opencode_channel
  build_root="$ROOT_DIR/vendor/opencode"
  [ -d "$build_root/packages/opencode" ] || fail "Vendored OpenCode source not found in $build_root"

  models_json="$build_root/models.dev.api.json"
  if [ ! -f "$models_json" ]; then
    printf '{}\n' > "$models_json"
  fi
  opencode_version="$(sed -n 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/p' "$build_root/packages/opencode/package.json" | head -n 1)"
  opencode_version="${opencode_version:-0.0.0-xhigh}"
  opencode_channel="${XHIGH_OPENCODE_CHANNEL:-latest}"

  if [ -z "${XHIGH_FORCE_REBUILD:-}" ]; then
    OPENCODE_BINARY="$(find "$build_root/packages/opencode/dist" -path '*/bin/opencode' -type f 2>/dev/null | head -n 1 || true)"
    if [ -n "$OPENCODE_BINARY" ] && [ -x "$OPENCODE_BINARY" ]; then
      ok "Vendored OpenCode already built"
      return 0
    fi
  fi

  step "Building vendored OpenCode TUI with Bun $(current_bun_version) (channel: $opencode_channel, version: $opencode_version)"
  (
    cd "$build_root"
    CI=1 HUSKY=0 HUSKY_SKIP_INSTALL=1 bun install
    OPENCODE_CHANNEL="$opencode_channel" \
      OPENCODE_VERSION="$opencode_version" \
      MODELS_DEV_API_JSON="$models_json" \
      bun run --cwd packages/opencode build -- --single --skip-install
  )

  OPENCODE_BINARY="$(find "$build_root/packages/opencode/dist" -path '*/bin/opencode' -type f 2>/dev/null | head -n 1 || true)"
  [ -n "$OPENCODE_BINARY" ] && [ -x "$OPENCODE_BINARY" ] || fail "OpenCode build completed but no binary was produced"
  ok "Vendored OpenCode built: $OPENCODE_BINARY"
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
  [ -n "$OPENCODE_BINARY" ] && [ -x "$OPENCODE_BINARY" ] || fail "OpenCode binary is not available to install"
  cp "$OPENCODE_BINARY" "$INSTALL_DIR/opencode"
  chmod +x "$INSTALL_DIR/opencode"
  for wrapper_name in codemax xhigh eburon-xhigh; do
    cp "$ROOT_DIR/bin/$wrapper_name" "$INSTALL_DIR/$wrapper_name"
    chmod +x "$INSTALL_DIR/$wrapper_name"
  done

  ok "Installed commands: opencode, codemax, xhigh, eburon-xhigh"

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
ensure_bun
build_vendored_opencode
install_ollama
ensure_ollama_running
ensure_model
install_config
install_launchers
start_tui
