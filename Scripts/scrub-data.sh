#!/bin/bash
#
# Deletes a build's data: its library, its cache and its preferences, current
# and retired alike.
#
# **Renamed from `scrub-dev.sh` on 2026-09-24, and widened.** It deleted only
# what the retired development libraries left behind — each build's `.dev`
# library and the surfaces' `.dev` and `.prod` domains, gone since every build
# got one set of assets. Syd: "I want scrub-dev.sh to be renamed
# 'scrub-data.sh', and have it also take variants and --all", and "this includes
# older versions of data files and current ones." So a variant's data is now
# everything any version of that build has kept.
#
# **A wrapper, not an implementation, since 2026-09-27.** The deleting moved into
# `Scrub` in `PhotosGoRoundInstall`, driven by `pgr_install scrub`, because the
# uninstaller on the DMG does the same thing and nothing in shell ships. Syd,
# 2026-09-19: "there should not be multiple versions of the build scripts."
# What follows describes `Scrub`; this script chooses variants and asks first.
# `Plans/Release DMG.md`.
#
# **Names come from `--variant`, never from a path.** Every name is spelled
# from `Storage` and `BuildVariant`; nothing is taken from an argument, from
# PGR_CONTAINER or from PGR_BUILD_ROOT — the one command whose whole job is
# deleting things is not one typo away from deleting something else.
#
# **The agent is stopped first** — unloaded, so `KeepAlive` does not bring it
# straight back — because a live agent holds the WAL open and republishes its
# port, and deleting underneath it leaves a half-deleted library and a running
# process disagreeing about what exists. It is left stopped: its plist stays
# installed, so it comes back at the next login, or with `pgr_install start`.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/variants.sh"

usage() {
    cat <<'USAGE'
usage: scrub-data.sh (--variant <name> ... | --all) [--yes] [--dry-run]

Deletes a build's data: its library and cache, its preferences and the
screensaver's and wallpaper's, and the same from every retired name the build
has used (`.dev`, `.prod`). Stops that build's agent first. Installed bundles
and LaunchAgents are left alone; see uninstall.sh.

  --variant <name>  release, debug or claude. May be given more than once.
  --all             All three.
  --yes             Do not ask.
  --dry-run         Say what would go; delete nothing.
  -h, --help        This.

The screensaver's and the wallpaper's remembered pictures live in containers
macOS protects. They are tried, and reported if macOS refuses; a terminal with
Full Disk Access can delete them.
USAGE
}

ASSUME_YES=0
DRY_RUN=0
while [[ $# -gt 0 ]]; do
    take_variant_option "$@"
    if (( CONSUMED > 0 )); then shift "$CONSUMED"; continue; fi
    case "$1" in
        --yes|-y)      ASSUME_YES=1 ;;
        --dry-run|-n)  DRY_RUN=1 ;;
        -h|--help)     usage; exit 0 ;;
        *)             echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done
require_variants

PGR_INSTALL="$(pgr_install_path)"

for variant in "${VARIANTS[@]}"; do
    "$PGR_INSTALL" scrub --variant "$variant" --dry-run
done

if (( DRY_RUN )); then
    echo "dry run — nothing stopped, nothing deleted"
    exit 0
fi

if (( ! ASSUME_YES )); then
    read -r -p "stop these builds' agents and delete their data? [y/N] " reply
    [[ "$reply" == [yY] ]] || { echo "left alone"; exit 1; }
fi

for variant in "${VARIANTS[@]}"; do
    "$PGR_INSTALL" scrub --variant "$variant"
done
