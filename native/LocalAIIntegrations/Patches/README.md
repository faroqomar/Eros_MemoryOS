# Wax iOS desktop guards

Base: Wax 0.1.47, commit `e4587f8cebb76aa92ece008253f13c66b756e68b`.

Stock Wax declares iOS support, but this revision fails an actual arm64 iOS simulator build. `AgentBrokerClient.swift` exposes a Foundation `Process` parameter and calls macOS `proc_pidpath`. `MemorySemantics.swift` invokes Git through `Process`. These APIs are unavailable on iOS.

The patch excludes the desktop process helper on mobile platforms and restricts broker process inspection/restart to macOS. Existing mobile broker startup still throws an explicit unsupported-platform error. Git ancestry that cannot be checked on mobile becomes `unknown`; an equal stored/live SHA remains `yes`. Desktop paths retain their existing behavior. The retrieval adapter does not use the broker or repository ancestry feature. No fake process implementation, network fallback, model or SDK manifest change is added.

Use a separate upstream checkout. Keep the canonical dependency URL and pin unchanged. After obtaining the real reviewed Git checkout, prepare a new local override directory with:

```sh
python3 native/LocalAIIntegrations/scripts/prepare-wax-ios-override.py \
  --source /ABSOLUTE/UPSTREAM/Wax \
  --destination /ABSOLUTE/UPSTREAM/Wax-ios-evaluation
```

The script requires the exact Git commit, a clean tracked tree and the expected upstream file hashes. It uses a local Git archive and applies this patch without network access. The output is a patched source snapshot, not a new Git repository. The original upstream checkout remains intact. It emits a receipt beside the output. It does not activate a SwiftPM or Xcode override. Add the resulting local package explicitly in the evaluation workspace, with empty Wax traits. Preserve and label that workspace configuration and its source receipt. This is an experimental patched configuration, not an unmodified upstream pin pass.

The source-only snapshots used for the current compiler checks have separate Git-tree/blob verification receipts in `docs/evidence/local-ai-2026-11-14/resume-wax/`. They are not Git checkouts and are not inputs to the preparation script. Current host contracts and simulator compile results are recorded there. A simulator build does not prove simulator execution or phone performance.
