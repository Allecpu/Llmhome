# Repository Guidelines

## Project Structure & Module Organization

This repository packages a Windows-based local LLM serving and benchmarking setup with two stacks. The primary server is OVMS (OpenVINO Model Server) configured in root-level `start-ovms-server.ps1`, serving the OpenVINO model under `models/ov/qwen9b` on port 8000; `start-server.bat` is its user-friendly launcher. The fallback is llama.cpp: `start-llama-server.ps1` holds its configuration (port 8080). Bundled binaries live under `tools/ovms/` and `tools/llama-vulkan-*/`. Keep downloaded GGUF files in `models/` or in the LM Studio path referenced by the PowerShell script; OpenVINO exports go under `models/ov/`. Benchmark methodology and results belong in `LM_STUDIO_BENCHMARK.md`; the quality suite lives in `benchmark_cases.py` (shared cases/scoring), `benchmark-openvino-models.py` (GenAI pipelines), and `benchmark-api-models.py` (OpenAI-compatible endpoints). Runtime `*.log` files are diagnostic output, not source code.

## Build, Test, and Development Commands

There is no compilation step; the repository includes prebuilt OVMS and llama.cpp executables. Only one server at a time — both need most of the 16 GB VRAM; running them together collapses OVMS to ~1 token/s.

- `./start-server.bat` (or `./start-ovms-server.ps1`) starts the primary OVMS server (validates ovms.exe, model, API key).
- `./start-llama-server.ps1` starts the fallback llama.cpp server.
- `Invoke-RestMethod http://127.0.0.1:8000/v2/health/ready` (OVMS) or `http://127.0.0.1:8080/health` (llama.cpp) performs a smoke test after startup.
- `python benchmark-api-models.py qwen http://127.0.0.1:8000/v3 llama-api-key.txt --nothink` runs the quality suite against the running server.

Run commands from the repository root in Windows PowerShell. Stop the server with `Ctrl+C`.

## Coding Style & Naming Conventions

Use four-space indentation in PowerShell and preserve `$ErrorActionPreference = 'Stop'`. Prefer descriptive camelCase variables such as `$apiKeyFile`, `Join-Path` for paths, and `Test-Path -LiteralPath` for validation. Keep one server option per continuation line so changes remain reviewable. Batch scripts should quote paths and use `%~dp0`. Name documentation with uppercase descriptive Markdown filenames and generated logs as `<model>-<scenario>.out.log` or `.err.log`.

## Testing Guidelines

No automated test framework or coverage requirement is configured. For script changes, run the affected server, call its health endpoint, and make one authenticated request (`http://127.0.0.1:8000/v3/chat/completions` for OVMS, `http://127.0.0.1:8080/v1` for llama.cpp). The first OVMS request with `tools` after a cold start may fail once (guided-generation warm-up) — retry before concluding it is broken. Confirm useful failure messages when validation logic changes. Record meaningful performance comparisons and hardware assumptions in `LM_STUDIO_BENCHMARK.md`.

## Commit & Pull Request Guidelines

Git history is unavailable in this checkout, so use short, imperative commit subjects, for example `Tune Vulkan context settings`. Keep commits focused. Pull requests should explain the hardware and model tested, list changed server flags, include before/after throughput or memory results when relevant, and link related issues. Include logs only when concise and scrubbed of secrets.

## Security & Configuration

Never commit `llama-api-key.txt`; it is intentionally ignored. Do not add model weights, credentials, or machine-specific absolute paths. The server binds to `0.0.0.0`, so retain API-key protection and verify firewall exposure before LAN testing.
