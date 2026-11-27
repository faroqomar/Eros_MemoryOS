import MemoryCore

extension PersonalMemoryEntry {
  func statusTitle(_ language: AppLanguage) -> String {
    guard kind == .interpretation else { return kind.title(language) }
    switch interpretationStatus {
    case .ownerReviewed:
      return language.text(
        "Interpretation confirmed by you · revisable", "تفسير أكدته أنت · قابل للتصحيح")
    case .aiProposed:
      return language.text("AI hypothesis · revisable", "فرضية ذكاء اصطناعي · قابلة للتصحيح")
    case nil:
      return language.text("Interpretation · author unknown", "تفسير · صاحبه غير محدد")
    }
  }

  func confirmationTitle(_ language: AppLanguage) -> String? {
    guard kind != .interpretation, confirmed else { return nil }
    return language.text("Confirmed by you", "أكدتها أنت")
  }
}

extension PersonalMemoryKind {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .fact: language.text("Reported fact", "حقيقة مذكورة")
    case .preference: language.text("Preference", "تفضيل")
    case .goal: language.text("Goal", "هدف")
    case .interpretation: language.text("Interpretation · correctable", "تفسير قابل للتصحيح")
    case .idea: language.text("Tentative idea", "فكرة مبدئية")
    case .plan: language.text("Current plan", "خطة حالية")
    case .workflow: language.text("Workflow update", "تحديث سير العمل")
    case .commitment: language.text("Commitment", "التزام")
    case .summary: language.text("Summary", "ملخص")
    case .venting: language.text("Just venting", "فضفضة فقط")
    case .rolePlay: language.text("Role-play / hypothetical", "تمثيل أو افتراض")
    case .conversationOnly: language.text("Keep original only", "الاحتفاظ بالأصل فقط")
    }
  }
}

extension PersonalPhotoOrigin {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .supplied: language.text("Supplied photo", "صورة مقدمة")
    case .imported: language.text("Imported source photo", "صورة من مصدر مستورد")
    case .generated: language.text("Generated image", "صورة مولدة")
    }
  }
}

extension PersonalProfileQuestion {
  func title(_ language: AppLanguage) -> String {
    switch self {
    case .priority: language.text("What matters to you right now?", "ما الذي يهمك الآن؟")
    case .preference:
      language.text("Which preference should I remember?", "أي تفضيل تريد أن أتذكره؟")
    case .relationship: language.text("How do you know this person?", "كيف تعرف هذا الشخص؟")
    case .communication:
      language.text("What communication pattern have you noticed?", "ما نمط التواصل الذي لاحظته؟")
    }
  }
}
