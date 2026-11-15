# llama.cpp evaluation adapter

Status, 2026-11-15: the real CPU/Accelerate adapter is linked into `MemoryOSAILab`. All SDK/model downloads finished and passed full hashes. Five linked asset/settings/native contracts passed in Step 1. Step 2 adds a parameterized embedded-NUL rejection regression. Qwen3-0.6B and Qwen3-1.7B each completed 90 Simulator cases. The 0.6B model also completed the shared host workload under OS-enforced network denial. These are experimental results, not production adoption or phone measurements.

## Reviewed configuration

The official b12387 release archive has no Simulator slice. The package uses generated, ignored XCFramework slices built from exact upstream commit `a956a852c9c8bc1fb07206364838ddef299178c0` in its separate upstream checkout. The build uses CPU and Apple Accelerate on all three platforms: macOS arm64, iOS device arm64 and iOS Simulator arm64. It includes no server, TLS or Metal backend. `scripts/fetch-llama-evaluation-source.py` verifies pinned source inputs; `scripts/prepare-llama-evaluation.py` builds the slices and source/binary receipt. No engine algorithm patch is applied.

A local reviewed GGUF file and SHA-256 enter `LlamaTextRuntime` through its initializer. Before loading, the adapter verifies the full file hash. It uses a 2048-token context, at most 256 output tokens, four decode/batch threads and greedy temperature zero. Greedy sampling does not use the recorded seed. Qwen3 uses its reviewed non-thinking generation prefix. Unsupported templates and overlong inputs fail without truncation. Embedded NUL characters in instructions, questions, source IDs or source text fail before asset access, because the upstream chat-template API accepts NUL-terminated strings.

The actor retains model weights during one batch, then the composition root unloads them. Each request resets KV state and the sampler. Cold first-token time includes asset verification, model loading and prefill; warm requests retain weights. Cancellation checks run before loading, during hashing and between decoded tokens. Synchronous upstream loading/decoding may delay cancellation; the ViewModel waits for completion before enabling a rerun.

No downloader, URLSession, cloud fallback or production store enters the adapter. Keep weights outside Git. The [support review](../../docs/reference/2026-11-14-local-ai-support.md) records SDK/model pins and licenses. Preserve MIT and transitive notices before distribution; no distribution is authorized here.

## Verification

```sh
swift test --package-path native/LocalTextEvaluation -c release
```

The linked tests cover missing assets, hash mismatch, unsupported sampling, remote URL rejection and a hash-verified invalid GGUF passed to the native loader. They do not assert model quality. The [measured report](../../docs/evidence/local-ai-2026-11-14/resume-summary.md) links actual model outputs, separate builder quality reviews, cancellation, repeated Simulator runs and build evidence. Reports use format 2 with scope/repetition metadata; decoding still accepts format 1.

Historical header-only checks and stopped downloads remain in the [task history](../../docs/tasks/2026-11-14-local-ai-phone-evaluation.md). They do not describe this final configuration.
