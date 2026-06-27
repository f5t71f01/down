@echo off
set /p HOSTNAME=hostname: 
set /p PORT=localhost port: 

cloudflared access rdp --hostname %HOSTNAME% --url rdp://localhost:%PORT%

pause