#!/bin/sh

# Shared helpers for loading Docker Compose environment variables.
# Expects DOCKER_DIR to point at the docker/ directory inside the repo.

if [ -z "${DOCKER_DIR:-}" ]; then
    echo "DOCKER_DIR must be set before sourcing scripts/lib/env.sh" >&2
    exit 1
fi

ENV_CONFIG_FILE="${ENV_CONFIG_FILE:-$DOCKER_DIR/config.env}"
ENV_CONFIG_TEMPLATE="${ENV_CONFIG_TEMPLATE:-$DOCKER_DIR/config.env.template}"
ENV_SECRETS_FILE="${ENV_SECRETS_FILE:-$DOCKER_DIR/.env}"
ENV_SECRETS_TEMPLATE="${ENV_SECRETS_TEMPLATE:-$DOCKER_DIR/.env.template}"

ensure_env_file() {
    file_path="$1"
    template_path="$2"
    label="$3"

    if [ -f "$file_path" ]; then
        return 0
    fi

    echo "Error: $label not found at $file_path." >&2
    if [ -n "$template_path" ] && [ -f "$template_path" ]; then
        echo "       Copy $template_path to $file_path and customize it." >&2
    fi
    return 1
}

load_env_files() {
    ensure_env_file "$ENV_CONFIG_FILE" "$ENV_CONFIG_TEMPLATE" "config.env" || return 1
    ensure_env_file "$ENV_SECRETS_FILE" "$ENV_SECRETS_TEMPLATE" ".env" || return 1

    set -a
    # shellcheck disable=SC1090
    . "$ENV_CONFIG_FILE"
    # shellcheck disable=SC1090
    . "$ENV_SECRETS_FILE"
    set +a
}
