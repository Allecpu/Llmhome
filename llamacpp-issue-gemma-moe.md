# Eval bug: GGML_ASSERT(id >= 0 && id < n_expert) with Gemma 4 26B-A4B + `--n-cpu-moe` on Vulkan (crash) / corrupted output with reduced `--ubatch-size`

### Name and Version

```
version: 10042 (3f08ef2c5)
built with Clang 20.1.8 for Windows x86_64
```
Also reproduced on `version: 10038 (a320cbfcb)`.

Vulkan device line at load:
```
ggml_vulkan: 0 = Intel(R) Arc(TM) A770 Graphics (Intel Corporation) | uma: 0 | fp16: 1 | bf16: 0 | fp4: 0 | warp size: 32 | shared memory: 49152 | int dot: 1 | matrix cores: none
```

### Operating systems

Windows

### GGML backends

Vulkan

### Hardware

Intel Core i5-13600K + Intel Arc A770 16GB (GPU driver 32.0.101.8861)

### Models

`lmstudio-community/gemma-4-26B-A4B-it-GGUF` → `gemma-4-26B-A4B-it-Q4_K_M.gguf` (MoE, A4B).

### Problem description & steps to reproduce

When offloading the routed experts to CPU with `--n-cpu-moe` (MoE-aware offload) on the **Vulkan** backend, Gemma 4 26B-A4B crashes **partway through a long prompt prefill** with:

```
GGML_ASSERT(id >= 0 && id < n_expert) failed   (ggml/src/ggml-backend.cpp:1615)
```

The model loads fine and prefill starts at a healthy rate (~130–160 t/s), then aborts once the prompt reaches roughly 10–20% of a 64K context. The exact crash point is data-dependent and differs between builds (see logs).

Minimal server repro:
```
llama-server \
  --model gemma-4-26B-A4B-it-Q4_K_M.gguf \
  --ctx-size 65536 --n-gpu-layers 99 --n-cpu-moe 24 --flash-attn on \
  --cache-type-k q8_0 --cache-type-v q8_0 --jinja
```
Then send a chat request with a prompt of ~8K+ tokens. It crashes during prompt processing.

Also reproducible with `llama-bench` at depth:
```
llama-bench -m gemma-4-26B-A4B-it-Q4_K_M.gguf -fa on -ctk q8_0 -ctv q8_0 -ngl 99 -ncmoe 99 -p 512 -n 0 -d 65024
```
(pp512 @ depth 0 succeeds; the deep test aborts with the same assert.)

### What narrows it down

- **SYCL backend (Level Zero, same Arc A770) does NOT crash.** With `--n-cpu-moe` the same Gemma model prefills the full 64K without the assert (just slowly, ~52 t/s). So the fault appears specific to the **Vulkan MoE-offload path**, not to `--n-cpu-moe` in general.
- **GPT-OSS 20B (also MoE) with the same `--n-cpu-moe` on Vulkan does NOT crash** and completes 64K. So the trigger seems tied to Gemma 4's expert configuration rather than MoE offload universally.
- **Reducing `--ubatch-size` to 256 avoids the hard assert** — the prefill runs to the full 64K — **but the output becomes corrupted at high context** (garbled/misspelled tokens), while the same server produces clean text at low context. This strongly suggests the underlying cause is **wrong expert index selection under Vulkan MoE offload**: with `-ub 512` the bad index trips the assert; with `-ub 256` it silently selects wrong experts and produces corrupt output.

**The crash point moves with the memory path**, which points at the expert-id copy across the Vulkan→CPU boundary:

- default: crashes at ~6K (b10038) / ~8K (b10042) prompt tokens;
- `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1`: crash is pushed to ~22.5K tokens, and output is **correct** up to that point (prefill stays ~115–125 t/s), but it still hits the same assert eventually;
- `GGML_VK_DISABLE_FUSION=1`: no effect (still crashes at ~8K);
- `--ubatch-size 256`: no hard assert up to full 64K, but output becomes corrupted at high context (as above).

Taken together (SYCL fine, GPT-OSS fine, crash position shifting with the host-visible-vidmem path, corruption vs assert flipping with ubatch), this looks like a **wrong/overflowing expert index read from the ids tensor** in the Vulkan MoE-offload path — a stride/offset/dtype or synchronization issue at the point where the GPU-computed top-k expert ids are consumed by the CPU-side expert matmul, rather than a logic error in `--n-cpu-moe` itself.

### Source-level analysis

The assert at `ggml-backend.cpp:1615` is in the MoE weight-offload path, where the used experts are discovered by reading the ids tensor back from the backend that produced it (Vulkan):

```cpp
if (ids_tensor != prev_ids_tensor) {
    ids.resize(ggml_nbytes(ids_tensor) / sizeof(int32_t));
    ggml_backend_tensor_get_async(ids_backend, ids_tensor, ids.data(), 0, ggml_nbytes(ids_tensor));
    ggml_backend_synchronize(ids_backend);

    // find the used experts
    ...
    int32_t id = ids[i1 * ids_tensor->nb[1]/sizeof(int32_t) + i0 * ids_tensor->nb[0]/sizeof(int32_t)];
    GGML_ASSERT(id >= 0 && id < n_expert);   // <-- fails here
```

Given the evidence (Vulkan-only; SYCL fine; crash position shifting with `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM`; corruption-vs-assert flipping with `ubatch`; Gemma 4 affected but GPT-OSS not), the `ids` buffer read from the Vulkan backend appears to contain wrong values for certain configurations. Two plausible root causes at this spot:

1. **Async copy / synchronization**: `ggml_backend_tensor_get_async(ids_backend, ...)` followed by `ggml_backend_synchronize(ids_backend)` may not fully guarantee the Vulkan read has landed before `ids` is consumed, so stale/garbage data is read. A race would explain the strong dependence on position, ubatch, and the memory path.
2. **View offset / stride handling**: if `ids_tensor` is a non-contiguous view (offset into its buffer, or `nb[1] != ne[0]*nb[0]`), the raw `ggml_backend_tensor_get_async(..., 0, ggml_nbytes)` copy plus the stride-based indexing may not agree on the Vulkan backend, so the wrong element is read as an expert id.

A maintainer with the Vulkan backend can likely confirm quickly by dumping the `ids` values (and `ids_tensor->ne/nb`, view offset) right before the assert, comparing Vulkan vs CPU/SYCL for the same step.

This looks related to the (closed) #18786, which reported the same assert for GPT-OSS 20B on Vulkan and was attributed to commit `2038101bd9b1` (#18166) / tag b7668. The GPT-OSS case now works, but Gemma 4 26B-A4B still fails on current `master`/release b10042.

### Relevant log output

Crash during prefill (b10038, `-ncmoe`, default ubatch):
```
slot print_timing: prompt processing, n_tokens = 4097, t = 31.59 s / 129.67 tokens per second
slot print_timing: prompt processing, n_tokens = 6145, t = 45.29 s / 135.68 tokens per second
D:/a/llama.cpp/llama.cpp/ggml/src/ggml-backend.cpp:1615: GGML_ASSERT(id >= 0 && id < n_expert) failed
```

Crash on b10042 (same config), aborts a bit later:
```
slot print_timing: prompt processing, n_tokens = 8193, progress = 0.19, t = 53.95 s / 151.85 tokens per second
D:/a/llama.cpp/llama.cpp/ggml/src/ggml-backend.cpp:1615: GGML_ASSERT(id >= 0 && id < n_expert) failed
```

Corrupted (non-crashing) output with `--ubatch-size 256` on b10042 at ~65K prompt tokens:
```
"LeIn frsi sopra riportate si sono ripetutute in modo identico per numer centosettantaantqu"
```
(same server, short prompt, correct output: "Il mare calmo riflette la luce del sole all'orizzonte...")
