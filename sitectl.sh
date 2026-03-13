#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AVAILABLE_DIR="${ROOT_DIR}/nginx/conf/sites-available"
ENABLED_DIR="${ROOT_DIR}/nginx/conf/sites-enabled"
TEMPLATE_FILE="${AVAILABLE_DIR}/php-site.conf.template"

usage() {
  cat <<'EOF'
Usage:
  ./sitectl.sh list
  ./sitectl.sh new <site.conf>
  ./sitectl.sh enable <site.conf>
  ./sitectl.sh disable <site.conf>

Notes:
  - "new" copies php-site.conf.template into sites-available.
  - "enable" creates/updates a symlink in sites-enabled.
EOF
}

cmd="${1:-}"
name="${2:-}"

case "${cmd}" in
  list)
    echo "Available:"
    ls -1 "${AVAILABLE_DIR}" || true
    echo
    echo "Enabled:"
    ls -1 "${ENABLED_DIR}" || true
    ;;
  new)
    [[ -n "${name}" ]] || { usage; exit 1; }
    [[ -f "${TEMPLATE_FILE}" ]] || { echo "Template not found: ${TEMPLATE_FILE}" >&2; exit 1; }
    target="${AVAILABLE_DIR}/${name}"
    [[ ! -e "${target}" ]] || { echo "File already exists: ${target}" >&2; exit 1; }
    cp "${TEMPLATE_FILE}" "${target}"
    echo "Created ${target}"
    ;;
  enable)
    [[ -n "${name}" ]] || { usage; exit 1; }
    src="${AVAILABLE_DIR}/${name}"
    dst="${ENABLED_DIR}/${name}"
    [[ -f "${src}" ]] || { echo "Missing site config: ${src}" >&2; exit 1; }
    ln -sfn "../sites-available/${name}" "${dst}"
    echo "Enabled ${name}"
    ;;
  disable)
    [[ -n "${name}" ]] || { usage; exit 1; }
    dst="${ENABLED_DIR}/${name}"
    [[ -e "${dst}" || -L "${dst}" ]] || { echo "Not enabled: ${name}" >&2; exit 1; }
    rm -f "${dst}"
    echo "Disabled ${name}"
    ;;
  *)
    usage
    exit 1
    ;;
esac
