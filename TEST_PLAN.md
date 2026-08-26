# EditSmith Acceptance Test Plan

Use this checklist on a signed Debug or Release build. Unless a case says otherwise,
start with a fresh app launch and keep a disposable Xcode project open.

## 1. Workbench appearance and navigation

- [ ] Launch at the default window size. The sidebar, editor, results area, and
      inspector are visible without overlap or clipped primary controls.
- [ ] Resize down to the minimum window size and back up. Split panes remain usable,
      dividers drag smoothly, and no view jumps or constraint warnings appear.
- [ ] Show and hide the inspector. Its width remains within a practical range and
      the center editor reflows rather than being covered.
- [ ] Switch between All, Built-in, JavaScript, Model, Favorites, and enabled-state
      filters. Counts and selected rows stay correct.
- [ ] Collapse and expand capability categories. Search for an action, clear search,
      favorite it, duplicate it, and use its context menu.
- [ ] Verify toolbar priority: Run is obvious, fixture navigation is grouped, and
      secondary actions are available without crowding the title bar.
- [ ] Check light mode, dark mode, increased contrast, and 200% text scaling.
- [ ] Navigate controls with Tab and VoiceOver. Icon-only buttons announce useful
      labels; status is not communicated by color alone.

## 2. Deterministic action workflow

- [ ] Create a JavaScript action, edit its name/description/source, and save it.
- [ ] Add two fixtures: one full-buffer fixture and one with two non-overlapping
      Xcode-style selections.
- [ ] Run the current fixture and Run All. Verify pass/fail/pending states, duration,
      issue summary, output, and selection ranges.
- [ ] Create a JavaScript syntax error. Verify source location, stack details, and
      the issue bar; fix it and confirm the stale error disappears.
- [ ] Use `console.log`, then filter, copy, and clear the console.
- [ ] Inspect added, removed, modified, and unchanged lines in the diff. Line numbers
      stay aligned while scrolling.
- [ ] Update a snapshot, then Test & Enable. A failing fixture must prevent enabling.
- [ ] Export and re-import an action. The imported copy starts disabled and preserves
      its fixtures and configuration.

## 3. Creative Lab built-ins

For each action, run its included example and one custom ASCII/Unicode sample.

- [ ] Leetspeak
- [ ] ROT13
- [ ] Fullwidth
- [ ] Circled Text
- [ ] Unicode Monospace
- [ ] Unicode Bold
- [ ] Unicode Italic
- [ ] Small Caps
- [ ] Upside Down Text
- [ ] Reverse Characters
- [ ] Glitch / Zalgo Text
- [ ] Text to Binary
- [ ] Morse Code
- [ ] ASCII Box
- [ ] ASCII Banner

Also verify that searching for “ASCII”, “hacker”, “Morse”, and “Unicode” makes the
relevant actions discoverable, and that repeated deterministic examples produce the
same expected output.

## 4. Model action gallery and editing

- [ ] Browse all ten examples: Explain Selected Code, Add Helpful Comments,
      Refactor Swift, Generate Swift Tests, Review for Bugs, Draft Commit Message,
      Draft Release Notes, Translate to English, Simplify Writing, and Generate Regex.
- [ ] Create a model action. Verify prompt editing, `{{input}}`, provider selection,
      provider-specific settings, instructions, fixtures, and disabled-by-default state.
- [ ] Run with no selection and confirm the full buffer is replaced.
- [ ] Run with two selections and confirm only those ranges are replaced, surrounding
      source remains byte-for-byte unchanged, and returned selections cover new text.
- [ ] Cause an unavailable-provider or malformed-endpoint error. The original source
      remains unchanged and the failure is understandable.
- [ ] Export/import the model action. Provider, model name, endpoint, instructions,
      prompt, and fixtures round-trip; the imported action starts disabled.

## 5. Provider matrix

### Apple On-Device

- [ ] On macOS 26+ with Apple Intelligence available, run a short fixture and verify
      a response. Disable or make Apple Intelligence unavailable and verify a clear
      error rather than a crash.
- [ ] Confirm the action works without an Internet connection.

### Apple Private Cloud Compute

- [ ] On macOS 27+ using an eligible signed build with Apple's PCC entitlement, run
      a short fixture and verify a response.
- [ ] On an ineligible build/device, verify the app reports PCC as unavailable and
      points to OS/account/entitlement requirements.

### Ollama / Local LLaMA

- [ ] Use a signed build and confirm both App and Source Editor Extension targets have
      outgoing-client permission. Start Ollama and ensure the configured model is installed.
- [ ] Test `http://127.0.0.1:11434` with a short fixture, a missing model, a stopped
      server, a malformed URL, and a non-2xx response.
- [ ] Verify EditSmith sends a non-streaming `/api/generate` request and displays only
      the returned response text.
- [ ] Repeat once from Xcode. Confirm neither target has server/listener permission and
      that EditSmith never contacts Ollama until the user invokes an Ollama action.

## 6. Xcode Source Editor Extension

- [ ] Enable EditSmith in System Settings, restart Xcode if needed, and confirm only
      enabled actions appear under Editor → EditSmith.
- [ ] Run a built-in action on one selection, multiple selections, and no selection.
- [ ] Run a JavaScript action and an Apple On-Device model action. Verify selection
      boundaries, line endings, Unicode, undo, and a 5 MB limit failure.
- [ ] Turn on dry-run preview. Verify the extension does not modify source and the app
      shows the pending diff. Turn it off and repeat the action.
- [ ] Verify a thrown script/model error leaves the Xcode buffer unchanged.

## 7. Persistence, privacy, and release checks

- [ ] Relaunch the app. Favorites, filters, pane choices, actions, prompts, fixtures,
      and provider configuration persist.
- [ ] Confirm no credentials are requested or stored by EditSmith. Ollama configuration
      contains only endpoint/model/instructions.
- [ ] Verify JavaScript and Apple On-Device actions make no outbound request.
- [ ] Verify remote-provider copy clearly states when selected/full-buffer text can
      leave the Mac and that no remote provider is selected implicitly.
- [ ] Run `cd Core && swift test`.
- [ ] Run `xcodebuild test -project EditSmith.xcodeproj -scheme EditSmith \
      -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`.
- [ ] Run `scripts/verify-release.sh` before distributing a signed build.
