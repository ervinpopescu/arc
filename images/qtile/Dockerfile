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

# Re-apply sudoers config to be safe and ensure runner is in the sudo group
RUN usermod -aG sudo runner \
    && echo "%sudo ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner \
    && chmod 0440 /etc/sudoers.d/runner \
    && echo "Defaults env_keep += \"DEBIAN_FRONTEND\"" > /etc/sudoers.d/env_keep \
    && chmod 0440 /etc/sudoers.d/env_keep

USER runner
