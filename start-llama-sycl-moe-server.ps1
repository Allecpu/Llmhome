param(
    [string]$Model = (Join-Path $env:USERPROFILE '.lmstudio\models\lmstudio-community\gemma-4-26B-A4B-it-GGUF\gemma-4-26B-A4B-it-Q4_K_M.gguf'),
    [int]$NCpuMoe = 99,
    [int]$CtxSize = 65536,
    [int]$Port = 8082
)

$ErrorActionPreference = 'Stop'

# Variante di start-llama-sycl-server.ps1 per modelli MoE piu' grandi dei
# 16GB di VRAM dell'Arc A770 (Gemma 4 26B-A4B, GPT-OSS): --n-cpu-moe
# offload gli esperti routati su RAM di sistema. Backend SYCL obbligatorio,
# non Vulkan: vedi CLAUDE.md / issue ggml-org/llama.cpp#25777.
#
# -NCpuMoe 99 offload tutti gli esperti su CPU (piu' lento, meno VRAM
# richiesta); ridurre il valore per bilanciare piu' esperti su GPU se il
# modello ci sta parzialmente.
$server = Join-Path $PSScriptRoot 'tools\llama-sycl\llama-server.exe'
$apiKeyFile = Join-Path $PSScriptRoot 'llama-api-key.txt'

if (-not (Test-Path -LiteralPath $server)) {
    throw "llama-server (SYCL) non trovato: $server"
}

if (-not (Test-Path -LiteralPath $Model)) {
    throw "Modello non trovato: $Model"
}

if (-not (Test-Path -LiteralPath $apiKeyFile)) {
    throw "API key non trovata: $apiKeyFile"
}

$apiKey = (Get-Content -LiteralPath $apiKeyFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "API key vuota: $apiKeyFile"
}

& $server `
    --model $Model `
    --host 0.0.0.0 `
    --port $Port `
    --api-key $apiKey `
    --ctx-size $CtxSize `
    --parallel 1 `
    --n-gpu-layers 99 `
    --n-cpu-moe $NCpuMoe `
    --flash-attn on `
    --reasoning off `
    --cache-prompt `
    --cache-reuse 256 `
    --metrics
