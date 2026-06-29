#!/usr/bin/env bash
# =============================================================================
# REMVPS — docker/engine.sh
# All Docker interactions for REMVPS: build, create, manage containers
# =============================================================================

# Constants
readonly REMVPS_LABEL="remvps=true"
readonly REMVPS_IMAGE_BASE="remvps"
readonly REMVPS_BUILD_DIR="/tmp/remvps"
readonly REMVPS_META_LABEL_OS="remvps.os"
readonly REMVPS_META_LABEL_HOSTNAME="remvps.hostname"
readonly REMVPS_META_LABEL_CREATED="remvps.created"

# remvps_docker_check — verify Docker is available and daemon is running
remvps_docker_check() {
    if ! command -v docker &>/dev/null; then
        return 2   # Docker not installed
    fi
    if ! docker info &>/dev/null; then
        return 3   # Docker daemon not running or no permission
    fi
    return 0
}

# remvps_docker_version — print Docker version string
remvps_docker_version() {
    docker version --format '{{.Server.Version}}' 2>/dev/null || printf 'unknown'
}

# remvps_docker_image_tag OS_IMAGE — compute the REMVPS image tag for a given base OS
remvps_docker_image_tag() {
    local os_image="$1"
    local suffix
    suffix=$(printf '%s' "$os_image" | tr ':/' '--')
    printf '%s-%s' "${REMVPS_IMAGE_BASE}" "$suffix"
}

# remvps_docker_build_image OS_IMAGE — build the REMVPS image for the given OS
# Writes progress to stdout. Returns non-zero on build failure.
remvps_docker_build_image() {
    local os_image="$1"
    local tag
    tag=$(remvps_docker_image_tag "$os_image")

    # Already built?
    if docker image inspect "$tag" &>/dev/null; then
        return 0
    fi

    mkdir -p "${REMVPS_BUILD_DIR}"
    local dockerfile="${REMVPS_BUILD_DIR}/Dockerfile.${tag}"

    {
        printf 'FROM %s\n' "$os_image"
        remvps_os_dockerfile_snippet "$os_image"
        remvps_os_ssh_snippet "$os_image"
        printf 'CMD ["bash"]\n'
    } > "$dockerfile"

    docker build -t "$tag" -f "$dockerfile" "${REMVPS_BUILD_DIR}" &>/dev/null
}

# remvps_docker_create — create a new REMVPS container
# Args: NAME HOSTNAME OS_IMAGE ROOT_PASS [CPU_LIMIT] [RAM_LIMIT]
remvps_docker_create() {
    local name="$1"
    local hostname="$2"
    local os_image="$3"
    local root_pass="$4"
    local cpu_limit="${5:-}"
    local ram_limit="${6:-}"

    local tag
    tag=$(remvps_docker_image_tag "$os_image")

    local created_at
    created_at=$(date '+%Y-%m-%d %H:%M:%S')

    # Build resource flags
    local resource_flags=()
    [[ -n "$cpu_limit" ]] && resource_flags+=("--cpus=${cpu_limit}")
    [[ -n "$ram_limit" ]] && resource_flags+=("--memory=${ram_limit}")

    # Encode root password as a startup script
    # The container runs init.sh on first attach which sets the password.
    local init_script="${REMVPS_BUILD_DIR}/init_${name}.sh"
    remvps_generate_init_script "$init_script" "$hostname" "$root_pass" "$os_image"

    docker run -dit \
    --label "${REMVPS_LABEL}" \
    --label "${REMVPS_META_LABEL_OS}=${os_image}" \
    --label "${REMVPS_META_LABEL_HOSTNAME}=${hostname}" \
    --label "${REMVPS_META_LABEL_CREATED}=${created_at}" \
    --name "$name" \
    --hostname "$hostname" \
    "${resource_flags[@]}" \
    --volume "${init_script}:/remvps_init.sh:ro" \
    "$tag" bash
}
# remvps_generate_init_script PATH HOSTNAME ROOT_PASS OS_IMAGE
# Writes a one-time initialization script for the container.
remvps_generate_init_script() {
    local path="$1" hostname="$2" root_pass="$3" os_image="$4"

    cat > "$path" <<INITSCRIPT
#!/bin/bash
# REMVPS — Container Initialization Script
# This file is injected into the container at creation time.

set -e

# Set hostname
hostname "$hostname" 2>/dev/null || true

# Set root password
echo "root:${root_pass}" | chpasswd 2>/dev/null || true

# Configure SSH
if [ -f /etc/ssh/sshd_config ]; then
    sed -i 's/^#\\?PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
fi

# Generate SSH host keys if missing
if command -v ssh-keygen >/dev/null 2>&1; then
    ssh-keygen -A 2>/dev/null || true
fi

# Generate MOTD
cat > /etc/motd <<MOTD

  ██████╗ ███████╗███╗   ███╗██╗   ██╗██████╗ ███████╗
  ██╔══██╗██╔════╝████╗ ████║██║   ██║██╔══██╗██╔════╝
  ██████╔╝█████╗  ██╔████╔██║██║   ██║██████╔╝███████╗
  ██╔══██╗██╔══╝  ██║╚██╔╝██║╚██╗ ██╔╝██╔═══╝ ╚════██║
  ██║  ██║███████╗██║ ╚═╝ ██║ ╚████╔╝ ██║     ███████║
  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝  ╚═══╝  ╚═╝     ╚══════╝
  VPS Manager — Container Ready
  Hostname : ${hostname}
  Managed by REMVPS

MOTD

# Configure Bash prompt
cat > /root/.bashrc <<BASHRC
# REMVPS — Bash configuration
export PS1='\\[\\e[1;31m\\][REMVPS]\\[\\e[0m\\] \\[\\e[1;33m\\]\\u@${hostname}\\[\\e[0m\\]:\\[\\e[1;34m\\]\\w\\[\\e[0m\\]\\\\$ '
export TERM=xterm-256color
alias ll='ls -la --color=auto'
alias l='ls -l --color=auto'
alias cls='clear'
alias update='apt-get update 2>/dev/null || apk update 2>/dev/null || true'
alias upgrade='apt-get upgrade -y 2>/dev/null || apk upgrade 2>/dev/null || true'
alias ports='ss -tulnp'
alias meminfo='free -h'
alias cpuinfo='grep "model name" /proc/cpuinfo | head -1'
BASHRC

echo "REMVPS container initialized."
INITSCRIPT

    chmod +x "$path"
}

# remvps_docker_start NAME — start a stopped REMVPS container
remvps_docker_start() {
    local name="$1"
    docker start "$name" &>/dev/null
}

# remvps_docker_stop NAME — stop a running REMVPS container
remvps_docker_stop() {
    local name="$1"
    docker stop "$name" &>/dev/null
}

# remvps_docker_restart NAME — restart a REMVPS container
remvps_docker_restart() {
    local name="$1"
    docker restart "$name" &>/dev/null
}

# remvps_docker_delete NAME — remove a REMVPS container (must be stopped)
remvps_docker_delete() {
    local name="$1"
    docker rm -f "$name" &>/dev/null
}

# remvps_docker_open NAME — attach an interactive shell to a running container
# Runs init script on first attach if it hasn't run yet.
remvps_docker_open() {
    local name="$1"

    # Start container if stopped
    local state
    state=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null)
    if [[ "$state" != 'running' ]]; then
        docker start "$name" &>/dev/null
    fi

    # Run init script once if present
    local init_ran
    init_ran=$(docker inspect --format '{{index .Config.Labels "remvps.init_ran"}}' "$name" 2>/dev/null)
    if [[ "$init_ran" != 'true' ]]; then
        docker exec "$name" bash /remvps_init.sh &>/dev/null || true
        docker container update --label-add "remvps.init_ran=true" "$name" &>/dev/null || true
    fi

    docker exec -it "$name" bash
}

# remvps_docker_list_all — list all REMVPS containers (all states)
# Prints: NAME STATE OS HOSTNAME CONTAINER_ID
remvps_docker_list_all() {
    docker ps -a \
        --filter "label=${REMVPS_LABEL}" \
        --format '{{.Names}}\t{{.Status}}\t{{.ID}}' \
        2>/dev/null
}

# remvps_docker_count_running — count of running REMVPS containers
remvps_docker_count_running() {
    docker ps \
        --filter "label=${REMVPS_LABEL}" \
        --filter "status=running" \
        --format '{{.Names}}' \
        2>/dev/null | wc -l | tr -d ' '
}

# remvps_docker_count_stopped — count of stopped REMVPS containers
remvps_docker_count_stopped() {
    docker ps -a \
        --filter "label=${REMVPS_LABEL}" \
        --filter "status=exited" \
        --format '{{.Names}}' \
        2>/dev/null | wc -l | tr -d ' '
}

# remvps_docker_count_total — total REMVPS containers
remvps_docker_count_total() {
    docker ps -a \
        --filter "label=${REMVPS_LABEL}" \
        --format '{{.Names}}' \
        2>/dev/null | wc -l | tr -d ' '
}

# remvps_docker_inspect NAME — fetch container info as associative array output
# Prints: KEY=VALUE lines
remvps_docker_inspect() {
    local name="$1"
    local fmt
    fmt='{{.Id}}\t{{.Name}}\t{{.State.Status}}\t{{index .Config.Labels "remvps.os"}}\t{{index .Config.Labels "remvps.hostname"}}\t{{index .Config.Labels "remvps.created"}}\t{{.HostConfig.CpusetCpus}}\t{{.HostConfig.Memory}}\t{{.Config.Image}}'

    local raw
    raw=$(docker inspect --format "$fmt" "$name" 2>/dev/null) || return 1

    local id name_clean status os hostname_label created cpu mem image
    IFS=$'\t' read -r id name_clean status os hostname_label created cpu mem image <<< "$raw"

    # IP address — only meaningful when running
    local ip
    ip=$(docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$name" 2>/dev/null)

    printf 'CONTAINER_ID=%s\n'    "$id"
    printf 'CONTAINER_NAME=%s\n'  "${name_clean#/}"
    printf 'STATUS=%s\n'          "$status"
    printf 'OS_IMAGE=%s\n'        "$os"
    printf 'HOSTNAME=%s\n'        "$hostname_label"
    printf 'CREATED=%s\n'         "$created"
    printf 'CPU_LIMIT=%s\n'       "${cpu:-(none)}"
    printf 'RAM_LIMIT=%s\n'       "${mem:-(none)}"
    printf 'DOCKER_IMAGE=%s\n'    "$image"
    printf 'IP_ADDRESS=%s\n'      "${ip:-(not running)}"
}

# remvps_docker_names_all — list only names of all REMVPS containers
remvps_docker_names_all() {
    docker ps -a \
        --filter "label=${REMVPS_LABEL}" \
        --format '{{.Names}}' \
        2>/dev/null
}

# remvps_docker_pull_image IMAGE — pull a Docker image, showing progress
remvps_docker_pull_image() {
    local image="$1"
    docker pull "$image" 2>&1
}

# remvps_docker_image_exists IMAGE — returns 0 if base image exists locally
remvps_docker_image_exists() {
    docker image inspect "$1" &>/dev/null
}

# remvps_docker_system_info — print Docker system summary
remvps_docker_system_info() {
    docker info --format \
        'Server Version: {{.ServerVersion}}\nOS/Arch: {{.OSType}}/{{.Architecture}}\nContainers Total: {{.Containers}}\nImages: {{.Images}}' \
        2>/dev/null || printf 'unavailable'
}
