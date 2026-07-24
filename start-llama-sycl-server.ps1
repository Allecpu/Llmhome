$ErrorActionPreference = 'Stop'

# Server llama.cpp SYCL per Intel Arc A770: alternativa a Vulkan quando serve
# offload MoE su RAM CPU con --n-cpu-moe. Backend Vulkan crasha con
# GGML_ASSERT(id >= 0 && id < n_expert) su modelli MoE (Gemma 4 26B-A4B,
# GPT-OSS) offloadati con --n-cpu-moe: bug tracciato in
# ggml-org/llama.cpp#25777, non ancora risolto upstream. SYCL non soffre
# di questo bug (percorso di sincronizzazione Vulkan diverso da Level-Zero).
#
# Richiede runtime oneAPI in tools/llama-sycl (bundlato: sycl8.dll,
# ur_loader.dll, ur_adapter_level_zero.dll, mkl_*, libiomp5md.dll, *.spv).
# Per rebuild da sorgente vedi AGENTS.md.
$server = Join-Path $PSScriptRoot 'tools\llama-sycl\llama-server.exe'
$model = Join-Path $env:USERPROFILE '.lmstudio\models\lmstudio-community\Qwen3.5-9B-GGUF\Qwen3.5-9B-Q4_K_M.gguf'
$apiKeyFile = Join-Path $PSScriptRoot 'llama-api-key.txt'

if (-not (Test-Path -LiteralPath $server)) {
    throw "llama-server (SYCL) non trovato: $server"
}

if (-not (Test-Path -LiteralPath $model)) {
    throw "Modello non trovato: $model"
}

if (-not (Test-Path -LiteralPath $apiKeyFile)) {
    throw "API key non trovata: $apiKeyFile"
}

$apiKey = (Get-Content -LiteralPath $apiKeyFile -Raw).Trim()
if ([string]::IsNullOrWhiteSpace($apiKey)) {
    throw "API key vuota: $apiKeyFile"
}

& $server `
    --model $model `
    --host 0.0.0.0 `
    --port 8081 `
    --api-key $apiKey `
    --ctx-size 65536 `
    --parallel 1 `
    --n-gpu-layers 99 `
    --flash-attn on `
    --cache-type-k q8_0 `
    --cache-type-v q8_0 `
    --reasoning off `
    --cache-prompt `
    --cache-reuse 256 `
    --metrics
