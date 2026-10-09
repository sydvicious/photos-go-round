#!/bin/bash
#
# Makes a release. **main always carries the version of the next release**, so
# from main this builds a Release "Photos-Go-Round.app" that can be handed to
# another person: signed with Developer ID, notarized, stapled, and wrapped in a
# DMG that is signed, notarized and stapled in turn. It copies the DMG to the
# releases folder, and then tags the commit it built
# release-<version>-build-<build>.
#
# **It does not bump.** A release may take several candidates before one ships,
# so bump-version.sh stays separate: with no options for the next candidate,
# which needs a new build number (this refuses a version and build already
# released), and with --minor once a release has shipped.
#
# Nothing is pushed. With --no-notarize it only builds and packages, from any
# branch, and neither copies nor tags. It never starts from a dirty repo.
#
# Syd's to run, not an agent's: it builds the Release identity, it uploads the
# build to Apple's notary service, and it tags. It launches nothing and installs
# nothing.
#
# Needs, once per Mac:
#   - a Developer ID Application certificate for team R5PQPZARC5 in the login
#     keychain (Xcode -> Settings -> Accounts -> Manage Certificates), and
#   - notarytool credentials in the keychain:
#       xcrun notarytool store-credentials "pgr-notary" \
#           --apple-id "sydvicious@mac.com" --team-id "R5PQPZARC5"

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$REPO/Photos-Go-Round.xcodeproj"
TEAM_ID="R5PQPZARC5"
# **Build artifacts never land in the repository.** Syd, 2026-09-19. See
# make-saver-bundle.sh and CLAUDE.md.
DERIVED_DATA="${PGR_BUILD_ROOT:-$HOME/Library/Developer/Xcode/DerivedData/Photos-Go-Round-scripts}"
BUILD_DIR="$DERIVED_DATA/release"
PROFILE="pgr-notary"
# Where a finished release is kept. Syd, 2026-10-09: "Release script should copy
# resulting dmg to /Users/jazzman/iCloud/dev/Photos-Go-Round Releases/". Until
# then the image stayed in DerivedData, and one was lost the day he cleared it.
RELEASES_DIR="$HOME/iCloud/dev/Photos-Go-Round Releases"
NOTARIZE=1

usage() {
    cat <<'HELPTEXT'
Releases Photos-Go-Round: a Developer ID signed, notarized DMG, and a tag on
the commit it was built from. It does not bump; bump-version.sh does that.

USAGE
  ./Scripts/release-build.sh [options]

OPTIONS
  --output <dir>              Where to build. Default:
                              ~/Library/Developer/Xcode/DerivedData/Photos-Go-Round-scripts/release
                              or $PGR_BUILD_ROOT/release. Never the repository.
  --releases <dir>            Where the finished DMG is copied. Default:
                              ~/iCloud/dev/Photos-Go-Round Releases
  --keychain-profile <name>   The notarytool credentials to submit with.
                              Default: pgr-notary.
  --no-notarize               Sign and package, but upload nothing to Apple,
                              copy nothing to the releases folder, and do not
                              tag. Works from any branch, but still only from
                              a clean repo. Gatekeeper refuses the result on
                              any other Mac.
  -h, --help                  This.

NEEDS, ONCE PER MAC
  A Developer ID Application certificate for team R5PQPZARC5, and:

    xcrun notarytool store-credentials "pgr-notary" \
        --apple-id "sydvicious@mac.com" --team-id "R5PQPZARC5"

NEEDS, EVERY RELEASE
  A clean main (no changes, and no untracked files that are not ignored), with a
  version and build not yet released: neither an image in <releases> nor a tag
  release-<version>-build-<build>. Each is refused before anything is built.

RESULT
  <releases>/Photos-Go-Round <version> (<build>).dmg, and the tag
  release-<version>-build-<build> on the commit it was built from. The image it
  was copied from stays in <output>, with the stapled app beside it in
  <output>/export. Nothing is pushed.

  Launching the app installs its agent, as every build does, unless one of the
  same or a greater version is already installed and running.

AFTERWARDS
  Another candidate:          ./Scripts/bump-version.sh
  It shipped:                 ./Scripts/bump-version.sh --minor
HELPTEXT
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) BUILD_DIR="$2"; shift 2 ;;
        --releases) RELEASES_DIR="$2"; shift 2 ;;
        --keychain-profile) PROFILE="$2"; shift 2 ;;
        --no-notarize) NOTARIZE=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

# **Never from a dirty repo**, in any mode: what is built has to be a commit
# anyone can check out, and the About box shows that commit. Syd, 2026-09-27: "I
# need to commit before doing a release dmg run, so the commit hash in the about
# box does not say '-dirty'", and 2026-09-28: "the release script should refuse
# to start if the repo is dirty." Untracked files count too, because Xcode
# compiles whatever is in a synchronized folder whether git knows about it or
# not. Ignored files do not. There is no way to override it.
if [[ -n "$(git -C "$REPO" status --porcelain)" ]]; then
    echo "the repo is dirty; commit or remove these first:" >&2
    git -C "$REPO" status --short >&2
    exit 1
fi

# **A version and build are released once.** On 2026-10-09 the folder already
# held a 0.5 (2) from September; a second 0.5 (2) was built, and the old image
# was installed in its place because the two had one name. Asked here, of the
# version the build is about to be given, so that the answer comes before the
# archive and two trips to Apple and not after. Asked again of the built app
# below, which is what names the image.
if [[ $NOTARIZE -eq 1 ]]; then
    NEXT_VERSION="$(sed -n 's/^MARKETING_VERSION *= *//p' "$REPO/Config/Version.xcconfig")"
    NEXT_BUILD="$(sed -n 's/^CURRENT_PROJECT_VERSION *= *//p' "$REPO/Config/Version.xcconfig")"
    TAKEN="$RELEASES_DIR/Photos-Go-Round $NEXT_VERSION ($NEXT_BUILD).dmg"
    # **The tag is how the repo says what has been released.** Syd, 2026-10-09:
    # "the release script should make the tag". It goes on the commit this
    # build starts from, at the very end, and it belongs on main. Asked about
    # here with the rest, before anything is built.
    TAG="release-$NEXT_VERSION-build-$NEXT_BUILD"
    COMMIT="$(git -C "$REPO" rev-parse HEAD)"
    BRANCH="$(git -C "$REPO" branch --show-current)"
    problems=()
    [[ "$BRANCH" == "main" ]] || problems+=("not on main: ${BRANCH:-no branch}")
    [[ -e "$TAKEN" ]] && problems+=("already in the releases folder: $TAKEN")
    git -C "$REPO" show-ref --verify --quiet "refs/tags/$TAG" && problems+=("tag $TAG already exists")
    if (( ${#problems[@]} > 0 )); then
        echo "cannot release $NEXT_VERSION ($NEXT_BUILD):" >&2
        printf '  %s\n' "${problems[@]}" >&2
        echo "for another candidate, move the build number first: Scripts/bump-version.sh" >&2
        exit 1
    fi
fi

case "$BUILD_DIR" in
    "$REPO"|"$REPO"/*) echo "refusing to build inside the repository: $BUILD_DIR" >&2; exit 2 ;;
esac

IDENTITY="$(security find-identity -v -p codesigning \
    | sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\"/\1/p" | head -1)"
if [[ -z "$IDENTITY" ]]; then
    echo "no Developer ID Application certificate for team $TEAM_ID in the keychain." >&2
    echo "Create one in Xcode -> Settings -> Accounts -> Manage Certificates." >&2
    exit 1
fi

ARCHIVE="$BUILD_DIR/Photos-Go-Round.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Photos-Go-Round.app"
rm -rf "$ARCHIVE" "$EXPORT_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving Release"
xcodebuild archive -project "$PROJECT" -scheme "Photos-Go-Round" \
    -configuration Release -destination "generic/platform=macOS" \
    -derivedDataPath "$BUILD_DIR/DerivedData" -archivePath "$ARCHIVE" -quiet

echo "==> Exporting with Developer ID"
OPTIONS="$BUILD_DIR/ExportOptions.plist"
cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
</dict>
</plist>
PLIST
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates -quiet

# **The export signs again and drops the requirement every build states.**
# Measured 2026-10-09: the exported 0.5 (3) stated the default Developer ID one
# on the app, the agent and the widget, where the archive it came from stated
# the team's. So everything is signed once more here, inside first, with the
# requirement and nothing else changed. `Scripts/sign-shared-requirement.sh`.
echo "==> Stating the shared signing requirement"
"$REPO/Scripts/sign-shared-requirement.sh" "$APP" "$IDENTITY" "$TEAM_ID"

# Notarization refuses anything without the hardened runtime, and a hardened
# agent without the Photos entitlement finds no photographs. Check both here,
# where the answer is a line of output rather than a rejection from Apple or a
# blank desktop on somebody else's Mac.
echo "==> Checking signatures"
codesign --verify --deep --strict "$APP"
SERVER="$APP/Contents/Helpers/Photos-Go-Round Server.app"
UNINSTALLER="$APP/Contents/Helpers/Uninstall Photos-Go-Round.app"
WALLPAPER="$APP/Contents/Library/Wallpaper/Photos-Go-Round Wallpaper.appex"
SAVER="$APP/Contents/Resources/Photos-Go-Round Screensaver.saver"
# The widget extension, carried by this app until there is a menubar app to
# carry it. `Plans/Photos-Go-Round Widgets.md`.
WIDGET="$APP/Contents/PlugIns/Photos-Go-Round Widget.appex"
[[ -d "$WIDGET" ]] || { echo "no widget extension in the app: $WIDGET" >&2; exit 1; }
for bundle in "$APP" "$SERVER" "$UNINSTALLER" "$WALLPAPER" "$SAVER" "$WIDGET"; do
    # `-dvv`: `-dv` prints no Authority lines, so a check of its output never
    # passed — found 2026-09-27, on the first run from the Release DMG target.
    info="$(codesign -dvv "$bundle" 2>&1)"
    grep -q "Authority=Developer ID Application" <<<"$info" \
        || { echo "not signed with Developer ID: $bundle" >&2; exit 1; }
    grep -q "flags=.*runtime" <<<"$info" \
        || { echo "no hardened runtime: $bundle" >&2; exit 1; }
done
# The widget shows photographs from Photos under the app's permission, so it
# needs the entitlement as the app and the agent do.
for bundle in "$APP" "$SERVER" "$WIDGET"; do
    codesign -d --entitlements - --xml "$bundle" 2>/dev/null \
        | grep -q "com.apple.security.personal-information.photos-library" \
        || { echo "no Photos entitlement: $bundle" >&2; exit 1; }
done
# The system will not load a widget extension that is not sandboxed.
codesign -d --entitlements - --xml "$WIDGET" 2>/dev/null \
    | grep -q "com.apple.security.app-sandbox" \
    || { echo "the widget extension is not sandboxed: $WIDGET" >&2; exit 1; }
# The widget is let into a folder only through a bookmark the app leaves in the
# App Group container the two share, so both have to belong to the group.
for bundle in "$APP" "$WIDGET"; do
    codesign -d --entitlements - --xml "$bundle" 2>/dev/null \
        | grep -q "com.apple.security.application-groups" \
        || { echo "no App Group entitlement: $bundle" >&2; exit 1; }
done
# Every build states one signing requirement that all of this team's builds
# meet, so that a privacy permission given to a Release build is not asked for
# again by a Debug one. The step after the export puts it on every bundle; this
# is the check that it is there, where the answer is a line of output and not
# two builds asking for Photos in turn.
for bundle in "$APP" "$SERVER" "$UNINSTALLER" "$WALLPAPER" "$SAVER" "$WIDGET"; do
    codesign -d -r- "$bundle" 2>&1 \
        | grep -q "designated => anchor apple generic and certificate leaf\[subject.OU\] = $TEAM_ID" \
        || { echo "does not state the shared signing requirement: $bundle" >&2; exit 1; }
done

notarize() {
    local file="$1" result status id
    echo "==> Notarizing $(basename "$file")"
    result="$(xcrun notarytool submit "$file" --keychain-profile "$PROFILE" \
        --wait --output-format json)"
    status="$(plutil -extract status raw - <<<"$result")"
    id="$(plutil -extract id raw - <<<"$result")"
    if [[ "$status" != "Accepted" ]]; then
        echo "notarization $status for $(basename "$file"):" >&2
        xcrun notarytool log "$id" --keychain-profile "$PROFILE" >&2 || true
        exit 1
    fi
}

if [[ $NOTARIZE -eq 1 ]]; then
    ZIP="$BUILD_DIR/Photos-Go-Round.zip"
    ditto -c -k --keepParent "$APP" "$ZIP"
    notarize "$ZIP"
    rm -f "$ZIP"
    xcrun stapler staple "$APP"
fi

# **From the app, not from Version.xcconfig**, so the image can never be named
# differently from the build inside it. Syd, 2026-09-27: "the title of the disk
# image needs to include them. 'Photos-Go-Round 0.1 (1).dmg', for example."
VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)"
BUILD="$(defaults read "$APP/Contents/Info.plist" CFBundleVersion)"
if [[ $NOTARIZE -eq 1 && "$TAG" != "release-$VERSION-build-$BUILD" ]]; then
    echo "the app is $VERSION ($BUILD), but Version.xcconfig named $TAG" >&2
    exit 1
fi
TITLE="Photos-Go-Round $VERSION ($BUILD)"
DMG="$BUILD_DIR/$TITLE.dmg"
echo "==> Packaging $(basename "$DMG")"
# The app, /Applications, the uninstaller and the About document, laid out by
# Finder. `Scripts/make-dmg.sh`; `Plans/Release DMG.md`, Phase 3.
"$REPO/Scripts/make-dmg.sh" "$APP" "$DMG" >/dev/null
codesign --sign "$IDENTITY" --timestamp "$DMG"

if [[ $NOTARIZE -eq 0 ]]; then
    echo "$DMG"
    exit 0
fi

notarize "$DMG"
xcrun stapler staple "$DMG"
echo "==> Gatekeeper"
spctl --assess --type execute -vv "$APP"
spctl --assess --type open --context context:primary-signature -vv "$DMG"

# Never over one that is there. The check before the build asked the same of
# Version.xcconfig; this asks it of the name the built app gave the image.
FINAL="$RELEASES_DIR/$(basename "$DMG")"
if [[ -e "$FINAL" ]]; then
    echo "$FINAL already exists; the new image is at $DMG" >&2
    exit 1
fi
mkdir -p "$RELEASES_DIR"
cp "$DMG" "$FINAL"

# The tag goes on the commit the build started from, and only once the image is
# in the releases folder. Advice goes to stderr, so the last line on stdout is
# the image in the releases folder, which is what the Release DMG target reveals
# in Finder.
echo "==> Tagging $TAG"
git -C "$REPO" tag -a "$TAG" "$COMMIT" -m "Photos-Go-Round $VERSION ($BUILD)"
echo "nothing is pushed; to send the tag: git push origin $TAG" >&2
echo "another candidate: Scripts/bump-version.sh" >&2
echo "it shipped:        Scripts/bump-version.sh --minor" >&2
echo "$FINAL"
