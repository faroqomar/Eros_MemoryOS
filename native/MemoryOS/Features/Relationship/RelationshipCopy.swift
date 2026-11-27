import MemoryCore

extension RelationshipKind {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .unspecified: language.text("Unspecified", "غير محددة")
    case .partner: language.text("Partner", "شريك")
    case .friend: language.text("Friend", "صديق")
    case .family: language.text("Family", "عائلة")
    case .colleague: language.text("Colleague", "زميل")
    }
  }
}
extension RelationshipViewModel.Mode {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .discussion: language.text("Discussion and timeline", "النقاش والتسلسل الزمني")
    case .patterns: language.text("Possible patterns", "أنماط محتملة")
    case .advice: language.text("Next steps and tradeoffs", "الخطوات والمقايضات")
    case .draft: language.text("Draft a reply", "صياغة رد")
    case .conversation: language.text("Conversation summary", "ملخص المحادثة")
    case .topic: language.text("Topic summary", "ملخص الموضوع")
    case .period: language.text("Time-period summary", "ملخص الفترة")
    }
  }
}
extension RelationshipSummaryLevel {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .conversation: language.text("Conversation summary", "ملخص المحادثة")
    case .topic: language.text("Topic summary", "ملخص الموضوع")
    case .period: language.text("Time-period summary", "ملخص الفترة")
    }
  }
}
extension RelationshipFindingKind {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .agreement: language.text("Reported agreement", "اتفاق مذكور")
    case .disagreement: language.text("Reported disagreement", "خلاف مذكور")
    case .unresolved: language.text("Unresolved", "دون حل")
    case .commitment: language.text("Reported commitment", "التزام مذكور")
    case .repairAttempt: language.text("Possible repair attempt", "محاولة إصلاح محتملة")
    case .changeOverTime: language.text("Change over time", "تغير مع الزمن")
    case .possibleEmotion: language.text("Possible emotion · hypothesis", "شعور محتمل · فرضية")
    case .communicationPattern: language.text("Possible pattern · hypothesis", "نمط محتمل · فرضية")
    case .interpretation: language.text("Revisable interpretation", "تفسير قابل للمراجعة")
    case .nextStep: language.text("Option · you decide", "خيار · القرار لك")
    case .insight: language.text("Source-backed insight", "ملاحظة مرتبطة بمصدر")
    }
  }
}
extension RelationshipViewModel.Failure {
  func message(_ language: AppLanguage) -> String {
    switch self {
    case .storage:
      language.text(
        "Could not read saved memory. Try again.", "تعذرت قراءة الذاكرة المحفوظة. حاول مجدداً.")
    case .selection:
      language.text("Choose relevant saved sources first.", "اختر المصادر المحفوظة المناسبة أولاً.")
    case .tooLarge:
      language.text(
        "This selection or answer exceeds the local limit. Choose fewer sources or a narrower question; no partial report was kept.",
        "يتجاوز الاختيار أو الجواب الحد المحلي. اختر مصادر أقل أو سؤالاً أضيق؛ لم نحفظ تقريراً ناقصاً."
      )
    case .invalidEvidence:
      language.text(
        "Couldn't verify this answer against your sources. No interpretation was saved. Try a narrower question.",
        "تعذر التحقق من الجواب بمقارنته بمصادرك. لم نحفظ تفسيراً. جرّب سؤالاً أضيق.")
    case .stale:
      language.text(
        "Memory changed. The earlier interpretation is hidden; explore the current sources again.",
        "تغيرت الذاكرة. أخفينا التفسير السابق؛ استكشف المصادر الحالية مجدداً.")
    case .unavailable:
      language.text(
        "Local analysis could not finish. Check the local model or choose less context, then retry.",
        "تعذر إكمال التحليل المحلي. تحقق من النموذج أو اختر سياقاً أقل ثم أعد المحاولة.")
    }
  }
}

extension RelationshipProactiveInsight {
  func title(_ language: AppLanguage) -> String {
    switch kind {
    case .commitmentReview:
      language.text(
        "Review a recorded commitment; its completion is unknown.",
        "راجع التزاماً مذكوراً؛ لا نعرف إن تم تنفيذه.")
    case .unresolvedReview:
      language.text(
        "Revisit information you marked unresolved.", "راجع المعلومات التي صنفتها دون حل.")
    case .recurringTopic:
      language.text("Revisit a recurring topic: ", "راجع موضوعاً متكرراً: ") + (topic ?? "")
    }
  }
}

extension RelationshipMemoryLayer {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .originalStatement: language.text("Original statement", "العبارة الأصلية")
    case .extractedInformation:
      language.text("Extracted information · unconfirmed", "معلومة مستخرجة · غير مؤكدة")
    case .ownerConfirmedInformation:
      language.text("Information confirmed by you", "معلومة أكدتها أنت")
    case .confirmedInterpretation:
      language.text("Interpretation confirmed by you · revisable", "تفسير أكدته أنت · قابل للتصحيح")
    case .unreviewedInterpretation:
      language.text("Interpretation · author unknown", "تفسير · صاحبه غير محدد")
    case .aiHypothesis:
      language.text("AI hypothesis · revisable", "فرضية ذكاء اصطناعي · قابلة للتصحيح")
    }
  }
}
