$ErrorActionPreference = 'Stop'

# Server OVMS per Qwen 3.5 9B int4 su GPU Arc: prefill ~10x rispetto a
# llama.cpp Vulkan a contesto pieno, generazione ~47 token/s.
# Endpoint OpenAI-compatible: http://<host>:8000/v3/chat/completions
$ovmsDir = Join-Path $PSScriptRoot 'tools\ovms'
$ovms = Join-Path $ovmsDir 'ovms.exe'
$setupVars = Join-Path $ovmsDir 'setupvars.ps1'
$model = Join-Path $PSScriptRoot 'models\ov\qwen9b'
$apiKeyFile = Join-Path $PSScriptRoot 'llama-api-key.txt'

if (-not (Test-Path -LiteralPath $ovms)) {
    throw "ovms non trovato: $ovms"
}

if (-not (Test-Path -LiteralPath $model)) {
    throw "Modello non trovato: $model"
}

if (-not (Test-Path -LiteralPath $apiKeyFile)) {
    throw "API key non trovata: $apiKeyFile"
}

# Inizializza PATH e variabili delle DLL OVMS nel processo corrente.
& $setupVars | Out-Null

# --tool_parser hermes3: unico parser corretto per Qwen 3.5.
# --enable_tool_guided_generation: senza, il blocco <tool_call> non viene emesso.
# --cache_size 8: KV cache preallocata 8 GB; col default dinamico la
#   generazione crolla a ~1,5 token/s.
# Reasoning off per richiesta: "chat_template_kwargs": {"enable_thinking": false}.
& $ovms `
    --model_path $model `
    --model_name qwen `
    --task text_generation `
    --target_device GPU `
    --rest_port 8000 `
    --rest_bind_address 0.0.0.0 `
    --api_key_file $apiKeyFile `
    --tool_parser hermes3 `
    --reasoning_parser qwen3 `
    --enable_tool_guided_generation true `
    --enable_prefix_caching true `
    --cache_size 8
