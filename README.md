Запустить простой http-сервер systemd demon. Приложение должно работать от имени пользователя web-user

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
