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
