#!/usr/bin/env bash
# =============================================================================
# REMVPS — os/packages.sh
# OS-aware Dockerfile package installation for each supported base image
# =============================================================================

# remvps_os_dockerfile_snippet OS_IMAGE
# Prints the Dockerfile RUN line appropriate for the given OS image.
remvps_os_dockerfile_snippet() {
    local image="$1"

    case "$image" in
        ubuntu:24.04|ubuntu:*)
            cat <<'SNIPPET'
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget nano vim sudo git zip unzip tar \
    python3 python3-pip openssh-server \
    htop screen tmux ca-certificates \
    net-tools procps iproute2 passwd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
SNIPPET
            ;;
        debian:12|debian:*)
            cat <<'SNIPPET'
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget nano vim sudo git zip unzip tar \
    python3 python3-pip openssh-server \
    htop screen tmux ca-certificates \
    net-tools procps iproute2 passwd && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
SNIPPET
            ;;
        alpine:*|alpine)
            cat <<'SNIPPET'
RUN apk update && apk add --no-cache \
    bash curl wget nano vim sudo git zip unzip tar \
    python3 py3-pip openssh-server \
    htop screen tmux ca-certificates \
    net-tools procps iproute2 shadow && \
    rm -rf /var/cache/apk/*
SNIPPET
            ;;
        *)
            # Fallback — try apt, warn user
            cat <<'SNIPPET'
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash curl wget nano vim sudo git && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
SNIPPET
            ;;
    esac
}

# remvps_os_ssh_snippet OS_IMAGE
# Prints the Dockerfile lines that set up SSH and root access per OS.
remvps_os_ssh_snippet() {
    local image="$1"

    case "$image" in
        alpine:*|alpine)
            cat <<'SNIPPET'
RUN ssh-keygen -A && \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
SNIPPET
            ;;
        *)
            cat <<'SNIPPET'
RUN mkdir -p /run/sshd && \
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
SNIPPET
            ;;
    esac
}

# remvps_os_label OS_IMAGE — human-readable OS label
remvps_os_label() {
    case "$1" in
        ubuntu:24.04)  printf 'Ubuntu 24.04' ;;
        debian:12)     printf 'Debian 12'    ;;
        alpine:*)      printf 'Alpine Linux' ;;
        *)             printf '%s' "$1"       ;;
    esac
}

# remvps_os_menu_options — print the OS selection menu items (for use in select loops)
remvps_os_menu_options() {
    printf '%s\n' \
        "Ubuntu 24.04  (ubuntu:24.04)" \
        "Debian 12     (debian:12)" \
        "Alpine Linux  (alpine:latest)"
}

# remvps_os_image_from_choice CHOICE_STRING — return the Docker image name
remvps_os_image_from_choice() {
    case "$1" in
        *ubuntu:24.04*|*Ubuntu*24*)  printf 'ubuntu:24.04'    ;;
        *debian:12*|*Debian*12*)     printf 'debian:12'        ;;
        *alpine*|*Alpine*)           printf 'alpine:latest'    ;;
        *)                           printf 'ubuntu:24.04'     ;;
    esac
}
