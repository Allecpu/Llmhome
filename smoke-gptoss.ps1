# Smoke test correttezza GPT-OSS 20B su Arc: verifica output coerente (non gibberish).
# Prova la build indicata; su Arc+Vulkan il bug noto produce testo corrotto.
# Uso: ./smoke-gptoss.ps1 -Build b10038   (default) | b10002

param(
    [ValidateSet('b10002', 'b10038')]
    [string]$Build = 'b10038',
    [int]$GpuLayers = 99
)

$ErrorActionPreference = 'Stop'

$cli = Join-Path $PSScriptRoot "tools\llama-vulkan-$Build\llama-cli.exe"
if (-not (Test-Path -LiteralPath $cli)) { throw "llama-cli non trovato: $cli" }

$found = Get-ChildItem -Path (Join-Path $PSScriptRoot 'models') -Filter '*mxfp4*.gguf' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $found) { throw "GPT-OSS GGUF non trovato in models/ (glob *mxfp4*.gguf)" }
$modelPath = $found.FullName

Write-Host "Build   : $Build" -ForegroundColor Cyan
Write-Host "Modello : $($found.Name)"
Write-Host ""

# Prompt con risposta verificabile: 17*23 = 391.
$prompt = 'What is 17 multiplied by 23? Reply with one short sentence.'

$out = & $cli `
    --model $modelPath `
    --n-gpu-layers $GpuLayers `
    --flash-attn on `
    --jinja `
    --ctx-size 8192 `
    --temp 0 `
    --n-predict 128 `
    -st `
    --prompt $prompt 2>$null

$text = ($out | Out-String)

Write-Host "===== OUTPUT MODELLO =====" -ForegroundColor Yellow
Write-Host $text
Write-Host "==========================" -ForegroundColor Yellow

# Euristiche gibberish: risposta deve contenere 391 ed essere per lo piu ASCII stampabile.
$has391 = $text -match '391'
$printable = ($text.ToCharArray() | Where-Object { [int]$_ -ge 32 -and [int]$_ -lt 127 }).Count
$ratio = if ($text.Length -gt 0) { $printable / $text.Length } else { 0 }

Write-Host ""
Write-Host ("Contiene '391' : {0}" -f $has391)
Write-Host ("Ratio ASCII    : {0:P0}" -f $ratio)

if ($has391 -and $ratio -gt 0.85) {
    Write-Host "ESITO: OUTPUT COERENTE - build $Build rende correttamente GPT-OSS su Arc" -ForegroundColor Green
    exit 0
} else {
    Write-Host "ESITO: SOSPETTO GIBBERISH/ERRATO - provare altra build o backend SYCL" -ForegroundColor Red
    exit 1
}
