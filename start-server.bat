@echo off
setlocal
cd /d "%~dp0"

echo Avvio llama-server con Qwen 3.5 9B...
echo Endpoint locale: http://127.0.0.1:8080/v1
echo Contesto: 65536 token
echo KV cache: Q8 - limite risposta: 2048 token
echo Prompt cache e riuso KV: attivi
echo Accesso LAN abilitato con API key in llama-api-key.txt
echo Premi Ctrl+C per arrestare il server.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-gemma-server.ps1"

if errorlevel 1 (
    echo.
    echo llama-server terminato con un errore.
    pause
)

endlocal
