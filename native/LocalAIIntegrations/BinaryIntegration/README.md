# Wax binary evaluation configuration

Package: `LocalWaxBinaryEvaluation`. Product: `WaxEvaluationAdapterBinary`. The adapter's imported module remains `WaxEvaluationAdapter` and its public API remains unchanged. The small export target links the existing `AIEvaluationCore` source product once.

This configuration packages actual compiled SDK and adapter objects. It avoids making each upstream SDK an Xcode workspace root, which activates unused upstream tools/tests. The canonical source package remains in the parent directory with its original HTTPS URL and exact Wax revision. It has no implicit local override.

Generate `Artifacts/` from the recorded explicit graph with `../scripts/build-wax-xcframework.py`, supplying the reviewed `--source-provenance` JSON. The builder checks source and SDK manifest hashes before and after each slice. The graph uses the reviewed Wax 0.1.47 base plus the documented two-file iOS desktop guard patch. SDK manifests stay unchanged. The script builds arm64 macOS, arm64 iOS device and arm64 iOS simulator slices, archives real selected target objects, excludes all core objects, checks that public interfaces expose no vendor SDK module, and invokes `xcodebuild -create-xcframework`. It never fetches dependencies. It requires already verified external SDK source paths in the explicit temporary package.

The binary is tied to the recorded toolchain, exact adapter source, exact core source and configuration. Core is not a separately stable binary API. Keep it as the same source dependency used for compilation. Do not substitute a different core revision and assume ABI compatibility. This is a personal experimental configuration, not a general SDK release or a production provider selection.

The approach uses Apple's [binary Swift package](https://developer.apple.com/documentation/xcode/distributing-binary-frameworks-as-swift-packages) and [static framework](https://developer.apple.com/documentation/xcode/creating-a-static-framework) formats. Source and binary package results remain separate evidence.

Resource bundles must be copied to the app resource root because that is where the actual generated SDK `Bundle.module` accessors search. After building the artifacts, wire a scoped app build phase to:

```sh
python3 /ABSOLUTE/LocalAIIntegrations/scripts/copy-wax-resources.py \
  --platform-source /ABSOLUTE/BinaryIntegration/Artifacts/Resources/iphonesimulator \
  --destination /ABSOLUTE/BUILT-APP-RESOURCE-ROOT \
  --receipt /ABSOLUTE/BinaryIntegration/Artifacts/packaging-receipt.json \
  --staging-root /ABSOLUTE/DECLARED-STAGING-DIRECTORY
```

For Xcode, choose the source subdirectory with `PLATFORM_NAME` (`iphonesimulator`, `iphoneos`, or `macosx`). Declare the receipt, helper and bundle inputs and the five bundle/ownership-marker outputs. The helper verifies all source files against the receipt before any replacement. It replaces only matching or previously owned bundles, stages the copy, preserves unrelated app resources and rolls back a failed replacement. A hash mismatch or unknown resource conflict fails the build.

`Artifacts/` contains the static XCFramework, separate platform resource bundles, packaging receipt and source/license provenance. It is generated and ignored. Preserve compact receipts and test/link results in task evidence. The source package contracts, binary host contracts, simulator execution and physical-phone measurements are distinct checks.
