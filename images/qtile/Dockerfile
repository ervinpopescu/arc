# syntax=docker/dockerfile:1

ARG QTILE_CI_BASE=ghcr.io/ervinpopescu/qtile-ci-base:latest
FROM ${QTILE_CI_BASE}

LABEL org.opencontainers.image.description="https://github.com/qtile/qtile custom runner image"
LABEL org.opencontainers.image.source="https://github.com/ervinpopescu/arc/tree/main/images/qtile"

# Override upstream entrypoint
ENTRYPOINT []
ENV HOME=/home/runner

USER root

ARG RUNNER_VERSION="2.334.0"
ARG RUNNER_ARCH="x64"
ARG RUNNER_CONTAINER_HOOKS_VERSION="0.8.1"

# ARC runner system deps + .NET runtime deps required by the runner binary on Fedora
# Ref: https://github.com/actions/runner/blob/main/docs/start/envlinux.md
RUN dnf install -y \
    curl \
    unzip \
    sudo \
    shadow-utils \
    passwd \
    vim-minimal \
    jq \
    wget \
    seatd \
    lttng-ust \
    openssl-libs \
    krb5-libs \
    zlib \
    libicu \
    && dnf clean all

# Setup runner user and group (Fedora uses wheel, not sudo)
RUN groupadd -g 123 runner-group \
    && useradd -m -d /home/runner -s /bin/bash -u 1001 -g runner-group runner \
    && usermod -aG wheel runner \
    && echo "%wheel ALL=(ALL:ALL) NOPASSWD:ALL" > /etc/sudoers.d/wheel-nopasswd \
    && chmod 0440 /etc/sudoers.d/wheel-nopasswd

WORKDIR /home/runner

RUN curl -fL -o runner.tar.gz \
    "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz \
    && curl -fL -o hooks.zip \
    "https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip" \
    && unzip hooks.zip -d ./k8s \
    && rm hooks.zip \
    && chown -R runner:runner-group /home/runner

ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

USER runner
CMD ["/home/runner/run.sh"]
