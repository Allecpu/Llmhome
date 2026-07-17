@echo off
setlocal
cd /d "%~dp0"

echo Avvio OVMS con Qwen 3.5 9B int4 su GPU Arc...
echo Endpoint: http://127.0.0.1:8000/v3/chat/completions
echo Reasoning off per richiesta: "chat_template_kwargs": {"enable_thinking": false}
echo Tool calling nativo (parser hermes3) - KV cache preallocata 8 GB
echo Accesso LAN abilitato con API key in llama-api-key.txt
echo Nota: la prima richiesta con tools dopo l'avvio puo' fallire una volta (warm-up).
echo Fallback llama.cpp: eseguire start-llama-server.ps1 (porta 8080), mai insieme a OVMS.
echo Premi Ctrl+C per arrestare il server.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-ovms-server.ps1"

if errorlevel 1 (
    echo.
    echo OVMS terminato con un errore.
    pause
)

endlocal
