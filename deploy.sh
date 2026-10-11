#!/bin/bash

set -u

SERVICE_NAME="http-server.service"
PORT="8080"
URL="http://127.0.0.1:${PORT}"
APP_USER="web-user"
REPO_URL="https://github.com/asb1122/web_server"
APP_DIR="/opt/web-server"
SERVICE_PATH="/etc/systemd/system/web-server"
LOG_FILE="/var/log/http-server-deploy.log"
HEALTH_ENDPOINT="health"

log() {
  local level=$1
  local msg=$2
  local ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] - [$level] $msg" >> $LOG_FILE
}

# проверка системного пользователя
check_user() {
  if id $APP_USER > /dev/null 2>&1; then
    log "INFO" "User $APP_USER exists"
    return 0
  else
    log "INFO" "Creating the user $APP_USER for the operation of the web server..."
    adduser --disabled-password --gecos "" "$APP_USER"
    log "INFO" "User $APP_USER created."
    return 1
  fi
}

# проверка наличия git
check_git() {
  if command -v git > /dev/null 2>&1; then
    log "INFO" "Git is already installed"
    return 0
  else
    log "Warning" "Git is not installed. Install GIT to continue."
    return 1
  fi
}

#проверка директории
check_dir() {
  if [ -d "${APP_DIR}" ] && [ "$(find "${APP_DIR}" -mindepth 1 -print -quit)" ]; then
    log "ERROR" "The ${APP_DIR} directory exists and  is not empty."
    return 1
  else
    log "WARNING" "${APP_DIR} not found. Creating dir."
    if mkdir -p "${APP_DIR}" ; then
      log "INFO" "${APP_DIR} created."
      return 0
    fi
  fi
}

#клонирование репозитория
clone_repo() {
  if git clone "${REPO_URL}" "${APP_DIR}" >> "${LOG_FILE}" 2>&1; then
    log "INFO" "Clone from ${REPO_URL} successful."
    return 0
  else
    log "ERROR" "Clone from ${REPO_URL} finished with error"
    return 1
  fi
}

permission_on_app_dir() {
  if chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}" ; then
    log "INFO" "Permissions granted to user: web-user"
    return 0
  else
    log "ERROR" "Failed to grant permissions"
    return 1
  fi
}

#создание и запуск сервиса
configure_service() {
  if [ ! -f "${SERVICE_PATH}" ]; then
    log "INFO" "Creating UNIT file for $SERVICE_NAME..."
    cp "${APP_DIR}/${SERVICE_NAME}" "${SERVICE_PATH}"

    log "INFO" "Activatind service"
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}"
  else
    log "INFO" "Service ${SERVICE_NAME} already exists — updating the configuration."
    cp "${APP_DIR}/${SERVICE_NAME}" "${SERVICE_PATH}"
    systemctl daemon-reload
  fi

  log "INFO" "Reload $SERVICE_NAME..."
  systemctl restart "${SERVICE_NAME}"
  check_health_endpoint
}

#проверка endpoint /healthh
check_health_endpoint() {
    local url="${URL}/${HEALTH_ENDPOINT}"
    local status
    local response

    timeout 30 bash -c "until systemctl is-active --quiet '${SERVICE_NAME}'; do sleep 0.5; done" \
        || { log "ERROR" "${SERVICE_NAME} did not become active"; return 1; }

    response=$(curl -s -L --max-time 3 -w '\n%{http_code}' "${url}" 2>/dev/null)

    status=$(echo "$response" | jq -r '.status // empty' 2>/dev/null)

    if [ "$status" = "ok" ]; then
        log "INFO" "Endpoint ${HEALTH_ENDPOINT} status: ${status}"
        echo "Deployment completed successfully"
        return 0
    else
        log "ERROR" "Health check failed! status='${status}' (http_code='${http_code}')"
        return 1
    fi
}


#проверка пререквизитов
main() {
  if [ "$(id -u)" -ne 0 ]; then
    log "ERROR" "Usage: sudo $0"
    exit 1
  fi

  log "INFO" "$SERVICE_NAME start deploy"
  echo "$SERVICE_NAME start deploy process"

  if ! check_user ; then
    echo "ERROR: USER - See log : ${LOG_FILE}"
    exit 1
  fi

  if ! check_git ; then
     echo "ERROR: GIT - See log: ${LOG_FILE}"
     exit 1
  fi

  if ! check_dir ; then
    echo "ERROR: DIR - See log: ${LOG_FILE}"
    exit 1
  fi

  if ! permission_on_app_dir ; then
    echo "ERROR: See log: ${LOG_FILE}"
    exit 1
  fi


  if ! clone_repo ; then
    echo "ERROR: CLON REPO - See log: ${LOG_FILE}"
    exit 1
  fi

  if ! configure_service ; then
    echo "ERROR: SYSTEMD -  See log: ${LOG_FILE}"
    exit 1
  fi
}


main "$@"
