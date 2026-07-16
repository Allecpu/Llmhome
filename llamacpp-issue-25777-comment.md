Some additional findings that narrow this down further.

**The crash point moves with the memory path**, which points at the expert-id copy across the Vulkan→CPU boundary:

- default: crashes at ~6K (b10038) / ~8K (b10042) prompt tokens;
- `GGML_VK_DISABLE_HOST_VISIBLE_VIDMEM=1`: crash is pushed to ~22.5K tokens, and output is **correct** up to that point (prefill stays ~115–125 t/s), but it still hits the same assert eventually;
- `GGML_VK_DISABLE_FUSION=1`: no effect (still crashes at ~8K);
- `--ubatch-size 256`: no hard assert up to full 64K, but output becomes corrupted at high context.

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

Possibly related to the closed #18786 (same assert for GPT-OSS 20B on Vulkan, attributed to commit `2038101bd9b1` / #18166 / tag b7668). That GPT-OSS case is now fixed, while Gemma 4 26B-A4B still fails on b10042 — so this may be a separate/remaining variant.
