$ErrorActionPreference = 'Stop'

$server = Join-Path $PSScriptRoot 'tools\llama-vulkan-b10002\llama-server.exe'
$model = Join-Path $env:USERPROFILE '.lmstudio\models\lmstudio-community\Qwen3.5-9B-GGUF\Qwen3.5-9B-Q4_K_M.gguf'
# Modello draft per speculative decoding: stesso vocabolario del 9B, ~0,8 GiB.
# Il modellino propone piu token in blocco, il 9B li verifica: +~9% generazione.
$modelDraft = Join-Path $PSScriptRoot 'models\Qwen3.5-0.8B-Q8_0.gguf'
$apiKeyFile = Join-Path $PSScriptRoot 'llama-api-key.txt'

if (-not (Test-Path -LiteralPath $server)) {
    throw "llama-server non trovato: $server"
}

if (-not (Test-Path -LiteralPath $model)) {
    throw "Modello non trovato: $model"
}

if (-not (Test-Path -LiteralPath $modelDraft)) {
    throw "Modello draft non trovato: $modelDraft"
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
    --port 8080 `
    --api-key $apiKey `
    --ctx-size 65536 `
    --parallel 1 `
    --n-predict 2048 `
    --threads 14 `
    --threads-batch 14 `
    --batch-size 2048 `
    --ubatch-size 512 `
    --fit on `
    --fit-target 256 `
    --flash-attn on `
    --cache-type-k q8_0 `
    --cache-type-v q8_0 `
    --model-draft $modelDraft `
    --n-gpu-layers-draft 99 `
    --spec-draft-n-max 8 `
    --cache-type-k-draft q8_0 `
    --cache-type-v-draft q8_0 `
    --mmap `
    --reasoning off `
    --cache-prompt `
    --cache-reuse 256 `
    --metrics
