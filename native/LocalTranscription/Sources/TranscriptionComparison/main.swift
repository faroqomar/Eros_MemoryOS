import AudioCore
import Darwin
import Foundation
import TranscriptionSupport
import WhisperCppTranscription
import WhisperKitTranscription

struct CancellationReport: Codable {
  let provider: String
  let modelID: String?
  let audioSHA256: String
  let audioSeconds: Double
  let cancelAfterSeconds: Double
  let cancellationSeconds: Double
  let cancelled: Bool
  let residentBytesBefore: UInt64?
  let residentBytesAtCancellation: UInt64?
  let residentBytesAfter: UInt64?
}

struct ComparisonReport: Codable {
  let provider: String
  let audioSHA256: String
  let audioSeconds: Double
  let elapsedSeconds: Double
  let realTimeFactor: Double
  let processPeakResidentBytes: Int
  let operatingSystem: String
  let modelID: String
  let language: String?
  let decodingConfiguration: String?
  let passages: [TranscriptPassage]
}

@main struct ComparisonCommand {
  static func main() async {
    do { try await run() } catch {
      FileHandle.standardError.write(
        Data("Transcription failed: \(String(reflecting: type(of: error)))\n".utf8))
      exit(1)
    }
  }

  private static func run() async throws {
    let args = CommandLine.arguments
    guard args.count >= 5 else {
      throw NSError(
        domain:
          "Usage: transcription-comparison whisperkit|whisper.cpp MODEL_DIRECTORY AUDIO REPORT_JSON [CANCEL_SECONDS] [--model tiny|small-q5_1] [--language auto|en|ar]",
        code: 1)
    }
    var selectedModel = WhisperCppModel.tiny
    var selectedLanguage = WhisperCppLanguage.automatic
    var cancelDelay: Double?
    var index = 5
    var suppliedOptions: Set<String> = []
    while index < args.count {
      let option = args[index]
      if option == "--model" || option == "--language" {
        guard args[1] == "whisper.cpp", index + 1 < args.count,
          suppliedOptions.insert(option).inserted
        else { throw LocalTranscriptionError.invalidModel }
        if option == "--model" {
          guard let value = WhisperCppModel(rawValue: args[index + 1]) else {
            throw LocalTranscriptionError.invalidModel
          }
          selectedModel = value
        } else {
          guard let value = WhisperCppLanguage(rawValue: args[index + 1]) else {
            throw LocalTranscriptionError.invalidModel
          }
          selectedLanguage = value
        }
        index += 2
      } else {
        guard index == 5, let delay = Double(option), delay > 0, delay <= 30 else {
          throw LocalTranscriptionError.invalidModel
        }
        cancelDelay = delay
        index += 1
      }
    }
    let provider: any TranscriptionProvider
    switch args[1] {
    case "whisperkit": provider = WhisperKitTranscriber()
    case "whisper.cpp":
      provider = WhisperCppTranscriber(model: selectedModel, language: selectedLanguage)
    default: throw LocalTranscriptionError.invalidModel
    }
    let model = URL(fileURLWithPath: args[2], isDirectory: true)
    let audio = URL(fileURLWithPath: args[3])
    let duration = Double(try TranscriptionPCM.load(audio).count) / TranscriptionPCM.sampleRate
    let hash = try TranscriptionModelIdentity.fileSHA256(audio)
    if let delay = cancelDelay {
      let residentBefore = residentBytes()
      let task = Task { try await provider.transcribe(audioURL: audio, modelDirectory: model) }
      try await Task.sleep(for: .seconds(delay))
      let residentAtCancellation = residentBytes()
      let requested = Date()
      task.cancel()
      do {
        _ = try await task.value
        throw LocalTranscriptionError.inferenceFailed
      } catch is CancellationError {
        let report = CancellationReport(
          provider: provider.id,
          modelID: provider.id == "whisper.cpp" ? selectedModel.modelID : nil,
          audioSHA256: hash,
          audioSeconds: duration, cancelAfterSeconds: delay,
          cancellationSeconds: Date().timeIntervalSince(requested), cancelled: true,
          residentBytesBefore: residentBefore,
          residentBytesAtCancellation: residentAtCancellation,
          residentBytesAfter: residentBytes())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: URL(fileURLWithPath: args[4]), options: .atomic)
        print("Cancelled \(provider.id)")
        return
      }
    }
    let start = Date()
    let result = try await provider.transcribe(audioURL: audio, modelDirectory: model)
    try AudioValidation.passages(result.passages, duration: duration)
    let elapsed = Date().timeIntervalSince(start)
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    let report = ComparisonReport(
      provider: provider.id, audioSHA256: hash,
      audioSeconds: duration, elapsedSeconds: elapsed, realTimeFactor: elapsed / duration,
      processPeakResidentBytes: Int(usage.ru_maxrss),
      operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
      modelID: result.modelID, language: result.language,
      decodingConfiguration: provider.id == "whisper.cpp"
        ? "greedy;language=\(selectedLanguage.rawValue);temperature=0;temperatureIncrement=0;noContext=true;gpu=false;threads=\(min(4, max(1, ProcessInfo.processInfo.activeProcessorCount)))"
        : nil,
      passages: result.passages)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(report).write(to: URL(fileURLWithPath: args[4]), options: .atomic)
    print("Completed \(provider.id): \(String(format: "%.2f", elapsed)) seconds")
  }

  /// RSS observations include allocator/cache behavior; they do not prove absence of leaks.
  private static func residentBytes() -> UInt64? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
      MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
      }
    }
    return result == KERN_SUCCESS ? info.resident_size : nil
  }
}
