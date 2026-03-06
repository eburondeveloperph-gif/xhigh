FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV XHIGH_MODEL=eburonmax/eburon-xhigh-hidden:latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates curl git procps \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://ollama.com/install.sh | sh
RUN curl -fsSL https://bun.sh/install | bash

ENV BUN_INSTALL=/root/.bun
ENV PATH=/root/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

WORKDIR /opt/xhigh

COPY bin ./bin
COPY config ./config
COPY docker ./docker
COPY vendor ./vendor
COPY package.json ./package.json
COPY setup.sh ./setup.sh

RUN cd /opt/xhigh/vendor/opencode \
  && MODELS_DEV_API_JSON=/opt/xhigh/vendor/opencode/models.dev.api.json bun install \
  && MODELS_DEV_API_JSON=/opt/xhigh/vendor/opencode/models.dev.api.json bun run --cwd packages/opencode build -- --single --skip-install \
  && cp "$(find /opt/xhigh/vendor/opencode/packages/opencode/dist -path '*/bin/opencode' -type f | head -n 1)" /opt/xhigh/bin/opencode

RUN chmod +x /opt/xhigh/setup.sh /opt/xhigh/bin/codemax /opt/xhigh/bin/xhigh /opt/xhigh/bin/eburon-xhigh /opt/xhigh/bin/xhigh-setup /opt/xhigh/docker/entrypoint.sh \
  && chmod +x /opt/xhigh/bin/opencode \
  && ln -sf /opt/xhigh/bin/codemax /usr/local/bin/codemax \
  && ln -sf /opt/xhigh/bin/xhigh /usr/local/bin/xhigh \
  && ln -sf /opt/xhigh/bin/eburon-xhigh /usr/local/bin/eburon-xhigh \
  && ln -sf /opt/xhigh/bin/xhigh-setup /usr/local/bin/xhigh-setup \
  && ln -sf /opt/xhigh/bin/opencode /usr/local/bin/opencode

VOLUME ["/root/.ollama", "/root/.config/opencode"]

ENTRYPOINT ["/opt/xhigh/docker/entrypoint.sh"]
