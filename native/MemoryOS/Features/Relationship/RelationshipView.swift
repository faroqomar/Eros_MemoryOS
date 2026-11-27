import MemoryCore
import SwiftUI

struct RelationshipView: View {
  @Bindable var model: RelationshipViewModel
  let language: AppLanguage
  @State private var choosing = false
  @State private var sourceQuery = ""

  private var matchingSources: [PersonalMemorySource] {
    let query = sourceQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    return model.snapshot.sources
      .filter { query.isEmpty || $0.text.localizedStandardContains(query) }
      .sorted { $0.createdAt > $1.createdAt }
  }

  var body: some View {
    List {
      Section {
        Button {
          choosing = true
        } label: {
          Label(language.text("Choose sources", "اختيار المصادر"), systemImage: "text.quote")
            .frame(minHeight: 44)
        }
        .accessibilityValue(
          language.text("Selected: \(model.selected.count)", "المحددة: \(model.selected.count)")
        )
        .accessibilityIdentifier("relationship-choose-sources")
        Text(
          language.text(
            model.selected.isEmpty
              ? "Choose saved messages to start an analysis."
              : "Selected sources: \(model.selected.count)",
            model.selected.isEmpty
              ? "اختر رسائل محفوظة لبدء التحليل."
              : "المصادر المحددة: \(model.selected.count)"
          )
        )
        .font(.subheadline).foregroundStyle(MemoryTheme.secondary)
        Picker(language.text("Relationship", "العلاقة"), selection: $model.relationship) {
          ForEach(RelationshipKind.allCases, id: \.self) { item in
            Text(item.title(language)).tag(item)
          }
        }
        Picker(language.text("Explore", "استكشاف"), selection: $model.mode) {
          ForEach(RelationshipViewModel.Mode.allCases) { item in
            Text(item.title(language)).tag(item)
          }
        }.accessibilityIdentifier("relationship-mode")
        let questionLabel = language.text("Your question (optional)", "سؤالك (اختياري)")
        TextField(
          questionLabel, text: $model.question,
          prompt: MemoryTheme.fieldPrompt(questionLabel), axis: .vertical
        )
        .accessibilityIdentifier("relationship-question")
        let interpretationLabel = language.text(
          "Your interpretation (optional)", "تفسيرك (اختياري)")
        TextField(
          interpretationLabel, text: $model.ownerInterpretation,
          prompt: MemoryTheme.fieldPrompt(interpretationLabel), axis: .vertical
        )
        .accessibilityIdentifier("relationship-owner-account")
      }.disabled(model.isBusy)
      Section {
        Text(
          language.text(
            "Local analysis can miss evidence. Check the original messages before acting.",
            "قد يفوّت التحليل المحلي بعض الأدلة. راجع الرسائل الأصلية قبل التصرف."
          )
        )
        .font(.callout).foregroundStyle(MemoryTheme.secondary)
        DisclosureGroup(language.text("How analysis works", "كيف يعمل التحليل")) {
          Text(
            language.text(
              "The analysis can describe up to four discussion events. You can use either participant's saved history. The source label tells you where a message was saved. Check the message to see who spoke.",
              "يصف التحليل حتى أربعة أحداث في النقاش. يمكنك استخدام السجل المحفوظ لأي طرف. يوضح اسم المصدر مكان حفظ الرسالة. راجع الرسالة لمعرفة المتحدث."
            )
          )
          Text(
            language.text(
              "Your interpretation stays beside the originals. If they conflict, MemoryOS asks for clarification before giving advice.",
              "يبقى تفسيرك بجانب الأصول. عند التعارض، يطلب MemoryOS توضيحاً قبل تقديم النصيحة."
            )
          )
        }
        .font(.callout)
      }
      if model.isBusy {
        Section {
          ProgressView(
            language.text(
              "Reading the selected sources on this device…",
              "قراءة المصادر المختارة على هذا الجهاز…"))
          Button(language.text("Cancel", "إلغاء")) { model.cancel() }
        }
      } else {
        Button(
          language.text(
            model.mode == .draft ? "Prepare draft" : "Explore evidence",
            model.mode == .draft ? "إعداد مسودة" : "استكشاف الأدلة")
        ) {
          Task { await model.analyze() }
        }.disabled(model.selected.isEmpty).accessibilityIdentifier("relationship-analyze")
      }
      if let error = model.error {
        Section {
          Text(error.message(language)).foregroundStyle(MemoryTheme.secondary)
            .accessibilityIdentifier("relationship-error")
          if error == .storage || error == .stale {
            Button(language.text("Refresh saved sources", "تحديث المصادر المحفوظة")) {
              Task { await model.load() }
            }.disabled(model.isBusy)
          } else if error == .selection || error == .tooLarge {
            Button(language.text("Review source selection", "مراجعة المصادر المختارة")) {
              choosing = true
            }
            .disabled(model.isBusy)
          }
        }
      }
      if let result = model.result {
        Section {
          Button(
            language.text(
              "Keep this source-linked report", "الاحتفاظ بهذا التقرير المرتبط بالمصادر")
          ) {
            Task { await model.saveReport() }
          }.disabled(model.isBusy || model.isUpdatingSavedReports)
            .accessibilityIdentifier("relationship-save-report")
        }
        RelationshipReportView(result: result, language: language)
      }
      if !model.savedReports.isEmpty {
        Section(language.text("Saved summaries and accounts", "الملخصات والتفسيرات المحفوظة")) {
          ForEach(model.savedReports, id: \.viewID) { report in
            Button(report.summaries.first?.title ?? report.input.request.question) {
              Task { await model.openSaved(report) }
            }
          }
          Button(
            language.text("Remove saved reports", "إزالة التقارير المحفوظة"), role: .destructive
          ) {
            Task { await model.clearSavedReports() }
          }.disabled(model.isUpdatingSavedReports)
          Text(
            language.text(
              "Memory changes can make these reports outdated. Generate a fresh report from current sources. Interpretations you keep remain in personal memory.",
              "قد تجعل تغييرات الذاكرة هذه التقارير قديمة. أنشئ تقريراً جديداً من المصادر الحالية. تبقى التفسيرات التي تحتفظ بها في الذاكرة الشخصية."
            )
          )
          .font(.caption).foregroundStyle(MemoryTheme.secondary)
        }
      }
      if !model.insights.isEmpty {
        Section(language.text("Worth reviewing", "مواضيع للمراجعة")) {
          ForEach(model.insights) { insight in
            Button {
              model.selected = Set(insight.sourceIDs)
              model.mode = .discussion
              model.invalidate()
              choosing = true
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(insight.title(language))
                Text(
                  language.text(
                    "Review the originals before drawing conclusions.", "راجع الأصول قبل الاستنتاج."
                  )
                )
                .font(.caption).foregroundStyle(MemoryTheme.secondary)
              }.frame(minHeight: 44)
            }
          }
        }
      }
    }
    .scrollContentBackground(.hidden)
    .scrollDismissesKeyboard(.interactively)
    .sheet(isPresented: $choosing, onDismiss: { sourceQuery = "" }) { sourcePicker }
    .task {
      model.answerInArabic = language == .arabic
      await model.load()
    }
    .refreshable { await model.load() }
    .onDisappear { model.cancel() }
    .accessibilityIdentifier("relationship-workspace")
  }

  private var sourcePicker: some View {
    NavigationStack {
      List {
        if model.snapshot.sources.isEmpty {
          ContentUnavailableView(
            language.text("No saved sources", "لا توجد مصادر محفوظة"),
            systemImage: "text.quote",
            description: Text(
              language.text(
                "Save a conversation or add information in Notes, then return to choose sources.",
                "احفظ محادثة أو أضف معلومة في الملاحظات، ثم عد لاختيار المصادر."
              )
            )
          )
        } else if matchingSources.isEmpty {
          ContentUnavailableView {
            Label(
              language.text("No matching sources", "لا توجد مصادر مطابقة"),
              systemImage: "magnifyingglass")
          } description: {
            Text(
              language.text(
                "Try a different word from the original message.",
                "جرّب كلمة أخرى من الرسالة الأصلية."))
          } actions: {
            Button(language.text("Clear search", "مسح البحث")) { sourceQuery = "" }
          }
        }
        ForEach(matchingSources) { source in
          Button {
            if model.selected.contains(source.id) {
              model.selected.remove(source.id)
            } else {
              model.selected.insert(source.id)
            }
          } label: {
            HStack(alignment: .top) {
              VStack(alignment: .leading, spacing: 6) {
                Text(source.text).lineLimit(4)
                Text(source.createdAt, format: .dateTime.year().month().day().hour().minute()).font(
                  .caption)
                Text(source.origin).font(.caption).foregroundStyle(MemoryTheme.secondary)
              }
              Spacer()
              Image(
                systemName: model.selected.contains(source.id) ? "checkmark.circle.fill" : "circle"
              ).accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }.buttonStyle(.plain)
            .accessibilityAddTraits(model.selected.contains(source.id) ? .isSelected : [])
            .accessibilityIdentifier("relationship-source-\(source.id)")
        }
      }
      .searchable(
        text: $sourceQuery, prompt: language.text("Find words in sources", "ابحث بكلمات من المصادر")
      )
      .navigationTitle(language.text("Original sources", "المصادر الأصلية"))
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(language.text("Done", "تم")) { choosing = false }
        }
      }
    }.preferredColorScheme(.dark)
  }
}

struct RelationshipReportView: View {
  let result: RelationshipUnderstandingResult
  let language: AppLanguage
  var body: some View {
    Section {
      Text(
        language.text(
          "Local AI analysis · verify against originals", "تحليل ذكاء محلي · تحقق من الأصول")
      )
      .font(.caption).foregroundStyle(MemoryTheme.secondary)
    }
    if let account = result.input.request.ownerInterpretation {
      Section(language.text("Your account · retained separately", "تفسيرك · محفوظ بشكل منفصل")) {
        Text(account).textSelection(.enabled)
      }
    }
    if let clarification = result.clarification {
      Section(language.text("Clarify before answering", "توضيح قبل الإجابة")) {
        Text(clarification).accessibilityIdentifier("relationship-clarification")
        Text(
          language.text(
            "Edit your interpretation above and explore again. Both your account and the original messages remain visible.",
            "عدّل تفسيرك أعلاه ثم استكشف مجدداً. يبقى تفسيرك والرسائل الأصلية ظاهرين."))
      }
    }
    if result.insufficientEvidence {
      Section {
        Text(
          language.text(
            "The selected records do not support an answer. Add relevant context.",
            "لا تدعم السجلات المختارة إجابة. أضف سياقاً مناسباً."))
      }
    }
    ForEach(result.findings) { finding in
      Section(finding.kind.title(language)) {
        Text(finding.text).textSelection(.enabled)
        RelationshipEvidenceRows(evidence: finding.evidence, result: result, language: language)
        ForEach(finding.alternatives, id: \.self) {
          Text(language.text("Alternative: ", "تفسير بديل: ") + $0).font(.callout)
        }
        if !finding.counterevidence.isEmpty {
          Text(language.text("Counterevidence", "أدلة مخالفة")).font(.caption.bold())
          RelationshipEvidenceRows(
            evidence: finding.counterevidence, result: result, language: language)
        }
        ForEach(finding.tradeoffs, id: \.self) {
          Text(language.text("Tradeoff: ", "مقايضة: ") + $0).font(.callout)
        }
      }
    }
    if !result.timeline.isEmpty {
      Section(language.text("Timeline · source dates", "التسلسل الزمني · تواريخ المصادر")) {
        ForEach(result.timeline) { event in
          VStack(alignment: .leading, spacing: 4) {
            Text(event.firstRecordedAt, format: .dateTime.year().month().day())
            Text(event.finding.text)
          }
        }
      }
    }
    ForEach(result.summaries) { summary in
      Section(summary.title) {
        Text(summary.level.title(language)).font(.caption).foregroundStyle(MemoryTheme.secondary)
        Text(summary.text).textSelection(.enabled)
        RelationshipEvidenceRows(evidence: summary.evidence, result: result, language: language)
      }
    }
    if let draft = result.draft {
      Section(language.text("Optional draft · you decide", "مسودة اختيارية · القرار لك")) {
        Text(draft).textSelection(.enabled).accessibilityIdentifier("relationship-draft")
      }
    }
    if !result.input.memories.isEmpty {
      Section(language.text("Current memory layers", "طبقات الذاكرة الحالية")) {
        ForEach(result.input.memories) { memory in
          NavigationLink(value: DemoDestination.personalEntry(memory.entry.id)) {
            VStack(alignment: .leading, spacing: 6) {
              Text(memory.layer.title(language)).font(.caption.weight(.semibold))
              if memory.entry.isOwnerCorrected == true {
                Text(
                  language.text("Corrected by you · original retained", "عدّلته أنت · الأصل محفوظ")
                )
                .font(.caption).foregroundStyle(MemoryTheme.secondary)
              }
              Text(memory.entry.text)
            }.frame(minHeight: 44)
          }
        }
      }
    }
    Section(language.text("Originals and surrounding context", "الأصول والسياق المحيط")) {
      ForEach(result.input.sources) { context in
        sourceLink(context.source)
        ForEach(context.surrounding) { sourceLink($0) }
      }
    }
    Section(language.text("Limits", "الحدود")) {
      Text(
        language.text(
          "AI interpretations can be wrong. Available history may be one-sided or incomplete. Dates record capture time; sarcasm and culture may change meaning. Silence does not establish agreement or completed commitments.",
          "قد تخطئ تفسيرات الذكاء الاصطناعي. قد يكون السجل أحادي الطرف أو ناقصاً. التواريخ تخص الحفظ، وقد تغير السخرية والثقافة المعنى. لا يثبت الصمت الاتفاق أو تنفيذ الالتزامات."
        )
      )
      .font(.caption).foregroundStyle(MemoryTheme.secondary)
    }
  }
  private func sourceLink(_ source: PersonalMemorySource) -> some View {
    NavigationLink(value: DemoDestination.personalSource(source.id)) {
      VStack(alignment: .leading, spacing: 4) {
        Text(source.text).lineLimit(5)
        Text(source.createdAt, format: .dateTime.year().month().day().hour().minute()).font(
          .caption)
      }
    }
  }
}

private struct RelationshipEvidenceRows: View {
  let evidence: [PersonalMemoryEvidence]
  let result: RelationshipUnderstandingResult
  let language: AppLanguage
  var body: some View {
    ForEach(evidence, id: \.identity) { evidence in
      NavigationLink(value: DemoDestination.personalSource(evidence.sourceID)) {
        VStack(alignment: .leading, spacing: 4) {
          Text("“" + evidence.quote + "”").font(.callout)
          if let source = result.input.sources.flatMap({ [$0.source] + $0.surrounding }).first(
            where: { $0.id == evidence.sourceID })
          {
            Text(source.createdAt, format: .dateTime.year().month().day().hour().minute()).font(
              .caption)
          }
          Text(language.text("Open original and context", "فتح الأصل والسياق")).font(.caption)
        }
      }
    }
  }
}

extension PersonalMemoryEvidence {
  fileprivate var identity: String { sourceID.uuidString + ":" + quote }
}

extension RelationshipUnderstandingResult {
  fileprivate var viewID: [String] {
    [
      input.request.sourceIDs.map(\.uuidString).sorted().joined(separator: ","),
      input.request.question, input.request.ownerInterpretation ?? "",
      input.request.relationship.rawValue, input.request.focus?.rawValue ?? "",
      String(input.request.draftRequested),
    ]
  }
}
