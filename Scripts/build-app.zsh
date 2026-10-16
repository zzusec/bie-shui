#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
cd "$root_dir"

# macOS 27 的 Command Line Tools 缺少 SwiftUI 宏插件，直接使用默认 SDK 会构建失败
# （plugin for module 'SwiftUIMacros' not found）；若本机存在 26.x SDK 则显式使用。
sdk_flag=()
fallback_sdk="$(/bin/ls -d /Library/Developer/CommandLineTools/SDKs/MacOSX26*.sdk 2>/dev/null | sort -V | tail -n 1)"
if [[ -n "$fallback_sdk" ]]; then
  sdk_flag=(--sdk "$fallback_sdk")
fi

swift build -c release "${sdk_flag[@]}"

app_dir="$root_dir/dist/别睡.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$root_dir/.build/release/LidAwake" "$app_dir/Contents/MacOS/LidAwake"
cp "$root_dir/Assets/AppIcon.icns" "$app_dir/Contents/Resources/AppIcon.icns"

cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleDisplayName</key>
    <string>别睡</string>
    <key>CFBundleExecutable</key>
    <string>LidAwake</string>
    <key>CFBundleIdentifier</key>
    <string>local.hx10.lidawake</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>别睡</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.3.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Local utility</string>
</dict>
</plist>
PLIST

/usr/bin/touch "$app_dir"
printf 'Built: %s\n' "$app_dir"
