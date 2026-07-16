# Repository Guidelines

## Project Structure & Module Organization

This repository packages a Windows-based local LLM serving and benchmarking setup. Root-level `start-gemma-server.ps1` contains the llama.cpp server configuration; `start-gemma-server.bat` is its user-friendly launcher. Bundled Vulkan binaries live under `tools/llama-vulkan-b10002/`. Keep downloaded GGUF files in `models/` or in the LM Studio path referenced by the PowerShell script. Benchmark methodology and results belong in `LM_STUDIO_BENCHMARK.md`. Runtime `*.log` files are diagnostic output, not source code.

## Build, Test, and Development Commands

There is no compilation step; the repository includes prebuilt llama.cpp executables.

- `./start-gemma-server.ps1` starts the OpenAI-compatible server and validates the executable, model, and API key.
- `./start-gemma-server.bat` launches the same server from Command Prompt and displays active settings.
- `./tools/llama-vulkan-b10002/llama-server.exe --help` verifies the bundled runtime and lists supported flags.
- `Invoke-RestMethod http://127.0.0.1:8080/health` performs a smoke test after startup.

Run commands from the repository root in Windows PowerShell. Stop the server with `Ctrl+C`.

## Coding Style & Naming Conventions

Use four-space indentation in PowerShell and preserve `$ErrorActionPreference = 'Stop'`. Prefer descriptive camelCase variables such as `$apiKeyFile`, `Join-Path` for paths, and `Test-Path -LiteralPath` for validation. Keep one server option per continuation line so changes remain reviewable. Batch scripts should quote paths and use `%~dp0`. Name documentation with uppercase descriptive Markdown filenames and generated logs as `<model>-<scenario>.out.log` or `.err.log`.

## Testing Guidelines

No automated test framework or coverage requirement is configured. For script changes, run the server, call `/health`, and make one authenticated request against `http://127.0.0.1:8080/v1`. Confirm useful failure messages when validation logic changes. Record meaningful performance comparisons and hardware assumptions in `LM_STUDIO_BENCHMARK.md`.

## Commit & Pull Request Guidelines

Git history is unavailable in this checkout, so use short, imperative commit subjects, for example `Tune Vulkan context settings`. Keep commits focused. Pull requests should explain the hardware and model tested, list changed server flags, include before/after throughput or memory results when relevant, and link related issues. Include logs only when concise and scrubbed of secrets.

## Security & Configuration

Never commit `llama-api-key.txt`; it is intentionally ignored. Do not add model weights, credentials, or machine-specific absolute paths. The server binds to `0.0.0.0`, so retain API-key protection and verify firewall exposure before LAN testing.
