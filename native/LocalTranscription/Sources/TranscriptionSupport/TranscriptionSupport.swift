import AVFoundation
import CryptoKit
import Foundation

public enum LocalTranscriptionError: Error, Equatable, Sendable {
  case missingModel(String)
  case invalidModel
  case unsupportedAudio
  case audioTooLong
  case busy
  case inferenceFailed
}

/// Local decoding is shared by both providers so comparisons use identical samples.
public enum TranscriptionPCM {
  public static let sampleRate = 16_000.0
  public static let maximumSeconds = 900.0

  public static func load(_ url: URL) throws -> [Float] {
    try Task.checkCancellation()
    let file: AVAudioFile
    do { file = try AVAudioFile(forReading: url) } catch {
      throw LocalTranscriptionError.unsupportedAudio
    }
    let inputFormat = file.processingFormat
    guard inputFormat.sampleRate > 0, file.length > 0 else {
      throw LocalTranscriptionError.unsupportedAudio
    }
    guard Double(file.length) / inputFormat.sampleRate <= maximumSeconds else {
      throw LocalTranscriptionError.audioTooLong
    }
    guard
      let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate, channels: 1, interleaved: false),
      let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
      let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 8192),
      let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 8192)
    else { throw LocalTranscriptionError.unsupportedAudio }
    // The default remaps channels; explicitly mix stereo imports so neither side is lost.
    converter.downmix = true
    var samples: [Float] = []
    samples.reserveCapacity(Int(Double(file.length) / inputFormat.sampleRate * sampleRate) + 8192)
    var readError: Error?
    var finished = false
    while !finished {
      try Task.checkCancellation()
      var conversionError: NSError?
      let status = converter.convert(to: output, error: &conversionError) { requested, state in
        do {
          if file.framePosition >= file.length {
            state.pointee = .endOfStream
            return nil
          }
          try file.read(into: input, frameCount: min(requested, input.frameCapacity))
          if input.frameLength == 0 {
            state.pointee = .endOfStream
            return nil
          }
          state.pointee = .haveData
          return input
        } catch {
          readError = error
          state.pointee = .endOfStream
          return nil
        }
      }
      guard readError == nil, conversionError == nil, status != .error,
        let channel = output.floatChannelData?[0]
      else { throw LocalTranscriptionError.unsupportedAudio }
      samples.append(
        contentsOf: UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
      guard samples.count <= Int(maximumSeconds * sampleRate) + 8192 else {
        throw LocalTranscriptionError.audioTooLong
      }
      finished = status == .endOfStream
    }
    guard !samples.isEmpty, samples.allSatisfy(\.isFinite) else {
      throw LocalTranscriptionError.unsupportedAudio
    }
    return samples
  }
}

/// Only reviewed assets can reach the native parser. Selection never downloads weights.
public enum WhisperCppModel: String, CaseIterable, Codable, Sendable {
  case tiny
  case smallQ5 = "small-q5_1"

  public var filename: String { "ggml-\(rawValue).bin" }

  public var sha256: String {
    switch self {
    case .tiny: "be07e048e1e599ad46341c8d2a135645097a538221678b7acdd1b1919c6e1b21"
    case .smallQ5: "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
    }
  }

  public var modelID: String { "ggerganov/whisper.cpp/\(filename)@\(sha256)" }
}

public enum TranscriptionModelFiles {
  public static let whisperKitRequired = [
    "AudioEncoder.mlmodelc", "TextDecoder.mlmodelc", "MelSpectrogram.mlmodelc",
    "tokenizer.json", "tokenizer_config.json",
  ]
  public static func validateWhisperKit(_ directory: URL) throws {
    for name in whisperKitRequired {
      guard FileManager.default.fileExists(atPath: directory.appending(path: name).path) else {
        throw LocalTranscriptionError.missingModel(name)
      }
    }
  }
  public static func whisperCppModel(
    _ directory: URL, model: WhisperCppModel = .tiny
  ) throws -> URL {
    let file = directory.appending(path: model.filename)
    guard FileManager.default.fileExists(atPath: file.path) else {
      throw LocalTranscriptionError.missingModel(model.filename)
    }
    let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
    guard values.isRegularFile == true, values.isSymbolicLink != true,
      try TranscriptionModelIdentity.fileSHA256(file) == model.sha256
    else { throw LocalTranscriptionError.invalidModel }
    return file
  }
}

/// Hash actual selected bytes rather than trusting a directory label.
public enum TranscriptionModelIdentity {
  public static func fingerprint(_ directory: URL) throws -> String {
    guard
      let enumerator = FileManager.default.enumerator(
        at: directory,
        includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
        options: [.skipsHiddenFiles])
    else { throw LocalTranscriptionError.invalidModel }
    var entries: [(String, URL)] = []
    var total = 0
    for case let file as URL in enumerator {
      let values = try file.resourceValues(forKeys: [
        .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
      ])
      guard values.isSymbolicLink != true else { throw LocalTranscriptionError.invalidModel }
      guard values.isRegularFile == true else { continue }
      total += values.fileSize ?? 0
      guard total <= 1_073_741_824, entries.count < 512 else {
        throw LocalTranscriptionError.invalidModel
      }
      entries.append((String(file.path.dropFirst(directory.path.count)), file))
    }
    guard !entries.isEmpty else { throw LocalTranscriptionError.invalidModel }
    var digest = SHA256()
    for (path, file) in entries.sorted(by: { $0.0 < $1.0 }) {
      try Task.checkCancellation()
      digest.update(data: Data(path.utf8))
      digest.update(data: Data([0]))
      digest.update(data: Data(try fileSHA256(file).utf8))
      digest.update(data: Data([0]))
    }
    return digest.finalize().map { String(format: "%02x", $0) }.joined()
  }

  public static func fileSHA256(_ file: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: file)
    defer { try? handle.close() }
    var digest = SHA256()
    while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
      try Task.checkCancellation()
      digest.update(data: data)
    }
    return digest.finalize().map { String(format: "%02x", $0) }.joined()
  }
}
