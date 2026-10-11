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





