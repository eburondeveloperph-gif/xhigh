FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV XHIGH_MODEL=eburonmax/eburon-xhigh-hidden:latest

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates curl git procps \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://ollama.com/install.sh | sh
RUN curl -fsSL https://opencode.ai/install | bash

WORKDIR /opt/xhigh

COPY bin ./bin
COPY config ./config
COPY docker ./docker
COPY package.json ./package.json
COPY setup.sh ./setup.sh

RUN chmod +x /opt/xhigh/setup.sh /opt/xhigh/bin/codemax /opt/xhigh/bin/xhigh /opt/xhigh/bin/eburon-xhigh /opt/xhigh/bin/xhigh-setup /opt/xhigh/docker/entrypoint.sh \
  && ln -sf /opt/xhigh/bin/codemax /usr/local/bin/codemax \
  && ln -sf /opt/xhigh/bin/xhigh /usr/local/bin/xhigh \
  && ln -sf /opt/xhigh/bin/eburon-xhigh /usr/local/bin/eburon-xhigh \
  && ln -sf /opt/xhigh/bin/xhigh-setup /usr/local/bin/xhigh-setup

VOLUME ["/root/.ollama", "/root/.config/opencode"]

ENTRYPOINT ["/opt/xhigh/docker/entrypoint.sh"]
