# syntax=docker/dockerfile:1

# --- Stage 1: Builder ---
FROM mcr.microsoft.com/dotnet/runtime-deps:11.0-preview-resolute-amd64 AS builder

ARG RUNNER_VERSION="2.331.0"
ARG RUNNER_ARCH="x64"
ARG RUNNER_CONTAINER_HOOKS_VERSION="0.8.1"

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip

WORKDIR /home/runner

# Download and extract runner
RUN curl -f -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

# Download and extract hooks
RUN curl -f -L -o runner-container-hooks.zip https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

# --- Stage 2: Final Image ---
FROM mcr.microsoft.com/dotnet/runtime-deps:11.0-preview-resolute-amd64

LABEL org.opencontainers.image.description="Base custom runner image"
LABEL org.opencontainers.image.source="https://github.com/ervinpopescu/arc/tree/main/images/base"

ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1

# Install runtime dependencies ONLY
COPY ./deps /deps
# hadolint ignore=DL3008,SC2046
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    jq \
    vim-tiny \
    ca-certificates \
    passwd \
    $(cat /deps) \
    && rm -rf /var/lib/apt/lists/*

# Setup runner user and group
# We remove NOPASSWD:ALL for security; permissions are handled via fsGroup: 123 in K8s
RUN groupadd -g 123 runner-group \
    && useradd -m -d /home/runner -s /bin/bash -u 1001 -g runner-group runner

WORKDIR /home/runner

# Copy pre-extracted files from builder
COPY --from=builder --chown=runner:runner /home/runner /home/runner

USER runner
