# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Windows-based local LLM serving + benchmarking setup around llama.cpp (Vulkan build) on Intel Arc A770 / i5-13600K hardware. No compilation step — prebuilt binaries under `tools/llama-vulkan-b10002/`. Serves an OpenAI-compatible API for the Qwen 3.5 9B GGUF model. See `AGENTS.md` for detailed contributor conventions; this file covers the operational essentials.

## Run / test

```powershell
./start-gemma-server.ps1          # start OpenAI-compatible server (validates exe, model, API key)
./start-gemma-server.bat          # same, launched from Command Prompt
```

- Endpoint: `http://127.0.0.1:8080/v1` — binds `0.0.0.0` (LAN-exposed, API-key protected).
- Smoke test after startup: `Invoke-RestMethod http://127.0.0.1:8080/health`
- Authenticated request needs the key from `llama-api-key.txt` in the `Authorization: Bearer` header.
- Inspect runtime flags: `./tools/llama-vulkan-b10002/llama-server.exe --help`
- Stop with `Ctrl+C`. No automated test framework exists.

## Architecture / key facts

- **`start-gemma-server.ps1`** is the source of truth for server config: model path, context size (65536), KV cache quant (`q8_0`), flash-attn, `--fit`/`--fit-target` VRAM fitting, thread counts. The `.bat` is just a launcher that shells into the `.ps1`. Edit tuning in the `.ps1`.
- **Model path** is `$env:USERPROFILE\.lmstudio\models\...\Qwen3.5-9B-Q4_K_M.gguf` — reuses LM Studio's download location. Changing model = edit `$model` in the `.ps1`.
- **Speculative decoding**: the server also requires a draft model at `models\Qwen3.5-0.8B-Q8_0.gguf` (`$modelDraft` in the `.ps1`, startup fails without it). `models/` is gitignored — weights live there locally, plus OpenVINO exports under `models/ov/` used by `benchmark-openvino-models.py`.
- **`LM_STUDIO_BENCHMARK.md`** records hardware assumptions, methodology, and throughput/memory results (Italian). Update it when tuning server flags — record before/after numbers.
- **`*.log`** at root are diagnostic output (`<model>-<scenario>.out.log`/`.err.log`), not source.

## Constraints

- `llama-api-key.txt` is gitignored — never commit it, model weights, credentials, or machine-specific absolute paths.
- PowerShell: 4-space indent, keep `$ErrorActionPreference = 'Stop'`, one server option per continuation line, `Test-Path -LiteralPath` + `Join-Path` for paths.
- Documentation and this repo's prose are written in Italian.
