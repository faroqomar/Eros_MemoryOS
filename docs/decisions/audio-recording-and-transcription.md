# Local audio recording and transcription options

Recorded on 2026-11-07. Owner source: C08 in the [source register](../reference/source-register.md).

## Decision and status

**Confirmed:** Document WhisperKit and whisper.cpp as local transcription candidates. Document AVAudioRecorder as the candidate component for recording new audio in Swift.

The owner requested these options in the documentation. This does not select a final engine, model, app framework, or implementation stage. This was the 2026-11-07 research status. The group 6 implementation update below supersedes its integration claim; physical-phone benchmarks remain open.

**Assistant recommendation:** Evaluate WhisperKit first and whisper.cpp as an alternative. Keep recording, transcription, runtime memory, and text-model execution separate so each component can change independently.

## Components

### AVAudioRecorder: record new audio

Apple provides AVAudioRecorder in AVFAudio. It records the microphone input to a file and supports pause, resume, and recording-level measurements. The app must obtain microphone permission and configure its audio session.

AVAudioRecorder does not convert speech into text. Imported voice notes already contain audio; they do not need to be recorded again.

Source: [Apple AVAudioRecorder documentation](https://developer.apple.com/documentation/avfaudio/avaudiorecorder).

### WhisperKit: local transcription candidate

WhisperKit is part of the Argmax open-source Swift package. It runs speech recognition on-device and can transcribe local audio files. Its examples include WAV, MP3, M4A, and FLAC files. The exact decoder and model compatibility must be checked in the app.

After obtaining the model files, the proposed workflow must transcribe without a network connection. Model downloads and runtime transcription are separate operations.

Source: [WhisperKit repository, examples, and model choices](https://github.com/argmaxinc/argmax-oss-swift#whisperkit).

### whisper.cpp: alternative local transcription candidate

whisper.cpp provides local Whisper inference, a Swift package binding, an Apple XCFramework, and a SwiftUI example. Evaluate its integration and performance against WhisperKit using the same recordings.

Sources: [whisper.cpp](https://github.com/ggml-org/whisper.cpp), [Swift package](https://github.com/ggml-org/whisper.spm), [SwiftUI example](https://github.com/ggml-org/whisper.cpp/tree/master/examples/whisper.swiftui).

## Arabic and English

Both transcription candidates can run multilingual Whisper models. Whisper includes Arabic and English. Models ending in `.en` support English only and do not meet the Arabic requirement.

Language support does not establish acceptable accuracy. Test Iraqi Arabic, mixed Arabic/English speech, names, dates, quiet speech, and background noise on the iPhone 15 Pro Max. Keep transcription in the source language; translation is a separate choice.

Source: [Whisper language definitions](https://github.com/openai/whisper/blob/main/whisper/tokenizer.py).

## Proposed workflow for recordings and imported conversations

1. Save the new recording or import the actual voice-note file. A text-only chat export may omit its media; report missing files rather than inventing transcripts.
2. Preserve the original audio and available message ID, sender, conversation, and date links. Determine supported chat exports and audio codecs during implementation.
3. Decode or convert an unsupported format locally when possible. Keep the original file. Do not assume every OGG/Opus or other chat format works directly with either engine.
4. Queue transcription jobs. Show queued, running, completed, interrupted, and failed states. Plan resumable processing for large imports and long recordings.
5. Save timestamped, editable text linked to the audio. Record the engine, model/version, language settings, and transcript revision. Preserve earlier results when comparing engines.
6. Send selected transcript text to the separate memory layer for organization and retrieval. Changing between Wax and a Cactus-based memory configuration should not require changing the recording component.

The queue, transcript versions, format conversion, and engine-switching interface are design proposals. They are not implemented features. Speaker identification and multi-speaker separation remain separate questions; a chat sender label does not prove who speaks in an attached recording.

## Proposed device checks

- Download the required models, enable airplane mode, record audio, and transcribe imported audio locally.
- Compare both engines on the same fictional Arabic, English, and mixed-language recordings. Record model and decoding settings.
- Verify source links, timestamps, edits, transcript versions, and restart behavior.
- Check interruption recovery and missing or unsupported audio files without losing originals or duplicating records.
- Measure accuracy, response time, app memory, storage, battery use, and heat. Set numeric targets after reviewing initial measurements.

At the time of the original research, no test result existed. See the current task for later evidence. Keep cloud transcription an explicit separate choice; do not add a silent network fallback.

Related records: [feature register](../feature-register.md), [decision register](decision-register.md), [runtime memory options](runtime-memory-options.md).

## Group 6 Step 1 implementation, 2026-11-15

The owner now authorizes recording, import, local transcription comparison, review, source links, export and interruption recovery. This supersedes the earlier no-implementation status for this bounded task. See the [current task and builder evidence](../tasks/2026-11-15-voice-transcription.md); earlier research above remains historical.

The implementation uses AVAudioRecorder for 16 kHz mono PCM CAF capture. Recording and import accept up to 250 MiB and two hours; the initial local transcription adapters accept up to 15 minutes to bound decoded memory. Imported WAV, M4A, MP3, AIFF, CAF and FLAC files must pass actual local decoding. Container extensions alone do not establish codec support.

MemoryOS owns a separate version-1 audio library, immutable saved audio hashes, stable recording/person/source UUIDs, original engine passages, timestamp/uncertainty evidence and appended corrections. A plain Swift domain target separates these records from the atomic file repository and SDK adapters. Transcript JSON exports retain associations and history; they do not replace an audio backup. Existing text-record archives remain their own format. Automatic backup, complete audio archive restore and production data-policy approval remain open.

Models enter through an explicit local folder import. Runtime transcription has no cloud fallback. Both adapters preserve the spoken language and unknown speaker status; neither establishes diarization or speaker identity. Model fingerprints and separate engine results support comparison without selecting a production engine/model. Reopening marks unfinished recording and transcription jobs interrupted; users recover written audio or restart transcription. Processing restarts from the original after interruption; it does not claim resumable inference checkpoints.

Apple references checked for implementation: [AVAudioRecorder](https://developer.apple.com/documentation/avfaudio/avaudiorecorder), [microphone permission](https://developer.apple.com/documentation/avfaudio/avaudioapplication/requestrecordpermission(completionhandler:)), and [audio interruptions](https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions). The task record distinguishes current builder results, independent verification, natural Iraqi speech qualification and physical-device checks.

## Voice-to-chat follow-up, 2026-11-17

Home now saves a recording before creating its conversation. The user message retains audio playback and an expandable transcript; local AI answers from that transcript, and follow-ups stay together. Voice chat bundles the pinned multilingual small Q5_1 whisper.cpp candidate, with explicit local import still available. The measured English repair and owner phone acceptance do not qualify natural Iraqi/mixed accuracy or device cost. See the [current task](../tasks/2026-11-17-voice-chat.md). The research-only wording above describes the earlier checkpoint.
