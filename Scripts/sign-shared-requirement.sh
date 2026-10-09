#!/bin/bash
#
# Signs a built Photos-Go-Round.app again, and everything inside it, so that
# each signature states the one requirement every build of this team meets.
# `Plans/Photos-Go-Round Widgets.md`, *Next: the app's sources, then Photos*.
#
# **Why a signature has to state it.** macOS records a privacy permission with
# the requirement the allowed build's signature states. Left alone, a Release
# build states a Developer ID requirement and a Debug build a development one,
# so each is asked again for a permission the other was given. Builds made by
# Xcode state the shared one through `OTHER_CODE_SIGN_FLAGS` in the project.
#
# **Why a release needs this as well.** `xcodebuild -exportArchive` signs the
# archive again with Developer ID and drops the stated requirement. Measured
# 2026-10-09: the exported 0.5 (3) stated the default one on the app, the agent
# and the widget. So `Scripts/release-build.sh` runs this on what the export
# produced, before it checks or notarizes anything.
#
# Everything else about each signature is kept: its identifier, its
# entitlements, and its flags, the hardened runtime among them. Inside first,
# since a bundle's signature covers the signatures of what it contains.
#
# It signs, and uploads nothing. An agent may run it on a build of its own with
# `--no-timestamp`; on a release it is `release-build.sh` that runs it.

set -euo pipefail

usage() {
    cat <<'HELPTEXT'
Signs an app and the code inside it again, stating the team's one requirement.

USAGE
  ./Scripts/sign-shared-requirement.sh [--no-timestamp] <app> <identity> <team-id>

  <app>        The built Photos-Go-Round.app.
  <identity>   What to sign with, as `security find-identity` names it.
  <team-id>    The team the requirement names, such as R5PQPZARC5.

OPTIONS
  --no-timestamp   Sign without asking Apple's timestamp service. For a build
                   that will not be notarized. A release needs the timestamp.
  -h, --help       This.
HELPTEXT
}

TIMESTAMP="--timestamp"
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-timestamp) TIMESTAMP="--timestamp=none"; shift ;;
        -h|--help) usage; exit 0 ;;
        -*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
        *) ARGS+=("$1"); shift ;;
    esac
done
if [[ ${#ARGS[@]} -ne 3 ]]; then
    usage >&2
    exit 2
fi
APP="${ARGS[0]}"
IDENTITY="${ARGS[1]}"
TEAM_ID="${ARGS[2]}"
[[ -d "$APP/Contents" ]] || { echo "not an app bundle: $APP" >&2; exit 1; }

# Without an identifier, as in the project: a Debug build's helper libraries are
# signed with the same flags and have identifiers of their own.
REQUIREMENT="=designated => anchor apple generic and certificate leaf[subject.OU] = $TEAM_ID"

sign() {
    codesign --force --sign "$IDENTITY" "$TIMESTAMP" \
        --preserve-metadata=identifier,entitlements,flags,runtime \
        --requirements "$REQUIREMENT" "$1"
}

# The deepest path first, by its count of slashes.
find "$APP/Contents" \( -name "*.app" -o -name "*.appex" -o -name "*.saver" \
        -o -name "*.framework" -o -name "*.xpc" -o -name "*.bundle" -o -name "*.dylib" \) -print \
    | awk '{ print gsub("/", "/") "\t" $0 }' | sort -rn | cut -f2- \
    | while IFS= read -r nested; do
        sign "$nested"
    done
sign "$APP"

codesign --verify --deep --strict "$APP"
