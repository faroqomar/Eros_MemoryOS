import AVFoundation
import Foundation
import Testing
import TranscriptionSupport
import WhisperCppTranscription
import WhisperKitTranscription

@Test func absentModelFailsBeforeAudioOrNetwork() async throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  await #expect(throws: LocalTranscriptionError.missingModel("AudioEncoder.mlmodelc")) {
    try await WhisperKitTranscriber().transcribe(audioURL: folder, modelDirectory: folder)
  }
  await #expect(throws: LocalTranscriptionError.missingModel("ggml-tiny.bin")) {
    try await WhisperCppTranscriber().transcribe(audioURL: folder, modelDirectory: folder)
  }
}

@Test func corruptedCppAssetRejectedBeforeNativeParser() async throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  try Data("corrupt".utf8).write(to: folder.appending(path: "ggml-tiny.bin"))
  await #expect(throws: LocalTranscriptionError.invalidModel) {
    try await WhisperCppTranscriber().transcribe(audioURL: folder, modelDirectory: folder)
  }
}

@Test(arguments: WhisperCppModel.allCases)
func selectedCppModelRejectsChangedBytesBeforeNativeParser(model: WhisperCppModel) async throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  try Data("corrupt".utf8).write(to: folder.appending(path: model.filename))
  await #expect(throws: LocalTranscriptionError.invalidModel) {
    try await WhisperCppTranscriber(model: model).transcribe(
      audioURL: folder, modelDirectory: folder)
  }
}

@Test func modelSelectionDoesNotSilentlyChangeDefaultOrFallBack() async throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  try Data("unselected".utf8).write(to: folder.appending(path: "ggml-small-q5_1.bin"))
  await #expect(throws: LocalTranscriptionError.missingModel("ggml-tiny.bin")) {
    try await WhisperCppTranscriber().transcribe(audioURL: folder, modelDirectory: folder)
  }
  try FileManager.default.removeItem(at: folder.appending(path: "ggml-small-q5_1.bin"))
  try Data("unselected".utf8).write(to: folder.appending(path: "ggml-tiny.bin"))
  await #expect(throws: LocalTranscriptionError.missingModel("ggml-small-q5_1.bin")) {
    try await WhisperCppTranscriber(model: .smallQ5).transcribe(
      audioURL: folder, modelDirectory: folder)
  }
}

@Test func corruptedWhisperKitAssetsRejectedBeforeModelLoad() throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  for name in TranscriptionModelFiles.whisperKitRequired {
    try Data("corrupt".utf8).write(to: folder.appending(path: name))
  }
  #expect(throws: LocalTranscriptionError.invalidModel) {
    try WhisperKitTranscriber.validateModel(directory: folder)
  }
}

@Test func fingerprintTracksContentAndRejectsSymlink() throws {
  let folder = URL.temporaryDirectory.appending(path: UUID().uuidString)
  try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? FileManager.default.removeItem(at: folder) }
  let file = folder.appending(path: "tokenizer.json")
  try Data("first".utf8).write(to: file)
  let first = try TranscriptionModelIdentity.fingerprint(folder)
  try Data("other".utf8).write(to: file)
  #expect(try TranscriptionModelIdentity.fingerprint(folder) != first)
  try FileManager.default.createSymbolicLink(
    at: folder.appending(path: "link"), withDestinationURL: file)
  #expect(throws: LocalTranscriptionError.invalidModel) {
    try TranscriptionModelIdentity.fingerprint(folder)
  }
}

@Test func damagedAudioReportsDecodeFailure() throws {
  let file = URL.temporaryDirectory.appending(path: "\(UUID()).wav")
  try Data("not-audio".utf8).write(to: file)
  defer { try? FileManager.default.removeItem(at: file) }
  #expect(throws: LocalTranscriptionError.unsupportedAudio) { try TranscriptionPCM.load(file) }
}

@Test func commonDecoderResamplesStereoToIdenticalMonoSamples() throws {
  let file = URL.temporaryDirectory.appending(path: "\(UUID()).wav")
  defer { try? FileManager.default.removeItem(at: file) }
  let format = try #require(
    AVAudioFormat(
      commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
      channels: 2, interleaved: false))
  let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 48_000))
  buffer.frameLength = buffer.frameCapacity
  for channel in 0..<2 {
    for frame in 0..<48_000 {
      buffer.floatChannelData?[channel][frame] =
        Float(sin(Double(frame) * 440 * 2 * .pi / 48_000)) * 0.2
    }
  }
  do {
    let output = try AVAudioFile(forWriting: file, settings: format.settings)
    try output.write(from: buffer)
  }
  let samples = try TranscriptionPCM.load(file)
  #expect(abs(samples.count - 16_000) < 10)
  #expect(samples.allSatisfy { $0.isFinite })
  #expect(samples.contains { abs($0) > 0.1 })
  #expect(try TranscriptionPCM.load(file) == samples)
}
