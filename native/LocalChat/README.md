# LocalChat

MemoryOS-owned chat contracts, use cases, persistence and presentation state. This package has no external dependencies. It uses Swift 6 language mode and supports iOS 18 and macOS 14. The main app injects a reviewed local model and current-record retrieval adapters. No module opens a network connection.

- `ChatCore`: app-owned value types and protocols, conversation rules, history construction, fresh memory evidence, stop/error outcomes and generation coordination.
- `ChatPersistence`: versioned atomic JSON in an injected app-private location. iOS writes use complete file protection. The directory stays outside automatic backups. Unsupported or malformed archives fail without replacement.
- `ChatPresentation`: an observable MainActor ViewModel. Views render its state and send actions. It uses injected use cases and never calls a concrete provider or store.

Each request retains user/assistant history. The core refuses requests above a conservative 6000-byte prompt preflight; the runtime must enforce its exact token limit. It never removes older general-chat turns to fit. Ordinary follow-ups retain earlier assistant replies only while their cited evidence is unchanged and present. Memory mode refreshes original-record evidence for each question and keeps prior AI turns as explicit redaction placeholders in the model request. The visible chat retains the original messages. No matching evidence returns `noEvidence` before model execution. Source/context preflight failures preserve the unsent draft and conversation. The retrieval contract keeps the current question separate from previous questions so adapters can prioritize a new topic. AI cannot write original records through these read-only contracts.

Send persists the user message and assistant slot before generation. Retry/regenerate reuse that assistant ID. Until the first nonempty new prefix arrives, regeneration keeps the old reply and sources; an early failure or cancellation restores its prior status. Stop and output-limit errors preserve partial text. Relaunch changes abandoned generating slots to interrupted. A failed reply write retains the partial in memory and reports storage failure; a successful later flush persists it. The ViewModel exposes `isTransitioning` while it commits an outgoing draft and changes chats; controls must disable input in that state. Draft autosave uses a 180 ms debounce; background handling must call `interrupt()` to join generation, flush and unload. A forced process kill inside the debounce can lose the latest unflushed keystrokes. Chat archives remain separate from the existing original-record JSON export; no cloud backup or sync enters this task.

Streaming emits first text and final text and coalesces intervening presentation/persistence updates to 50 ms. The native model call runs in a structured child task. Cancellation joins that call before completion; synchronous provider work may delay it. Phone performance and accessibility claims need app/device evidence from the task record.

```sh
swift test --package-path native/LocalChat -c release
xcrun swift-format lint --strict --recursive native/LocalChat/Sources native/LocalChat/Tests
```

`MemoryEvidenceFiltering` selects source IDs without changing passages. The optional
`SubjectAwareMemoryEvidenceFiltering` capability carries explicit profile names and record associations
separately from source text. The app's `SourceBoundedChatEvidenceFilter` reuses memory search's subject
and topic checks after hybrid candidate search. It verifies at most eight passages, then returns at most
three current sources. A shared name alone is insufficient. Invalid output, unknown IDs and unavailable
assets fail explicitly. Queries are not indexed. The app rechecks source bytes and identity associations
after verification. One inference coordinator shares the resident model between relevance and replies;
the borrowed filter does not unload those weights. This relevance check does not authorize automatic
profile writes or establish source truth.

Home capture owns its input in `ChatViewModel.homeDraft`. After a separate record write commits, the caller uses `clearSavedHomeDraft(submitted)`; it clears only byte-identical input through the existing autosave setter. Later typing and Unicode-equivalent text with different bytes remain. Failed writes must not call this operation.
