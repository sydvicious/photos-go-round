#!/bin/bash
#
# Wraps a built Photos-Go-Round.app in the finished disk image: the app, a link
# to /Applications, the uninstaller and the About document, arranged by Finder.
# `Plans/Release DMG.md`, Phase 3.
#
# It packages what it is given and signs nothing. `Scripts/release-build.sh`
# calls it, then signs, notarizes and staples the image it makes. On its own it
# wraps any exported app, one from Organizer's Direct Distribution included.
#
# **Named with the version and the build**, read from the app rather than from
# Version.xcconfig so the image can never be named differently from what is
# inside it: "Photos-Go-Round 0.1 (1)". Syd, 2026-09-27.
#
# **Syd's to run, not an agent's**, because the layout drives Finder on his
# screen; the first run asks to let Terminal control Finder. `--no-layout`
# skips Finder and makes the same image unarranged, which is what an agent may
# run to check the rest, and what a CI runner with no Finder session would need.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ABOUT="$REPO/Packaging/DMG/About Photos-Go-Round.rtf"
LAYOUT=1

usage() {
    cat <<'HELPTEXT'
Wraps Photos-Go-Round.app in the finished disk image.

USAGE
  ./Scripts/make-dmg.sh [--no-layout] <Photos-Go-Round.app> <output.dmg>

  --no-layout   Leave the window unarranged, and do not drive Finder.

The image holds the app, a link to /Applications, the uninstaller from inside the
app, and Packaging/DMG/About Photos-Go-Round.rtf. It is compressed and read-only,
and not signed.
HELPTEXT
}

while [[ $# -gt 0 && "$1" == -* ]]; do
    case "$1" in
        --no-layout) LAYOUT=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done
[[ $# -eq 2 ]] || { usage >&2; exit 2; }
APP="$1"
DMG="$2"

case "$(cd "$(dirname "$DMG")" 2>/dev/null && pwd)" in
    "$REPO"|"$REPO"/*) echo "refusing to write inside the repository: $DMG" >&2; exit 2 ;;
esac

UNINSTALLER="$APP/Contents/Helpers/Uninstall Photos-Go-Round.app"
for needed in "$APP" "$UNINSTALLER" "$ABOUT"; do
    [[ -e "$needed" ]] || { echo "missing: $needed" >&2; exit 1; }
done

VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)"
BUILD="$(defaults read "$APP/Contents/Info.plist" CFBundleVersion)"
TITLE="Photos-Go-Round $VERSION ($BUILD)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/stage"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/Photos-Go-Round.app"
ln -s /Applications "$STAGE/Applications"
ditto "$UNINSTALLER" "$STAGE/Uninstall Photos-Go-Round.app"
cp "$ABOUT" "$STAGE/"

mkdir -p "$(dirname "$DMG")"
rm -f "$DMG"

if [[ $LAYOUT -eq 0 ]]; then
    hdiutil create -volname "$TITLE" -srcfolder "$STAGE" -fs HFS+ -format UDZO -quiet "$DMG"
    echo "$DMG"
    exit 0
fi

# **Writable first, so Finder can arrange it, then compressed.** Finder writes
# the window's layout into the volume's .DS_Store when the window closes, which
# needs a volume it can write to. Extra room for that file.
RW="$WORK/rw.dmg"
hdiutil create -volname "$TITLE" -srcfolder "$STAGE" -fs HFS+ -format UDRW \
    -size "$(( $(du -sm "$STAGE" | cut -f1) + 20 ))m" -quiet "$RW"
# `diskutil image attach`, not `hdiutil attach`, which macOS 27 calls deprecated
# on every run. Read-write by default, with the same tab-separated device and
# mount point. **Not `--nobrowse`**: Finder has to see the volume to arrange it.
ATTACHED="$(diskutil image attach "$RW")"
DEVICE="$(awk -F'\t' '/Apple_HFS/ { print $1 }' <<<"$ATTACHED" | tr -d '[:space:]')"
MOUNT="$(awk -F'\t' '/Apple_HFS/ { print $NF }' <<<"$ATTACHED")"
detach() { [[ -n "${DEVICE:-}" ]] && hdiutil detach "$DEVICE" -quiet || true; }
trap 'detach; rm -rf "$WORK"' EXIT

# Positions are the centres of the icons, in points from the window's top left:
# the app and Applications on the first row, the uninstaller and the About
# document below. **Narrow, and close to the top**, Syd, 2026-09-27: "too much
# space at the top of this view, and it needs to be much narrower." **And tall,
# with room under the second row** for a two-line name at a large text size:
# "It needs to be quite a bit taller so that dynamic text in large mode has a
# hope of showing something." 480 x 520.
#
# **Closed and opened again before it is saved.** The first layout closed the
# window once, and Finder kept neither its size nor its place. The second pass,
# with a pause, is what Finder needs to write the window into .DS_Store.
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$TITLE"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 680, 640}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 13
        set position of item "Photos-Go-Round.app" of container window to {120, 80}
        set position of item "Applications" of container window to {360, 80}
        set position of item "Uninstall Photos-Go-Round.app" of container window to {120, 250}
        set position of item "About Photos-Go-Round.rtf" of container window to {360, 250}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# Finder's event log on the volume is not the user's business.
if [[ -n "$MOUNT" && -d "$MOUNT/.fseventsd" ]]; then rm -rf "$MOUNT/.fseventsd"; fi

sync
detach
DEVICE=""
hdiutil convert "$RW" -format UDZO -o "$DMG" -quiet
echo "$DMG"
