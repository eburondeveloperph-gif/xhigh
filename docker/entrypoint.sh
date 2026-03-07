#!/usr/bin/env bash
set -euo pipefail

MODEL="${XHIGH_MODEL:-qwen3.5}"
CONFIG_DIR="/root/.config/opencode"
ROOT_DIR="/opt/xhigh"

wait_for_ollama() {
  local i
  for i in $(seq 1 30); do
    if curl -fsS "http://127.0.0.1:11434/api/tags" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

mkdir -p "$CONFIG_DIR"
cp "$ROOT_DIR/config/opencode.json" "$CONFIG_DIR/opencode.json"
cp "$ROOT_DIR/config/tui.json" "$CONFIG_DIR/tui.json"

nohup ollama serve >/tmp/xhigh-ollama.log 2>&1 &
wait_for_ollama || {
  echo "Ollama failed to start inside the container" >&2
  exit 1
}

if ! ollama list 2>/dev/null | grep -q "^${MODEL}[[:space:]]"; then
  ollama pull "$MODEL"
fi

exec "$ROOT_DIR/bin/codemax" "$@"
