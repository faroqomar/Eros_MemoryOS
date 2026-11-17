import AVFoundation
import CryptoKit
import Foundation
import Testing
import TranscriptionSupport

struct RecordingPCMTests {
  @Test(arguments: [1, 129, 8191, 8192, 8193, 32_173])
  func recorderCAFDecodesEveryInt16SampleWithoutChangingSource(frameCount: Int) throws {
    let url = URL.temporaryDirectory.appending(path: "\(UUID()).caf")
    defer { try? FileManager.default.removeItem(at: url) }
    let format = try #require(
      AVAudioFormat(
        commonFormat: .pcmFormatInt16, sampleRate: 16_000,
        channels: 1, interleaved: true))
    let buffer = try #require(
      AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)))
    buffer.frameLength = buffer.frameCapacity
    let channel = try #require(buffer.int16ChannelData?[0])
    var expected: [Float] = []
    for frame in 0..<frameCount {
      // An integer ramp catches lost, repeated or reordered samples across decoder buffers.
      let sample = Int16(truncatingIfNeeded: frame * 977 - 32_768)
      channel[frame] = sample
      expected.append(Float(sample) / 32_768)
    }
    do {
      let file = try AVAudioFile(
        forWriting: url, settings: format.settings,
        commonFormat: .pcmFormatInt16, interleaved: true)
      try file.write(from: buffer)
    }
    let originalHash = try SHA256.hash(data: Data(contentsOf: url))

    let decoded = try TranscriptionPCM.load(url)

    #expect(decoded.count == frameCount)
    #expect(decoded == expected)
    #expect(try SHA256.hash(data: Data(contentsOf: url)) == originalHash)
  }

  @Test(arguments: [44_100.0, 48_000.0])
  func stereoResamplingPreservesDurationAmplitudeAndSource(sampleRate: Double) throws {
    let url = URL.temporaryDirectory.appending(path: "\(UUID()).caf")
    defer { try? FileManager.default.removeItem(at: url) }
    let frameCount = Int(sampleRate * 2.137)
    let format = try #require(
      AVAudioFormat(
        commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
        channels: 2, interleaved: false))
    let buffer = try #require(
      AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)))
    buffer.frameLength = buffer.frameCapacity
    let channels = try #require(buffer.floatChannelData)
    for frame in 0..<frameCount {
      let wave = Float(sin(Double(frame) * 440 * 2 * .pi / sampleRate))
      channels[0][frame] = wave * 0.6
      channels[1][frame] = wave * 0.2
    }
    do {
      var settings = format.settings
      settings[AVLinearPCMIsNonInterleaved] = false
      let file = try AVAudioFile(forWriting: url, settings: settings)
      try file.write(from: buffer)
    }
    let originalHash = try SHA256.hash(data: Data(contentsOf: url))

    let decoded = try TranscriptionPCM.load(url)

    let expectedCount = Int(Double(frameCount) / sampleRate * 16_000)
    #expect(abs(decoded.count - expectedCount) <= 2)
    #expect(decoded.allSatisfy { $0.isFinite })
    try #require(decoded.count > 400)
    // Exclude filter transients. Averaging the two channels yields amplitude 0.4.
    let steady = Array(decoded.dropFirst(200).dropLast(200))
    let rms = sqrt(steady.reduce(0.0) { $0 + Double($1 * $1) } / Double(steady.count))
    #expect(abs(rms - 0.4 / sqrt(2)) < 0.002, "Measured RMS: \(rms)")
    let cycles = zip(steady, steady.dropFirst()).filter { $0 <= 0 && $1 > 0 }.count
    let frequency = Double(cycles) / (Double(steady.count) / 16_000)
    #expect(abs(frequency - 440) < 1)
    #expect(try SHA256.hash(data: Data(contentsOf: url)) == originalHash)
  }
}
