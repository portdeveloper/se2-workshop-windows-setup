# Mimics what an attendee sees on first launch of WSL Ubuntu:
# - Ubuntu 24.04 base
# - a non-root user with passwordless sudo (WSL user has sudo via wheel)
# - curl + ca-certificates present (so the `curl | bash` bootstrap pattern works)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends sudo curl ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash -G sudo workshop \
 && echo "workshop ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/workshop \
 && chmod 0440 /etc/sudoers.d/workshop

USER workshop
WORKDIR /home/workshop
SHELL ["/bin/bash", "-c"]
