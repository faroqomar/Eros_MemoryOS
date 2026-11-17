# Local transcription adapters

Experimental local integration. These models do not have production acceptance.

`WhisperKitTranscriber()` and `WhisperCppTranscriber()` implement AudioCore's
`TranscriptionProvider`. The product names are `WhisperKitTranscription` and
`WhisperCppTranscription`; provider IDs are `whisperkit` and `whisper.cpp`.
Voice chat packages the reviewed multilingual small Q5_1 whisper.cpp model for offline use.
The library also supports explicit local model-folder import. Runtime inference has
no model download or remote transcription fallback.

The Xcode build phase runs `scripts/bundle-speech-model.py`, verifies the pinned
SHA-256, and copies only the selected model into `SpeechModels/ggml-small-q5_1.bin`.
Set `MEMORYOS_SPEECH_MODEL` to the prepared file when its local path differs.
The default is `~/Dev/Tools/MemoryOS-Evaluation-Upstream/transcription-models/whisper-small-q5/ggml-small-q5_1.bin`.
A missing or changed model fails the build with preparation instructions. Weights
stay outside Git; the app includes the OpenAI Whisper MIT notice. Bundling this
experimental model does not establish natural Iraqi Arabic accuracy.

Prepare this asset explicitly with `python3 scripts/prepare-transcription-models.py /path/to/models --cpp-model small-q5_1`.
`MEMORYOS_SPEECH_MODEL_KIND` selects the build validator and generated `SpeechModels/model-kind.txt`
manifest; composition uses that same value. Imported folders are indexed per
model, so old tiny imports remain intact without overriding the upgrade. Existing
chat text remains its historical snapshot. Use Recordings → Transcribe to append a
fresh transcript for saved audio; ordinary chat retry reuses its existing result.

## Reproduce

1. Run `python3 scripts/prepare-transcription-framework.py` from the repository root.
2. Run `python3 scripts/prepare-transcription-models.py /path/to/models` explicitly.
3. Run `python3 scripts/prepare-transcription-fixtures.py` for fictional local TTS.
4. Run `python3 scripts/run-transcription-comparison.py /path/to/models native/verification/audio-step1/fixtures /path/to/results`.
5. Run `swift test --package-path native/LocalTranscription`.

The comparison launches a fresh host process for each case/provider/repetition.
It measures elapsed load+inference time, audio duration, real-time factor and
process peak resident bytes. OS/CoreML caches persist across processes. The
normalized word-error rate uses NFKC, Unicode word tokens and case folding. It
does not normalize Arabic spelling or dialect. Synthetic Iraqi wording does
not qualify natural Iraqi accents or human code switching.

## Boundaries and assets

- Argmax OSS / WhisperKit v1.1.1: `1bbc57cb7fe6410248a685b1c5a3c6d56adc2ed4`.
- whisper.cpp v1.9.5: `d1be6fde11ac6e0407606b4e42fe72d34add8037`; official b5454
  XCFramework SHA-256 `e57f8c48933000acabc13bb913fbe82805d483a2deff692cc6738836bd92393b`.
- WhisperKit folder: `AudioEncoder.mlmodelc`, `TextDecoder.mlmodelc`,
  `MelSpectrogram.mlmodelc`, `tokenizer.json`, and `tokenizer_config.json`.
  Import and runtime require the reviewed multilingual tiny fingerprint
  `e2cfb4a0a36d03e2f7f88bbea36fc251919d67d8663c54bfd6c4a4ed85664c0e`.
  The model store validates copied content before switching the active pointer;
  rejected replacements preserve the previous model.
- whisper.cpp folder: `ggml-tiny.bin`, with required SHA-256
  `be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21`.
- Voice-chat upgrade: `ggml-small-q5_1.bin`, 190,085,487 bytes, required SHA-256
  `ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb`, from
  [pinned upstream assets](https://huggingface.co/ggerganov/whisper.cpp/tree/5359861c739e955e79d9a303bcbc70fb988958b1).
  The package/CLI default remains tiny for reproducible earlier comparisons;
  select `--model small-q5_1 --language auto` explicitly in the comparison CLI.
- Preparation pins all model/tokenizer repository revisions and verifies remote
  content hashes. It writes a local receipt. Model files stay outside Git.
- Both adapters use the same local mono 16 kHz PCM decoder. Inference limits audio
  to 15 minutes per operation. Saving longer recordings does not promise they can
  be transcribed in one operation. No translation or speaker identification runs.
- WhisperKit's upstream tokenizer loader can fall back to a remote download.
  This adapter preloads the tokenizer through its local-folder API and injects it
  before model loading. Invalid local tokenizers fail without that fallback.
- The whisper framework uses dynamic two-level namespaces but exports GGML
  internals. The chat engine must use its own dynamic framework with private
  GGML/GGUF symbols; static llama linkage caused an actual phone crash.
  `scripts/check-inference-linkage.py` checks the built app, and
  `scripts/check-inference-coexistence.py` loads and decodes with both engines.

Upstream licenses: Argmax and whisper.cpp use MIT. Argmax bundles Hugging Face
Swift Transformers components under Apache-2.0 (see upstream `NOTICES`), and its
CLI manifest references Apple's Swift Argument Parser under Apache-2.0. The app
links WhisperKit, not the server/TTS/speaker products. Preserve upstream notices
when distributing; this task does not authorize distribution. OpenAI Whisper
weights/tokenizer use MIT as stated by the upstream model card.

Primary sources: [Argmax v1.1.1](https://github.com/argmaxinc/argmax-oss-swift/tree/v1.1.1),
[whisper.cpp v1.9.5](https://github.com/ggml-org/whisper.cpp/tree/v1.9.5),
[OpenAI Whisper](https://github.com/openai/whisper), and
[CoreML model repository](https://huggingface.co/argmaxinc/whisperkit-coreml).

## Builder checks, 2026-11-15

On an Apple M1 Pro host with macOS 27.2.1 / Xcode 27.2, all five package tests pass.
Release comparison completed 30 operations: five fictional recordings, two
engines, three fresh processes each. Each inference process denied network
operations through the macOS sandbox and passed the app's timestamp/transcript
validation. Results remain host evidence, not iPhone performance or acceptance.

| Fixture | WhisperKit median seconds / WER | whisper.cpp median seconds / WER |
| --- | --- | --- |
| English | 1.230 / 18.8% | 0.634 / 18.8% |
| Iraqi wording, synthetic Arabic voice | 1.187 / 54.5% | 0.737 / 54.5% |
| Mixed speech | 1.149 / 83.3% | 0.663 / 83.3% |
| Names | 0.974 / 0% | 0.503 / 0% |
| Background noise | 0.979 / 37.5% | 0.434 / 25.0% |

The first WhisperKit specialization run took 11.851 seconds. Maximum process
resident peaks were 211.9 MiB for WhisperKit and 301.3 MiB for whisper.cpp.
A 600.49-second repeated fictional recording, cancelled one second after starting
the provider call, returned CancellationError after 0.104 seconds (WhisperKit)
and 1.317 seconds (whisper.cpp) from the cancellation request. This probe does
not establish termination recovery, background behavior, or physical call handling.

Both models need correction, particularly on synthetic Iraqi wording and mixed
speech. No production model is selected. Uncertainty flags use uncalibrated
heuristics (word probability below 0.6; additional passage thresholds); absence
of a flag does not establish correctness or a confirmed fact. Speakers remain
unknown until the user supplies a label.

Ignored task diagnostics live under `native/verification/audio-step1/` from the
repository root. The main task record owns retained evidence and later-stage
status. The preparation receipt records all 22 model files (157,090,259 bytes).
The final package resolves canonical upstream URLs and exact revisions; a
verified shallow upstream cache avoided stalled full-history Git transfers.
No source override or upstream patch remains in the package configuration.

## Voice-chat quality repair, 2026-11-17

The owner reported poor English recognition despite clear microphone playback.
The same five immutable fictional fixtures were compared with tiny and small Q5_1,
three fresh CPU-only processes each, four threads, greedy decoding, automatic
language, temperature zero and no temperature fallback. English WER fell from
18.75% to 6.25%; noise from 25% to 6.25%. The remaining English difference was
numeric formatting. Names stayed exact; synthetic Iraqi wording and mixed speech
improved but still fail the existing quality targets. See the
[current task](../../docs/tasks/2026-11-17-voice-chat.md) for timings, memory,
cancellation, native checks and phone status. This selects a bounded app upgrade,
not production qualification or a new WhisperKit-versus-whisper.cpp result.

PCM now enables AVAudioConverter downmix explicitly: its default remapped stereo
to the left channel. Regression cases cover exact mono capture bytes and stereo
mixing/resampling without changing source files. This separate import defect did
not affect the owner's mono microphone format or the mono comparison fixtures.
