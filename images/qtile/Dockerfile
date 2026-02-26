# syntax=docker/dockerfile:1

FROM ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-26.04 AS base
LABEL org.opencontainers.image.description="https://github.com/qtile/qtile custom runner image"
LABEL org.opencontainers.image.source="https://github.com/ervinpopescu/arc/tree/main/images/qtile"

COPY ./deps /deps
RUN sudo apt update -y && sudo apt upgrade -y && sudo apt install curl unzip adduser sudo git gcc g++ wget vim jq $(cat /deps) -y
