# Local MLX evaluation adapter

This isolated package connects MemoryOS's app-owned `TextRuntimeAdapter` to MLX Swift LM. It does not open production memories. The adapter receives fictional source values and returns text plus the SDK's generated-token count. It calls local-directory model and tokenizer APIs. It has no downloader object, remote model identifier, cloud fallback or tool executor.

## Reviewed inputs

- MLX Swift LM 3.32.3: commit `3b339ad6e3b3f44c8121ecff5131c7fd55e075e6`. The package disables `FoundationModelsIntegration` and uses `MLXLLM` / `MLXLMCommon`.
- Hugging Face Swift Transformers 1.4.0: commit `402a8a1105f52038b0949d9596981fc9e32bed17`. `AutoTokenizer.from(modelFolder:)` loads the local tokenizer. The adapter maps its Sendable tokenizer protocol to MLX's tokenizer protocol.
- [MLX fixture](https://huggingface.co/mlx-community/Qwen3-0.6B-4bit): revision `73e3e38d981303bc594367cd910ea6eb48349da8`, converted from Qwen3-0.6B with MLX LM 0.24.0. `model.safetensors` contains 335,450,584 bytes with SHA-256 `392e8d466d56100ada00eb82031fb854297fc9e389b7d303eba3af114e87bce2`. The fixture uses MLX 4-bit quantization; it is not a GGUF Q4_K_M artifact. Record this difference in runtime comparisons.

The manifest pins the reviewed direct revisions. `Package.resolved` records the canonical graph, including MLX Swift 0.32.3, Crypto 3.15.1 and yyjson 0.13.0. This configuration resolved through standard SwiftPM against original upstream URLs and passed Release compilation plus real Mac GPU tests. MLX Swift LM uses MIT; Swift Transformers uses Apache 2.0. The model card declares Apache 2.0. Complete dependency notices and compiler/runtime results belong with the resolved graph and task evidence. These evaluation inputs do not select a production dependency.

## Adapter behavior

`public actor MLXTextRuntime(modelDirectory: URL)` conforms to `TextRuntimeAdapter`. This evaluation arm requires the reviewed Qwen3-0.6B fixture and verifies weight/tokenizer SHA-256 plus configuration Git blob identities before loading. It rejects extra unreviewed safetensors, remote URLs and invalid generation settings, and permits one generation at a time. A fresh prepared input and nil KV cache receive each case, with temperature and seed from the common contract. It disables Qwen3 thinking through the tokenizer's `enable_thinking` context. It treats model output as text and has no tool executor.

The actor retains loaded weights for warm cases and resets history for each case. The evaluation runner measures total request duration. `preparationSeconds` measures the checksum/model/tokenizer-load section; `wasColdLoad` identifies the first case. Warm preparation measures the resident-container check and excludes prompt tokenization. The adapter uses MLX's public `generateTokensTask` raw-token stream. It measures request start to the first emitted token, includes cold preparation when applicable, and joins the generation worker before returning or propagating cancellation. The SDK completion event supplies the generated-token count. Generated text still needs human review for Arabic, Iraqi Arabic, names, dates, evidence and uncertainty.

The [pinned MLX Swift 0.32.3 documentation](https://github.com/ml-explore/mlx-swift/blob/0.32.3/Source/MLX/Documentation.docc/Articles/running-on-ios.md#developing-for-ios) says iOS Simulator lacks the Metal GPU family required to evaluate MLX arrays. The adapter returns an unavailable result before GPU setup on iOS Simulator. Simulator source compilation does not establish simulator generation. The real model run must use an Apple silicon Mac or supported physical iPhone, with each result labeled for that environment.

## Build and run

The optional download tool fetches the reviewed public artifact into `~/Library/Caches/MemoryOS-AI-Evaluation/models/mlx-qwen3-0.6b-4bit-73e3e38d`. It verifies each LFS SHA-256 or Git blob identity and writes `memoryos-asset-manifest.json`. It uses the repository's resumable ranged helper for the large weights/tokenizer. It sends no app records. Weights stay outside Git and app source.

```sh
python3 native/LocalMLXEvaluation/Tools/download-model.py
swift package --package-path native/LocalMLXEvaluation resolve
```

The [upstream README](https://github.com/ml-explore/mlx-swift/blob/0.32.3/README.md#xcodebuild) recommends Xcode for Metal resources. This host's Swift 6.4.2 command defaults to the `swiftbuild` engine and generated a real `default.metallib` during Release tests. Older SwiftPM engines may require `xcodebuild`. Check the compiled resource bundle and run the real model test before claiming usable GPU inference. Xcode builds also verify the iOS targets.

The host executable accepts an explicit local model path and source identity:

```text
mlx-evaluation --model-dir LOCAL_DIRECTORY --source-identity COMMIT_OR_SOURCE_MANIFEST --output REPORT.json
```

The optional `--output` flag writes the report atomically to its own JSON file, so SDK console messages cannot corrupt the report. Without that flag, the executable writes JSON to standard output.

It runs the same 15 fictional cases as the other evaluation configurations with text-only scope. The evaluator marks retrieval as not applicable and gives MLX the same complete source corpus. It labels output as host smoke. It records no phone cost metrics and selects no component winner. Simulator compilation, simulator execution, Mac execution and physical-phone measurements remain separate evidence states.

## Simulator lab integration

The nested `SimulatorAvailability` package depends only on `AIEvaluationCore`. The native lab composes `MLXSimulatorUnavailableRuntime()` from its `MLXSimulatorAvailability` product. Its Simulator compile guard returns the documented unsupported reason; a full-suite test checks blocked generation, absent output and retrieval marked not applicable. The real MLX SDK package remains the host/device integration target.

## Host Metal resource staging

The real host GPU test first exposed a resource lookup failure with this SwiftBuild test runner. The pinned SDK supports a colocated `mlx.metallib` lookup. After building, `Tools/install-host-metal-resource.py --products PRODUCTS_DIRECTORY --receipt RECEIPT.json` copies the actual compiled `default.metallib` to the CLI and test-binary lookup paths. It records hashes in the verification evidence and preserves conflicting files. It does not patch SDK source.

The canonical real-model test passed cold/warm generation, bounded real token counts, first-token timing, cancellation and a successful rerun. The separate OS-network-denied host run completed all fifteen cases. Its launcher receipt records the binary, source, model assets, Metal resource, kernel-denial probe and exit code. The CLI keeps its default `offlineConfirmed=false`; the receipt records external enforcement without editing the raw report.

Canonical evidence uses `mlx-host-canonical-network-denied.json` and `mlx-canonical-real-model-tests.log` under `native/verification/local-ai-step1/resume`. The older `mlx-host-results.json` retains provisional execution on an override with yyjson 0.12.0. The effective versioned Tokenizers manifest requires 0.13.0. All fifteen canonical generated texts match the preserved provisional texts exactly. The separate builder AI review remains distinct from human review and owner acceptance.

The canonical-cache recovery tools verify immutable upstream archives against original commit/tree/blob identities and full Git integrity checks before standard SwiftPM consumes them. The final package uses the generated lockfile and canonical checkouts. Historical snapshot/transport helper source remains in the verification record; it is not current setup.
