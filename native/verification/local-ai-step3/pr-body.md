## Summary

Adds an isolated native lab for comparing real local AI SDKs and multilingual models against shared fictional examples.

```text
MemoryOS.xcodeproj       → existing Capture/local storage
MemoryOSAILab.xcodeproj  → lab View → ViewModel → evaluation use case
                                                → app-owned contracts
                                                → Wax / Cactus / llama.cpp adapters
                                                → explicit MLX Simulator unavailability
```

Models, generated SDK binaries and caches stay outside Git. Pins, preparation scripts, original results and source manifests remain retained. Group 5 chat is future work; measured model quality still prevents production adoption.

## Evidence

- **Before:** the main app could not resolve without ignored lab binaries; Cactus preparation accepted dirty checkouts; Dynamic Type audits failed.
  **After:** source-only main resolution/build/analysis pass; 24 source-gate regressions pass; both unfiltered accessibility audits pass with zero diagnostics.
- Independent checks pass: 32 core/presentation functions, four final UI scenarios, strict formatting of 44 Swift files, Release builds/static analysis, native export and source/binary integrity.
- Final runtime identity: `27da28f731c39205d196215d9d2e891a7f45202c457299d9880f7d95fd7b4a63`. Unchanged SDK/model evidence is reused against verified hashes.
- [Task and measured evidence](https://github.com/faroqomar/Eros_MemoryOS/blob/feat/local-ai-evaluation/docs/tasks/2026-11-14-local-ai-phone-evaluation.md) · [Independent repair review](https://github.com/faroqomar/Eros_MemoryOS/blob/feat/local-ai-evaluation/native/verification/local-ai-step2/repairs/independent-repair-recheck.md)

## Merge Danger

**Door:** two-way

The experiment has a separate project and bundle. It does not open the production memory store or change its schema. The change can be reverted without migrating stored records.

**Blast Radius:** experiment

No cloud processing, production provider selection or app release. Physical-phone cost and iOS 18 runtime compatibility remain unverified. Generated evidence logs use binary diffs for review readability; their original bytes remain unchanged.
