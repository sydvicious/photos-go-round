#!/bin/bash
#
# Makes the app icon as the widgets draw it: four sizes, eight bits a channel,
# in `Widgets/Shared/Sources/PhotosGoRoundWidgetFace/Resources`.
#
# Run it from anywhere whenever `Artwork/PhotosGoRound.icon` changes, and commit
# what it writes.
#
# **Why the widgets have pictures of their own.** A widget extension is ended at
# 30 MB. Its placeholder is the icon, and the icon was one picture of 1024
# pixels at 16 bits a channel: 8 MB decoded, before a copy at the size wanted
# was made from it. That took an extension to 25 MB on an iPad and 39.9 MB at a
# phone's sizes. Each of these is drawn from as it is, at four bytes a pixel,
# and the largest is 4 MB. `Plans/PGR Widgets - iOS.md`, *The icon, made for
# widgets*.
#
# **Each size is Icon Composer's own drawing of the icon at that size**, not one
# picture made smaller.
#
# **Nothing but the four pictures is written in the checkout.** What Icon
# Composer exports goes to a temporary folder, removed at the end.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON="$REPO/Artwork/PhotosGoRound.icon"
RESOURCES="$REPO/Widgets/Shared/Sources/PhotosGoRoundWidgetFace/Resources"
ICTOOL="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
# `WidgetFace.iconSizes` is the same list, and `WidgetIconTests` holds the
# pictures to it.
SIZES=(256 512 768 1024)

if [ ! -x "$ICTOOL" ]; then
    echo "make-widget-icons: Icon Composer's ictool is not at $ICTOOL" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for size in "${SIZES[@]}"; do
    "$ICTOOL" "$ICON" --export-image --output-file "$WORK/$size.png" \
        --platform iOS --rendition Default --width "$size" --height "$size" --scale 1 > /dev/null
    swift "$REPO/Scripts/eight-bit-png.swift" "$WORK/$size.png" "$RESOURCES/PhotosGoRoundIcon-$size.png"
    echo "PhotosGoRoundIcon-$size.png"
done
