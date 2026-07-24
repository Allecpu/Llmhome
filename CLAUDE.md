# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Windows-based local LLM serving + benchmarking setup on Intel Arc A770 / i5-13600K hardware. Three serving stacks: **OVMS** (OpenVINO Model Server, primary — ~10x faster prefill at deep context) under `tools/ovms/`, **llama.cpp Vulkan** (fallback) under `tools/llama-vulkan-*/`, and **llama.cpp SYCL** (for MoE models needing `--n-cpu-moe` CPU-RAM offload — see below) under `tools/llama-sycl/`. All serve an OpenAI-compatible API. See `AGENTS.md` for detailed contributor conventions; this file covers the operational essentials.

## Run / test

```powershell
./start-server.bat                # primary launcher (Command Prompt): shells into start-ovms-server.ps1
./start-ovms-server.ps1           # primary: OVMS, Qwen 9B int4 OpenVINO, port 8000
./start-llama-server.ps1          # fallback: llama.cpp Vulkan, Qwen 9B GGUF, port 8080
./start-llama-sycl-server.ps1     # SYCL fallback: Arc A770, port 8081 — needed for MoE models with --n-cpu-moe
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
- **`start-llama-sycl-server.ps1` / `tools/llama-sycl/`**: llama.cpp built with the SYCL backend (Intel oneAPI DPC++, `GGML_SYCL_TARGET=INTEL`) instead of Vulkan. Exists specifically because Vulkan crashes with `GGML_ASSERT(id >= 0 && id < n_expert)` on MoE models (Gemma 4 26B-A4B, GPT-OSS) offloaded with `--n-cpu-moe` — tracked upstream at [ggml-org/llama.cpp#25777](https://github.com/ggml-org/llama.cpp/issues/25777), unresolved as of 2026-07. SYCL's Level-Zero sync path doesn't hit the bug — verified end-to-end with a 20K-token prefill on Gemma 4 26B-A4B + `--n-cpu-moe 99`, no crash. Use this stack (with `--n-cpu-moe N` added to the launch args) for any MoE model too large for the 16GB VRAM budget alone; for models that fit fully in VRAM (like Qwen 9B), Vulkan or OVMS remain faster. The binary bundle needs runtime DLLs beyond llama.cpp's own build output — notably `ur_loader.dll` (Unified Runtime loader, dynamically loaded by `ur_win_proxy_loader.dll`, not a static import — easy to miss and causes a silent null-pointer crash on device enumeration) and the `libsycl-fallback-*.spv` device libraries. To rebuild: install oneAPI Base Toolkit + VS Build Tools (C++ workload) + Ninja, then `cmake -B build -G Ninja -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=icx -DGGML_SYCL=ON -DGGML_SYCL_TARGET=INTEL -DCMAKE_BUILD_TYPE=Release` (oneAPI's `setvars.bat` is broken on this install — per-component `vars.bat` calls fail; set up MSVC/oneAPI env vars manually instead, see git history for the working incantation).
- **`LM_STUDIO_BENCHMARK.md`** records hardware assumptions, methodology, and throughput/memory results (Italian). Update it when tuning server flags — record before/after numbers.
- **`*.log`** at root are diagnostic output (`<model>-<scenario>.out.log`/`.err.log`), not source.

## Constraints

- `llama-api-key.txt` is gitignored — never commit it, model weights, credentials, or machine-specific absolute paths.
- PowerShell: 4-space indent, keep `$ErrorActionPreference = 'Stop'`, one server option per continuation line, `Test-Path -LiteralPath` + `Join-Path` for paths.
- Documentation and this repo's prose are written in Italian.
