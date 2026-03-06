# XHigh

Portable OpenCode launcher for the `eburonmax/eburon-xhigh-hidden:latest` Ollama model.

Model page:

- https://ollama.com/eburonmax/eburon-xhigh-hidden

OpenCode TUI source:

- vendored in `vendor/opencode`
- built locally during setup with Bun

## Quick start

```bash
bash setup.sh
```

One-line installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/eburondeveloperph-gif/xhigh/main/setup.sh)
```

One-line curl pipeline:

```bash
curl -fsSL https://raw.githubusercontent.com/eburondeveloperph-gif/xhigh/main/setup.sh | bash
```

Then run:

```bash
codemax
```

Or:

```bash
xhigh
```

## What this repo installs

- `codemax`
- `xhigh`
- `eburon-xhigh`
- `xhigh-setup`
- locked OpenCode config using `eburonmax/eburon-xhigh-hidden:latest`
- automatic model pull from `https://ollama.com/eburonmax/eburon-xhigh-hidden`
- vendored OpenCode source and local TUI build
- automatic Ollama install
- automatic TUI launch at the end of setup

## npm

Install directly from GitHub:

```bash
npm install -g github:eburondeveloperph-gif/xhigh
xhigh-setup
```

This installs the package bins:

- `opencode`
- `codemax`
- `xhigh`
- `eburon-xhigh`
- `xhigh-setup`

## Docker

Build:

```bash
docker build -t xhigh .
```

Run:

```bash
docker run --rm -it -v xhigh-ollama:/root/.ollama -v xhigh-config:/root/.config/opencode xhigh
```

The container starts Ollama, pulls `eburonmax/eburon-xhigh-hidden:latest` if needed, and then opens the TUI.

## Independent OpenCode build

The current OpenCode TUI source used by XHigh is committed in `vendor/opencode`.

Manual local build:

```bash
cd vendor/opencode
MODELS_DEV_API_JSON="$(pwd)/models.dev.api.json" bun install
MODELS_DEV_API_JSON="$(pwd)/models.dev.api.json" bun run --cwd packages/opencode build -- --single --skip-install
find packages/opencode/dist -path '*/bin/opencode' -type f
```

## Files

- `bin/codemax`
- `bin/xhigh`
- `bin/eburon-xhigh`
- `bin/xhigh-setup`
- `config/opencode.json`
- `config/tui.json`
- `docker/entrypoint.sh`
- `Dockerfile`
- `package.json`
- `setup.sh`
- `vendor/opencode`
