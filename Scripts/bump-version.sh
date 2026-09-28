#!/bin/bash
#
# Moves the version and the build number in Config/Version.xcconfig, which every
# product reads — the app, the service, the uninstaller, the screensaver and the
# wallpaper extension — and records the move in git: a branch, a commit, a merge
# into main, and a tag on the merge. Syd, 2026-09-27: "make a branch, update the
# version, commit the branch, then merge to main, and tag the commit."
#
# **The build number only ever goes up**, and never resets when the version
# moves, so every build anyone was handed has a number of its own — a second
# Mac running an older build is what started this, 2026-09-26. Syd, 2026-09-27:
# "keep the build number never resetting." The DMG is named from both:
# "Photos-Go-Round 0.5 (3)".
#
# **From a clean main, and nowhere else**, so the version commit holds the
# version and nothing more. Nothing is pushed: the last line says what to push.
#
# Syd's to run: it commits, merges and tags. An agent may run `--dry-run`.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$REPO/Config/Version.xcconfig"
DRY_RUN=0

usage() {
    cat <<'HELPTEXT'
Moves the version and the build number, and records it in git.

USAGE
  ./Scripts/bump-version.sh [--dry-run]                  build number + 1
  ./Scripts/bump-version.sh [--dry-run] --minor          0.5 -> 0.6, build + 1
  ./Scripts/bump-version.sh [--dry-run] --major          0.6 -> 1.0, build + 1
  ./Scripts/bump-version.sh [--dry-run] --version <x.y>  that version, build + 1

From a clean main, it makes the branch version-<x.y>-<build>, commits the change
to Config/Version.xcconfig there, merges it into main with a merge commit, and
tags the merge v<x.y>-<build>. Nothing is pushed. The build number never resets.

  --dry-run   Say what it would do, and change nothing.
HELPTEXT
}

CHANGE=""
VERSION_ARG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --minor|--major) CHANGE="$1"; shift ;;
        --version)
            [[ "${2:-}" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "--version needs x.y" >&2; exit 2; }
            CHANGE="--version"; VERSION_ARG="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
done

git() { command git -C "$REPO" "$@"; }

read_setting() { sed -n "s/^$1 = //p" "$CONFIG" | tr -d '[:space:]'; }

VERSION="$(read_setting MARKETING_VERSION)"
BUILD="$(read_setting CURRENT_PROJECT_VERSION)"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]] || { echo "MARKETING_VERSION is not x.y: $VERSION" >&2; exit 1; }
[[ "$BUILD" =~ ^[0-9]+$ ]] || { echo "CURRENT_PROJECT_VERSION is not a number: $BUILD" >&2; exit 1; }

MAJOR="${VERSION%%.*}"
MINOR="${VERSION#*.}"
case "$CHANGE" in
    "") NEW_VERSION="$VERSION" ;;
    --minor) NEW_VERSION="$MAJOR.$((MINOR + 1))" ;;
    --major) NEW_VERSION="$((MAJOR + 1)).0" ;;
    --version) NEW_VERSION="$VERSION_ARG" ;;
esac
NEW_BUILD="$((BUILD + 1))"
BRANCH="version-$NEW_VERSION-$NEW_BUILD"
TAG="v$NEW_VERSION-$NEW_BUILD"
TITLE="$NEW_VERSION ($NEW_BUILD)"

# Everything that would stop it, found before anything is changed.
problems=()
[[ "$(git branch --show-current)" == "main" ]] || problems+=("not on main: $(git branch --show-current)")
git diff --quiet HEAD -- || problems+=("uncommitted changes to tracked files")
git show-ref --verify --quiet "refs/heads/$BRANCH" && problems+=("branch $BRANCH already exists")
git show-ref --verify --quiet "refs/tags/$TAG" && problems+=("tag $TAG already exists")

echo "$VERSION ($BUILD) -> $TITLE"
echo "  branch $BRANCH, commit \"Version $TITLE\", merge into main, tag $TAG"

if (( ${#problems[@]} > 0 )); then
    printf '  cannot: %s\n' "${problems[@]}" >&2
    exit 1
fi
if (( DRY_RUN )); then
    echo "dry run — nothing changed"
    exit 0
fi

# If a step fails part way, say where things were left rather than undo them.
trap 'echo "stopped part way; now on $(git branch --show-current). Check git status and git log." >&2' ERR

git switch --quiet -c "$BRANCH"
sed -i '' \
    -e "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $NEW_VERSION/" \
    -e "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $NEW_BUILD/" \
    "$CONFIG"
git add "$CONFIG"
git commit --quiet -m "Version $TITLE"
git switch --quiet main
git merge --quiet --no-ff "$BRANCH" -m "Merge version $TITLE"
git tag -a "$TAG" -m "Photos-Go-Round $TITLE"

echo "on main at $(git rev-parse --short HEAD), tagged $TAG"
echo "to publish: git push origin main $TAG"
