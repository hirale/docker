#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/xdebug.sh on
  ./scripts/xdebug.sh off
  ./scripts/xdebug.sh status
EOF
}

if [[ -f "${ENV_FILE}" ]]; then
  set -a; source "${ENV_FILE}"; set +a
fi

PHP_CONFIG_PATH="${PHP_CONFIG:-./php-fpm/conf}"
[[ "${PHP_CONFIG_PATH}" == /* ]] || PHP_CONFIG_PATH="${ROOT_DIR}/${PHP_CONFIG_PATH#./}"
XDEBUG_INI="${PHP_CONFIG_PATH}/php/conf.d/docker-php-ext-xdebug.ini"

if [[ ! -f "${XDEBUG_INI}" ]]; then
  echo "Xdebug ini not found: ${XDEBUG_INI}" >&2
  exit 1
fi

is_enabled() {
  grep -q '^zend_extension' "${XDEBUG_INI}"
}

restart_if_running() {
  if docker ps -q --filter "name=^php-fpm$" --filter "status=running" | grep -q .; then
    echo "Restarting php-fpm..."
    docker restart php-fpm
  fi
}

cmd="${1:-}"
case "${cmd}" in
  on)
    if is_enabled; then
      echo "Xdebug is already on."
      exit 0
    fi
    sed -i 's/^; \(zend_extension\|xdebug\.\)/\1/' "${XDEBUG_INI}"
    echo "Xdebug enabled."
    restart_if_running
    ;;
  off)
    if ! is_enabled; then
      echo "Xdebug is already off."
      exit 0
    fi
    sed -i 's/^\(zend_extension\|xdebug\.\)/; \1/' "${XDEBUG_INI}"
    echo "Xdebug disabled."
    restart_if_running
    ;;
  status)
    if is_enabled; then
      echo "Xdebug: on"
    else
      echo "Xdebug: off"
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
