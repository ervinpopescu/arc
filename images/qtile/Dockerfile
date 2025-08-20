# syntax=docker/dockerfile:1

FROM ghcr.io/ervinpopescu/arc-custom-runner:ubuntu-24.04 AS base

COPY ./deps /deps
RUN sudo apt update -y && sudo apt upgrade -y && sudo apt install curl unzip adduser sudo git gcc g++ wget vim jq $(cat /deps) -y
