#!/bin/bash
#
# Moves the version and the build number in Config/Version.xcconfig, which every
# product reads: the app, the service, the uninstaller, the screensaver and the
# wallpaper extension. Syd, 2026-09-27: "a script to update the version and
# build numbers", run when a branch is made for new work.
#
# **The build number only ever goes up**, and never resets when the version
# moves, so every build anyone was handed has a number of its own — a second
# Mac running an older build is what started this, 2026-09-26. The DMG is named
# from both: "Photos-Go-Round 0.1 (2)".

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO/Config/Version.xcconfig"

usage() {
    cat <<'HELPTEXT'
Moves the version and the build number in Config/Version.xcconfig.

USAGE
  ./Scripts/bump-version.sh                  build number + 1
  ./Scripts/bump-version.sh --minor          0.1 -> 0.2, and build number + 1
  ./Scripts/bump-version.sh --major          0.2 -> 1.0, and build number + 1
  ./Scripts/bump-version.sh --version <x.y>  that version, and build number + 1

The build number never resets.
HELPTEXT
}

read_setting() { sed -n "s/^$1 = //p" "$CONFIG" | tr -d '[:space:]'; }

VERSION="$(read_setting MARKETING_VERSION)"
BUILD="$(read_setting CURRENT_PROJECT_VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "MARKETING_VERSION is not x.y: $VERSION" >&2; exit 1; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "CURRENT_PROJECT_VERSION is not a number: $BUILD" >&2; exit 1; }

MAJOR="${VERSION%%.*}"
MINOR="${VERSION#*.}"
NEW_VERSION="$VERSION"
case "${1:-}" in
    "") ;;
    --minor) NEW_VERSION="$MAJOR.$((MINOR + 1))" ;;
    --major) NEW_VERSION="$((MAJOR + 1)).0" ;;
    --version)
        [[ "${2:-}" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "--version needs x.y" >&2; exit 2; }
        NEW_VERSION="$2" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
esac
NEW_BUILD="$((BUILD + 1))"

sed -i '' \
    -e "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION/" \
    -e "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" \
    "$CONFIG"

echo "$VERSION ($BUILD) -> $NEW_VERSION ($NEW_BUILD)"
