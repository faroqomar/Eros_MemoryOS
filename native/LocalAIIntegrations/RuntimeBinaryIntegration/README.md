# Local Wax runtime artifact

The main app uses `WaxMemoryRuntimeBinary`, with the app-owned `RetrievalCore` linked from source. The archive contains Wax 0.1.47 and its pinned dependencies plus the app-owned thin adapter. It contains no evaluation core or fixtures. It preserves the previously reviewed two-file iOS desktop-API guard patch. This personal local integration does not establish retrieval quality or release readiness.

Upstream source stays outside this repository. Build the ignored `Artifacts` directory from reviewed clean upstream checkouts; no download runs in these scripts. Use the existing `prepare-wax-ios-override.py` first to create a patched Wax snapshot and its receipt. Then:

```sh
python3 native/LocalAIIntegrations/scripts/prepare-wax-runtime-package.py \
  --wax-source /absolute/prepared/Wax \
  --dependency-checkouts /absolute/pinned/checkouts \
  --destination /absolute/new/temporary-runtime-package
python3 native/LocalAIIntegrations/scripts/build-wax-xcframework.py \
  --module-name WaxMemoryRuntime \
  --package /absolute/new/temporary-runtime-package \
  --build-root /absolute/task-build \
  --output native/LocalAIIntegrations/RuntimeBinaryIntegration/Artifacts \
  --evidence /absolute/task-diagnostics \
  --source-provenance /absolute/new/temporary-runtime-package/source-provenance.json
```

The output must not already exist. The builder checks source and SDK tree fingerprints, emits macOS, iOS Simulator and iOS device slices, and excludes app-owned core objects from the archive. Source-linked core and adapter must use the recorded source/toolchain combination; their ABI is not a general compatibility promise. The core source hash in the artifact provenance must match the app checkout.

The app build first runs `verify-wax-runtime.py --artifacts <artifact-directory> --platform <platform>`. It rejects a changed adapter/core, toolchain, public interface, archive, SDK resources or bundled license. The app build then uses `copy-wax-resources.py` with this artifact's `Resources/<platform>` and `packaging-receipt.json`. That script verifies the five required SDK bundles before copying. The dependency wrapper also bundles the reviewed upstream license notices. The older evaluation binary and its recipe default remain separate.

No environment variable is required by the main app's binary dependency. `MEMORYOS_WAX_PACKAGE_PATH` is an explicit development-only override for the separate source adapter package; the unmodified canonical source pin cannot compile its desktop broker APIs on iOS.
