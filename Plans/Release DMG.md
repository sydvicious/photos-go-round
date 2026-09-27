# Summary

Turn the plain DMG that `Scripts/release-build.sh` makes into a finished one. It
carries the app, an `/Applications` link, a double-clickable uninstaller and an
"About Photos-Go-Round" document, arranged in the window.

# Rationale

A DMG is the first thing another person sees of Photos-Go-Round, and today it is
a bare Finder window with two icons in it. Installing is already one drag,
because the app installs everything else at launch (`Release App Installer.md`).
Removing it is not: the agent, the wallpaper registration and the screensaver
link outlive a dragged-away app, and the only ways to remove them are the Help
menu, which needs the app, and `Scripts/uninstall.sh`, which needs the checkout.
It is the last item on the *Before the first release* checklist.

# Phases

- **Phase 1: the uninstaller.** A new app target, `Uninstall Photos-Go-Round`,
  embedded in `Photos-Go-Round.app` and copied onto the DMG.
  - A target and a scheme of its own in `Photos-Go-Round.xcodeproj`, built with `xcodebuild` in all three configurations like every other product.
  - Links `PhotosGoRoundInstall` and runs `Uninstall.plan` for its own build variant.
  - Then deletes that build's data: the library, the cache, the preferences — the agent's, the wallpaper's and the screensaver's — and the wallpaper extension's own container.
  - The deleting moves out of `Scripts/scrub-data.sh` into `PhotosGoRoundInstall`, and the script becomes a wrapper, as `uninstall.sh` is.
  - Asks, then moves the installed app to the Trash.
  - Embedded in `Contents/Helpers`, beside the agent, so one archive signs and notarizes it.
  - `release-build.sh` checks it for the Developer ID signature and the hardened runtime.
  - Claude builds it in the `Claude` configuration to check it compiles, and never runs it.
- **Phase 2: the About document.** `About Photos-Go-Round.rtf`, kept in the repository and edited in TextEdit.
  - Claude drafts it; Syd rewrites it.
  - Covers what it is, installing, what the first launch does, Photos access, and uninstalling.
- **Phase 3: the layout.** A new `Scripts/make-dmg.sh` wraps an exported app in the finished DMG, and `release-build.sh` calls it.
  - Finder AppleScript sets the window and the icon positions. No background picture and no custom volume icon.
  - Converted to compressed read-only, then signed, notarized and stapled as today.
- **Phase 4: run it.** Syd runs `release-build.sh`, opens the DMG, installs from it, and uninstalls with the uninstaller — on his Mac and on Plex.

# Design Decisions

- **The uninstaller is a build target in the Xcode project.** Syd, 2026-09-27: "since the uninstaller is itself an app, it should be a build target in the xcode project." The app target embeds its product in `Contents/Helpers` with a Copy Files phase, as it embeds the agent.
- **The uninstaller is a signed app, not a script.** A `.command` script cannot be notarized, so Gatekeeper refuses it when it comes off a downloaded DMG.
- **It runs `Uninstall.plan`, not a copy of it.** Syd, 2026-09-19: "there should not be multiple versions of the build scripts"; the Help menu and `uninstall.sh` already share it.
- **It removes its own build's copy only**, `[BuildVariant.current]`, as the Help menu does. A Release uninstaller never takes a Debug agent down.
- **It removes the library, the cache and the preferences too.** Syd, 2026-09-27: "It should remove the library and preferences also." An uninstaller that leaves settings behind leaves the one thing a user would notice (`PLAN.md`, *Settings are the only data a user would miss*), and they are user-by-machine, never exported.
- **One implementation of deleting a build's data.** `scrub-data.sh` does it in shell today; it moves into `PhotosGoRoundInstall`, so the uninstaller and the script share it.
- **It uninstalls for the user who runs it, and no one else.** Syd, 2026-09-27: "I am deliberately not addressing other users who might run this; their data is stranded." Every other account's agent, registrations, library and preferences stay where they are.
- **The screensaver's remembered picture is left where macOS protects it, and that is not an error.** It is inside `legacyScreenSaver`'s container, which is Apple's; the uninstaller is refused there every time (2026-09-27), and only a terminal with Full Disk Access gets through. Neither remembered picture is mentioned, deleted or left — Syd, 2026-09-27: "do not worry about telling the user about the cached images for wallpaper and screensaver."
- **Container folders macOS keeps are left, and not mentioned.** Tried 2026-09-27: asking Finder to trash them (`NSWorkspace.recycle`) was refused without a password prompt, for a library's claimed container and the wallpaper extension's alike. Only Full Disk Access would do it. Moving the libraries to Application Support stops new ones being made; the wallpaper extension's is macOS's, as every sandboxed app's container is.
- **It may ask the user to authenticate.** Syd, 2026-09-27. Deleting the wallpaper extension's container is the step likely to ask.
- **Anything that will not stop gets an alert offering Force Quit.** Syd, 2026-09-27. The app first, and the agent if launchd cannot remove it; nothing is deleted underneath a running process.
- **The uninstaller's icon is the app's with a red circle-slash over its lower-right corner.** Syd, 2026-09-27. `Artwork/Uninstaller.icon`: the app icon's two layers, and a third on top, `1 Circle Slash.svg`, opaque, with a white edge so it reads against both the background and the photographs.
- **It installs nothing at launch.** It does not link the app's launch-time install, so opening it cannot restart the agent it is about to remove.
- **It trashes the app only if it is in `/Applications`.** Syd, 2026-09-27: "I think you should only delete the app itself if it is /Applications." A build in DerivedData, or a copy kept elsewhere, is left where it is; it is still asked to quit.
- **The app it trashes is the one the agent's plist points into**, not whatever LaunchServices finds by bundle identifier, which every build shares. *Claude's.*
- **The About document is RTF.** It opens in TextEdit on every Mac, and needs no generator in the build. *Claude's.*
- **The DMG step is its own script**, `Scripts/make-dmg.sh`, so it can wrap any exported app, including one from Organizer. *Claude's.*
- **Finder lays the window out**, not a checked-in `.DS_Store` or a third-party DMG tool. No dependencies, and the result is whatever Finder itself would save.
- **The DMG and its volume are named with the version and the build**, `Photos-Go-Round 0.1 (1).dmg`, read from the app's own `Info.plist` so the name can never disagree with what is inside. Syd, 2026-09-27: "the title of the disk image needs to include them."
- **Every build records the git commit it came from, and the About box shows it with Option held.** Syd, 2026-09-27: "every build phase", and "I need to be able to get to it on any variant I am running." The app target's *Record Git Commit* phase writes `PGRGitCommit` — `git describe --always --dirty` — into the built `Info.plist` before signing, in all three configurations. It is the project's only script phase, and that target runs with script sandboxing off so `git` can read `.git`.
- **Every product takes its version and build from `Config/Version.xcconfig`.** The agent's and the screensaver's `Info.plist` hardcoded `0.1` and `1` until 2026-09-27.
- **No background picture and no custom volume icon.** Syd, 2026-09-27: "no background picture in the dmg", and "no custom icon".
- **The About document lives in `Packaging/DMG/`.** It is source, so it is in the repository; nothing generated is. *Claude's.*

# Background

`Scripts/release-build.sh`, written 2026-09-23, archives Release, exports it
with Developer ID, checks every bundle's signature, hardened runtime and Photos
entitlement, notarizes and staples the app, then makes a DMG with `hdiutil
create -format UDZO` from a folder holding the app and an `/Applications`
symlink, and signs, notarizes and staples that. The certificate and the
`pgr-notary` profile have been in Syd's keychain since.

Every build of the app carries the agent, the wallpaper extension and the
screensaver, installs and restarts the agent at every launch, and in Release
registers the wallpaper and links the saver. The Help menu installs and
uninstalls each piece for its own build. `Release App Installer.md`.

Syd, 2026-09-23: the DMG should carry a double-clickable uninstaller and an
"About …" document, with the icons arranged in a pleasing way, which he recalls
took AppleScript last time. `TODO.md`, *A finished DMG*.

# Detailed discussions

## The uninstaller

### Why an app

Three shapes were weighed.

- **A `.command` shell script.** The cheapest thing to write, and the one that
  does not survive distribution. A file downloaded from the internet carries the
  quarantine attribute, and Gatekeeper refuses to open quarantined code that is
  not notarized. A shell script cannot carry a notarization ticket of its own: it
  is not a Mach-O or a bundle, and a `codesign` signature on a plain file lives
  in extended attributes that a DMG copy may or may not keep. The user would get
  "cannot be opened because it is from an unidentified developer" from the one
  file whose job is to clean up. It would also need `pgr_install`, which does not
  ship inside the app.
- **An AppleScript applet.** Signable and notarizable, since it is a bundle. But
  the uninstall logic would have to be written again in AppleScript, or it would
  have to shell out to something that ships — and nothing that ships can do it
  from a script. Two implementations is what Syd ruled out on 2026-09-19.
- **A small Swift app linking `PhotosGoRoundInstall`.** Signed, hardened and
  notarized by the same archive as everything else, and it runs the same
  `Uninstall.plan` the Help menu runs. Chosen.

A fourth — the app itself with an `--uninstall` argument, and the DMG carrying
an alias — fails on the rule that every launch of the app installs and restarts
the agent. The app would have to decide not to install before it knew why it was
launched, and a Finder alias cannot pass arguments anyway.

### What it does, in order

1. **Says what it will remove, and asks.** One window: the app, its background
   service, the wallpaper, the screensaver, and its settings, one line each,
   dimmed when it is not here. No explanatory small print — Syd, 2026-09-27:
   "Get rid of all of that explanatory small text." The Uninstall button is
   disabled when there is nothing to remove. When it is done the window says
   only "Photos-Go-Round has been removed.", with an OK button; the report in a
   console font appears only when something was refused.
2. **Quits the app if it is running.** `NSRunningApplication` for the app's
   bundle identifier, filtered to the one at the path it is about to trash —
   every build shares the identifier, so a running Debug app must not be asked
   to quit. `terminate()`, then a wait of a few seconds. **If it has not quit, an
   alert says the app did not shut down and offers Force Quit or Cancel**;
   Force Quit is `forceTerminate()`. Syd, 2026-09-27: "the uninstaller should
   put up an alert explaining the running service did not shutdown, and should
   prompt them to Force quit." The agent gets the same alert if launchd still
   has it after `Uninstall`'s ten-second wait, with Force Quit sending it
   `SIGKILL`. Nothing further is removed until whatever was running has gone.
3. **Runs `Uninstall.plan(variants: [BuildVariant.current])`** with every part,
   and applies it, as `Installer.uninstall` does. That boots the agent out and
   deletes its plist, unregisters the wallpaper extension and restarts
   `WallpaperAgent`, and removes the screensaver symlink and stops
   `legacyScreenSaver`.
4. **Deletes the build's data** — after step 3, because a live agent holds the
   database's WAL open and republishes its port. The container,
   `~/Library/Application Support/<name>` — and the retired `~/Library/Containers/<name>` —;
   the cache, `~/Library/Caches/<name>`; and the
   preference domains `<name>`, `<name>.wallpaper` and `<name>.screensaver`,
   each by deleting its plist file and then restarting `cfprefsd` so it
   forgets its cached copy. *Not `removePersistentDomain`, which made
   `cfprefsd` write the file back empty — measured 2026-09-27.* The wallpaper
   extension's own sandbox container, below. The same for every retired name
   the build has used, as `scrub-data.sh` does. **A folder macOS will not remove is emptied instead** — measured 2026-09-27, the Debug container had been claimed by `containermanagerd`, and removing the folder was refused while everything in it went. Every refusal is reported and the rest carries on. Syd, 2026-09-27:
   "It should remove the library and preferences also."
5. **Moves the app to the Trash**, with `FileManager.trashItem`, so it can be
   put back. Never a permanent delete.
6. **Says what it did**, one line per piece.

### Deleting the data, and sharing it with `scrub-data.sh`

`Scripts/scrub-data.sh` already deletes a build's data: it unloads the agent,
removes the container and the cache, runs `defaults delete` on each domain and
deletes its plist, and does the same for every retired name (`.dev`, `.prod`).
It is shell, and it sources `Scripts/variants.sh` for the names, so nothing in it
can ship.

The uninstaller needs the same thing in Swift. Writing it a second time is what
Syd ruled out on 2026-09-19, so it moves: a `Scrub` alongside `Uninstall` in
`PhotosGoRoundInstall`, a `pgr_install scrub --variant` verb, and
`scrub-data.sh` reduced to a wrapper, exactly the shape `uninstall.sh` took. The
names come from `Storage` and `BuildVariant`, never from a path argument — the
rule `scrub-data.sh` states for itself, since deleting is its whole job.

`scrub-data.sh` leaves the agent stopped but installed. The uninstaller has
already uninstalled it by then, so there is nothing to leave.

**The wallpaper extension's own container goes too.** Syd, 2026-09-27: "yes, delete the extension's container too." The extension keeps its last picture (`LastPicture`) and its standard defaults in its sandbox container, `~/Library/Containers/<wallpaperExtensionIdentifier>` — `com.sydpolk.photosgoround.wallpaper.extension`, with `.debug` or `.claude` before `.extension` for the other builds — so `Scrub` removes it after the extension is unregistered and its process stopped. macOS owns that directory, and deleting another app's container from outside it may raise the "would like to access data from other apps" prompt. **Asking the user to authenticate is acceptable.** Syd, 2026-09-27: "it's ok to require the user the authenticate." So a prompt here, or a password, is expected rather than a failure to design around. If the user declines, the uninstaller says so, names the path, and carries on; nothing else depends on it. Since `Scrub` is shared, `scrub-data.sh` deletes it too.

### Which app it trashes

The bundle identifier `com.sydpolk.photosgoround` is the same in all three
configurations, because TCC grants hang off it (`BuildVariant.swift`). So asking
LaunchServices for "the app with this identifier" can return a Debug build in
DerivedData as readily as the Release one in `/Applications`.

The agent's plist is the better witness. It is at
`~/Library/LaunchAgents/<label>.plist` for this build's label, and its
`ProgramArguments` point at `…/Photos-Go-Round.app/Contents/Helpers/Photos-Go-Round
Server.app/…`. The app to trash is the one that path is inside. If there is no
plist, the uninstaller falls back to `/Applications/Photos-Go-Round.app` if it is
there and is this build — and otherwise trashes nothing and says so.

Read the plist before step 3 removes it.

### Where it lives

`Contents/Helpers/Uninstall Photos-Go-Round.app`, beside `Photos-Go-Round
Server.app`. So the one `xcodebuild archive` builds, signs and embeds it, and the
app's notarization covers it. `release-build.sh` copies it out with `ditto` to
the DMG's root, which keeps the signature intact.

An uninstaller inside the app it trashes is odd but harmless: a running process
does not need its bundle on disk. **The Help menu gets no item that opens it.** Syd, 2026-09-27: "The help menu does NOT get an uinstall item." It is reached from the DMG.

### Gatekeeper, for a copy taken off the DMG

The DMG is notarized and stapled, and notarizing a DMG records the code hash of
every signed binary inside it. Opened from the DMG, the uninstaller is covered by
the DMG's ticket. Copied off first, Gatekeeper checks its ticket online, which
also works; stapling the embedded helper separately would cover the offline
case. `stapler staple` on the app already staples it; whether that ticket covers
the nested helper once copied out is to be checked in Phase 4.

### Checking it

`release-build.sh` already walks a list of bundles checking for the Developer ID
authority and the hardened runtime. The uninstaller joins the list. It needs no
Photos entitlement, and should not have one.

### Testing without running it

Claude builds the target in the `Claude` configuration and runs the package
tests for anything added to `PhotosGoRoundInstall`. Claude never runs the
uninstaller: running it uninstalls. A `Claude` build would only take the Claude
variant's agent, wallpaper, saver and data — but that is still Syd's running system.
The part worth unit-testing is the plist-to-app-path step, which can take a
plist file and return a URL without touching anything.

## The About document

RTF over the alternatives:

- **PDF** needs something to make it from, and a generator is a build step and
  probably a dependency.
- **Markdown** shows as plain text in TextEdit and Quick Look alike, with the
  asterisks.
- **HTML** opens in a browser, which is a strange thing for a disk image to do.
- **RTF** opens in TextEdit on every Mac, looks like a document, and Syd can
  edit it directly. What is checked in is what ships.

Name: `About Photos-Go-Round.rtf`. Content, drafted by Claude:

- What Photos-Go-Round is, in two sentences.
- Installing: drag it to Applications, open it once. What that first launch
  does — the agent, the wallpaper in System Settings › Wallpaper, the
  screensaver in System Settings › Screen Saver.
- Photos access: Settings › Choose Collections › Allow Access….
- Uninstalling: open the uninstaller from this disk image. It removes everything, the settings and the chosen sources included.
- The version, and where to find out more.

## The layout

### How, with Finder

The standard way, which `create-dmg` and most hand-rolled scripts share:

1. `hdiutil create -format UDRW -srcfolder <staging> -volname "Photos-Go-Round"`
   — writable, sized to fit plus room for Finder's `.DS_Store`.
2. `hdiutil attach -readwrite -noverify -noautoopen` and note the mount point.
3. `osascript` telling Finder to open the disk, set icon view, hide the toolbar
   and status bar, set the window bounds and icon size, set the position of
   each item, update, and close. Closing is what makes Finder write `.DS_Store`.
4. `sync`, `hdiutil detach`.
5. `hdiutil convert -format UDZO` to the final compressed, read-only image.
6. `codesign`, notarize, staple — as `release-build.sh` does now.

The first run asks Syd to let Terminal control Finder. It is a one-time
Automation grant, and it is his to give.

### Why not a checked-in `.DS_Store`

It works without Finder, which is why CI setups use it. But it is a binary file
nobody can read or diff, and every change to the volume name, the items or
their positions means making it again by hand.
Finder writing it fresh each time is slower and always right. **Revisit if this
moves to CI**: Syd, 2026-09-27, "We might need it if we move to CI/CD later" —
and a CI runner has no Finder session to script.

### Why not `create-dmg` or `dmgbuild`

Both are third-party, and `PLAN.md`'s *No third-party dependencies* covers build
tools too. What they do is the six steps above.

### Positions

Window about 640 × 400 points. App at left and Applications at right on the
first row; the uninstaller and the About document on a
second, smaller row. Final numbers are set by looking at it.

### `make-dmg.sh`

Takes an exported, stapled app and an output path. Finds the uninstaller inside
the app, stages the app, the `/Applications` link, the uninstaller and the About
document, and runs the steps above. `release-build.sh` calls it where it runs
`hdiutil create` today. On its own, it can wrap an app exported from
Organizer's *Direct Distribution*. Signing and notarizing the DMG stay in
`release-build.sh`, so `make-dmg.sh` needs no credentials.

Syd's to run, like `release-build.sh`: it drives Finder on his screen.

## Open questions

- None left.

# References

- `TODO.md` — *Before the first release*; *A finished DMG*.
- `Plans/PLAN.md` — *Shipping it: 1.0 distribution and updates*; *Settings are
  the only data a user would miss*; *No third-party dependencies*.
- `Plans/Release App Installer.md` — *Uninstall*; the Help menu.
- `Plans/Xcode - Separate Build and Run.md` — why install logic lives in
  `PhotosGoRoundInstall`.
- `Scripts/release-build.sh`, `Scripts/uninstall.sh`.
- `MacOS/Shared/Sources/PhotosGoRoundInstall/Uninstall.swift`,
  `MacOS/Desktop/Sources/Installer.swift`.
- `man hdiutil`, `man tiffutil`, `man stapler`.
- Apple, *Notarizing macOS software before distribution*.
