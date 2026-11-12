#!/bin/zsh
# Archives Moneyglot and uploads it to App Store Connect (or exports a signed .ipa).
#
#   Tools/release.sh          upload to App Store Connect / TestFlight
#   Tools/release.sh export   write a signed .ipa to build/export instead
#
# Bump CURRENT_PROJECT_VERSION (and MARKETING_VERSION for a new App Store version) before each upload.
# Requires Xcode to be signed in to the team's Apple Account.
set -euo pipefail
cd "${0:A:h}/.."

destination="${1:-upload}"
settings=$(xcodebuild -project Moneyglot.xcodeproj -scheme Moneyglot -configuration Release -showBuildSettings 2>/dev/null)
version=$(print -r -- "$settings" | awk '$1 == "MARKETING_VERSION" { print $3 }')
build=$(print -r -- "$settings" | awk '$1 == "CURRENT_PROJECT_VERSION" { print $3 }')
archive="$HOME/Library/Developer/Xcode/Archives/$(date +%F)/Moneyglot $version ($build).xcarchive"

# The archive is built unsigned; the export step signs it with the team's cloud-managed
# Apple Distribution certificate, which doesn't need a registered test device.
echo "Archiving Moneyglot $version ($build)…"
xcodebuild -project Moneyglot.xcodeproj -scheme Moneyglot -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  CODE_SIGNING_ALLOWED=NO -quiet archive

options=$(mktemp -t moneyglot-export).plist
cp Tools/ExportOptions.plist "$options"
/usr/libexec/PlistBuddy -c "Set :destination $destination" "$options"

echo "Signing and ${destination}ing…"
xcodebuild -exportArchive -archivePath "$archive" -exportOptionsPlist "$options" \
  -exportPath build/export -allowProvisioningUpdates
rm -f "$options"
