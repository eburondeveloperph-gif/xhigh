# XHigh

Portable OpenCode launcher for the `eburonmax/eburon-xhigh-hidden:latest` Ollama model.

Model page:

- https://ollama.com/eburonmax/eburon-xhigh-hidden

## Quick start

```bash
bash setup.sh
```

One-line installer:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/eburondeveloperph-gif/xhigh/main/setup.sh)
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
- locked OpenCode config using `eburonmax/eburon-xhigh-hidden:latest`
- automatic model pull from `https://ollama.com/eburonmax/eburon-xhigh-hidden`
- automatic Ollama install
- automatic OpenCode install
- automatic TUI launch at the end of setup

## Files

- `bin/codemax`
- `bin/xhigh`
- `bin/eburon-xhigh`
- `config/opencode.json`
- `config/tui.json`
- `setup.sh`
