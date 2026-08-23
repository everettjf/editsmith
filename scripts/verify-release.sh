#!/bin/bash
set -euo pipefail

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir"

expected_app_id="com.xnu.editsmith"
expected_extension_id="com.xnu.editsmith.extension"
expected_group="group.com.xnu.editsmith"

test "$(git status --porcelain)" = ""
git diff --check

test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' EditSmith/EditSmith.entitlements)" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' EditSmithExtension/EditSmithExtension.entitlements)" = "true"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' EditSmith/EditSmith.entitlements)" = "$expected_group"
test "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' EditSmithExtension/EditSmithExtension.entitlements)" = "$expected_group"

rg -q "PRODUCT_BUNDLE_IDENTIFIER: $expected_app_id$" project.yml
rg -q "PRODUCT_BUNDLE_IDENTIFIER: $expected_extension_id$" project.yml
if rg -q 'com.apple.security.network|com.apple.security.files|com.apple.security.temporary-exception' EditSmith/*.entitlements EditSmithExtension/*.entitlements; then
    echo "Unexpected network, file, or temporary-exception entitlement" >&2
    exit 1
fi

xcodegen generate --spec project.yml
(cd Core && swift test)
xcodebuild test -project EditSmith.xcodeproj -scheme EditSmith \
    -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO

settings="$(xcodebuild -project EditSmith.xcodeproj -scheme EditSmith -showBuildSettings)"
product_dir="$(awk -F ' = ' '/TARGET_BUILD_DIR = / { print $2; exit }' <<<"$settings")"
app_binary="$product_dir/EditSmith.app/Contents/MacOS/EditSmith.debug.dylib"
test -f "$app_binary"
otool -L "$app_binary" | rg -q 'JavaScriptCore.framework'
otool -L "$app_binary" | rg -q 'FoundationModels.framework.*weak'

echo "EditSmith release verification passed."
