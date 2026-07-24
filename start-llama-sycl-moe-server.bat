@echo off
setlocal
cd /d "%~dp0"

echo Avvio llama.cpp SYCL con --n-cpu-moe (default: Gemma 4 26B-A4B su Arc A770)...
echo Endpoint: http://127.0.0.1:8082/v1/chat/completions
echo Per un modello diverso: powershell -File start-llama-sycl-moe-server.ps1 -Model [path] -NCpuMoe [N]
echo ATTENZIONE: nessuna API key, server esposto in chiaro su LAN.
echo Premi Ctrl+C per arrestare il server.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-llama-sycl-moe-server.ps1"

if errorlevel 1 (
    echo.
    echo Server terminato con un errore.
    pause
)

endlocal
