# Historical research and future feature register

The original report identifies itself as November 2025 research. L01 is the long report; L02 and L03 are its summaries. The originals remain unchanged. See the [source register](source-register.md) for hashes and section ranges.

**All H-items below are historical research unless the current feature register separately marks a matching owner request.** This register preserves ideas without adding them to an approved build. Similar entries are grouped to avoid repeating the same idea from three documents.

## People, insights, and memory

| ID | Historical feature group | Preserved details | Source |
| --- | --- | --- | --- |
| H01 | Natural-language recall | Ask about past events, decisions, people, topics, and relationships. Show the supporting records. | L01 sections 1, 3; L02-L03 |
| H02 | Life timelines | Organize events by year, month, and day. Summarize milestones and changes. | L01 section 5.1 |
| H03 | Event extraction | Identify who, what, when, and where. Connect explicit dates, invitations, milestones, trips, and related conversations. | L01 section 5.1 |
| H04 | Topic discovery | Group discussions into themes. Map topics to people and periods. Consider BERTopic or other clustering. | L01 sections 5.1-5.2 |
| H05 | Communication statistics | Count messages and contacts. Show reply times, active periods, top contacts, and changes in communication. Counts do not prove closeness or cause. | L01 sections 5.1-5.2 |
| H06 | Sentiment and emotion trends | Explore tone over time and by relationship. Allow analysis to be disabled and errors corrected. Treat sarcasm, culture, and missing data as limitations. | L01 sections 5 and 8 |
| H07 | Change detection | Find shifts in message frequency, topics, or tone. Show hypotheses with supporting counts and time ranges. | L01 section 5.1 |
| H08 | Commitments and conflict history | Extract promises, tentative plans, and disagreements. Track follow-ups where evidence supports them. Do not infer completion from silence. | L01 section 5.1 |
| H09 | Relationship graph | Connect people, groups, organizations, projects, events, and places. Explore communities and relationship changes. | L01 sections 3.3 and 5.2 |
| H10 | Evidence browser and feedback | Open cited snippets, inspect raw records and data ranges, correct insights, and merge/split contacts. Include reasons for negative feedback. | L01 sections 3.4, 5.3, 6, 8 |
| H11 | Proactive reflection | Offer daily/weekly summaries and "this day in history" prompts. Sensitivity and notification controls need review. | L01 sections 10.3 and risk register |

## Capture and personal controls

| ID | Historical feature group | Preserved details | Source |
| --- | --- | --- | --- |
| H12 | Broader imports | Gmail/IMAP, chat exports, SMS backups, diary entries, screenshots, photos, and email archives. Named connector ideas include WhatsApp, Messenger, Outlook, Slack, Teams, Notion, and note apps. | L01 sections 2, 6, 9, 10; L03 |
| H13 | Share capture | iOS share extension and Android share targets for text, links, and images. Store source metadata. | L01 section 6.1 |
| H14 | Quick capture access | Widgets, Siri/App Intents, home-screen shortcuts, Android intents, and possible assistant integrations. | L01 sections 6.1 and 10.1 |
| H15 | Camera and screenshot handling | Take or select images, read text, and consider screenshot import suggestions with permission. No continuous access or background monitoring has been approved. | L01 section 6.1 |
| H16 | OCR and speech review | Prefer local recognition, review uncertain text, support corrections and a possible names dictionary. Cloud fallback was an option, not current permission. | L01 sections 6.2 and 8.2 |
| H17 | Capture categories and browser | Ideas, decisions, tasks, journal/reflection, quotations/references, milestones, and conflict notes. Browse by date or tag, then edit or delete. Classification should be skippable or correctable. | L01 sections 6.1 and 6.3 |
| H18 | Offline queue and processing controls | Capture while offline, show queued/processing/failed/completed states, retry safely, and allow manual transfer controls. Old mandatory upload behavior is superseded by the current local-use preference. | L01 section 6; L03 Appendix F |
| H19 | Temporary conversations | Keep short-term conversational context separate from durable memory. Consider a configurable timeout, continue-later/pinned context, clear-session action, and private/incognito chat. | L01 sections 2.1 and 3.2 |
| H20 | Multilingual behavior | English, Arabic, and Turkish were named. Consider cross-language search, query translation, same-language replies, original/translated citations, and Arabic RTL. Current additional-language priorities remain open. | L01 section 3.2; L02-L03 |
| H21 | Owner data controls | Consent by source/purpose, a consent ledger, connected-source pause/revoke controls, inspect/correct/delete/export, retention choices, and disabling selected analyses. | L01 sections 1.2 and 7 |
| H22 | Privacy views and redaction | Explain why an insight appears. Consider masking selected identifiers, custom sensitive terms/topics, selective import, restricted export, and sensitivity settings. | L01 sections 1.2, 5.3, 7 and risk register |
| H23 | Portable exports | Export raw data and derived records in formats such as JSON/CSV; export reports as PDF/HTML. Exact formats are historical suggestions. | L01 section 1.2 |

## Persona and broader product editions

| ID | Historical feature group | Preserved details | Source |
| --- | --- | --- | --- |
| H24 | Writing-style profile | Analyze vocabulary, punctuation, sentence form, tone, greetings, emoji, and language mixing. Use a structured style guide and selected examples. | L01 section 4.1 |
| H25 | Persona style controls | Neutral/light/strong style levels, user adjustments, and factual grounding separate from presentation. Sensitive-topic tone behavior remains a design choice. | L01 sections 4.2-4.3 |
| H26 | Optional personal style training | Consider per-user LoRA/adapters or feedback-driven tuning later. This is research, not permission to train on private data. | L01 section 4.1 |
| H27 | Digital legacy persona | Preserve an explicitly labeled AI memory/style simulation. Explore consent or estate authority, an exportable read-only archive, identity disclosure, and limits. Current owner has not reconfirmed this product scope. | L01 sections 1, 4, 10.1 |
| H28 | Clinician or coach use | Consented client summaries, timelines, between-session reflection, and a limited pilot. No clinical validation or pilot authorization exists. | L01 sections 1.1, 6.1, 9.3 |
| H29 | Enterprise memory | Team knowledge, onboarding, expertise lookup, role continuity, workflow insights, and professional/industry editions. Shared access and consent would need a new design. | L01 sections 1.1, 9, 10.1 |
| H30 | Collaboration | Mutually shared memories or joint timelines. Private sharing and third-party data controls remain unresolved. | L01 section 10.1 |
| H31 | Additional personal sources | Health/fitness logs, photo metadata, travel/location context, external contacts/social graphs, and possible cross-source patterns. No sensor or health-data integration is authorized. | L01 sections 5.1-5.2 and 10.1 |
| H32 | External API and plugins | Query personal memory through authenticated tools. Consider email/chat plugins, Siri/Alexa hooks, and exports to other note systems. | L01 sections 9 and 10.1 |

## Technical and delivery research

| ID | Historical research group | Preserved details | Source |
| --- | --- | --- | --- |
| H33 | Three retrieval views | Semantic vectors, keyword/full-text search, and linked entities/events share stable source IDs. Graph traversal and nearby-thread/time context can supplement retrieval. | L01 sections 2-3 |
| H34 | Ranking and expansion experiments | RRF rank fusion, MMR diversity, BM25, HNSW/IVF, optional MiniLM/MPNet cross-encoders or ColBERT, HyDE, pseudo-relevance feedback, synonyms, recency weighting, and possible learned ranking/session embeddings. None is a selected app algorithm. | L01 section 3; L02-L03 |
| H35 | Historical cloud stack | Python/FastAPI, LangChain/custom orchestration or Haystack research; Postgres/pgvector; Neo4j/relational graph; Qdrant/Pinecone scale options; Elastic/OpenSearch; object storage; Docker/CI. Cloud-first launch is superseded for current planning. | L01 sections 2 and 10; L02-L03 |
| H36 | Historical model/tool choices | GPT-4/GPT-3.5, Claude, Llama 2/GPT-J, OpenAI embeddings, multilingual MPNet/LaBSE, spaCy/NER, date parsers, emotion lexicons, Presidio, Vision, ML Kit, and OS speech APIs. These names record past options, not current recommendations. | L01 sections 2-8; L02-L03 |
| H37 | Security research | Device/app unlock, encryption, protected keys, encrypted backups, deletion across derived stores, TLS, per-user isolation, 2FA/SSO, token controls, rate limits, safe logs, threat modeling, BYOK, KMS, confidential compute, and incident response. Designs need current review. | L01 section 7 |
| H38 | Evaluation research | Known-answer data, citation support, contradiction tests, precision/recall/MRR, RAGAS, OCR/ASR error rates, identity accuracy, injection/privacy testing, feedback, performance/cost measurements, and regression tests. Historical targets were not measured results. | L01 section 8; L02-L03 |
| H39 | Business and deployment options | Freemium/premium, one-time/lifetime or self-hosted editions, enterprise licenses, private/VPC/on-prem hosting, possible open-core code, pilots, partnerships, regional launches, and professional packs. No pricing, company launch, or deployment is selected. | L01 sections 9-10 |
| H40 | Delivery and growth suggestions | Prototype/MVP/v1/v2 stages, web dashboard, native mobile clients, TestFlight/beta plans, staffing, legal review, privacy documentation, support/community work, future research, cost monitoring, and optional capture gamification. No schedule, hiring, budget, or publication is approved. | L01 section 10; L02-L03 |

## Research limits and source defects

- The original report contains broad technical, legal, competitor, performance, and commercial claims. This task preserves them as historical material. It does not verify current law, provider terms, prices, accuracy, scale limits, or market claims.
- The report's table of contents lists "15 Novel Concepts." No separate numbered section containing those 15 concepts was found in the supplied body. Do not invent that list.
- Some citations are detached domain lines, repeated entries, or weakly matched references. They do not prove the associated claim.
- Some text-search examples use Postgres full-text ranking while also referring to BM25. A current implementation must select and validate an actual ranking method rather than assume they are interchangeable.
- Old formulas, thresholds, and budgets are illustrative. Do not copy them as validated algorithms or acceptance criteria. The recency explanation and formula, for example, need mathematical review before use.
- The research contains conflicting defaults for cloud processing and local speech recognition, as well as different rollout durations. Current local-first owner instructions take precedence. No historic duration is a current estimate.
- Older declarations of GDPR/KVKK/AI Act compliance or legal risk do not establish compliance. A future public/professional product needs a separate current assessment.
- None of the original files proves a built application, selected stack, approved design, successful pilot, trained persona, measured accuracy, or delivered release.
