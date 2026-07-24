param(
    [string]$Model = (Join-Path $env:USERPROFILE '.lmstudio\models\lmstudio-community\Qwen3-Next-80B-A3B-Instruct-GGUF\Qwen3-Next-80B-A3B-Instruct-Q4_K_M.gguf'),
    [int]$NCpuMoe = 99,
    [int]$CtxSize = 65536,
    [int]$Port = 8082
)

$ErrorActionPreference = 'Stop'

# Variante di start-llama-sycl-server.ps1 per modelli MoE piu' grandi dei
# 16GB di VRAM dell'Arc A770 (Qwen3-Next 80B-A3B, Qwen 3.6 35B-A3B, Gemma 4
# 26B-A4B, GPT-OSS): --n-cpu-moe offload gli esperti routati su RAM di
# sistema. Backend SYCL obbligatorio, non Vulkan: vedi CLAUDE.md / issue
# ggml-org/llama.cpp#25777.
# Default: Qwen3-Next 80B-A3B (stessi 3B parametri attivi di Qwen 3.6
# 35B-A3B ma qualita' superiore, 7/7 sul bench qualita' contro il 6/7 di
# Qwen 35B, vedi LM_STUDIO_BENCHMARK.md 24 luglio 2026). Richiede 48,5GB
# di file modello (Q4_K_M): margine risicato sui 48GB RAM + 16GB VRAM
# della macchina, verificato funzionante a 64K di contesto.
#
# -NCpuMoe 99 offload tutti gli esperti su CPU (piu' lento, meno VRAM
# richiesta); ridurre il valore per bilanciare piu' esperti su GPU se il
# modello ci sta parzialmente.
# Nessuna API key: server esposto in chiaro su LAN (0.0.0.0). Usare solo
# su rete fidata.
$server = Join-Path $PSScriptRoot 'tools\llama-sycl\llama-server.exe'

if (-not (Test-Path -LiteralPath $server)) {
    throw "llama-server (SYCL) non trovato: $server"
}

if (-not (Test-Path -LiteralPath $Model)) {
    throw "Modello non trovato: $Model"
}

& $server `
    --model $Model `
    --host 0.0.0.0 `
    --port $Port `
    --ctx-size $CtxSize `
    --parallel 1 `
    --n-gpu-layers 99 `
    --n-cpu-moe $NCpuMoe `
    --flash-attn on `
    --reasoning off `
    --cache-prompt `
    --cache-reuse 256 `
    --metrics
