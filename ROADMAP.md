# EditSmith Roadmap

EditSmith aims to become the best programmable text-action tool inside Xcode:
create an action in Swift or JavaScript, preview its result, and apply it safely
to the editor buffer.

## Product boundaries

- Focus on Xcode Source Editor workflows.
- Do not become a system-wide or general-purpose automation platform.
- Do not add a generic AI chat interface.
- Keep the product, packages, messaging, and community distinct from
  ScriptWidget.
- AI may help create actions, but saved actions must execute deterministically
  and remain reviewable before they modify source text.

## 1. Complete the public identity

- Keep the repository, targets, modules, bundle identifiers, App Group, command
  identifiers, documentation, website, and privacy policy consistently named
  EditSmith.
- Verify the GitHub About metadata, topics, website links, fresh clones, Swift
  package tests, and unsigned Xcode builds.
- Remove stale names from current product surfaces without rewriting historical
  articles that are intentionally archival.

Success means that a new user entering from GitHub, xnu.app, or search sees one
coherent EditSmith identity.

## 2. Define a reliable action model

The core execution path should be small and explicit:

```text
Selection or buffer
        -> EditSmith action
        -> Previewed edit
        -> Validation
        -> Apply to Xcode buffer
```

Evolve the core around these concepts:

- `EditorInput`: source text, selections, cursor, and relevant file metadata.
- `EditAction`: stable identity, parameters, and an execution entry point.
- `EditResult`: replacement text, resulting selections, and diagnostics.
- `EditPreview`: a reviewable representation of the proposed edit.
- `ActionManifest`: name, description, language, version, and applicability.
- `ExecutionError`: structured errors that can be displayed and located.

The Core package must not depend on XcodeKit. Equal inputs should produce equal
outputs, actions must not modify files directly, and the extension should only
adapt Xcode buffers to and from the core model. Every built-in action needs
deterministic fixtures and unit tests.

## 3. Make Recipe Workbench the creation loop

The Workbench should support the complete create-test-review-save workflow:

- Edit sample input and action code.
- Run an action without touching Xcode source files.
- Compare before and after output with a line-level diff.
- Show errors with useful locations.
- Save, rename, duplicate, and delete actions.
- Restore examples and provide extension-enablement guidance.

Follow with parameter forms, multiple-selection fixtures, empty-selection and
whole-file cases, Unicode and CRLF coverage, execution limits, action
import/export, and action versioning. The Workbench should remain a focused
action laboratory rather than grow into a general IDE.

## 4. Polish the Xcode workflow

- Use clear, stable command names and categories.
- Explain why an action is unavailable in the current context.
- Preserve cursor and selection state, including multiple selections where
  supported.
- Avoid blocking on large inputs.
- Leave the original buffer intact on failure.
- Apply changes as one undo-friendly operation.
- Guide first-time users through enabling the extension and detect common setup
  problems.

Start with a small, high-quality built-in set: sort lines, remove duplicate
lines, trim whitespace, normalize comments, format JSON, convert case, wrap a
selection, and perform regex replacement. These actions should demonstrate the
platform instead of becoming a large catalog to maintain.

## 5. Harden script execution

- Limit execution time and input/output size.
- Capture exceptions with useful script locations.
- Do not expose network, filesystem, process execution, sensitive environment
  variables, or other ambient authority by default.
- Validate actions before saving them.
- Clearly distinguish built-in actions from user-created actions.

If Swift actions are added, prefer controlled templates or a compile-time
plugin model. Do not dynamically execute arbitrary Swift code inside the main
application.

## 6. Add optional AI-assisted authoring

AI may help users:

- Generate an action draft from a description.
- Explain existing action code.
- Generate fixtures and edge cases.
- Diagnose an action error.
- Turn a repeated editing procedure into an action draft.

The intended flow is:

```text
Describe intent -> Generate draft -> Test fixtures -> Preview diff -> Save
```

AI must not be required when a saved action runs, write results into Xcode
without a preview, or replace deterministic formatters and transformations.

## 7. Prepare a trustworthy release

- Produce an app icon, screenshots, and a short workflow demonstration.
- Publish a concise extension-enablement guide and privacy policy.
- Validate signing, App Group and extension entitlements, archive output, and
  the minimum supported macOS version.
- Choose and document the release, update, crash-reporting, support, and
  community channels.

The release message should emphasize the outcome: select text in Xcode, run a
custom editing action, and reuse it in seconds.

## Near-term milestones

1. Complete and verify the EditSmith public identity.
2. Establish the core input, result, preview, error, and fixture model.
3. Complete the Workbench create-test-preview-save loop.

Action sharing, a broader library, and AI-assisted authoring should follow only
after these foundations are reliable.
