# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Windows-based local LLM serving + benchmarking setup on Intel Arc A770 / i5-13600K hardware. Two serving stacks, no compilation step: **OVMS** (OpenVINO Model Server, primary — ~10x faster prefill at deep context) under `tools/ovms/`, and **llama.cpp** (Vulkan builds, fallback) under `tools/llama-vulkan-*/`. Both serve an OpenAI-compatible API for Qwen 3.5 9B. See `AGENTS.md` for detailed contributor conventions; this file covers the operational essentials.

## Run / test

```powershell
./start-server.bat                # primary launcher (Command Prompt): shells into start-ovms-server.ps1
./start-ovms-server.ps1           # primary: OVMS, Qwen 9B int4 OpenVINO, port 8000
./start-llama-server.ps1          # fallback: llama.cpp Vulkan, Qwen 9B GGUF, port 8080
```

- OVMS endpoint: `http://127.0.0.1:8000/v3/chat/completions` — binds `0.0.0.0` (LAN-exposed, API-key protected). Reasoning off is per-request: `"chat_template_kwargs": {"enable_thinking": false}`. First `tools` request after cold start may fail once (guided-generation warm-up) — retry.
- llama.cpp endpoint: `http://127.0.0.1:8080/v1` — same auth model.
- Health checks: `Invoke-RestMethod http://127.0.0.1:8000/v2/health/ready` (OVMS), `http://127.0.0.1:8080/health` (llama.cpp).
- Authenticated request needs the key from `llama-api-key.txt` in the `Authorization: Bearer` header.
- Quality suite against a running server: `python benchmark-api-models.py qwen http://127.0.0.1:8000/v3 llama-api-key.txt --nothink`
- Stop with `Ctrl+C`. No automated test framework exists.

## Architecture / key facts

- **`start-ovms-server.ps1`** is the source of truth for the primary server: OpenVINO model path (`models/ov/qwen9b`), `hermes3` tool parser, `qwen3` reasoning parser, tool guided generation, prefix caching, `cache_size 8` (mandatory — dynamic KV cache collapses generation to ~1.5 token/s).
- **`start-llama-server.ps1`** is the source of truth for the fallback llama.cpp config: model path, context size (65536), KV cache quant (`q8_0`), flash-attn, `--fit`/`--fit-target` VRAM fitting, thread counts, speculative decoding draft. `start-server.bat` is just a launcher that shells into `start-ovms-server.ps1`. Edit tuning in the `.ps1` files.
- **Model path** is `$env:USERPROFILE\.lmstudio\models\...\Qwen3.5-9B-Q4_K_M.gguf` — reuses LM Studio's download location. Changing model = edit `$model` in the `.ps1`.
- **Speculative decoding**: the server also requires a draft model at `models\Qwen3.5-0.8B-Q8_0.gguf` (`$modelDraft` in the `.ps1`, startup fails without it). `models/` is gitignored — weights live there locally, plus OpenVINO exports under `models/ov/` used by `benchmark-openvino-models.py`.
- **`LM_STUDIO_BENCHMARK.md`** records hardware assumptions, methodology, and throughput/memory results (Italian). Update it when tuning server flags — record before/after numbers.
- **`*.log`** at root are diagnostic output (`<model>-<scenario>.out.log`/`.err.log`), not source.

## Constraints

- `llama-api-key.txt` is gitignored — never commit it, model weights, credentials, or machine-specific absolute paths.
- PowerShell: 4-space indent, keep `$ErrorActionPreference = 'Stop'`, one server option per continuation line, `Test-Path -LiteralPath` + `Join-Path` for paths.
- Documentation and this repo's prose are written in Italian.
