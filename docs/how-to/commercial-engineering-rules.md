# Commercial and engineering rules

Owner sources: C22 and C23, 2026-11-13, in the [source register](../reference/source-register.md). The owner intends to sell MemoryOS in several markets with optional cloud AI and sync. The owner asked to make the preceding commercial and engineering recommendations project rules.

Status: standing requirements for future authorized work. No compliance certification, production implementation, or release verification follows from this document. Exact markets, business location, pricing, database, providers, models, and delivery dates remain open. Preserve the C20 foundation scope and C21 dark-mode preference.

## Architecture and data ownership

1. Keep everyday capture and local memory usable without a Mac, account, or server. A user may enable cloud features through an explicit connection decision.
2. Use Swift with SwiftUI. Organize the app as a modular monolith: one app divided into modules with defined responsibilities. Use a small modular backend only when its implementation receives authorization.
3. Use MVVM (Model-View-ViewModel) for SwiftUI features. Separate Views/ViewModels, domain models/rules/use cases, local storage, and service adapters. Follow the mandatory responsibilities and checks below. Use cases coordinate product actions. Adapters connect external implementations through small interfaces.
4. Keep domain code independent of SwiftUI, database types, and vendor SDKs. Views must not call databases, AI providers, or network services. Inject dependencies through initializers and keep feature state bounded to its responsibility.
5. MemoryOS must own durable source records, stable IDs, source dates/links, user corrections, and confirmed facts. Keep original sources, extracted claims, user confirmations, and AI interpretations distinguishable. Preserve provenance when a user corrects a claim.
6. Treat embeddings and provider search indexes as derived data. Rebuild them from app-owned records. Verify source links, corrections, deletions, and recovery when switching providers or models. Do not assume model or index formats are interchangeable.
7. Keep recording, transcription, retrieval, model inference, imports, sync, and purchases behind separate interfaces where their responsibilities differ. Prefer small interfaces over speculative abstraction layers.
8. Record concrete storage/provider choices in decision notes with tradeoffs, license terms, supported versions, compatibility, and measured device results. These rules select boundaries, not a database or AI package.

## Mandatory MVVM, repository, and engine rules

Owner instruction C34, 2026-11-14, makes MVVM explicit alongside C26/D30 and C27/D31. Agents must apply these rules directly. A different feature architecture requires an explicit owner decision; do not infer an exception from a SwiftUI example or library preference.

| Layer | Required responsibility and boundary |
| --- | --- |
| View | Render feature state, bind inputs, and forward user actions to its ViewModel. Keep layout, focus, sheet visibility, and other view-local presentation state here. Do not perform product rules, persistence, provider calls, or network requests in View bodies, lifecycle handlers, or button closures. Stateless display components do not need empty ViewModels. |
| ViewModel | Own feature presentation state and action coordination. Call injected app use cases; expose results, progress, and recoverable errors to the View. Keep UI-facing state on the main actor when applicable. Do not import or call storage implementations, provider SDKs, or network clients. A renamed global service or a file named ViewModel does not establish this boundary. |
| Model and domain | Own app records, stable IDs, corrections, product rules, use cases, and the small protocols the feature needs. Keep this code independent of SwiftUI/UIKit, concrete databases, network clients, and vendor SDKs. Use cases call these protocols; concrete implementations enter through dependency injection. |
| Storage and integration adapters | Implement app-owned protocols and translate between app values and concrete storage, platform, or engine APIs. Keep vendor types inside the adapter. Use upstream libraries for their engine capabilities; keep product rules and authoritative records in MemoryOS. |
| Composition root | Construct implementations and inject them at the app boundary. Views and ViewModels receive their required dependencies rather than creating concrete providers or looking them up through a global service locator. |

The action path is **View → ViewModel → use case → app-owned protocol → storage/integration adapter → selected library or platform API**. Return app-owned values and structured errors along that path. Add only the use cases/protocols needed by implemented behavior; do not generate empty layers or duplicate business logic to match a diagram.

Repository and engine ownership are mandatory:

1. Keep one private canonical app Git repository, [faroqomar/Eros_MemoryOS](https://github.com/faroqomar/Eros_MemoryOS). Keep app features, domain code, small interfaces, thin adapters, and app tests there. A domain data-access “repository” protocol is a code interface, not a request to create another GitHub repository.
2. “Separate engine repositories” means the upstream repositories/checkouts of selected libraries, such as a future approved Wax or transcription dependency. It does not mean custom `Eros_MemoryEngine` or `Eros_Speech` repositories. Reuse upstream capabilities; do not copy engine implementation into app source or create replacement engines without a separate owner decision.
3. Integrate a selected library through a reviewed pinned package revision and retain the resolved dependency file. Keep upstream development and its tests in its own checkout. Use local overrides only for explicit integration tests; remove them and recheck the pinned delivered configuration. A fork requires a concrete necessary patch and a recorded maintenance reason. Libraries named in research remain candidates until selected for authorized work.
4. At actual SDK integration, enforce an independent plain Swift core and the required integration target boundaries inside the app repository. Add no empty packages or custom engine repositories for this policy. Recording, transcription, retrieval, and model execution need separate replaceable contracts when implemented.
5. MemoryOS owns originals, IDs, source links, user corrections, and confirmed facts. Provider indexes are rebuildable derivatives. Keep the existing contract, Arabic/English, offline, recovery, upgrade, and physical-device benchmark requirements in the [upstream rules](../decisions/independent-engine-packages.md#mandatory-architecture-and-adoption-rules).

Step 1 must name the affected View, ViewModel, model/use case, protocol, adapter, composition root, repository/checkouts, and dependency revision in the task record, or justify an unaffected layer. Step 2 must apply the [explicit architecture checklist](development-workflow.md#mandatory-step-2-architecture-and-upstream-checks) to actual code and tests. Step 3 must confirm the reviewed head still matches that evidence. Unresolved required violations block passage; a documentation update or a build alone does not establish MVVM compliance.

## Privacy and cloud boundaries

1. Document each data flow before implementation: purpose, data categories, origin, recipients, controller/processor roles, legal basis, retention, deletion, hosting region, subprocessors, and transfer safeguards.
2. Minimize collected and transmitted data. Review personal information about people in imported chats and recordings as well as the buyer. A buyer's permission does not establish the legal grounds for every use of other people's information. Assess additional conditions for sensitive data.
3. Keep cloud AI and sync as separate opt-in capabilities. Show the receiving AI provider and the selected content before transmission. Obtain explicit permission. Do not enable a silent network fallback when local processing fails.
4. Design sync with end-to-end encryption and an explicit key-recovery/lost-device policy. Review standard cryptographic components and protected key storage. Do not invent cryptographic algorithms. Explain metadata exposure and backup behavior.
5. Distinguish encrypted sync from cloud inference. Ordinary cloud AI requires readable selected content at its processing endpoint. Do not promise end-to-end secrecy from a provider that processes that content.
6. Review provider processing contracts, training use, retention, onward transfers, deletion support, and official integration terms. Keep service secrets out of app bundles and logs. An EU hosting region alone does not settle cross-border access or subprocessor obligations.
7. Provide applicable access, correction, portable export, deletion, and consent-withdrawal controls. Define deletion across source files, attachments, derived indexes, sync replicas, queued jobs, and backups. Document legal retention exceptions and backup expiry limits.
8. Require authorization on backend operations and storage access. Verify isolation between accounts. Treat imported text and model output as untrusted data; neither may grant permissions or override user rules.
9. Keep privacy-safe operational logs and a vulnerability/incident response process. Record any applicable notification deadlines in the launch assessment. Assess whether a formal data protection impact assessment, privacy representative, or data protection officer is required; do not assume each role is mandatory for every app.

## Upgrades and maintenance

1. Version database schemas, export formats, sync messages, and model/index metadata. Test upgrades from supported older app versions. Preserve a recovery path when an upgrade fails; do not assume a destructive database downgrade is safe.
2. Use transactions and resumable/idempotent work where interruptions or retries can corrupt or duplicate user data. Define sync conflicts and deletion markers so an offline device cannot restore deleted records by accident.
3. Require formatting, static analysis, compilation, concurrency checks, and tests relevant to each change. Keep changes small enough to review. Record meaningful architecture changes and compatibility limits in project Markdown.
4. Test behavior and failure cases: interrupted capture/import, rejected permissions, offline use, migrations, backup/restore, deletion, provider replacement, and index rebuild. Test cloud authorization and cross-account access whenever cloud features change.
5. Use fictional Arabic, Iraqi Arabic, English, and mixed-language evaluation data. Check source-backed answers, corrections, missing evidence, and instructions embedded in imported content. Measure real-device latency, memory, storage, battery use, and heat against agreed targets.
6. Pin dependencies and track third-party code, model weights, assets, and their commercial/distribution licenses. Review security updates and keep a component inventory. Use [OWASP MASVS](https://mas.owasp.org/MASVS/) as the mobile security baseline, not as proof of legal compliance.
7. Build and verify VoiceOver, Dynamic Type, readable contrast, touch targets, Reduced Motion, and Arabic RTL behavior. Automated checks do not replace physical-device accessibility review.

## Market assessment before sale

Create a dated assessment for each target market and the seller's business location before enabling sales. Record the product/data-flow version, applicable law, reasoning, evidence, required controls, responsible person, and unresolved items. Use current primary sources and obtain qualified legal/tax review for the actual launch configuration. Reassess when markets, data flows, intended use, or distribution terms change.

The following is a research baseline from the preceding discussion on 2026-11-13. Applicability and dates require fresh verification at launch.

| Area | Required assessment and preparation | Primary source |
| --- | --- | --- |
| EU GDPR | Assess territorial scope, roles, lawful grounds, sensitive data, notices, rights, retention, security, and accountability. Targeting EU customers can bring a seller outside the EU into scope. Perform a DPIA before processing likely to create high risks. | [EDPB principles](https://www.edpb.europa.eu/sme/learn-the-basics/data-protection-basics_en), [lawful processing](https://www.edpb.europa.eu/sme/be-compliant/process-personal-data-lawfully_en), [DPIA](https://www.edpb.europa.eu/topics/accountability-and-compliance-tools/data-protection-impact-assessment_en) |
| Providers and transfers | Assess processor contracts, subprocessors, transfer mechanisms and any required transfer impact assessment. | [EDPB international transfers](https://www.edpb.europa.eu/sme/be-compliant/international-data-transfers_en) |
| ePrivacy and UK PECR | Review storage/access technologies, analytics, tracking, and electronic marketing under applicable national rules. Obtain consent where required; do not assume all analytics have identical treatment. | [EDPB FAQ](https://www.edpb.europa.eu/sme/find-practical-info/faq_en), [ICO storage/access guidance](https://ico.org.uk/for-organisations/direct-marketing-and-privacy-and-electronic-communications/guidance-on-the-use-of-storage-and-access-technologies/what-are-the-pecr-rules) |
| EU AI Act | Classify actual intended uses and provider/deployer roles. Apply relevant AI transparency duties. A personal assistant is not automatically high-risk. The Commission records August 2026 application of transparency rules; verify current obligations before release. | [European Commission AI Act](https://digital-strategy.ec.europa.eu/en/policies/regulatory-framework-ai) |
| Cyber Resilience Act | Assess the commercial downloadable app's scope. If applicable, prepare vulnerability handling, support/security updates, technical documentation, reporting, and conformity obligations. The Commission records reporting from 11 September 2026 and main obligations from 11 December 2027. | [European Commission CRA](https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act) |
| Consumer protection | Define purchase/subscription terms, prices, renewals, cancellation, applicable withdrawal/refund rights, supported devices, remedies, and update/support commitments. | [Your Europe digital content and services](https://europa.eu/youreurope/citizens/consumers/shopping/guarantees/index_en.htm) |
| Accessibility | Assess European Accessibility Act coverage of the offered services and purchase flows, national implementation, and justified exemptions. Do not assume every app falls in the same category; service microenterprise exemptions exist. | [EU accessibility guidance](https://europa.eu/youreurope/business/selling-in-eu/selling-goods-services/accessibility/index_en.htm) |
| Apple distribution | Verify privacy disclosures, third-party AI permission, in-app account deletion if accounts exist, billing/subscription rules per storefront, and EU trader-status/contact requirements. Keep these platform requirements distinct from statutory compliance. | [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [EU trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements) |
| UK | Assess UK GDPR and applicable UK rules using current ICO guidance. | [ICO scope](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/personal-information-what-is-it/who-does-the-uk-gdpr-apply-to/) |
| US | Assess federal consumer-protection rules and applicable state privacy/security laws. Check CCPA scope and current thresholds rather than assuming it applies to every paid app. | [FTC privacy promises](https://www.ftc.gov/policy/advocacy-research/tech-at-ftc/2024/02/keeping-your-privacy-enhancing-technology-pet-promises), [California regulator FAQ](https://cppa.ca.gov/faq.html) |
| Other markets and business duties | Review local privacy, conversation-recording consent, imports, consumer law, tax/VAT, seller registration, and payment availability. Assess additional children's rules if the intended audience or actual use requires them. Record current official sources for each selected country and sales channel. | Country-specific assessment remains open. |

## Release evidence

Before a commercial release, record results for the implemented configuration: migration/data-loss safety, backup restoration, privacy controls, applicable cloud isolation, accessibility, AI quality, and supported physical-device performance. Resolve applicable legal and distribution obligations. Publish an accurate support/security-update commitment and support contact through the authorized release process.

Keep outstanding checks visible. Passing compilation does not prove compliance, restoration, AI quality, or installed-device behavior. Owner authorization for publication, deployment, purchases, and release remains separate.
