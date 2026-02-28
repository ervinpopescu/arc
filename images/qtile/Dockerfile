# syntax=docker/dockerfile:1

# Build on our new, optimized base image
FROM ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-26.04

LABEL org.opencontainers.image.description="https://github.com/qtile/qtile custom runner image"
LABEL org.opencontainers.image.source="https://github.com/ervinpopescu/arc/tree/main/images/qtile"

USER root

COPY ./deps /deps
RUN apt-get update && apt-get upgrade -y && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    git \
    gcc \
    g++ \
    wget \
    vim-tiny \
    jq \
    $(cat /deps) \
    && rm -rf /var/lib/apt/lists/*

USER runner
