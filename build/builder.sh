#!/usr/bin/env bash

set -eo pipefail

source ./build/util.sh

# Absolute path to the toplevel milvus directory.
toplevel=$(dirname "$(cd "$(dirname "${0}")"; pwd)")

if [[ "$IS_NETWORK_MODE_HOST" == "true" ]]; then
  sed -i '/builder:/,/^\s*$/s/image: \${IMAGE_REPO}\/milvus-env:\${OS_NAME}-\${DATE_VERSION}/&\n    network_mode: "host"/' $toplevel/docker-compose.yml
fi

if [[ -f "$toplevel/.env" ]]; then
    set -a  # automatically export all variables from .env
    source $toplevel/.env
    set +a  # stop automatically exporting
fi

pushd "${toplevel}"

if [[ "${1-}" == "pull" ]]; then
    $DOCKER_COMPOSE_COMMAND pull  builder
    exit 0
fi

if [[ "${1-}" == "down" ]]; then
    $DOCKER_COMPOSE_COMMAND down
    exit 0
fi

# 优先使用 TARGETARCH 环境变量，其次使用 PLATFORM_ARCH，最后使用 IMAGE_ARCH
if [ -n "$TARGETARCH" ]; then
    PLATFORM_ARCH="$TARGETARCH"
elif [ -n "$PLATFORM_ARCH" ]; then
    PLATFORM_ARCH="$PLATFORM_ARCH"
elif [ -n "$IMAGE_ARCH" ]; then
    PLATFORM_ARCH="$IMAGE_ARCH"
else
    # 自动检测
    MACHINE=$(uname -m)
    if [ "$MACHINE" = "x86_64" ]; then
        PLATFORM_ARCH="amd64"
    else
        PLATFORM_ARCH="arm64"
    fi
fi

export IMAGE_ARCH=${PLATFORM_ARCH}

mkdir -p "${DOCKER_VOLUME_DIRECTORY:-.docker}/${IMAGE_ARCH}-${OS_NAME}-ccache"
mkdir -p "${DOCKER_VOLUME_DIRECTORY:-.docker}/${IMAGE_ARCH}-${OS_NAME}-go-mod"
mkdir -p "${DOCKER_VOLUME_DIRECTORY:-.docker}/${IMAGE_ARCH}-${OS_NAME}-vscode-extensions"
mkdir -p "${DOCKER_VOLUME_DIRECTORY:-.docker}/${IMAGE_ARCH}-${OS_NAME}-conan"
chmod -R 777 "${DOCKER_VOLUME_DIRECTORY:-.docker}"

$DOCKER_COMPOSE_COMMAND pull builder
if [[ "${CHECK_BUILDER:-}" == "1" ]]; then
    $DOCKER_COMPOSE_COMMAND build builder
fi

$DOCKER_COMPOSE_COMMAND run --no-deps --rm builder "$@"

popd
