# Benchmark prefill/generazione a profondita crescenti fino a 64K.
# Replica il collo di bottiglia reale di Hermes: prompt processing a contesto pieno.
# Uso: ./bench-prefill.ps1   (default: qwen, build b10052)

param(
    [ValidateSet('qwen')]
    [string]$Model = 'qwen',
    [ValidateSet('b10052')]
    [string]$Build = 'b10052',
    [ValidateSet('q8_0', 'q4_0', 'f16')]
    [string]$KvType = 'q8_0',
    [int]$GpuLayers = 99,
    [int]$Repetitions = 2,
    [switch]$Quick
)

$ErrorActionPreference = 'Stop'

$bench = Join-Path $PSScriptRoot "tools\llama-vulkan-$Build\llama-bench.exe"

$models = @{
    qwen = Join-Path $env:USERPROFILE '.lmstudio\models\lmstudio-community\Qwen3.5-9B-GGUF\Qwen3.5-9B-Q4_K_M.gguf'
}

$modelPath = $models[$Model]

if (-not (Test-Path -LiteralPath $bench)) {
    throw "llama-bench non trovato: $bench"
}
if (-not (Test-Path -LiteralPath $modelPath)) {
    throw "Modello non trovato: $modelPath"
}

$suffix = if ($KvType -ne 'q8_0') { "-kv$KvType" } else { '' }
$outFile = Join-Path $PSScriptRoot "$Model-prefill$suffix.bench.md"

Write-Host "Modello : $Model   Build: $Build   KV: $KvType" -ForegroundColor Cyan
Write-Host "File    : $modelPath"
Write-Host "GPU lyr : $GpuLayers   Rip: $Repetitions   Quick: $Quick"
Write-Host "Output  : $outFile"
Write-Host ""

$common = @(
    '-m', $modelPath,
    '-fa', 'on',
    '-ctk', $KvType,
    '-ctv', $KvType,
    '-ngl', $GpuLayers,
    '-mmp', '1',
    '-r', $Repetitions,
    '-o', 'md'
)

# Ogni test e un'invocazione separata: evita il prodotto cartesiano di llama-bench.
# 1) Prefill incrementale di un blocco da 512 token a profondita crescenti
#    (costo reale per-turno di Hermes con contesto quasi pieno).
# 2) Prefill a freddo dell'intero contesto 64K (peggior caso primo turno).
# 3) Generazione con KV gia pieno a ~64K.
# -Quick: solo i punti sensibili alla KV (depth 0, depth 64K, gen 64K).
if ($Quick) {
    $tests = @(
        @{ Desc = 'prefill 512 @ depth 0';      Args = @('-p', '512', '-n', '0',  '-d', '0') },
        @{ Desc = 'prefill 512 @ depth 65024';  Args = @('-p', '512', '-n', '0',  '-d', '65024') },
        @{ Desc = 'generazione @ depth 65024';  Args = @('-p', '0',   '-n', '64', '-d', '65024') }
    )
} else {
    $tests = @(
        @{ Desc = 'prefill 512 @ depth 0';      Args = @('-p', '512',   '-n', '0',  '-d', '0') },
        @{ Desc = 'prefill 512 @ depth 8192';   Args = @('-p', '512',   '-n', '0',  '-d', '8192') },
        @{ Desc = 'prefill 512 @ depth 32768';  Args = @('-p', '512',   '-n', '0',  '-d', '32768') },
        @{ Desc = 'prefill 512 @ depth 65024';  Args = @('-p', '512',   '-n', '0',  '-d', '65024') },
        @{ Desc = 'prefill 64K a freddo';       Args = @('-p', '65536', '-n', '0',  '-d', '0') },
        @{ Desc = 'generazione @ depth 65024';  Args = @('-p', '0',     '-n', '64', '-d', '65024') }
    )
}

if (Test-Path -LiteralPath $outFile) { Remove-Item -LiteralPath $outFile }

foreach ($t in $tests) {
    Write-Host ">> $($t.Desc)" -ForegroundColor Yellow
    & $bench @common @($t.Args) 2>&1 | Tee-Object -FilePath $outFile -Append
    Write-Host ""
}

Write-Host "Risultati salvati in: $outFile" -ForegroundColor Green
