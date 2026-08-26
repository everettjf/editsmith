# EditSmith Release Checklist

Use this checklist for every public build. An unsigned debug build proves source
compatibility only; it does not prove signing, notarization, or store readiness.

## Product and documentation

- [ ] `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` are intentional.
- [ ] GitHub About, topics, website, README, privacy policy, and support links
      use the current EditSmith identity.
- [ ] The README quick start matches the current macOS and Xcode UI.
- [ ] App icon renders correctly at 16, 32, 128, 256, 512, and 1024 points.
- [ ] Capture a current Workbench screenshot and a short Xcode Editor-menu demo.
- [ ] Release notes describe user-visible changes and known limitations.

## Automated verification

```sh
xcodegen generate --spec project.yml
(cd Core && swift test)
xcodebuild test -project EditSmith.xcodeproj -scheme EditSmith \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

- [ ] Core and App tests pass, including fixtures, selections, archives, safety
      limits, diagnostics, built-ins, model/Ollama contracts, legacy decoding,
      library actions, and disabled imports/model drafts.
- [ ] The application and embedded Source Editor Extension build together.
- [ ] `git diff --check` passes and the working tree contains no generated files.

## Manual workflow verification

- [ ] A fresh launch shows built-in actions and the Workbench.
- [ ] Create, duplicate, rename, delete, import, and export a user action.
- [ ] Run one fixture, run all fixtures, inspect output/diff/console, and update a
      snapshot.
- [ ] Invalid JavaScript shows a useful line, column, and stack.
- [ ] Enable the extension using the Settings guidance.
- [ ] Run whole-buffer, single-selection, and multi-selection actions in Xcode.
- [ ] Confirm output selections are restored and one Undo reverses the edit.
- [ ] Confirm Dry Run saves a preview without changing the Xcode buffer.
- [ ] Confirm the rollback command restores the most recent saved buffer.
- [ ] On macOS 26 or later, generate an Apple Intelligence draft, verify it is
      disabled, test it, preview its diff, and enable it manually.
- [ ] Run one Apple On-Device model action and verify whole-buffer and
      multi-selection replacement.
- [ ] With Ollama running, verify the configured model from both the Workbench
      and Xcode Source Editor Extension.
- [ ] On an eligible macOS 27 signed build, verify PCC; otherwise confirm its
      unavailable-state guidance.
- [ ] On macOS 15, launch and use the deterministic workflow without
      loading Foundation Models.

## Security and privacy

- [ ] App and extension remain sandboxed with the shared App Group and outgoing
      client permission only; neither target has server, file, or temporary
      exception entitlements.
- [ ] Network entitlements match the shipped provider set; if enabled, verify Ollama access is opt-in and the privacy copy is current.
- [ ] Imported actions are disabled by default.
- [ ] Generated drafts, imported actions, and new model actions start disabled.
- [ ] Each enabled model action shows its provider and sends only the intended
      selection or full-buffer input.
- [ ] Oversized input, script, and output fixtures fail without modifying text.
- [ ] Test source, fixtures, logs, settings, and snapshots remain in the shared
      local container.
- [ ] Privacy policy matches the shipping binary and optional on-device model
      behavior.

## Signed archive

- [ ] Confirm the distribution channel and signing identity.
- [ ] Confirm the App ID, extension App ID, and App Group exist in the selected
      developer account.
- [ ] Archive the `EditSmith` scheme with signing enabled.
- [ ] Validate the archive's app and extension bundle identifiers, versions,
      entitlements, embedded provisioning profiles, and architectures.
- [ ] Launch the exported build on a clean user account and enable the extension.
- [ ] Complete notarization or App Store validation for the selected channel.
- [ ] Tag the exact reviewed commit and attach release notes and artifacts.
