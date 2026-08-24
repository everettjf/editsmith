# EditSmith 1.0

EditSmith brings local, testable text actions to Xcode's Editor menu.

## Highlights

- Create JavaScript actions and test them against Xcode-style fixtures before
  enabling them.
- Inspect output, line-level diffs, console logs, expected failures, and
  source-located JavaScript diagnostics.
- Run actions against a whole buffer or multiple selections while preserving
  the resulting selections for continued editing.
- Start with actions for sorting, duplicate removal, trailing whitespace,
  comments, JSON formatting, case conversion, wrapping, and regex replacement.
- Duplicate actions and move user actions between Macs with a versioned JSON
  archive. Imported actions start disabled.
- Preview changes with Dry Run and restore the last buffer with the rollback
  command.
- On macOS 26 or later, optionally use Apple Intelligence to create a local,
  disabled JavaScript draft for review and testing.

## Safety and privacy

- Actions run locally in JavaScriptCore without network, file, or process APIs.
- Input and output are limited to 5 MB, action source to 256 KB, and execution
  time to one second.
- The app and extension are sandboxed and share only the EditSmith App Group.
- Apple Intelligence is weak-linked and is not part of saved-action execution.
- Source text, actions, fixtures, logs, settings, and rollback data remain on
  the Mac.

## Requirements

- macOS 15 or later for the deterministic action workflow.
- Xcode with Source Editor Extension support.
- macOS 26 or later and an available Apple Intelligence model for optional
  action drafting.

See [README.md](README.md) for setup and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
for release validation.
