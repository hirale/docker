#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
CONTAINER_NAME="mysql"

usage() {
  cat <<'EOF'
Usage:
  ./db.sh list
  ./db.sh export <database> [output.sql.gz]
  ./db.sh ensure <database> [db_user] [db_password]
  ./db.sh import <dump.sql|dump.sql.gz> <database> [db_user] [db_password]

Examples:
  ./db.sh list
  ./db.sh export my_project_db
  ./db.sh export my_project_db ./sql/my_project_db.sql.gz
  ./db.sh ensure my_project_db
  ./db.sh import ./sql/my_project_db.sql.gz my_project_db
  ./db.sh import ./sql/my_project_db.sql.gz my_project_db my_project_db strong_password
EOF
}

require_env() {
  if [[ ! -f "${ENV_FILE}" ]]; then
    echo "Missing .env file at ${ENV_FILE}"
    exit 1
  fi
  set -a
  source "${ENV_FILE}"
  set +a
}

require_mysql_auth() {
  MYSQL_USER="${DB_TOOL_USER:-root}"
  MYSQL_PASS="${DB_TOOL_PASSWORD:-${MARIADB_ROOT_PASSWORD:-${MARIADB_PASSWORD:-}}}"
  if [[ -z "${MYSQL_PASS}" ]]; then
    echo "Missing DB password in .env. Set MARIADB_ROOT_PASSWORD or DB_TOOL_PASSWORD."
    exit 1
  fi
}

escape_sql_identifier() {
  printf '%s' "$1" | sed "s/\`/\`\`/g"
}

escape_sql_string() {
  printf '%s' "$1" | sed "s/'/''/g"
}

cmd_list() {
  docker exec "${CONTAINER_NAME}" mariadb -N -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "SHOW DATABASES;" | grep -Ev "^(information_schema|performance_schema|mysql|sys)$" || true
}

cmd_export() {
  local db_name="$1"
  local output_path="${2:-}"
  local timestamp
  local default_output

  timestamp="$(date +%Y%m%d_%H%M%S)"
  default_output="${ROOT_DIR}/sql/${db_name}_${timestamp}.sql.gz"
  output_path="${output_path:-${default_output}}"

  mkdir -p "$(dirname "${output_path}")"
  echo "Exporting '${db_name}' from container '${CONTAINER_NAME}'..."
  docker exec "${CONTAINER_NAME}" mariadb-dump -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${db_name}" | gzip > "${output_path}"
  echo "Done: ${output_path}"
}

cmd_ensure() {
  local db_name="$1"
  local db_user="${2:-${db_name}}"
  local db_password="${3:-${DB_DEFAULT_USER_PASSWORD:-${db_user}}}"
  local db_name_esc
  local db_user_esc
  local db_password_esc

  db_name_esc="$(escape_sql_identifier "${db_name}")"
  db_user_esc="$(escape_sql_string "${db_user}")"
  db_password_esc="$(escape_sql_string "${db_password}")"

  echo "Ensuring database '${db_name}' and user '${db_user}'..."
  docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "CREATE DATABASE IF NOT EXISTS \`${db_name_esc}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
     CREATE USER IF NOT EXISTS '${db_user_esc}'@'%' IDENTIFIED BY '${db_password_esc}';
     ALTER USER '${db_user_esc}'@'%' IDENTIFIED BY '${db_password_esc}';
     GRANT ALL PRIVILEGES ON \`${db_name_esc}\`.* TO '${db_user_esc}'@'%';
     FLUSH PRIVILEGES;"
  echo "Database access ready: '${db_user}' -> '${db_name}'."
}

cmd_import() {
  local dump_file="$1"
  local db_name="$2"
  local db_user="${3:-${db_name}}"
  local db_password="${4:-${DB_DEFAULT_USER_PASSWORD:-${db_user}}}"

  if [[ ! -f "${dump_file}" ]]; then
    echo "Dump file not found: ${dump_file}"
    exit 1
  fi

  cmd_ensure "${db_name}" "${db_user}" "${db_password}"

  echo "Importing '${dump_file}' into '${db_name}' on container '${CONTAINER_NAME}'..."
  if [[ "${dump_file}" == *.gz ]]; then
    gzip -dc "${dump_file}" | docker exec -i "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${db_name}"
  else
    docker exec -i "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${db_name}" < "${dump_file}"
  fi
  echo "Done."
}

main() {
  local cmd="${1:-}"
  require_env
  require_mysql_auth

  case "${cmd}" in
    list)
      if [[ $# -ne 1 ]]; then usage; exit 1; fi
      cmd_list
      ;;
    export)
      if [[ $# -lt 2 || $# -gt 3 ]]; then usage; exit 1; fi
      cmd_export "$2" "${3:-}"
      ;;
    ensure)
      if [[ $# -lt 2 || $# -gt 4 ]]; then usage; exit 1; fi
      cmd_ensure "$2" "${3:-}" "${4:-}"
      ;;
    import)
      if [[ $# -lt 3 || $# -gt 5 ]]; then usage; exit 1; fi
      cmd_import "$2" "$3" "${4:-}" "${5:-}"
      ;;
    ""|-h|--help|help)
      usage
      ;;
    *)
      echo "Unknown command: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
