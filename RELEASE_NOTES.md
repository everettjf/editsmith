# EditSmith 1.0

EditSmith brings testable JavaScript and model-powered text actions to Xcode's
Editor menu.

## Highlights

- Create JavaScript actions and test them against Xcode-style fixtures before
  enabling them.
- Inspect output, line-level diffs, console logs, expected failures, and
  source-located JavaScript diagnostics.
- Run actions against a whole buffer or multiple selections while preserving
  the resulting selections for continued editing.
- Start with actions for sorting, duplicate removal, trailing whitespace,
  comments, JSON formatting, case conversion, wrapping, and regex replacement.
- Explore 15 Creative Lab actions including leetspeak, fullwidth and circled
  Unicode, monospace/bold/italic styles, Zalgo, Morse, binary, ASCII boxes, and
  block banners.
- Create prompt-driven model actions and start from ten editable examples for
  explaining, commenting, refactoring, testing, reviewing, translating, and
  rewriting code or prose.
- Choose Apple On-Device Foundation Models, Apple Private Cloud Compute on
  eligible systems, or a user-configured Ollama / local LLaMA endpoint.
- Run JavaScript and model actions through the same XcodeKit bridge. When Xcode
  supplies selections, only those ranges are transformed and selected again.
- Duplicate actions and move user actions between Macs with a versioned JSON
  archive. Imported actions start disabled.
- Preview changes with Dry Run and restore the last buffer with the rollback
  command.
- On macOS 26 or later, optionally use Apple Intelligence to create a local,
  disabled JavaScript draft for review and testing.

## Safety and privacy

- JavaScript actions run locally in JavaScriptCore without network, file, or
  process APIs. Apple On-Device model actions also process input locally.
- Input and output are limited to 5 MB, action source to 256 KB, and execution
  time to one second.
- The app and extension are sandboxed, share the EditSmith App Group, and have
  outgoing-client access for explicitly invoked PCC or Ollama actions. They do
  not accept inbound connections.
- Foundation Models is weak-linked so the deterministic workflow remains
  available on macOS 15.
- Actions, prompts, provider settings, fixtures, logs, and rollback data remain
  on the Mac. PCC or Ollama receives selected/full-buffer text only when the
  user invokes an action configured for that provider.

## Requirements

- macOS 15 or later for the deterministic action workflow.
- Xcode with Source Editor Extension support.
- macOS 26 or later and an available Apple Intelligence model for optional
  action drafting and Apple On-Device model actions.
- macOS 27 or later, an eligible developer account, and Apple's PCC entitlement
  for Private Cloud Compute actions.
- A running Ollama server and installed model for Ollama / local LLaMA actions.

See [README.md](README.md) for setup and [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md)
for release validation.
