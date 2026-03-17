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
  ./db.sh copy <source_db> <target_db> [source_user] [target_user] [target_password] [--replace-target] [--ignore-table table]

Examples:
  ./db.sh list
  ./db.sh export my_project_db
  ./db.sh export my_project_db ./sql/my_project_db.sql.gz
  ./db.sh ensure my_project_db
  ./db.sh import ./sql/my_project_db.sql.gz my_project_db
  ./db.sh import ./sql/my_project_db.sql.gz my_project_db my_project_db strong_password
  ./db.sh copy my_project_db my_project_db_copy
  ./db.sh copy my_project_db my_project_db_copy my_project_db my_project_db_copy strong_password
  ./db.sh copy my_project_db my_project_db_copy --replace-target
  ./db.sh copy my_project_db my_project_db_copy --ignore-table logs
  ./db.sh copy my_project_db my_project_db_copy --replace-target --ignore-table logs --ignore-table audit_events
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

db_exists() {
  local db_name="$1"
  local db_name_esc
  local matched_db

  db_name_esc="$(escape_sql_string "${db_name}")"
  matched_db="$(docker exec "${CONTAINER_NAME}" mariadb -N -B -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${db_name_esc}' LIMIT 1;")"
  [[ "${matched_db}" == "${db_name}" ]]
}

db_user_exists() {
  local db_user="$1"
  local db_user_esc
  local matched_user

  db_user_esc="$(escape_sql_string "${db_user}")"
  matched_user="$(docker exec "${CONTAINER_NAME}" mariadb -N -B -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "SELECT User FROM mysql.global_priv WHERE User='${db_user_esc}' AND Host='%' LIMIT 1;")"
  [[ "${matched_user}" == "${db_user}" ]]
}

db_table_exists() {
  local db_name="$1"
  local table_name="$2"
  local db_name_esc
  local table_name_esc
  local matched_table

  db_name_esc="$(escape_sql_string "${db_name}")"
  table_name_esc="$(escape_sql_string "${table_name}")"
  matched_table="$(docker exec "${CONTAINER_NAME}" mariadb -N -B -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "SELECT TABLE_NAME
     FROM information_schema.TABLES
     WHERE TABLE_SCHEMA='${db_name_esc}' AND TABLE_NAME='${table_name_esc}'
     LIMIT 1;")"
  [[ "${matched_table}" == "${table_name}" ]]
}

prepare_large_import() {
  local import_server_max_packet="${DB_IMPORT_SERVER_MAX_ALLOWED_PACKET:-1073741824}"
  local import_net_read_timeout="${DB_IMPORT_NET_READ_TIMEOUT:-600}"
  local import_net_write_timeout="${DB_IMPORT_NET_WRITE_TIMEOUT:-600}"

  echo "Preparing MariaDB for large import (packet/timeouts)..."
  docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "SET GLOBAL max_allowed_packet=${import_server_max_packet};
     SET GLOBAL net_read_timeout=${import_net_read_timeout};
     SET GLOBAL net_write_timeout=${import_net_write_timeout};"
}

clone_user_auth() {
  local source_user="$1"
  local target_user="$2"
  local source_user_esc
  local target_user_esc
  local auth_row
  local auth_plugin
  local auth_string
  local auth_string_esc

  source_user_esc="$(escape_sql_string "${source_user}")"
  target_user_esc="$(escape_sql_string "${target_user}")"
  auth_row="$(docker exec "${CONTAINER_NAME}" mariadb -N -B -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "SELECT COALESCE(JSON_VALUE(Priv,'$.plugin'),''), COALESCE(JSON_VALUE(Priv,'$.authentication_string'),'')
     FROM mysql.global_priv
     WHERE User='${source_user_esc}' AND Host='%'
     LIMIT 1;" 2>/dev/null || true)"
  if [[ -z "${auth_row}" ]]; then
    return 1
  fi

  auth_plugin="$(printf '%s' "${auth_row}" | awk -F'\t' 'NR==1 {print $1}')"
  auth_string="$(printf '%s' "${auth_row}" | awk -F'\t' 'NR==1 {print $2}')"
  if [[ -z "${auth_plugin}" || ! "${auth_plugin}" =~ ^[A-Za-z0-9_]+$ ]]; then
    return 1
  fi

  if [[ -n "${auth_string}" ]]; then
    auth_string_esc="$(escape_sql_string "${auth_string}")"
    docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
      "CREATE USER IF NOT EXISTS '${target_user_esc}'@'%';
       ALTER USER '${target_user_esc}'@'%' IDENTIFIED VIA ${auth_plugin} USING '${auth_string_esc}';"
  else
    docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
      "CREATE USER IF NOT EXISTS '${target_user_esc}'@'%';
       ALTER USER '${target_user_esc}'@'%' IDENTIFIED VIA ${auth_plugin};"
  fi
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
  local import_client_max_packet="${DB_IMPORT_CLIENT_MAX_ALLOWED_PACKET:-1G}"
  local import_client_net_buffer="${DB_IMPORT_CLIENT_NET_BUFFER_LENGTH:-1M}"

  if [[ ! -f "${dump_file}" ]]; then
    echo "Dump file not found: ${dump_file}"
    exit 1
  fi

  cmd_ensure "${db_name}" "${db_user}" "${db_password}"
  prepare_large_import

  echo "Importing '${dump_file}' into '${db_name}' on container '${CONTAINER_NAME}'..."
  if [[ "${dump_file}" == *.gz ]]; then
    gzip -dc "${dump_file}" | docker exec -i "${CONTAINER_NAME}" mariadb \
      --max-allowed-packet="${import_client_max_packet}" \
      --net-buffer-length="${import_client_net_buffer}" \
      -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${db_name}"
  else
    docker exec -i "${CONTAINER_NAME}" mariadb \
      --max-allowed-packet="${import_client_max_packet}" \
      --net-buffer-length="${import_client_net_buffer}" \
      -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${db_name}" < "${dump_file}"
  fi
  echo "Done."
}

cmd_copy() {
  local source_db="$1"
  local target_db="$2"
  shift 2

  local positional=()
  local ignore_tables=()
  local env_ignore_tables="${DB_COPY_IGNORE_TABLES:-}"
  local source_user
  local target_user
  local target_password
  local replace_target="false"
  local target_db_esc
  local target_user_esc
  local target_password_esc
  local import_client_max_packet="${DB_IMPORT_CLIENT_MAX_ALLOWED_PACKET:-1G}"
  local import_client_net_buffer="${DB_IMPORT_CLIENT_NET_BUFFER_LENGTH:-1M}"
  local table_name
  local ignore_db
  local ignore_table
  local normalized_ignore_ref
  local env_ignore_arr=()
  local dump_ignore_args=()
  local ignore_table_names=()
  local target_exists="false"
  local preserve_dump_file=""
  local preserve_tables=()

  cleanup_preserve_dump() {
    if [[ -n "${preserve_dump_file:-}" && -f "${preserve_dump_file:-}" ]]; then
      rm -f "${preserve_dump_file:-}"
    fi
  }
  trap cleanup_preserve_dump RETURN

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ignore-table)
        if [[ $# -lt 2 || -z "${2}" ]]; then
          echo "Missing value for --ignore-table."
          exit 1
        fi
        ignore_tables+=("$2")
        shift 2
        ;;
      --ignore-table=*)
        table_name="${1#*=}"
        if [[ -z "${table_name}" ]]; then
          echo "Missing value for --ignore-table."
          exit 1
        fi
        ignore_tables+=("${table_name}")
        shift
        ;;
      --replace-target)
        replace_target="true"
        shift
        ;;
      --)
        shift
        while [[ $# -gt 0 ]]; do
          positional+=("$1")
          shift
        done
        ;;
      -*)
        echo "Unknown option for copy: $1"
        usage
        exit 1
        ;;
      *)
        positional+=("$1")
        shift
        ;;
    esac
  done

  if [[ ${#positional[@]} -gt 3 ]]; then
    echo "Too many positional arguments for copy."
    usage
    exit 1
  fi

  source_user="${positional[0]:-${source_db}}"
  target_user="${positional[1]:-${target_db}}"
  target_password="${positional[2]:-}"

  if [[ -n "${env_ignore_tables}" ]]; then
    IFS=',' read -r -a env_ignore_arr <<< "${env_ignore_tables}"
    for table_name in "${env_ignore_arr[@]}"; do
      table_name="${table_name#"${table_name%%[![:space:]]*}"}"
      table_name="${table_name%"${table_name##*[![:space:]]}"}"
      if [[ -n "${table_name}" ]]; then
        ignore_tables+=("${table_name}")
      fi
    done
  fi

  for table_name in "${ignore_tables[@]}"; do
    ignore_db="${source_db}"
    ignore_table="${table_name}"

    if [[ "${table_name}" == *.* ]]; then
      ignore_db="${table_name%%.*}"
      ignore_table="${table_name#*.}"
    fi

    if [[ "${ignore_db}" != "${source_db}" ]]; then
      echo "Ignored table '${table_name}' is not in source database '${source_db}'."
      exit 1
    fi

    if [[ -z "${ignore_table}" ]]; then
      echo "Invalid ignored table value: '${table_name}'"
      exit 1
    fi

    normalized_ignore_ref="${source_db}.${ignore_table}"
    dump_ignore_args+=("--ignore-table=${normalized_ignore_ref}")
    ignore_table_names+=("${ignore_table}")
  done

  if [[ "${source_db}" == "${target_db}" ]]; then
    echo "Source and target database names must be different."
    exit 1
  fi

  if ! db_exists "${source_db}"; then
    echo "Source database not found: ${source_db}"
    exit 1
  fi

  target_db_esc="$(escape_sql_identifier "${target_db}")"

  if db_exists "${target_db}"; then
    target_exists="true"
    if [[ "${replace_target}" == "true" ]]; then
      if [[ ${#ignore_table_names[@]} -gt 0 ]]; then
        for table_name in "${ignore_table_names[@]}"; do
          if db_table_exists "${target_db}" "${table_name}"; then
            preserve_tables+=("${table_name}")
          fi
        done
        if [[ ${#preserve_tables[@]} -gt 0 ]]; then
          preserve_dump_file="$(mktemp "${TMPDIR:-/tmp}/db_copy_preserve_${target_db}_XXXXXX.sql")"
          echo "Preserving target tables before replace: ${preserve_tables[*]}"
          docker exec "${CONTAINER_NAME}" mariadb-dump \
            -u"${MYSQL_USER}" -p"${MYSQL_PASS}" \
            --single-transaction --skip-add-drop-table \
            "${target_db}" "${preserve_tables[@]}" > "${preserve_dump_file}"
        fi
      fi

      echo "Replacing existing target database '${target_db}'..."
      docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
        "DROP DATABASE \`${target_db_esc}\`;"
    else
      echo "Target database already exists: ${target_db}"
      echo "Choose a new target database name, use --replace-target, or drop '${target_db}' first."
      exit 1
    fi
  fi

  target_user_esc="$(escape_sql_string "${target_user}")"

  echo "Creating target database '${target_db}'..."
  docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "CREATE DATABASE IF NOT EXISTS \`${target_db_esc}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

  if db_user_exists "${target_user}"; then
    echo "User '${target_user}' already exists; keeping existing credentials."
  elif [[ -n "${target_password}" ]]; then
    target_password_esc="$(escape_sql_string "${target_password}")"
    echo "Creating user '${target_user}' with provided password..."
    docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
      "CREATE USER IF NOT EXISTS '${target_user_esc}'@'%' IDENTIFIED BY '${target_password_esc}';
       ALTER USER '${target_user_esc}'@'%' IDENTIFIED BY '${target_password_esc}';"
  else
    echo "Copying credentials '${source_user}' -> '${target_user}'..."
    if ! clone_user_auth "${source_user}" "${target_user}"; then
      target_password="${DB_DEFAULT_USER_PASSWORD:-${target_user}}"
      target_password_esc="$(escape_sql_string "${target_password}")"
      echo "Could not copy source credentials; using default password fallback for '${target_user}'."
      docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
        "CREATE USER IF NOT EXISTS '${target_user_esc}'@'%' IDENTIFIED BY '${target_password_esc}';
         ALTER USER '${target_user_esc}'@'%' IDENTIFIED BY '${target_password_esc}';"
    fi
  fi

  docker exec "${CONTAINER_NAME}" mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASS}" -e \
    "GRANT ALL PRIVILEGES ON \`${target_db_esc}\`.* TO '${target_user_esc}'@'%';
     FLUSH PRIVILEGES;"

  prepare_large_import

  if [[ ${#dump_ignore_args[@]} -gt 0 ]]; then
    echo "Skipping tables: ${ignore_tables[*]}"
  fi

  echo "Copying database '${source_db}' -> '${target_db}'..."
  docker exec "${CONTAINER_NAME}" mariadb-dump \
    -u"${MYSQL_USER}" -p"${MYSQL_PASS}" \
    --single-transaction --routines --triggers --events \
    "${dump_ignore_args[@]}" \
    "${source_db}" \
    | docker exec -i "${CONTAINER_NAME}" mariadb \
      --max-allowed-packet="${import_client_max_packet}" \
      --net-buffer-length="${import_client_net_buffer}" \
      -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${target_db}"

  if [[ "${target_exists}" == "true" && "${replace_target}" == "true" && -n "${preserve_dump_file}" ]]; then
    echo "Restoring preserved target tables into '${target_db}'..."
    docker exec -i "${CONTAINER_NAME}" mariadb \
      --max-allowed-packet="${import_client_max_packet}" \
      --net-buffer-length="${import_client_net_buffer}" \
      -u"${MYSQL_USER}" -p"${MYSQL_PASS}" "${target_db}" < "${preserve_dump_file}"
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
    copy)
      if [[ $# -lt 3 ]]; then usage; exit 1; fi
      cmd_copy "$2" "$3" "${@:4}"
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
