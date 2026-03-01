# syntax=docker/dockerfile:1

# Build on our new, optimized base image
FROM arc-base:local

LABEL org.opencontainers.image.description="https://github.com/qtile/qtile custom runner image"
LABEL org.opencontainers.image.source="https://github.com/ervinpopescu/arc/tree/main/images/qtile"

USER root

COPY ./deps /deps
# hadolint ignore=DL3008,SC2046
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    gcc \
    g++ \
    wget \
    vim-tiny \
    jq \
    sudo \
    $(cat /deps) \
    && rm -rf /var/lib/apt/lists/*

USER runner
