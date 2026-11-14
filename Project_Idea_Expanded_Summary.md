Eros Memory OS — Expanded Research Summary

Executive Overview
- Purpose: A privacy-first memory OS that transforms personal digital traces (messages, emails, voice notes, screenshots) into a searchable memory, an explainable self‑insight engine, and an ethically‑bounded digital legacy persona.
- Why now: Recent advances in LLMs/embeddings and growing user demand for digital well‑being, memory augmentation, and control over personal data.
- Differentiators: Consent‑by‑design, provenance (citations on every answer), hybrid retrieval (vectors + BM25 + knowledge graph), graph‑enhanced insights, mobile capture with on‑device processing options, rigorous privacy and encryption.

Core Capabilities & Value
- Ask & Recall: Natural‑language questions across personal history, always grounded with citations to source snippets.
- Self‑Insight: Timelines, relationship patterns, trends (e.g., sentiment shifts), event summaries with evidence links.
- Digital Legacy Persona: An AI memory‑model that adapts to the user’s style (disclosed as AI), grounded in retrieved content.
- Exports & Control: Full export/delete; portable formats; per‑source consent management.

Ethical Boundaries & Consent
- Consent Ledger: Record data source, scope, purpose, and timestamp for all ingestions; user can pause/withdraw any source.
- Data Rights: Support GDPR/KVKK rights (access, erasure, portability, restriction/object); transparent explanations in a Privacy Dashboard.
- Digital Legacy: Require explicit prior consent (digital will) or estate authorization; persona never claims to be the person.
- Safety & Tone: For sensitive domains (health/legal), automatically shift to a neutral, factual style; content policies apply even in persona mode.

System Architecture (Capture → Preprocess → Index → Retrieve → Generate)
- Capture (Mobile/Web):
  - iOS: Share Extension, App Intents/Siri Shortcuts (“Add Memory”), on‑device Vision OCR, Apple speech APIs.
  - Android: Share Intent, widgets/shortcuts, ML Kit OCR, Android SpeechRecognizer/Gboard.
  - Batch Imports: Gmail/IMAP for email; chat exports (e.g., WhatsApp); user notes.
  - Offline‑first: Local queue; background sync when allowed; explicit privacy mode to keep raw media local.
- Preprocess:
  - OCR: On‑device first (Vision/ML Kit); server OCR fallback only with consent for hard cases (e.g., handwriting).
  - ASR: Prefer on‑device speech APIs; optional server models (e.g., Whisper small/medium) when permitted; show transcript for user edits with low‑confidence highlighting.
  - PII Redaction: Microsoft Presidio recognizers; policy tiers (mask CC/SSN, careful reveal of contact data only when explicitly asked); option to redact at prompt time.
  - Chunking: Conversation‑aware segmentation with overlap; preserve metadata (timestamp, participants, source, language, tags).
- Index (three coordinated stores):
  - Vector Index (semantic): Embeddings + metadata; ANN (e.g., pgvector HNSW). Enable filtering by time, participants, language.
  - Text Search (lexical): BM25 via Postgres full‑text initially; Elastic/OpenSearch optional later.
  - Knowledge Graph (KG): Property graph of entities (people, places, orgs, topics), events, and relations; every node/edge cites source chunks.
- Retrieve:
  - Hybrid recall from vector + BM25 + KG, then merge via rank fusion and diversify with MMR.
  - Optional rerankers (cross‑encoders or late‑interaction) at top‑K for precision.
  - Temporal filters and recency boosting when implied; multilingual handling.
- Generate:
  - Prompt templates enforce grounding (“only use provided snippets”), citations, safety, and optional style conditioning.
  - Persona responses disclose AI nature; style intensity is capped for sensitive topics.

Data Model & Storage Details
- Chunk: {id, source_type, source_id, text, lang, timestamp, participants[], tags[], pii_flags[], embedding, citation_ref}.
- Vector Store: Postgres + pgvector (MVP); plan for Qdrant if scale > ~5–10M vectors. HNSW index for latency; per‑chunk metadata filters.
- Text Index: Postgres full‑text (tsvector/ts_rank) initially; Elastic/OpenSearch if advanced DSL/fuzziness needed.
- Knowledge Graph:
  - Nodes: Person, Place, Organization, Topic, Event, Account, User.
  - Edges: communicated_with, about_topic, at_place, participated_in, friend_of, worked_on, mentioned_in.
  - Each node/edge maintains back‑pointers to chunk IDs for provenance.
  - Store in Neo4j or relational PG tables (entities, relations) for MVP simplicity.

Retrieval & Ranking Algorithms (Deep Dive)
- Dense + Sparse Hybrid: Retrieve top‑N embeddings neighbors and BM25 matches in parallel.
- Rank Fusion (RRF): Score(doc) = Σ 1/(k + rank_i(doc)) across lists; k is small (e.g., 60) to smooth.
- Maximal Marginal Relevance (MMR): Iteratively select next doc maximizing λ·sim(query, doc) − (1−λ)·max_sim(doc, selected), using embedding cosine similarity; tune λ (e.g., ~0.7) for relevance vs diversity.
- Rerankers (optional): Cross‑encoders (e.g., MiniLM/MPNet) or ColBERT‑style late interaction to refine top‑K.
- Query Expansion:
  - HyDE: Generate a hypothetical answer/document, embed it, and re‑query vector store to increase recall.
  - Pseudo‑relevance feedback: Extract salient terms from initial hits to refine BM25.
- Temporal/Recency Boosting: similarity_adj = similarity · (1 + α · recency_score), where recency_score = 1 / (1 + e^((now − t)/half_life)).
- Cross‑lingual: Multilingual embeddings; for BM25 on English text, optionally translate queries; store language metadata for filters.
- Session Memory: Retain recent turns separately; do not pollute long‑term memory; enable follow‑ups without re‑ingest.
- Provenance & Confidence: Always attach citation IDs; optionally compute a simple confidence from retrieval cohesion and answer coverage.

Generation & Prompting
- Q&A Prompt: Instruction to only use provided snippets; require inline citation tags [n]; refuse if insufficient evidence; acknowledge conflicts by presenting both sides.
- Persona Prompt: Insert “Style Profile” section derived from user corpus; require disclosure string (AI simulation of [Name]’s style); cap intensity on sensitive topics; still cite sources when facts are used.
- Post‑processing: Replace [n] with source excerpt metadata (date, app, participants); display expandable citations in UI.

Persona Modeling
- Style Profile (parameter‑free):
  - Lexical: frequent words, slang, emoji usage; bigrams vs general baseline.
  - Syntax/Discourse: sentence length, punctuation, questions, storytelling vs concise.
  - Tone: sentiment distribution; politeness markers; code‑switching/multilingual mix.
  - Representation: JSON style guide and/or promptable description; maintain examples that are generic and non‑sensitive.
- Few‑shot Nudging: Include short, non‑sensitive exemplars as style hints in prompts.
- Optional LoRA Later: Consider per‑user adapters for style only (no facts baked in); continue using retrieval for factuality; careful to avoid regurgitating private text.
- Guardrails: Persona never claims identity; sensitive topics auto‑downgrade to neutral style; content policies always apply.

Self‑Insight Engine
- Event Extraction & Timelines: Detect events (who/where/when/what); generate timelines (year/month/day) and summaries; highlight changes vs prior periods.
- Relationship Insights: Communication frequency trends, sentiment/tonality shifts, conflict markers; disambiguate contacts (entity resolution); allow user corrections (merge/split personas).
- Explainability: Each insight card includes “Why?” with counts/graphs and example snippets; user can down‑vote or correct.
- Error Modes & Mitigations: False correlations, missing context, entity resolution mistakes, sarcasm ambiguity, timestamps; mitigate via cautionary phrasing (“It appears that…”), user confirmation, and feedback loops.

Privacy, Security & Compliance
- Consent & Transparency: Explicit per‑source consent (onboarding + settings); visible data map; “Why am I seeing this?” explanations.
- PII Handling: Presidio detection; strong masking for secrets (cards/SSNs), careful treatment of contact data; disallow generation of sensitive numbers unless explicitly asked by the user.
- Encryption: TLS in transit; envelope encryption at rest with per‑user DEKs via KMS; audit key usage; optional BYOK for advanced users.
- Deletion & Backups: Cascade deletion across vectors/KG/caches; cryptographic erasure by dropping DEKs; scrub logs of raw content.
- Threat Model (STRIDE):
  - Spoofing: Strong auth (+ optional 2FA), short‑lived tokens, new‑device notifications.
  - Tampering: TLS, integrity checks, restricted DB roles, admin action audits.
  - Repudiation: Submission logs (non‑content metadata); strong identity verification for destructive actions.
  - Information Disclosure: Per‑tenant isolation, least‑privilege access, zero raw content in logs, moderation on outputs.
  - DoS: Rate limits/quotas; cost guards on LLM calls; storage quotas for giant uploads.
  - EoP: Strict authorization checks, protected admin surface (IP allow‑list/2FA), secure frameworks.
- Data Residency: Host EU/Turkish users in EU/Turkey regions to align with GDPR/KVKK expectations.

Evaluation & Quality Assurance
- RAG Quality (RAGAS):
  - Faithfulness: Fraction of answer supported by provided context.
  - Context Precision/Recall: Are snippets relevant; did we retrieve what’s needed?
  - Answer Relevancy/Correctness: Coverage of the user query.
- Retrieval Metrics: Precision@K (target high P@5), MRR, diversity (near‑duplicate rate), latency budget (< ~3–5s end‑to‑end typical).
- ASR/OCR: Word Error Rate (WER) tracking; OCR sampling accuracy; human‑in‑loop edits for low‑confidence regions.
- Red‑Team Suite: Prompt injection attempts in retrieved content; toxic/edge content handling; vague/complex queries; continuous regression.
- Human Feedback: Thumbs up/down; citation click‑through; lightweight telemetry with privacy scrubbing.

Competitive Landscape & Differentiation
- Landscape: Memory assistants (Rewind), note‑taking (Reflect), personal AI (Personal AI), companion chatbots (Pi).
- Differentiators: Consent‑first UX, provenance on all answers, KG‑powered insights and retrieval, mobile edge processing options, explicit persona disclosure and safety posture.

Implementation Roadmap (Detail)
- Phase 0 Prototype (6–8 weeks): Minimal ingestion, pgvector + BM25 hybrid, OpenAI Q&A with citations, barebones UI/CLI, synthetic evals.
- MVP (~12 weeks): Gmail/IMAP + chat imports; iOS capture (voice/text, basic OCR); Postgres+pgvector; initial KG in Postgres; hybrid RRF/MMR; GPT‑4/3.5; web dashboard with citations; Presidio redaction; consent flows; delete/export; basic auth; secure staging on cloud.
- v1 (~+6 weeks): Full KG (Neo4j or expanded PG graph), persona style controls & slider, insights dashboard & timelines, Android app, on‑device OCR/ASR, 2FA, KMS integration, enhanced audit logging.
- v2+: Enterprise SSO, additional connectors (Outlook/Slack), plugins, optional local models, performance/cost optimizations, deployment hardening.

90‑Day Plan (Condensed Checkpoints)
- Weeks 1–2: Repo + CI; PG + pgvector schema; simple ingestion + test vector search; iOS skeleton; OpenAI API smoke test; choose entity extraction tool.
- Weeks 3–4: Email importer; chunking + embeddings; BM25 search; RRF fusion + MMR; iOS Share Extension; auth; acceptance: import set → hybrid retrieval → GPT answers with source tags.
- Weeks 5–6: Prompt template; citation mapping; chat UI with tappable sources; basic sentiment; DB field encryption; acceptance: 8/10 factual queries answered correctly with proper citations on internal datasets.
- Week 7: Retrieval tuning; formatting fixes; safety refinements; add feedback loop; acceptance: stable quality and UI.
- Week 8: Presidio pipeline; consent screens; privacy policy; staging infra with TLS/encrypted DB; TestFlight prep; acceptance: PII masking verified; deployable build.

Costs & Resourcing (MVP ballpark)
- Cloud: DB + VMs ≈ $300/mo; storage ≈ $50/mo (low-volume beta).
- LLM API: Highly variable; order of magnitude ~$1k for ~100 moderate users; up to ~$10k for ~1000 heavy users (optimize with model tiering/caching).
- Team: 2–3 engineers for ~3 months ≈ $90k dev cost; add part‑time design/compliance support.

Risks & Mitigations
- Privacy Breach: Strong encryption, minimal logs, audits/pentests, per‑user keys, cryptographic erasure.
- Hallucinations/False Insights: Ground answers with citations, conservative language, RAGAS monitoring, retrieval/reranker tuning.
- Ethical Misuse (griefbots): Disclosure, bounded interactivity, expert consultation, phased rollout.
- Regulatory Shifts: Track GDPR/KVKK/AI Act; adjust features; temporary geo‑fencing if needed.
- Scale/Cost: Monitor latency/cost; switch vector DB if needed; add caching and selective reranking.
- Adoption: Immediate value (imports/insights), proactive summaries, frictionless capture.

Top Decisions (with rationale)
- Vector DB: Postgres + pgvector (HNSW) for MVP; re‑evaluate at ~5–10M vectors (Qdrant or Pinecone for scale).
- LLM: Use GPT‑4/3.5 initially; explore Claude/open‑source later for privacy/cost; keep pluggable backend interface.
- Platform Focus: iOS first to nail capture UX; stage Android.
- MVP Scope: Start with email/chat/notes; defer social/calendar/sensors; add connectors iteratively.
- Provenance: Show sources by default; never answer without citations.
- Safety: Integrate moderation; harden prompts against injection; persona never overrides safety.
- Metrics: Ship feedback/eval logging early to guide tuning.
- Infra & Keys: AWS with KMS; Dockerized services; defer Kubernetes until needed.

Key Metrics & Telemetry
- Retrieval: Precision@5, MRR, redundancy rate, query latency.
- Grounding: RAGAS faithfulness, context precision/recall, answer relevancy.
- ASR/OCR: WER, OCR accuracy samples, user edit rates.
- Engagement: Query volume, citation clicks, thumbs up/down, import completion.
- Safety: Moderation triggers, injection test pass rate.

Open Questions
- Which reranker (if any) provides best cost/latency tradeoff on personal data? Mini cross‑encoder vs ColBERT.
- Thresholds for style intensity auto‑downgrade in sensitive contexts.
- Extent of on‑device processing vs cloud for best UX/privacy balance per user preference.
- Data residency setups for Turkish users (EU vs Turkey region) based on KVKK guidance.

Appendix A — Example Prompts (Sketch)
- Q&A: “Use only the snippets below to answer. Cite sources like [1], [2]. If evidence is missing or conflicting, say so and show both sides. Snippets: … User question: …”
- Persona: “You are an AI simulation of [Name]’s style. Follow the Style Profile below, but keep facts grounded in retrieved snippets and cite sources. Disclose your AI nature. Style Profile: … Snippets: … User message: …”

Appendix B — Fusion & Diversity (Formulas)
- RRF: score(d) = Σ_i 1/(k + rank_i(d)); choose small k (e.g., 60).
- MMR: argmax_d∉S [ λ·sim(q,d) − (1−λ)·max_{s∈S} sim(d,s) ].
- Recency boost: similarity_adj = similarity·(1 + α·recency_score), recency_score = 1/(1 + e^((now−t)/half_life)).

Appendix C — Sample Postgres Schema (Sketch)
- chunks(id PK, source_type, source_id, text, lang, ts, participants JSONB, tags JSONB, pii JSONB)
- chunk_vectors(chunk_id FK, embedding VECTOR, ts, meta JSONB)
- ft_index via tsvector columns for text search.

Appendix D — KG Storage (Sketch)
- entities(id PK, type, name, attrs JSONB)
- relations(id PK, src_id FK, dst_id FK, type, ts, attrs JSONB)
- provenance tables mapping entity/relation IDs to chunk IDs.

Appendix E — Deletion Cascade Checklist
- Remove chunk + vector rows + FT entries + KG nodes/edges + caches.
- Delete per‑user DEK (cryptographic erasure); scrub logs; confirm backup retention policy.

Appendix F — Mobile Offline Sync (States)
- states: idle → capturing → queued → syncing → confirmed | failed(retry/backoff)
- privacy mode delays syncing; user can force sync on secure network.

Appendix G — Red‑Team Case Types
- Prompt injection in retrieved text; toxic historical messages; vague/under‑specified queries; requests for secrets (credit cards); competing/conflicting memories.

Appendix H — Consent Ledger Fields
- {user_id, source, scope, purpose, collected_at, expires_at?, revoked_at?, processing_flags, region, notes}

