**DEFERRED.** Syd, 2026-10-09: "let's not do that source reorg. just make an ios folder and
continue with what we are doing." The plan is kept as written that day; nothing in it is under way.
One part of it goes ahead anyway. The same day: "let's go ahead and put all of the widget stuff in one
folder at the top. Don't move anything else". So the widgets get their folder, with the iOS app in
it, and every other binary stays where it is (`Plans/PGR Widgets - iOS.md`, *Where the code
lives*).

# Summary

Reorganize the repository into a folder for each binary: agent, app, menubar, wallpaper,
screensaver, widget, pgr_ctl, and global. Only widget is on more than one platform, so only it is
divided again, into macOS, iOS and Shared. Syd, 2026-10-09; his thinking, not yet a decision.

# Rationale

The layout made on 2026-09-22 puts the platform first: `MacOS/` holds a folder for each Mac binary
and `Shared/` holds what crosses platforms. With the iOS app coming, the one product that crosses
platforms, the widgets, would be spread over `MacOS/Widget`, a new `iOS/`, and `Shared/`. A folder
for each binary keeps everything about one binary together. Syd: "That's a lot of work, but for
me, will pay off over time."

# Phases

Proposed by Claude, 2026-10-09; not yet agreed.

- **Phase 1** — Say where everything goes: a place for each thing in *What is not placed yet*.
- **Phase 2** — New iOS code is written where this layout puts it, so it is never moved.
- **Phase 3** — Move the existing code, one binary at a time.
  - After each move the build is warning-free on a clean build and the package tests pass.
  - `Package.swift` and the Xcode project follow each move.
- **Phase 4** — Everything that quotes a path: `CLAUDE.md`, `Scripts/`, `Documentation/`, the
  plans.

# Design Decisions

- **A folder for each binary: agent, app, menubar, wallpaper, screensaver, widget, pgr_ctl,
  global.** Syd, 2026-10-09.
- **Only widget is divided by platform: macOS, iOS and Shared.** It is the only one on more than
  one. Syd, 2026-10-09.
- *Proposed:* **moving the existing code is a branch of its own**, apart from the iOS app's.
- *Proposed:* **a move only moves.** Nothing is renamed or rewritten in the same change, as in the
  first reorganization.

# Background

- `Plans/Project Source Reorg.md` is the first reorganization, finished 2026-09-22. It planned an
  `iOS` folder at the top level, which was never made.
- Today: `MacOS/` has `Agent`, `Desktop`, `Screensaver`, `Wallpaper`, `Widget`, `Uninstaller`,
  `Tools` and `Shared`; the top-level `Shared/` has `PhotosGoRoundAgentAPI`,
  `PhotosGoRoundDisplay` and `TinyCache`.
- There is no menubar app yet, and no iOS code.
- This came up on 2026-10-09 while planning the iOS app, from the question of where its settings
  view should live (`Plans/PGR Widgets - iOS.md`, *Where the code lives*).

# Detailed discussions

Written by Claude on 2026-10-09 from one message of Syd's. Nothing here has been decided beyond
what *Design Decisions* attributes to him.

## What Syd said

2026-10-09: "I am thinking we need to reorganize the project into a folder for each binary: agent,
app, menubar, wallpaper, screensaver, widget, pgr_ctl, global. The only one of those that is cross
platform is widget, and that would have macOS, iOS, ans Shared. That's a lot of work, but for me,
will pay off over time."

## His folders, against what is there today

Claude's reading of where today's folders would go. The folder names are as he typed them; whether
they are capitalized, as today's are, was not said.

| His folder | What it would hold | Where that is today |
|---|---|---|
| `agent` | The agent, with its dashboard and endpoints | `MacOS/Agent` |
| `app` | Photos-Go-Round.app | `MacOS/Desktop` |
| `menubar` | The Widgets menubar app | nothing yet |
| `wallpaper` | The wallpaper extension and its host app | `MacOS/Wallpaper` |
| `screensaver` | The screensaver | `MacOS/Screensaver` |
| `widget/macOS` | The Mac's widget extension | `MacOS/Widget` |
| `widget/iOS` | The iOS app and its widget extension | nothing yet |
| `widget/Shared` | What both platforms' widgets compile | part of `MacOS/Widget/Sources`, and perhaps `Shared/Sources/TinyCache` |
| `pgr_ctl` | The command-line tool | `MacOS/Tools/pgr_ctl` |
| `global` | What more than one binary links | see below |

**The menubar app and the widget are separate folders in his list.** The menubar app is the Mac's
carrier for the widgets, as the iOS app is on a phone, yet the iOS app has no folder of its own in
the list. The table puts the iOS app in `widget/iOS`. Whether that is what he means, or the iOS
app is `app`'s counterpart somewhere else, is to be asked.

## What is not placed yet

Things in the repository that his list does not name:

- **`pgr_install`**, in `MacOS/Tools`, which the Install schemes run.
- **The uninstaller**, `MacOS/Uninstaller`.
- **The package targets that several binaries link.** `PhotosGoRoundKit`, `PhotosGoRoundInstall`
  and `Console` in `MacOS/Shared`; `PhotosGoRoundAgentAPI` and `PhotosGoRoundDisplay` in
  `Shared`. `global` is presumably theirs. The kit is linked by the agent and `pgr_ctl`; whether
  that makes it global or the agent's is a choice.
- **`TinyCache`**, which only the widgets use: `widget/Shared`, or `global`.
- **Each target's tests.** Today they sit beside their sources, in a `Tests` folder in each
  binary's folder; the first reorganization's rule was `Plans`, `Resources`, `Sources` and `Tests`
  in each. Whether that rule carries over was not said.
- **The top-level folders that are not code:** `Artwork`, `Audits`, `Config`, `Documentation`,
  `Packaging`, `Plans`, `Scripts`. They are presumably left where they are.
- **`MacOS/Desktop/FEATURES.md`**, and any other document kept beside code.

## What moving costs

- **`Package.swift`.** Sixteen targets, each with a `path:`. The agent's two are rooted at
  `MacOS/Agent` and list their folders.
- **The Xcode project.** Eleven targets. Its file references and each target's membership
  exceptions name folders; `BuildVariantTests` reads the project file.
- **`Package Tests.xctestplan`** names targets and no folders, so it needs nothing.
- **`Scripts/`**, which build, install, uninstall and release by path.
- **`CLAUDE.md`**, whose rules quote paths, and `Documentation/`.
- **The plans.** They quote paths throughout. The first reorganization left old paths in old
  plans; whether this one does was not said.
- **History.** `git log --follow` survives a move that changes nothing else, which is the reason
  for *a move only moves*.

A move is Syd's to commit, and it changes the checked-out tree under any other branch in flight.
So it is best done when no other branch is open, or the open ones are rebased across it by him.

## The order with the iOS app

Claude's proposal. The iOS app is the first thing that needs the new layout, and it is all new
code. So it can be written straight into `widget/iOS` and `widget/Shared` while everything else
stays where it is, and the move of the existing code can come at any time after: before the
widget extension in the iOS plan's Phase 2 needs the Mac widget's sources in `widget/Shared`, or
later with those few files moved first.

The other order is to do the whole reorganization first and start the iOS app in a finished
layout. It delays the iOS app by the length of the reorganization.

# References

- `Plans/Project Source Reorg.md` — the first reorganization, and its table of where things went.
- `Plans/PGR Widgets - iOS.md` — the iOS app, which is what raised this.
- `Plans/Photos-Go-Round Widgets.md` — the widgets product.
- `Package.swift`, `Photos-Go-Round.xcodeproj` — what a move has to follow.
