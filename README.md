# JSPower

JSPower is a Swift and SwiftUI text-automation workbench for Xcode. Create local JavaScript recipes, test them against sample input, and run enabled recipes from Xcode's Editor menu. Built-in recipes cover line sorting, trailing-whitespace cleanup, JSON formatting, and case conversion.

The 2.0 app and Source Editor Extension are implemented entirely in Swift. CocoaPods, AFNetworking, YYModel, remote package downloads, and the Objective-C runtime implementation are no longer part of the build.

Recipes execute locally in JavaScriptCore and receive only the text supplied by XcodeKit. The app has no network entitlement.

## Develop and verify

The checked-in Xcode project is generated from `project.yml`:

```sh
xcodegen generate --spec project.yml
cd Core && swift test && cd ..
xcodebuild -project JSPower.xcodeproj -scheme JSPower -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Enable the extension in System Settings → Privacy & Security → Extensions → Xcode Source Editor.
