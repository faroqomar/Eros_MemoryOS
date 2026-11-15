# Independent repair recheck: local AI evaluation

Date: 2026-11-15. Reviewer: `prestep3_correctness`, independent of the repair implementers.

**Result: PASS for checklist group 4 Step 2 under C40's fictional-data iOS 27.2 Simulator scope.** No actionable repair finding remains. This result does not select a production model, certify physical-phone readiness, or start Step 3.

Final runtime identity: `27da28f731c39205d196215d9d2e891a7f45202c457299d9880f7d95fd7b4a63`. The [machine-readable recheck](independent-repair-recheck.json) records the checks and evidence hashes.

## Actual source review

I compared the old 99-file runtime manifest with the final 100-file manifest and inspected the changed implementation. The shared changed runtime paths are the restored main project, the lab's section-heading presentation, and the generic adapter error string. The lab project and repointed scheme are new; the old lab scheme is absent from the main project. I independently recomputed the identity and all file hashes. All 67 binary/resource files match the earlier manifest. The reviewed [44-file Swift snapshot](verification-source-hashes.json) also matches current source, including the test-only switch action and sanitizer assertion.

- **Project isolation:** `native/MemoryOS.xcodeproj/project.pbxproj` matches `HEAD` byte for byte. A fresh temporary copy containing only the main project, app/test source and LocalMemory resolves successfully with no experimental package directory or binary artifact present. Its only resolved package is LocalMemory. I inspected the retained successful source-only main Release build/analysis receipt against this exact project. I did not repeat that unchanged compilation. The separate lab keeps its own SDK dependencies and scheme. Its documented command supplies `ARCHS=arm64` to the entire package graph; target-only architecture settings are not represented as a generic multiarchitecture fix. [Independent resolution](independent-main-resolution.json), [log](independent-main-resolution.log), [retained source-only build](package-isolation/after/receipt.json).
- **Cactus source gate:** I read the full gate and regression suite, independently reran all 24 tests, and ran the new gate read-only against the retained real patched 90-file snapshot. Both pass. The tests cover staged/unstaged/deleted/extra/ignored source, symlinks, wrong or absent source identity, receipt snapshots, retained empty-preimage patch additions, and rejection before patch/build work. The existing SDK binary and approved patch remain unchanged. [Independent tests](independent-cactus-source-tests.log), [repair reproduction/receipt](cactus-source/repair-receipt.json).
- **Scalable section headings:** I inspected the before/after source. The change replaces native collection headers with body rows using semantic `.headline`, flexible vertical text and `.isHeader`; it leaves run/result/export behavior intact. The final unfiltered English and Arabic audits now pass with zero diagnostics. The handler still returns `false` for issues, so it hides none. The test-only switch repair taps the actual inner control's center and asserts value `1` and the Arabic title before the audit. [Final UI log](accessibility/final-source-ui.log).
- **Recovery copy:** The generic adapter failure now directs the user to prepared local assets and retry. The new assertion retains the existing private-error sanitization check and rejects the nonexistent diagnostic-log instruction. I independently reran the affected Release package: 25 core and 7 presentation functions pass. [Fresh final-source tests](independent-final-core-tests.log).

## Final evidence

I independently parsed the final xcresult: four tests passed, zero failed, zero skipped and zero expected failures on iPhone 18 Pro Max / iOS 27.2 Simulator. Both full accessibility audit methods pass. The final analysis log ends in `ANALYZE SUCCEEDED` for the same `27da` identity. [Parsed xcresult](independent-xcresult-summary.json), [analysis](accessibility/final-source-analysis.log).

Read-only app-container inspection confirms the installed bundle embeds the final source identity and its executable SHA-256 matches the installation receipt. [Independent installed identity](independent-installed-identity.json).

I checked all seven final dark PNG hashes and dimensions (440 x 956), and viewed each capture. Largest English and Arabic headings grow; the Arabic Run control remains reachable. The final result image shows source prefix `27da28f731c3`. Capture 05 correctly records scope before the manual run, not a completed result. Intermediate `1b978` captures remain separate. [Capture manifest](screenshots/manifest.json).

All 13 final-source raw reports match their recorded hashes and source identity. They contain two complete six-suite control batches (180 completed retrieval cases) and one explicit MLX-unavailable suite (15 blocked generation cases, no output). They are flow checks, not replacement comparative model benchmarks. [Independent integrity receipt](independent-final-integrity.json).

I removed my completed 86,451,404-byte scratch core build after preserving the full test log. The source-only resolution scratch directory also no longer exists. [Cleanup receipt](independent-scratch-cleanup.json).

## Limits

The existing model quality failures, including Iraqi Arabic, still prevent production adoption. Physical-phone cost, battery/heat, iOS 18 runtime compatibility, owner product/design acceptance, and distribution remain separate where applicable. Existing Wax dSYM/debug-map warnings remain packaging/debug-symbol limitations.

I did not rerun unchanged SDK contracts or model inference. Their source-identified evidence remains valid for reuse: adapters, binary/resource files, fixtures, prompt/settings and declared model asset identities did not change in these repairs. I reused the earlier asset verification; I did not freshly hash the external weight files. The new error string changes only the failed generic-adapter path. Earlier failed/flaky and intermediate runs remain diagnostic history; they are not final passing evidence. No commit, push, PR, merge or release follows from this recheck.
