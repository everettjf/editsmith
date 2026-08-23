# EditSmith

[![GitHub](https://img.shields.io/badge/GitHub-everettjf%2Feditsmith-181717?logo=github)](https://github.com/everettjf/editsmith)
[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white)](https://discord.gg/eGzEaP6TzR)
[![Platform](https://img.shields.io/badge/platform-macOS%20%C2%B7%20Xcode-blue)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

![EditSmith Workbench showing a successful Sort Lines fixture and its diff](site/assets/workbench.png)

[Website](https://xnu.app/editsmith/) · [GitHub](https://github.com/everettjf/editsmith) · [Discord](https://discord.gg/eGzEaP6TzR)

**Scriptable text actions for Xcode.** EditSmith is a native SwiftUI workbench for creating local JavaScript recipes, testing them against realistic Xcode selections, and running enabled actions from Xcode's Editor menu.

## Why EditSmith

- **Stay inside Xcode.** Run named text actions from the Editor menu without moving source to another app.
- **Make transformations repeatable.** Save a JavaScript recipe once and reuse it across projects.
- **Test before enabling.** Verify output, selections, expected errors, diffs, and console logs in the app.
- **Move actions safely.** Duplicate actions or import and export a versioned JSON archive; imported actions start disabled.
- **Keep source local.** Recipes run in JavaScriptCore and receive only the text supplied by XcodeKit.
- **Start with useful actions.** Sorting, deduplication, comments, wrapping, regex replacement, whitespace cleanup, JSON formatting, and case conversion are included.
- **Draft with Apple Intelligence.** On macOS 26 or later, optionally generate a local JavaScript draft, then test and enable it yourself.

## Quick start

1. Build and launch EditSmith once.
2. Open System Settings → Privacy & Security → Extensions → Xcode Source Editor and enable EditSmith.
3. Create or enable a recipe in EditSmith, then save it.
4. In Xcode, select text and choose Editor → EditSmith → your recipe.

## Recipe model

Each recipe is a versioned action with applicability rules, parameters, and test fixtures. JavaScript actions define a `transform(input)` function that returns replacement text. Script execution has input, source, output, and one-second runtime limits. The workbench supports multiple fixtures, Xcode-style selection ranges, expected output and errors, snapshot updates, output diffs, console logs, source-located JavaScript diagnostics, duplication, and versioned JSON import/export.

Apple Intelligence is used only to author an optional draft on supported Macs. Generated actions are disabled by default, and saved actions run deterministically through JavaScriptCore without invoking a model.

## Requirements

- macOS 14 or later
- A supported Xcode installation
- XcodeGen when regenerating the checked-in project

## Develop and verify

```sh
xcodegen generate --spec project.yml
cd Core && swift test && cd ..
xcodebuild test -project EditSmith.xcodeproj -scheme EditSmith \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

The app and Source Editor Extension are implemented in Swift. The core has no third-party dependencies.

Before publishing a build, follow the [release checklist](RELEASE_CHECKLIST.md).
The repository also includes a repeatable `scripts/verify-release.sh` gate and
the current [release notes](RELEASE_NOTES.md).

## Privacy

EditSmith has no network entitlement. Recipe source and configuration stay on the Mac, and the Source Editor Extension processes only text supplied by XcodeKit. See the [privacy policy](https://xnu.app/editsmith/privacy.html).

## License

[MIT](LICENSE)
