# Product overview

Recorded on 2026-11-06. This document combines the current owner requests with labeled proposals. Source IDs refer to the [source register](reference/source-register.md).

Owner updates, 2026-11-07: use Swift with SwiftUI; start with a clickable interface demo using sample data and grow feature by feature; compare multiple local models; include Telegram, Instagram, and WhatsApp imports; start external AI with ChatGPT; limit initial actions to birthdays; add person-image options and guided questions. The storage approach and model choices remain open. See the current [demo and feature direction](decisions/demo-and-feature-direction.md).

## Purpose

The owner wants one private app to help manage personal information in their own way. They should be able to record or write a thought without selecting a folder first. The app should identify the people, projects, ideas, and dates involved.

The app should help the owner recall what happened, understand discussions, manage commitments, and choose what to remember about each person. It should remain simple to use.

This is the current personal second-brain direction. The old digital legacy and professional-product ideas remain historical options. See the [historical register](reference/historical-research.md).

## Confirmed device and local-use preference

- The owner's phone is an iPhone 15 Pro Max. Source: C02.
- The owner prefers processing on the iPhone, including difficult work where feasible. A Mac must not be a daily dependency. Source: C02.
- The owner wants as much local control and self-hosting as possible. Source: C01.
- Optional help from ChatGPT or Claude remains a requested capability. It must not become an automatic requirement. Source: C01.

Development can use a Mac. That does not mean the finished app needs a Mac during normal use. Performance, supported iOS versions, storage use, and battery cost remain unverified.

## What the owner can add

- Typed thoughts, ideas, plans, and free-form chat.
- New voice recordings and imported audio.
- Exported conversations with other people.
- Email from connected accounts.
- PDF and Word documents.
- Obsidian notes, subject to the integration mode selected later.

Screenshots, images, shared links, widgets, and voice shortcuts appear in the old research or assistant proposals. Their current implementation scope is not confirmed.

## What the app should organize

**People:** a profile for each person, with discussions, shared topics, important information, recordings, and selected reminders.

**Projects:** new information, ideas, current plans, and possible future work. The app should recognize which project a capture concerns.

**Ideas:** captured ideas with useful categories and links to related people or projects.

**Dates and actions:** birthdays, anniversaries or other owner-selected dates, follow-ups, and calendar items. The exact automatic-action rules remain open.

One capture may refer to several people and projects. The owner should be able to correct a mistaken connection. This multi-link and correction behavior is a supporting proposal, not a selected data model.

## Conversation understanding

The owner wants more than message storage. The app should help explain a specific conversation and a conflict. It should retain who said what and enough surrounding context to interpret it.

The proposed approach separates:

1. The original message, recording, or document.
2. Information extracted from that source.
3. Facts or corrections confirmed by the owner.
4. AI interpretations and unresolved questions.

A possible interpretation must not become a confirmed fact about a person's intentions. Different statements can reflect a changed plan, a disagreement, or missing information. The app should keep the source dates and show uncertainty.

For example, the owner could ask: "What caused this disagreement, what did each person say, and what remains unresolved?" Source-backed answers and editable interpretations are proposed safeguards for this requested feature.

## Example capture

Example only. The name and date below are fictional.

> Ali's birthday is 12 May. We discussed a new website. I might prepare a proposal next week.

The intended behavior is to connect the birthday to the person, connect the discussion to the website project, and preserve the possible proposal as an idea or tentative plan. The app should not treat "might" as a firm commitment. A reminder follows the owner's chosen rules.

## Interface

The owner requested a minimal interface with:

- A large recording button.
- A text/chat field for dumping information.
- A sidebar that appears only when opened.
- Tabs, including tabs the owner asks the app to create.

The assistant proposed an attachment button, a compact capture receipt, undo/correction actions, and a small reminder list. The assistant also proposed implementing custom tabs as saved filters over existing records. These details need owner review.

C20, 2026-11-13: the owner selected the supplied Capture and sidebar screenshots as the reference for the native foundation. Other screen layouts still need review. The app should not require a long questionnaire for each capture.

## Language

Arabic and English are required. Other languages are part of the requested vision. The exact list remains open.

Evaluation should include Iraqi Arabic, mixed Arabic/English, names, nicknames, sarcasm, dates, and Arabic right-to-left text. These are proposed evaluation cases. No model has established acceptable performance on them.

Keep original source language. A translated summary must remain distinguishable from the original. Cross-language search is a proposed supporting capability.

## Connections

- **Email and calendar:** read authorized email and create calendar items under owner-defined rules. Providers and permissions remain open.
- **Obsidian:** connect notes to a vault. Export/import and live shared-vault access are different options. Neither has been selected or tested.
- **ChatGPT and Claude:** optional help with difficult work. Manual handoff and official API integration are proposals. The requested iPhone subscription connection is not verified.
- **Future sync:** consider Convex or Supabase for MacBook, iPhone, and possibly Android. Neither service has been selected.

Email retrieval, cloud AI, and sync require network access. Offline capture and local memory should continue without these connections.

## Current implementation state

The workspace originally contained three research documents. Later work added documentation, an isolated development-memory connection, and browser design studies.

On 2026-11-13, C20 authorizes a native SwiftUI foundation and device readiness check. The source now exists under `native/` and passes a simulator build. Capture and the hidden sidebar follow the two supplied screenshots. Other sections have placeholders. Typed demo memories live in process memory and disappear when the process exits. Recording and attachment controls show scope notices. The app has no microphone access, imports, AI, network service, production store, release, or deployment. See [setup and verification](how-to/native-swiftui.md). Physical iPhone launch and phone benchmarks remain unverified.


Step 1 update, C28, 2026-11-14: the owner authorizes the complete native sample interface. The source now adds fictional People/details, Projects with separate plans/ideas, Birthdays/reminder previews, and BrainMap connections. People replaces the earlier Profiles display label. Capture retains the large microphone and composer. New layouts remain review proposals. The [active task record](tasks/2026-11-14-complete-interface-demo.md) owns current checks and blockers; the preceding foundation paragraph is a dated checkpoint. Reminder choices and captures reset on process restart. No scheduling, database, model, provider SDK, or service connection follows from this demo.
