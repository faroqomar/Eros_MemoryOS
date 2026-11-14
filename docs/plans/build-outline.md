# Proposed build outline

Status: assistant proposal from C03/C05, interpreted under current owner decisions. C10 selects Swift with SwiftUI; C11 selects a clickable sample-data demo. This document does not start implementation or a phase, or commit dates, budgets, models, or final UI designs.

Current owner sequencing, C09-C11 (2026-11-07): clickable interface demo with sample data first, using Swift with SwiftUI; then add and improve one feature at a time. The six steps below concern later functional work and remain supporting technical proposals, not requirements to implement real AI in the interface demo or a fixed delivery order. Apply the [demo and feature direction](../decisions/demo-and-feature-direction.md), including multiple-model evaluation, ChatGPT-first external AI, and birthday-only initial actions.

## Step 1: Test the phone

**Objective:** establish whether candidate local AI components can support useful work on the iPhone 15 Pro Max.

Use a small reviewed or synthetic Arabic/English set with known answers. Include names, mixed languages, tentative plans, conflicting statements, and a recording. Measure accuracy, time, storage, memory use, heat, and battery impact. Record the iOS version and model/runtime versions.

The output should be a comparison supported by measurements. No model is selected in advance. If a local task fails, record the limit. Do not silently switch to cloud processing.

## Step 2: Define and protect local records

**Objective:** keep captured information and its history safe before adding automation.

Proposed records include sources, source passages, people, projects, ideas, dated claims, owner corrections, interpretations, rules, and reminder proposals. Design source IDs, links, edits, deletion, attachments, backup/restore, and protected keys together.

SQLite is a candidate. A linked-record design does not require a separate graph server. The final database, encryption mechanism, schema, and search index remain open.

## Step 3: Add simple capture

**Objective:** save a recording, typed thought, or attachment without forcing manual organization.

Save the original before AI processing. Show whether processing is queued, running, complete, interrupted, or failed. Let the owner inspect the result and correct it. Keep the recording button and text field easy to reach. Open the sidebar only on request.

Swift with SwiftUI is selected under D21/C10. Exact screen and interaction design remains open.

## Step 4: Connect and retrieve memory

**Objective:** connect captures to people/projects and answer from their sources.

Evaluate extraction, name matching, tentative/confirmed state, keyword and semantic retrieval, multilingual behavior, source references, corrections, and changed information. Keep AI interpretations separate from confirmed facts.

Large imports should resume without duplicates. A correction should affect later retrieval. Deleting a source should update affected derived records according to an explicit retention policy.

## Step 5: Add selected actions and rules

**Objective:** apply owner choices to reminders, person-specific dates, and tabs.

Define how the owner creates and edits rules. Use visible action proposals for uncertain calendar information. Let the owner select trusted automatic cases. Test that imported text cannot change permissions or instruct tools.

Saved filters are the proposed implementation for custom tabs. A reminder schedule must survive app closure without requiring continuous AI execution.

## Step 6: Add connections in selected order

**Objective:** extend a working local app with the integrations the owner chooses.

Candidates include chat-export formats, PDF/DOCX and scanned-document reading, Obsidian, email/calendar providers, optional external AI, and later device sync. The first connector and exact order remain open.

Each connector needs an explicit access scope, transfer policy, deduplication strategy, error state, and disconnect behavior. Live Obsidian editing is a separate problem from Markdown export/import. A provider subscription is separate from a verified supported integration.

## Proposed first demonstration

The selected first demo is a clickable interface with sample data (D22/C11). The path below remains a proposal for a later functional demonstration. It is not the selected first-demo scope. After a separately authorized functional implementation task, demonstrate this path on the actual phone:

1. Download the selected model files.
2. Enable airplane mode.
3. Record a short Arabic/English note.
4. Save its audio and create editable text.
5. Link it to a fictional person and project.
6. Ask a known-answer question and open the supporting source.
7. Correct a mistaken detail and verify the next answer respects the correction.
8. Export the record or transcript.
9. Interrupt and resume an import without duplicate records or lost captures.

This is a proposed acceptance path. No step has passed in an app. Numeric quality/performance targets need owner review after measurements.

## Future sync boundary

Keep the local app usable without sync. Before selecting Supabase, Convex, or another backend, define stable IDs, edit versions, attachment transfer, conflict resolution, deletion propagation, encryption/key recovery, and offline behavior. A real-time server connection alone does not establish these properties.

MacBook and Android support are future goals. UI reuse does not prove equal AI speed, supported models, background behavior, or integrations on each device.
