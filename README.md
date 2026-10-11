1. Запустить простой http-сервер systemd demon. Приложение должно работать от имени пользователя web-user

````
artsiom@ubundu26:/opt/http-server$ sudo systemctl status http-server.service 
Warning: The unit file, source configuration file or drop-ins of http-server.service changed on disk. Run 'systemctl daemon-reload' to reload units.
● http-server.service - http-server lesson13
     Loaded: loaded (/etc/systemd/system/http-server.service; enabled; preset: enabled)
     Active: active (running) since Sat 2026-10-10 11:47:14 +03; 8min ago
 Invocation: 6fab8c3004da4542a2f0e5c0fc332b8a
   Main PID: 193125 (python3)
      Tasks: 1 (limit: 2338)
     Memory: 11.2M (peak: 11.4M)
        CPU: 310ms
     CGroup: /system.slice/http-server.service
             └─193125 python3 /opt/http-server/server.py

Oct 10 11:47:14 ubundu26 systemd[1]: Started http-server.service - http-server lesson13.
artsiom@ubundu26:/opt/http-server$ ps -o pid,user,group,cmd -p 193125
    PID USER     GROUP    CMD
 193125 web-user web-user python3 /opt/http-server/server.py
````
2. Cкрипт проверки запущенного сервиса

````
#!/bin/bash

SERVICE_NAME="http-server.service"
HOST="127.0.0.1"
PORT="8080"
HEALTH_URL="http://${HOST}:${PORT}/health"


#првоеряю статус
if systemctl is-active -q ${SERVICE_NAME}; then
  echo "Service ${SERVICE_NAME} is active"
else
  echo "Service ${SERVICE_NAME} is inactive"
fi

#проверка доступности порта
if ss -tuln | grep -q ":$PORT "; then
  echo "Port ${PORT} is open"
else
  echo "Port ${port} is not open"
fi

#провкра статуса
if curl -s "${HEALTH_URL}" | grep -q '"status": *"ok"'; then
    echo "STATUS OK"
else
    echo "FAILED"
fi
````

результат работы 
````
artsiom@ubundu26:~/home_works/web_server$ ./check_server.sh 
Service http-server.service is active
Port 8080 is open
STATUS OK
````

3. Репозиторий https://github.com/asb1122/web_server

4. Скрипт деплоя
````
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
````

результат из логов /var/log/http-server-deploy.log

````
[2026-10-11 23:19:54] - [INFO] http-server.service start deploy
[2026-10-11 23:19:54] - [INFO] User web-user exists
[2026-10-11 23:19:54] - [INFO] Git is already installed
[2026-10-11 23:19:54] - [WARNING] /opt/web-server not found. Creating dir.
[2026-10-11 23:19:54] - [INFO] /opt/web-server created.
[2026-10-11 23:19:54] - [INFO] Permissions granted to user: web-user
Cloning into '/opt/web-server'...
[2026-10-11 23:19:55] - [INFO] Clone from https://github.com/asb1122/web_server successful.
[2026-10-11 23:19:55] - [INFO] Creating UNIT file for http-server.service...
[2026-10-11 23:19:55] - [INFO] Activatind service
[2026-10-11 23:19:56] - [INFO] Reload http-server.service...
[2026-10-11 23:19:56] - [INFO] Endpoint health status: ok
````
