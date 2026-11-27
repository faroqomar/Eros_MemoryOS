import AudioCore
import MemoryCore
import SwiftUI
import UniformTypeIdentifiers

struct AudioLibraryView: View {
  @Bindable var model: AudioViewModel
  let records: LocalRecordsViewModel
  let language: AppLanguage
  var embedded = false
  var chatBusy = false
  var startChat: ((AudioRecording) async -> Bool)?
  @Environment(\.dismiss) private var dismiss
  @Environment(\.dynamicTypeSize) private var typeSize
  @State private var importing = false
  @State private var importingModel = false

  var body: some View {
    Group {
      if embedded {
        libraryContent
      } else {
        NavigationStack { libraryContent }
      }
    }
    .environment(\.layoutDirection, language == .arabic ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: language.rawValue))
    .preferredColorScheme(.dark)
    .onDisappear { Task { await model.leaveCapture() } }
  }

  private var transcriptionSettings: some View {
    Section {
      Text(language.text("Local transcription", "التفريغ النصي المحلي"))
        .font(.headline).fixedSize(horizontal: false, vertical: true)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("audio-transcription-heading")
      Picker(
        language.text("Transcription engine", "محرك التفريغ النصي"), selection: $model.engine
      ) {
        ForEach(model.engines, id: \.self) { Text($0).tag($0) }
      }.disabled(model.isProcessing || model.busy)
      Text(
        language.text(
          "Voice chats use the bundled multilingual speech model. You can import a model folder for the selected engine here. Transcription supports recordings up to 15 minutes and runs on this device.",
          "تستخدم المحادثات الصوتية نموذج الصوت متعدد اللغات المضمّن. يمكنك استيراد مجلد نموذج للمحرك المحدد هنا. يدعم التفريغ تسجيلات حتى 15 دقيقة ويعمل على هذا الجهاز."
        )
      )
      .font(.footnote).foregroundStyle(MemoryTheme.secondary)
      Button {
        importingModel = true
      } label: {
        Text(language.text("Import model folder", "استيراد مجلد النموذج"))
          .font(.body).fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .disabled(model.isProcessing || model.busy).accessibilityIdentifier("audio-model-import")
      if model.modelInstalled {
        Text(
          language.text(
            "Model folder saved. Open a recording to transcribe.",
            "حُفظ مجلد النموذج. افتح تسجيلاً لتفريغه نصياً.")
        ).font(.footnote)
      }
    }
  }

  private var libraryContent: some View {
    List {
      if let failure = model.failure {
        Section {
          Label(audioMessage(failure, language: language), systemImage: "exclamationmark.circle")
            .foregroundStyle(.primary)
            .accessibilityIdentifier("audio-error")
          Button(language.text("Dismiss message", "إغلاق الرسالة")) { model.dismissFailure() }
          if !model.hasLoaded {
            Button(language.text("Reload recordings", "إعادة تحميل التسجيلات")) {
              Task { await model.load() }
            }
          }
        }
      }
      Section(language.text("Voice capture", "التسجيل الصوتي")) {
        TextField(
          language.text("Recording title", "عنوان التسجيل"), text: $model.title,
          prompt: Text(language.text("Recording title", "عنوان التسجيل"))
            .foregroundStyle(MemoryTheme.secondary)
        )
        .disabled(model.draftID != nil).accessibilityIdentifier("audio-title")
        if model.draftID == nil {
          Text(
            language.text(
              "Record on this device. Leaving the app stops the recording.",
              "سجّل على هذا الجهاز. يتوقف التسجيل عند مغادرة التطبيق."
            )
          )
          .font(.footnote).foregroundStyle(MemoryTheme.secondary)
          Button {
            Task { await model.start(defaultTitle: language.text("Voice note", "ملاحظة صوتية")) }
          } label: {
            Label(language.text("Start recording", "بدء التسجيل"), systemImage: "mic")
              .font(.body).fixedSize(horizontal: false, vertical: true)
              .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
          }
          .disabled(!model.canStart || chatBusy).accessibilityIdentifier("audio-start")
        } else {
          Label(
            captureLabel,
            systemImage: model.captureState.state == .recording ? "record.circle" : "pause.circle"
          )
          .foregroundStyle(model.captureState.state == .recording ? .red : .primary)
          .accessibilityIdentifier("audio-state")
          Text(
            Duration.seconds(model.captureState.elapsedSeconds).formatted(
              .time(pattern: .minuteSecond))
          )
          .font(.title.monospacedDigit()).accessibilityIdentifier("audio-elapsed")
          if model.captureState.state == .recording {
            Button(language.text("Pause", "إيقاف مؤقت")) { Task { await model.pause() } }
              .accessibilityIdentifier("audio-pause")
          } else if model.captureState.state == .paused {
            Button(language.text("Resume", "متابعة")) { Task { await model.resume() } }
              .accessibilityIdentifier("audio-resume")
          }
          Button(language.text("Save recording", "حفظ التسجيل")) { Task { await model.save() } }
            .accessibilityIdentifier("audio-save")
          Button(
            language.text(
              "Keep unfinished recording for later", "الاحتفاظ بالتسجيل غير المكتمل لوقت لاحق")
          ) {
            Task { await model.keepForLater() }
          }
        }
        Button {
          importing = true
        } label: {
          Label(
            language.text("Import audio", "استيراد صوت"), systemImage: "square.and.arrow.down"
          )
          .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }.disabled(model.busy || model.draftID != nil || model.isProcessing)
          .accessibilityIdentifier("audio-import")
        DisclosureGroup(language.text("Audio formats and limits", "تنسيقات الصوت والحدود")) {
          Text(
            language.text(
              "WAV, M4A, MP3, AIFF, CAF and FLAC. Up to 250 MB and 2 hours.",
              "WAV وM4A وMP3 وAIFF وCAF وFLAC. حتى 250 ميغابايت وساعتين."
            )
          )
          .font(.callout)
          .foregroundStyle(MemoryTheme.secondary)
        }
      }
      if model.busy { ProgressView(language.text("Saving or loading…", "حفظ أو تحميل…")) }
      if typeSize.isAccessibilitySize { transcriptionSettings }
      Section(language.text("Recordings", "التسجيلات")) {
        if model.hasLoaded && model.recordings.isEmpty {
          Text(
            language.text(
              "Record a thought or import an audio file to begin.",
              "سجّل فكرة أو استورد ملفاً صوتياً للبدء.")
          ).foregroundStyle(MemoryTheme.secondary)
        }
        ForEach(model.recordings) { recording in
          NavigationLink {
            AudioRecordingDetail(
              model: model, records: records, recordingID: recording.id, language: language)
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              Text(recording.title).font(.headline)
              Text(recording.createdAt, style: .date)
                .font(.subheadline)
                .foregroundStyle(MemoryTheme.secondary)
              if let seconds = recording.durationSeconds {
                Text(Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond)))
                  .font(.caption.monospacedDigit())
                  .foregroundStyle(MemoryTheme.secondary)
              }
              if recording.state != .saved {
                Text(
                  language.text(
                    "Unfinished recording · review and save", "تسجيل غير مكتمل · راجعه واحفظه")
                )
                .font(.caption)
              }
            }.padding(.vertical, 4)
          }.accessibilityIdentifier("audio-recording-\(recording.id)")
          if recording.state == .saved, let startChat {
            Button {
              Task {
                if await startChat(recording), !embedded { dismiss() }
              }
            } label: {
              Label(
                language.text("Start chat from recording", "بدء محادثة من التسجيل"),
                systemImage: "bubble.left.and.bubble.right")
            }
            .disabled(chatBusy || model.busy || model.isProcessing || model.draftID != nil)
            .accessibilityIdentifier("audio-start-chat-\(recording.id)")
          }
        }
      }
      if !typeSize.isAccessibilitySize { transcriptionSettings }
    }
    .accessibilityIdentifier("audio-library-list")
    .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
    .navigationTitle(language.text("Voice notes", "الملاحظات الصوتية"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbarBackground(MemoryTheme.canvas, for: .navigationBar)
    .toolbarBackground(.visible, for: .navigationBar)
    .toolbar {
      if !embedded {
        ToolbarItem(placement: .confirmationAction) {
          Button {
            model.stopPlayback()
            dismiss()
          } label: {
            Image(systemName: "checkmark")
              .font(.body.weight(.semibold))
              .frame(minWidth: 44, minHeight: 44)
              .background(MemoryTheme.ink, in: Circle())
          }
          .buttonStyle(.plain)
          .foregroundStyle(MemoryTheme.onFilledControl)
          .accessibilityLabel(language.text("Done", "تم"))
          .accessibilityShowsLargeContentViewer {
            Label(language.text("Done", "تم"), systemImage: "checkmark")
          }
          .disabled(model.draftID != nil || model.busy)
        }
      }
    }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.audio, .data]) { result in
      Task { await model.importAudio(result) }
    }
    .fileImporter(isPresented: $importingModel, allowedContentTypes: [.folder]) { result in
      Task { await model.installModel(result) }
    }
    .task { await model.load() }
    .interactiveDismissDisabled(model.draftID != nil || model.busy)
  }

  private var captureLabel: String {
    switch model.captureState.state {
    case .recording: language.text("Recording", "جارٍ التسجيل")
    case .paused: language.text("Paused", "متوقف مؤقتاً")
    case .interrupted:
      language.text("Interrupted. Save the captured audio.", "انقطع التسجيل. احفظ الصوت المسجّل.")
    case .failed:
      language.text(
        "Recording stopped. Try saving the captured audio.", "توقف التسجيل. جرّب حفظ الصوت المسجّل.")
    default: language.text("Ready to save", "جاهز للحفظ")
    }
  }
}

private struct AudioRecordingDetail: View {
  @Bindable var model: AudioViewModel
  let records: LocalRecordsViewModel
  let recordingID: UUID
  let language: AppLanguage
  @State private var editing: PassageEdit?
  @State private var exporting = false
  @Environment(\.dynamicTypeSize) private var typeSize
  private var recording: AudioRecording? {
    model.snapshot.recordings.first { $0.id == recordingID }
  }
  private var transcripts: [AudioTranscript] {
    model.snapshot.transcripts.filter { $0.recordingID == recordingID }
  }

  var body: some View {
    List {
      if let recording {
        Section(language.text("Playback and transcription", "التشغيل والتفريغ النصي")) {
          Button(language.text("Play original audio", "تشغيل الصوت الأصلي")) {
            Task { await model.play(id: recordingID) }
          }.disabled(model.draftID != nil).accessibilityIdentifier("audio-play")
          Button(language.text("Stop playback", "إيقاف التشغيل")) { model.stopPlayback() }
          if recording.state != .saved, model.draftID != recordingID {
            Text(
              language.text(
                "An interruption left this recording unfinished. Recover the audio that was written to this device.",
                "ترك الانقطاع هذا التسجيل غير مكتمل. استعد الصوت المحفوظ على هذا الجهاز."))
            Button(language.text("Recover and save", "استعادة وحفظ")) {
              Task { await model.recover(id: recordingID) }
            }
            .accessibilityIdentifier("audio-recover")
          }
          if recording.state == .saved {
            if model.processingID == recordingID {
              ProgressView(
                language.text("Transcribing on this device…", "جارٍ التفريغ النصي على هذا الجهاز…"))
              Button(language.text("Cancel transcription", "إلغاء التفريغ النصي")) {
                model.cancelProcessing()
              }
            } else {
              Picker(language.text("Engine", "المحرك"), selection: $model.engine) {
                ForEach(model.engines, id: \.self) { Text($0).tag($0) }
              }.disabled(model.isProcessing)
              Button(language.text("Transcribe", "تفريغ نصي")) { model.transcribe(id: recordingID) }
                .disabled(model.isProcessing || model.busy || model.draftID != nil)
                .accessibilityIdentifier("audio-transcribe")
            }
          }
          if let failure = model.failure {
            Label(audioMessage(failure, language: language), systemImage: "exclamationmark.circle")
              .accessibilityIdentifier("audio-detail-error")
          }
          ForEach(
            model.snapshot.jobs.filter {
              $0.recordingID == recordingID && $0.state != .completed && $0.state != .running
            }
          ) { job in
            Text(
              language.text(
                "\(job.engineID): interrupted or failed. Your audio is safe; retry transcription.",
                "\(job.engineID): توقف أو فشل. صوتك محفوظ؛ أعد محاولة التفريغ النصي.")
            )
            .font(.footnote)
          }
        }
        Section(language.text("People and sources", "الأشخاص والمصادر")) {
          Text(
            language.text(
              "Links provide context. They do not identify a speaker.",
              "توفّر الروابط سياقاً. وهي لا تحدّد هوية المتحدث.")
          )
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
          if records.activeRecords.isEmpty {
            Text(
              language.text(
                "Create a person or thought in Your memories to link it here.",
                "أنشئ شخصاً أو فكرة في ذكرياتك لربطها هنا."))
          }
          ForEach(records.activeRecords) { record in
            let isPerson = record.kind == .person
            let selected = (isPerson ? recording.personIDs : recording.sourceRecordIDs).contains(
              record.id)
            Button {
              Task {
                await model.toggleAssociation(
                  recordingID: recordingID, linkedID: record.id, isPerson: isPerson)
              }
            } label: {
              Label(record.text, systemImage: selected ? "checkmark.circle.fill" : "circle")
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            }.disabled(model.busy).accessibilityAddTraits(selected ? .isSelected : [])
          }
        }
        ForEach(transcripts) { transcript in
          Section {
            Text(transcript.engineID).font(.headline)
            Text(transcript.modelID).font(.caption).foregroundStyle(MemoryTheme.secondary)
              .textSelection(
                .enabled)
            if transcript.currentPassages.isEmpty {
              Text(
                language.text(
                  "No speech recognized. Listen to the audio or try another model.",
                  "لم يُتعرّف على كلام. استمع إلى الصوت أو جرّب نموذجاً آخر."))
            }
            ForEach(transcript.currentPassages) { passage in
              VStack(alignment: .leading, spacing: 8) {
                Button {
                  Task { await model.play(id: recordingID, seconds: passage.startSeconds) }
                } label: {
                  Label(
                    "\(timestamp(passage.startSeconds)) – \(timestamp(passage.endSeconds))",
                    systemImage: "play.circle"
                  )
                  .frame(minHeight: 44)
                  .contentShape(Rectangle())
                }.accessibilityLabel(
                  language.text(
                    "Play passage at \(timestamp(passage.startSeconds))",
                    "تشغيل المقطع عند \(timestamp(passage.startSeconds))"))
                Text(passage.text).textSelection(.enabled)
                if let original = transcript.passages.first(where: { $0.id == passage.id }),
                  !original.text.utf8.elementsEqual(passage.text.utf8)
                {
                  DisclosureGroup(language.text("Original recognition", "النص الأصلي للمحرك")) {
                    Text(original.text).textSelection(.enabled)
                    if original.words.contains(where: \.uncertain) {
                      Text(
                        language.text("Unclear speech: ", "كلام غير واضح: ")
                          + original.words.filter(\.uncertain).map(\.text).joined(separator: " ")
                      )
                      .font(.caption).foregroundStyle(.orange)
                    }
                  }
                }
                if passage.words.contains(where: \.uncertain) {
                  Text(
                    language.text("Unclear speech: ", "كلام غير واضح: ")
                      + passage.words.filter(\.uncertain).map(\.text).joined(separator: " ")
                  )
                  .font(.caption).foregroundStyle(.orange)
                }
                Text(passage.speaker ?? language.text("Unknown speaker", "متحدث غير معروف"))
                  .font(.caption).foregroundStyle(MemoryTheme.secondary)
                if passage.uncertain {
                  Label(
                    language.text("Needs review", "يحتاج مراجعة"),
                    systemImage: "questionmark.circle"
                  ).font(.caption)
                }
                Button(language.text("Correct passage", "تصحيح المقطع")) {
                  model.dismissFailure()
                  editing = PassageEdit(transcriptID: transcript.id, passage: passage)
                }
                .frame(minHeight: 44)
              }
              .buttonStyle(.borderless)
              .padding(.vertical, 6)
            }
            Text(
              language.text(
                "\(transcript.corrections.count) saved corrections. Original audio and engine text are retained.",
                "\(transcript.corrections.count) تصحيحات محفوظة. نحتفظ بالصوت الأصلي ونص المحرك.")
            )
            .font(.caption).foregroundStyle(MemoryTheme.secondary)
            Button(
              language.text("Export transcript with source links", "تصدير النص مع روابط المصادر")
            ) {
              Task { if await model.export(id: transcript.id) { exporting = true } }
            }.accessibilityIdentifier("audio-export")
          }
        }
      } else {
        ContentUnavailableView {
          Label(
            language.text("Recording unavailable", "التسجيل غير متاح"),
            systemImage: "waveform")
        } description: {
          Text(
            language.text(
              "Reload the library to check this recording.",
              "أعد تحميل المكتبة للتحقق من هذا التسجيل."))
        } actions: {
          Button(language.text("Reload recordings", "إعادة تحميل التسجيلات")) {
            Task { await model.load() }
          }
          .frame(minHeight: 44)
          .disabled(model.busy)
        }
        .listRowBackground(Color.clear)
      }
    }
    .toolbar(.visible, for: .navigationBar)
    .navigationTitle(recording?.title ?? language.text("Recording", "تسجيل"))
    .navigationBarTitleDisplayMode(.inline)
    .scrollContentBackground(.hidden).background(MemoryTheme.canvas)
    .sheet(item: $editing) { item in
      PassageEditor(model: model, item: item, language: language)
    }
    .fileExporter(
      isPresented: $exporting, document: AudioTranscriptDocument(data: model.exportData ?? Data()),
      contentType: .json, defaultFilename: "MemoryOS-transcript"
    ) { result in
      if case .failure(let error) = result { model.report(error) }
    }
  }

  private func timestamp(_ value: Double) -> String {
    Duration.seconds(value).formatted(.time(pattern: .minuteSecond))
  }
}

private struct PassageEdit: Identifiable {
  let transcriptID: UUID
  let passage: TranscriptPassage
  var id: UUID { passage.id }
}

private struct PassageEditor: View {
  let model: AudioViewModel
  let item: PassageEdit
  let language: AppLanguage
  @Environment(\.dismiss) private var dismiss
  @State private var text: String
  @State private var speaker: String
  @State private var uncertain: Bool
  init(model: AudioViewModel, item: PassageEdit, language: AppLanguage) {
    self.model = model
    self.item = item
    self.language = language
    _text = State(initialValue: item.passage.text)
    _speaker = State(initialValue: item.passage.speaker ?? "")
    _uncertain = State(initialValue: item.passage.uncertain)
  }
  var body: some View {
    NavigationStack {
      Form {
        Section(language.text("Transcript", "النص")) {
          TextEditor(text: $text)
            .frame(minHeight: 160)
            .accessibilityLabel(language.text("Corrected transcript", "النص المصحّح"))
            .accessibilityIdentifier("audio-correction-text")
          Toggle(language.text("Needs review", "يحتاج مراجعة"), isOn: $uncertain)
          TextField(
            language.text("Speaker label (optional)", "اسم المتحدث (اختياري)"), text: $speaker)
          Text(
            language.text(
              "Leave the speaker blank when unknown. Mark unclear words with [?]. Saving keeps the original text and audio.",
              "اترك اسم المتحدث فارغاً إذا كان مجهولاً. ضع [?] بجانب الكلمات غير الواضحة. يحفظ التصحيح النص والصوت الأصليين."
            )
          )
          .font(.footnote)
        }
        if let failure = model.failure { Text(audioMessage(failure, language: language)) }
      }
      .scrollContentBackground(.hidden)
      .background(MemoryTheme.canvas)
      .navigationTitle(language.text("Review passage", "مراجعة المقطع"))
      .navigationBarTitleDisplayMode(.inline)
      .interactiveDismissDisabled(model.busy)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(language.text("Cancel", "إلغاء")) { dismiss() }
            .disabled(model.busy)
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Save", "حفظ")) {
            Task {
              if await model.correct(
                transcriptID: item.transcriptID, passage: item.passage,
                text: text, speaker: speaker, uncertain: uncertain)
              {
                dismiss()
              }
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(MemoryTheme.ink)
          .foregroundStyle(MemoryTheme.onFilledControl)
          .disabled(model.busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .environment(\.layoutDirection, language == .arabic ? .rightToLeft : .leftToRight)
    .environment(\.locale, Locale(identifier: language.rawValue))
    .preferredColorScheme(.dark)
  }
}

struct AudioTranscriptDocument: FileDocument {
  static let readableContentTypes: [UTType] = [.json]
  let data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}

func audioMessage(_ error: Error, language: AppLanguage) -> String {
  if error is CancellationError {
    return language.text(
      "Transcription stopped. Your audio is saved; you can retry.",
      "توقف التفريغ النصي. صوتك محفوظ ويمكنك إعادة المحاولة.")
  }
  if let failure = error as? AudioWorkflowError, case .invalidModel = failure {
    return language.text(
      "This model is damaged or does not match the supported model for this engine. Your previous model is unchanged. Choose a verified copy and retry.",
      "هذا النموذج تالف أو لا يطابق النموذج المدعوم لهذا المحرك. لم يتغير نموذجك السابق. اختر نسخة موثوقة وأعد المحاولة."
    )
  }
  if let failure = error as? AudioWorkflowError, case .transcriptionTooLong = failure {
    return language.text(
      "Transcription currently supports up to 15 minutes. Your original recording is saved; import a shorter excerpt to transcribe.",
      "يدعم التفريغ النصي حالياً حتى 15 دقيقة. تسجيلك الأصلي محفوظ؛ استورد مقطعاً أقصر لتفريغه.")
  }
  if error is AudioWorkflowError {
    return language.text(
      "Import the selected engine’s multilingual model folder, then retry. Audio stays on this device.",
      "استورد مجلد النموذج متعدد اللغات للمحرك المحدد، ثم أعد المحاولة. يبقى الصوت على هذا الجهاز.")
  }
  if let failure = error as? AudioCaptureFailure {
    switch failure {
    case .permissionDenied:
      return language.text(
        "Microphone access is off. Enable it for MemoryOS in Settings, or import an audio file.",
        "الوصول إلى الميكروفون مغلق. فعّله لتطبيق MemoryOS في الإعدادات أو استورد ملفاً صوتياً.")
    case .unsupportedFormat:
      return language.text(
        "Unsupported audio format. Choose WAV, M4A, MP3, AIFF, CAF or FLAC.",
        "تنسيق صوت غير مدعوم. اختر WAV أوM4A أوMP3 أوAIFF أوCAF أوFLAC.")
    case .damagedFile:
      return language.text(
        "This audio file is damaged or uses an unsupported codec. Keep the original and try a playable copy.",
        "هذا الملف الصوتي تالف أو يستخدم ترميزاً غير مدعوم. احتفظ بالأصل وجرّب نسخة قابلة للتشغيل.")
    case .fileTooLarge, .durationTooLong:
      return language.text(
        "Choose audio under 250 MB and 2 hours. Captured audio remains available to save.",
        "اختر صوتاً أقل من 250 ميغابايت وساعتين. يبقى الصوت المسجّل متاحاً للحفظ.")
    case .lowStorage:
      return language.text(
        "Storage is low. Recording stopped. Free space, then save the captured audio.",
        "المساحة منخفضة. توقف التسجيل. وفّر مساحة ثم احفظ الصوت المسجّل.")
    default: break
    }
  }
  if let failure = error as? AudioError {
    switch failure {
    case .unsupportedFormat, .damagedAudio, .invalidDuration:
      return language.text(
        "This audio format or file cannot be read. Choose an undamaged WAV, M4A, MP3, AIFF, CAF or FLAC file, up to 2 hours.",
        "تعذّرت قراءة هذا التنسيق أو الملف. اختر ملف WAV أوM4A أوMP3 أوAIFF أوCAF أوFLAC سليماً لا يتجاوز ساعتين."
      )
    case .audioTooLarge, .insufficientStorage, .limitReached:
      return language.text(
        "The audio exceeds a limit or storage is low. Free space and try a file under 250 MB. Existing audio is retained.",
        "يتجاوز الصوت الحد أو المساحة منخفضة. وفّر مساحة وجرّب ملفاً أقل من 250 ميغابايت. نحتفظ بالصوت الموجود."
      )
    case .originalChanged:
      return language.text(
        "The original audio changed or is missing. Processing stopped to protect its source links.",
        "تغير الصوت الأصلي أو فُقد. توقفت المعالجة لحماية روابط مصادره.")
    default: break
    }
  }
  return language.text(
    "Could not finish. Keep your source file, check free space and the selected model, then retry. Existing recordings remain saved.",
    "تعذّر الإكمال. احتفظ بملف المصدر وتحقق من المساحة والنموذج المحدد ثم أعد المحاولة. التسجيلات الموجودة محفوظة."
  )
}
