Eros Memory OS — Summary of Key Ideas, Features, Algorithms, and Tools

Overview
- Vision: Build a privacy-first “second brain” that ingests a user’s personal digital traces (messages, email, voice notes, screenshots) to enable: (1) Digital Legacy personas that emulate the user’s communication style (without identity claims), and (2) Self‑Insight analytics that surface patterns about life, relationships, and decisions.
- Differentiators: Consent-by-design, provenance/citations on every answer, hybrid RAG retrieval (vectors + BM25 + knowledge graph), graph‑enhanced insights, mobile-first capture with on‑device processing options, strong privacy and encryption.

Core Use Cases
- Self‑Insight: Ask questions about past events, decisions, relationships; view timelines and trends (e.g., sentiment over time).
- Digital Legacy Persona: An AI memory-model that writes in the user’s style, discloses it is an AI, and stays grounded in retrieved memories.
- Search & Recall: Natural language search across chats, emails, notes, screenshots; always cite sources.

Ethics & Consent
- Consent-first ingestion with a Consent Ledger recording source, purpose, and time of consent; data is user-owned and revocable.
- Data subject rights (GDPR/KVKK): Access, Erasure, Portability, Restrict/Object, and clear “Right to be Informed” via a Privacy Dashboard.
- Digital legacy requires explicit “digital will” or estate consent; the persona never claims to be the actual person.
- Safety stance: No afterlife claims; neutral tone for sensitive domains (health/legal); content policies apply even in persona mode.

System Architecture (Capture → Preprocess → Index → Retrieve → Generate)
- Capture: iOS/Android share extensions, quick-add voice/text, screenshot import, batch imports (Gmail/IMAP, chat exports).
- Preprocess: OCR/ASR as needed; PII redaction; segmentation/chunking with conversation boundaries and overlap; metadata extraction (timestamps, participants, language).
- Index: Three coordinated stores per chunk with shared IDs:
  - Vector Index (semantic): embeddings + metadata for ANN search.
  - Text Search (lexical): BM25 keyword/full‑text index.
  - Knowledge Graph (KG): entities, events, relations with links to source snippets.
- Retrieve: Hybrid retrieval from vector, BM25, and KG, then merge and diversify; optional re‑rank; temporal and filter controls.
- Generate: LLM composes answers/persona outputs grounded in retrieved context with inline citations and safeguards.

Data Sources & Capture Layer (Mobile)
- iOS: Share Extension; on-device Vision OCR; Apple Dictation/Speech for ASR; Siri Shortcuts/App Intents for “Add Memory”; offline queueing.
- Android: Share Intent; ML Kit text recognition for on‑device OCR; SpeechRecognizer/Gboard; widgets/shortcuts; offline queueing.
- Privacy Mode: Prefer on-device OCR/ASR and send only extracted text; allow user to delay/opt‑in to cloud processing.

Preprocessing & Redaction
- OCR: On-device first (Apple Vision / Android ML Kit); server OCR fallback (e.g., for hard cases) only with consent.
- ASR: Prefer OS speech APIs for on-device; Whisper (small/medium) or server ASR as optional fallback; show transcript for user correction; highlight low‑confidence spans.
- PII Redaction: Microsoft Presidio-based detection; policy-tiered masking (e.g., mask card/SSN; cautious reveal of contacts only when explicitly asked); optional output-time redaction.
- Chunking: Conversation-aware splitting with overlap; metadata includes timestamp, participants, source, language.

Knowledge Graph (Graph‑Enhanced Retrieval & Insights)
- Entities: People, places, orgs, topics, events, projects, accounts.
- Relations: Communications (“A messaged B at time about topic”), social ties, event participation, locations, timelines.
- Store: Property graph (Neo4j) or relational model in Postgres; every node/edge cites supporting chunks.
- Uses: Graph lookup/hops during retrieval; timeline views; relationship graphs; high‑precision fact grounding for persona responses.

Retrieval & Reasoning Algorithms
- Dense + Sparse Hybrid: Combine embeddings similarity with BM25.
- Rank Fusion: Reciprocal Rank Fusion (RRF) to merge ranked lists from vector, BM25, and KG.
- Diversity: Maximal Marginal Relevance (MMR) to reduce redundancy and increase coverage.
- Reranking (optional): Cross‑encoders (e.g., MiniLM/MPNet) or late‑interaction models (e.g., ColBERT) for precision at top‑K.
- Query Expansion: HyDE (Hypothetical Document Embeddings) and pseudo‑relevance feedback to improve recall.
- Temporal/Recency: Time‑decay boosting when queries imply “latest/current,” plus explicit date filters.
- Cross‑lingual: Multilingual embeddings; optional translate‑then‑search for BM25; language‑aware pipelines.
- Session Memory: Lightweight recent-turn memory for follow‑ups (kept separate from long‑term memory).

Persona Modeling (Style, Safety, and Controls)
- Style Profile (no fine‑tuning): Derive lexical, syntactic, discourse, tone cues; store a structured style guide/prompt.
- Prompting & Few‑Shot: In‑prompt style conditioning and safe few‑shot examples; style intensity slider with caps for sensitive contexts.
- Optional Fine‑Tuning (later): Per‑user LoRA/adapters for style only (never to replace retrieval for facts); strong guardrails to prevent memorized private content.
- Disclosure & Guardrails: Always label as “AI Simulation of [Name]’s style.” For sensitive topics, auto‑shift to neutral factual tone.

Self‑Insight Engine
- Event Extraction & Timelines: Detect events from messages/emails; build yearly/monthly timelines; change detection over time.
- Relationship Insights: Communication frequency trends, sentiment tone shifts, conflict patterns; entity disambiguation for contacts.
- Evidence & Explainability: Every insight links to backing snippets/data; present numbers (counts/trends) and example citations.
- Error Mitigation: Ask for confirmation on speculative insights; support user corrections (split/merge contacts; label sarcasm vs conflict).

Privacy, Security & Compliance
- Data Rights: Full export and deletion; deletion cascades to vectors, KG, caches, and backups (cryptographic erasure strategy).
- Encryption: TLS in transit; envelope encryption at rest with per‑user DEKs via KMS (e.g., AWS KMS); audit key usage; BYOK option for advanced users; device‑side encryption (iOS Keychain; Android EncryptedSharedPreferences/SQLCipher).
- Confidential Compute (advanced/enterprise): Consider enclaves (SGX/Nitro) or confidential VMs for sensitive processing.
- Threat Model: STRIDE analysis with mitigations for spoofing, tampering, disclosure, DoS, and EoP; rigorous multi‑tenant isolation; rate limits and quotas.
- Output Safety: Moderation filters; prompt hardening against injection; never newly generate harmful content; provenance-first UI.

Evaluation & Quality Assurance
- RAG Quality: RAGAS metrics (faithfulness, context precision/recall, answer relevancy); synthetic datasets with known ground truth.
- Retrieval Metrics: Precision@K, MRR, diversity checks; latency SLAs (< ~3–5s end‑to‑end typical).
- ASR/OCR: WER for ASR; OCR accuracy sampling; human‑in‑loop transcript edits for low‑confidence segments.
- Red‑Team Suite: Prompt‑injection attempts; toxic/edge content; vague/complex queries; continuous regression tests.
- Human Feedback: Thumbs up/down per answer; track citation clicks; evaluation logs with privacy scrubbing.

Product & GTM Highlights
- Initial Focus: B2C self‑insight for living users; small clinician pilot under strict privacy; digital legacy in cautious private beta.
- Differentiators: Consent-first UX, show‑your‑work citations, graph‑enhanced insights, local/on‑device capture, clear persona disclosure.
- Pricing/Cost Sensitivity: Optimize LLM usage (3.5 for routine, 4 for complex), cache embeddings, and tune retrieval to control API cost.

Implementation Roadmap (Condensed)
- Phase 0 Prototype (6–8 wks): Minimal ingestion; pgvector + BM25; OpenAI Q&A; barebones UI/CLI; verify citations.
- MVP (~12 wks): Gmail/IMAP + chat import; iOS capture (voice/text) and basic OCR; Postgres+pgvector; initial KG in Postgres; hybrid retrieval with RRF/MMR; GPT‑4/3.5 generation; web dashboard; core privacy (delete/export, consent flows); Presidio redaction.
- v1 (~+6 wks): Full KG (Neo4j or expanded PG graph), persona style controls, insights dashboard/timelines, Android app, on‑device OCR/ASR, 2FA, KMS.
- v2+: Enterprise SSO, plugins (Outlook/Slack), optional local models, broader connectors, deployment hardening.

Top Concrete Decisions (from the plan)
- Vector DB: Start with Postgres + pgvector (HNSW); re‑evaluate at ~5–10M vectors; Qdrant or managed Pinecone if scale demands.
- LLM: Use OpenAI GPT‑4/3.5 at launch; explore Claude; plan for open‑source fallback (Llama‑2 + adapters) for privacy/cost.
- Platform Focus: Prioritize iOS first for capture; stage Android.
- MVP Scope: Limit to emails, chat logs, and notes; add connectors gradually.
- Provenance: Show sources by default in UI; never answer without citations.
- Safety: Moderate outputs; adhere to safety policies regardless of persona style.
- Metrics: Ship feedback loop and evaluation logging from day one.
- Cloud & Keys: Deploy on AWS with KMS; keep infra simple (Docker + ECS/VM) before K8s.

Key Algorithms & Techniques (At a Glance)
- Hybrid Search: Embeddings + BM25; fusion via RRF; diversity via MMR.
- Rerankers: Cross‑encoders (MiniLM/MPNet) or ColBERT.
- Query Expansion: HyDE; pseudo‑relevance feedback.
- Temporal Boosting: Time‑decay factor for recency‑sensitive queries.
- Entity/Relation Extraction: Build KG from communications (people, places, events, topics) with links to source chunks.
- Style Modeling: Structured style profile; in‑prompt conditioning; adjustable intensity; optional LoRA later.
- Redaction: Presidio detectors; layered policies; output‑time masking.

Primary Tools & Stack
- Backend: Python FastAPI; orchestration with LangChain or custom pipeline; Docker; GitHub Actions for CI/CD.
- Datastores: Postgres (+ pgvector); text search via Postgres full‑text (Elastic/OpenSearch later if needed); Neo4j or relational KG in Postgres; object storage (e.g., S3) for files.
- Vector Search: pgvector (MVP), Qdrant for scale; HNSW indexes.
- LLMs/Embeddings: OpenAI GPT‑4/3.5 for generation; OpenAI text‑embedding‑ada‑002 (or similar); explore Claude and open‑source (Llama 2) later.
- Mobile: iOS (Swift, Vision OCR, Speech/Dictation); Android (ML Kit OCR, SpeechRecognizer); share extensions/intents; offline caching.
- Redaction & Security: Microsoft Presidio; AWS KMS; TLS; device‑side encryption; optional confidential compute for enterprise.

Risks & Mitigations (Summary)
- Privacy Breach: Strong encryption, minimal logging, audits/pentest, KMS per‑user keys, cryptographic erasure.
- Hallucinations/False Insights: Grounding via citations; conservative language (“seems”); user verification; RAGAS monitoring; improve retrieval.
- Ethical Misuse (griefbots): Clear disclosure; bounded interactivity; expert consultation; cautious rollout.
- Regulatory Uncertainty: Track GDPR/KVKK/AI Act; adjust features; geo‑fence if required.
- Cost/Latency: Hybrid retrieval efficiency; model tiering; caching; consider switching vector DB or adding reranker only as needed.
- Adoption: Deliver immediate value (imports, insights); proactive summaries; make capture effortless.

Key Metrics to Track
- Retrieval: P@5, MRR, diversity indicators, end‑to‑end latency.
- Groundedness: RAGAS faithfulness/context metrics.
- ASR/OCR: WER and OCR accuracy samples; user transcript edits.
- Engagement: Query frequency, citation click‑through, thumbs up/down, import completion rates.
- Safety: Moderation flags, injection resilience test pass rate.

MVP Deliverables (Condensed)
- Ingestion (Gmail/IMAP + chat export), hybrid retrieval (pgvector + PG full‑text + RRF/MMR), GPT‑backed answers with citations, iOS capture (voice/text + share), Presidio redaction, delete/export, basic dashboard/chat UI, auth, Dockerized backend on AWS with encrypted DB.

Notes
- Host Turkish/EU user data in EU/Turkey to align with KVKK/GDPR where needed.
- Keep prompts hardened; ensure system instructions cannot be overridden by retrieved content.
- Treat style as “presentation,” facts from retrieval/KG; never invent.

