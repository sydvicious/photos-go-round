# TODO

Things to look into, deferred out of the phase list. Each one earns its own plan document if and when it is picked up; nothing here is designed yet.

**This file holds only what is left.** An item is deleted when it is done, not struck through and not annotated as fixed — Syd, 2026-09-19: "`git log` and the plans tell me what has been done, so let's remove things as they get done", and "cleaning it up every once in a while keeps me sane". The record of finished work lives in the commit history and in `Plans/`; a TODO that also carries it stops being readable as a list of what remains.

**When a plan closes, check what it was holding.** Anything it left as later work moves here before the plan is marked done, or it disappears with it.

## Before the first release

Syd, 2026-09-23, after the first notarized Release worked end to end: "checklist for final release".

- [ ] **A finished DMG.** *A finished DMG*, below.
- [ ] **The proof-of-concept widget is out of `Photos-Go-Round.app`.** It comes out when there is a menubar app to carry it. `Plans/Photos-Go-Round Widgets.md`, *The proof of concept, in the existing app*.

## Passed over on 2026-09-16 — to fix, not to keep

Syd, 2026-09-16: "i have no deadlines, and I hate tech debt surprises. I won't remember any issues you mention and bypass, so let's not bypass them." Every issue Claude mentioned during the agent performance work and did not fix is here. **Delete each one when it is fixed** — Syd, 2026-09-19: "cleaning it up every once in a while keeps me sane." Git has what was removed.

- **Flaky tests, below: how to fix them.** Syd, 2026-09-16: "we fixed flaky timing tests at Indeed by using await Task {}.run." *Claude's reading: a test awaits the work it depends on rather than racing it against a clock.*
- **The flaky build problem — caught and named 2026-09-19.** It is not a flaky *test*: it is `pgr_ctl`'s **testable** build failing to compile. `WallpaperCommands.swift:36` reports `cannot find type 'Deployment' in scope` and then `cannot find type 'BuildVariant'`, with `import PhotoGoRoundAgentAPI` present on line 3 of that file. Everything downstream of it — the whole run — is then reported as a test failure, which is why it read as flakiness for three days.
  - **Build-order dependent.** `xcodebuild clean test` passes every time; incremental `xcodebuild test -scheme "Package Tests"` failed on the second of six consecutive runs over an unchanged tree. The full log is at `~/.claude/build/flaky/run2.log`.
  - **The same shape as `Build Plan.md`'s 2026-09-16 finding**, where `pgr_ctl` linked when built alone and failed when built after `Photo-Go-Round Server` in the same folder. That one was fixed by declaring the package product dependency, which *is* declared here — so this is a second instance with a different cause, not a regression of the first.
  - **The leading suspect is a second builder.** Syd, 2026-09-19: "There is another agent working on the fact that the wallpaper agent wasn't changing pictures" — in this same working copy. `WallpaperCommands.swift` was being edited by it while these runs happened, and two builders sharing intermediates invalidate each other's, which `CLAUDE.md` already says of Syd's own Xcode. A source file rewritten under an incremental compile would produce exactly this.
  - **To settle it:** run the loop again when nothing else is working in the checkout. If it stops failing, the answer is contention and there is no defect to chase. If it still fails, the suspicion is the `-enable-testing` variant of `PhotoGoRoundAgentAPI` being rebuilt under the compile that needs it — unmeasured.
  - It is a build problem wearing a test problem's clothes, and the two above it are the timing-flaky tests proper.
- **Some photographs change on every refresh.** After Phase 4 was installed, 2026-09-16 22:24, two refreshes 20 seconds apart each wrote about 17 pages of Favorites (source 5) with one or two "changed" rows apiece; the probe's refreshes before it showed the same. Nothing about those photographs changed in between, so a storage or byte size is probably read differently each walk — a Photos asset whose size flips between known and unknown, say. Each costs a short lock (0–4 ms) and a needless write. Not looked into; the `REFRESH:` line does not name which rows.
- **The test run stalls the cooperative pool for up to two seconds.** Measured 2026-09-16 while fixing `RequestBodyTests`: a 10 ms `Task.sleep` resumed 1.2–1.96 s late in full parallel runs of the agent's tests. Not traced to which suites hold pool threads. The same shape as the agent's own pool starvation that afternoon, so the one lead from the flaky-test work that may matter outside the tests. Syd, the same evening, on flaky tests that expose no code problem: "are they really worth it?"
- **A test that asks the real Photos library: `SourceEndpointTests` "An album identifier that names nothing is refused at the door".** It posts a `photos_collection` source through the endpoint's default providers, which ask PhotoKit on whatever Mac runs the tests, under a time bound. It failed in two full runs while `ServingUnderLoadTests` froze the pool.
- **`PhotosSourceEditingTests` fails under machine load, against a fake library.** 2026-09-21, load average 21–28 from something else on the Mac: five of its tests failed in each of three full runs (seven in one, with two walk-stall tests), each taking ~11 s, and all 18 passed alone in 5 s. They fail because `SourceStore.validationLimit` (5 s) expires, so the source is recorded rather than refused. An untouched copy of `HEAD` passed once and failed `SourceEndpointTests` once in the same window, so it is load, not a change. A test that races a wall clock against the pool — the same shape as the item above.
- **Every configuration's screensaver has the same principal class, `PGRScreenSaverView`.** Found 2026-09-21: with the Debug saver loaded, a `(Claude)` saver shown in the same host ran Debug's code, on Debug's port, against Syd's running agent — the Objective-C runtime keeps the first class of a name in a process. So the three configurations' savers install side by side but cannot run side by side, which `CLAUDE.md`'s table implies they can. The class is named by `@objc(PGRScreenSaverView)` in `MacOS/Screensaver/Sources/PGRScreenSaverView.swift` and `NSPrincipalClass` in the saver's `Info.plist`; each configuration needs its own.
- **Settings has no way to ask for Photos access.** Found 2026-09-24 after access was reset: the sources list shows "Photos access has not been granted yet" with nothing to press, and only the album picker's "Allow Access…" raises the prompt. The list should offer the same button, and it should read the agent's status first (`GET /v2/photos/authorization`): `authorized` refreshes the album sources without asking the system; `notDetermined` asks, then refreshes on a grant; `denied` or `restricted` points to System Settings. Not refresh-first: a cold album walk takes 40–60 s, so the prompt would wait that long. And the picker's error after a grant should say the library is still starting: from 17:11:08 to 17:11:40 its listings failed `503 library did not answer`, which read as a refusal though access was `authorized`.
- **`ConsoleMirrorTests` "A change keeps its mark and its suffix" fails in full parallel runs.** Seen 2026-09-24, once in three runs; it passed alone three times out of three. `Mirrored.install()` swaps the process-wide `Console.mirror` hook, so another test writing through it at the same moment is the likely cause.
- **Restructure the tests so none fails on wall-clock time.** Syd, 2026-09-21: "some of the tests need to be restructured not to fail on wall clock time." Started and set aside the same day; nothing changed yet.
  - **Why they lose under load:** `Deadline.run` times on a `DispatchSourceTimer` since 2026-09-18, so its limit expires on time even when the pool is starved — while the work it bounds, a fake that would answer at once, waits for a pool thread. The timer was made robust for the agent; for a test that expects the answer, that is what makes it lose.
  - **The likely shape of the fix:** production bounds such as `SourceStore.validationLimit` become injectable, so a test expecting an answer passes a bound it cannot reach, and a test about silence uses a fake that never answers — which then fails only one way whatever the clock does. The "await the work, don't race it" idea above is the same thing.
  - **Scope:** about 55 test files mention a sleep, a clock, a `Duration` or a timeout (`grep -E "Task\.sleep|ContinuousClock|Deadline|\.seconds\(|\.milliseconds\(|timeout|within:"` over every `Tests` folder). Many test the bounds themselves (`DeadlineTests`, `ServeWaitTests`, `PoolWaitTests`) and need a different treatment from those that only happen to sit behind one. Classify first; known losers so far are `PhotosSourceEditingTests` (five tests), the two walk-stall tests, and `SourceEndpointTests` above.
  - **Another, 2026-09-22:** `SilentLibraryTests`, *A stalled walk leaves the source unavailable, not emptied* and *A walk that stalls part way is bounded, and keeps what it received*, failed once in a full `Package Tests` run, the suite taking 10 seconds. The suite alone passed three times out of three in 5 seconds, and the next full run passed.

## Examine the cache size

**`cacheByteCeiling` is 1 GB and has never been measured.** `PLAN.md` says so itself: "the default
byte ceiling is explicitly a starting point to be replaced by measurement." The sweep that was going
to do that (5 / 10 / 25 / 50 / 100 GB) was **cancelled** on 2026-09-06, and nothing replaced it.

**What the cache is for, so the next measurement asks the right question.** Syd, 2026-09-19: "the
cache is basically there so that when a card is asked for, it will have been rendered because our
deck is essentially a 20 image lookahead. For small libraries, having the renders/cards reused is a
happy benefit. We will never have everything cached for a large enough library, and that's ok."

So the criterion is **does the lookahead always have its bytes ready**, not a hit rate. Reuse is a
bonus at the small end and is expected to be zero at the large end. A low hit rate on a big library
is the design working, not a fault.

- **Measured 2026-09-19, three hours:** 1,295 pictures served, 1,294 fresh renders — so reuse on
  this 9,185-photograph library is essentially nil, exactly as the above predicts. The cache sat at
  997.8 MB of its 1,000 MB, 276 originals, turning over about 50 MB an hour across 41 evictions.
  *Recorded so nobody later reads that ratio as a defect and optimises for a hit rate that was never
  the point.*
- **Against the real criterion the cache is passing, and it was checked rather than assumed.** Over
  the same three hours every serve said *is here* — 1,285 of them, with no miss on the serve path.
  (Two said *unconfirmed*, which is the source not answering whether the photograph still exists, not
  a cache miss.) 20 queued cards at roughly 3.6 MB apiece is about 72 MB of lookahead inside a
  1,000 MB ceiling, so eviction is working a long way from the cards that matter.
- **The likely answer is that 1 GB is too big, not too small.** Syd, 2026-09-19: "with this framing,
  1 GB is certainly too big." The lookahead needs about 72 MB and the cache is holding 276 originals
  to serve 20 — an order of magnitude of disk spent on photographs the deck is not about to deal.
  **This inverts the cancelled sweep**, which explored 5 / 10 / 25 / 50 / 100 GB on the assumption
  that bigger bought a better hit rate; under the staging-area framing the interesting range is
  *below* where it starts.
- **Deferred to its own plan.** Syd, 2026-09-19: "further discussions can be deferred until we fix
  this in a separate plan." Nothing here is designed, and the tension to settle there is the small
  library against the large one — the same ceiling has to leave reuse intact where reuse happens and
  not hoard where it cannot.
- **It needs no new code to measure.** `RENDER:` against `served status=200` gives the reuse rate,
  the eviction lines give the churn, and the `SERVE:` lines say whether a dealt card ever arrived
  without its bytes.

## A disallow-list for images that will not decode

Syd, 2026-09-16: "The client needs to log when the decode fails. Later, we might keep track of which
images in the client fail, and when a certain number of failures in a row happen, we have an
endpoint to tell put the image on a disallow-list."

Moved here 2026-09-19 when `Plans/Agent Performance Overhaul.md` was closed — it was the one piece of
that plan deliberately left as later work, and closing the plan would have buried it.

- **What exists already.** A client that cannot decode what it was given discards it and asks for
  another card — decided 2026-09-16, "the client discards it… The agent has already moved on at that
  point" — and logs a line naming the card, the deal, the photograph, its source, the byte count and
  the content type. The line was written so this work could start from it: it already names
  everything a client would need to report.
- **What it costs today, known and accepted:** a bad file stays in the deck, and every time it is
  dealt it spends one request and one failed decode on the client.
- **Undecided, and all of it:** the count, the threshold, the endpoint, and whether the list is the
  agent's existing `render_failures` retirement or something beside it. *Claude's note: the two are
  not obviously the same thing — `render_failures` retires a photograph the **agent** could not
  resize, and this would retire one **clients** cannot decode. A file the agent resizes happily may
  still arrive unusable, and a file the agent cannot resize is sent as an original the client may
  decode fine.*
- **The agent's retirement stays either way.** Syd, 2026-09-16: "yes, keep the retirement."

## Shared schemes for `pgr_ctl` and `pgr_install`

Syd, 2026-09-16: "add a target for pgr_ctl to the Xcode project".

- **The target is already there:** `pgr_ctl` in `Photo-Go-Round.xcodeproj`, which `Build Plan.md`, *The targets*, records, and which gained its `PhotoGoRoundDisplay` dependency on 2026-09-16.
- **Decided 2026-09-19: no install.** Syd: `pgr_ctl` is a copy or a symlink into `~/bin`, and Archive is the route for anything shipped. `Build Plan.md`, *The install phases*.
- **What is left is one shared scheme each, for `pgr_ctl` and `pgr_install`.** Neither has one, so Xcode autocreates them per user and nobody else gets the settings — which is how the agent's scheme came to launch with `-NSDocumentRevisionsDebugMode` and refuse to start. Every other target has one now, including the three `Install …` schemes.
- `Package Tests` is the exception to where they live: `.swiftpm/xcode/xcshareddata/xcschemes/`, because a scheme whose targets are the package's is a package scheme. `pgr_ctl` and `pgr_install` are Xcode targets, so theirs go in `Photo-Go-Round.xcodeproj/xcshareddata/xcschemes/` with the rest.
- Set `debugDocumentVersioning = "NO"` in both, as every other scheme now does.

## A section of our own for the screensaver in System Settings

Syd, 2026-09-16: "Is there a way to have a custom section for our screensaver?" — asked while the wallpaper's development builds were being put in one *Photo-Go-Round* section in the Wallpaper pane.

- **Not looked into.** What is known, from the wallpaper work: the `.saver` is listed by System Settings itself, and `WallpaperAgent` hosts it as `ScreenSaverWallpaper` with provider `com.sydpolk.photogoround.saver`. The wallpaper extension's section *did* appear in the Screen Saver list on 2026-09-15, so an extension on `com.apple.wallpaper` can put a section there — `Wallpaper Plan.md`, *The real extension, inside the app*, the Screen Saver list notes.
- *Claude's reading, not measured:* a custom section probably means the screensaver answering the pane as an extension, as the wallpaper does, rather than as a `.saver` bundle.

## The tag line: "Your Photos, shuffled"

Syd, 2026-09-16: "change the tag lines for both wallpaper and screensaver to "Your photos, shuffled"." **Capitalized 2026-09-27:** "Your Photos, shuffled".

- **The wallpaper's** is the pane item's `localizedDescription` in `MacOS/Wallpaper/Sources/PaneModels.swift`, now "Photographs from your library, shuffled".
- **The screensaver has none in its sources.** A search for the wallpaper's wording and for "your library" and "your photo" under `MacOS/` finds no description for the `.saver`; where System Settings would show one for it is not known.

## Statistics about resized copies, where they belong

Syd, 2026-09-16: "put statistics about the cached resized picture where appropriate".

- **Today nothing counts them apart.** `PhotoCache.status()` folds copies into `bytesOnDisk` with the originals, so `pgr_ctl cache status` and the dashboard show one total. No count of copies, no bytes for copies alone, no hits or misses on the copy lookup, and eviction's tally does not say how many of what it took were copies (`LaunchTally.Evictions`). *Already there:* a request's `TIMING:` line names its stage `resized copy`, `render` or `resize gave up`, so one request says which it was; nothing adds them up.
- *Claude's candidates, not decided — where each would go is Syd's:*
  - **`pgr_ctl cache status`**: copies held and their bytes, beside originals.
  - **The dashboard's cache panel** and `/v1/dashboard`: the same, and copy hits against resizes since launch — the number that says whether the resize cache is saving the resizer anything.
  - **Evictions**: copies and originals taken, separately.
- Anything added to the dashboard or `pgr_ctl` is documented in `Documentation/photogoroundd.md` or `pgr_ctl.md`, and tested.

## Cached files broken down by source, in the dashboard

Syd, 2026-09-19: *"add a panel in the dashboard breaking down how many files have been cached broken down by source"*. Nothing is designed.

- **Today it is one number.** *Photos in the cache* and *Cache on disk* both come from `PhotoCache.status()`, which counts resident entries and bytes across the whole cache; `pgr_ctl cache status` shows the same totals. Nothing is per source.
- **The cache already knows the source.** A cache path is the source, then `.original`, then the photograph's own identity, and every `CACHE:` line names `(source N)` — so the breakdown is there on disk and in the log, and nothing adds it up.
- **Open, and Syd's:** files, bytes, or both; sources named by title (*Photos › Favorites*) or by id; and whether referenced photos are in it, since they are not copied and not budgeted.
- **Related:** *Statistics about resized copies, where they belong*, which wants the same panel to split originals from copies. If both land it is one table — a row per source, a column per thing counted — rather than two panels.
- Anything added to the dashboard or `pgr_ctl` is documented in `Documentation/photogoroundd.md` or `pgr_ctl.md`, and tested.

## A finished DMG

`Plans/Release App Installer.md` built the app as the installer on 2026-09-21; the DMG that carries it is what is left. Syd, 2026-09-23: it should carry a double-clickable uninstaller and an "About …" document, with the icons arranged in a pleasing way, which he recalls took AppleScript last time. **Built 2026-09-27**, `Plans/Release DMG.md`: the `Release DMG` target makes `Photos-Go-Round 0.1 (1).dmg`, notarized, with the uninstaller and the About document. What is left is Phase 4: install from it and uninstall with it, here and on Plex.

## Release the way every app now releases

Syd, 2026-09-28: "This is the way all of my app releases should work." The flow is the global `app-release` skill, and `MarkdownPreviewApp` is its reference implementation. This project predates it and differs in one way:

- **`bump-version.sh` branches and merges, and pushes nothing.** It should refuse to start unless on a clean main (untracked files count), then commit `Config/Version.xcconfig` straight to main, tag it `v<x.y>-<build>` as it does now, and push main and its tags to origin with `--follow-tags`.

Nothing else changes: the Finder layout, the uninstaller, the About document and the `pgr-notary` profile all stay.

## A shared repo for the build and release scripts

Syd, 2026-09-28: "we might need to make a separate repo for build/release scripts." `Scripts/release-build.sh` and `Scripts/bump-version.sh` exist here and, adapted, in `MarkdownPreviewApp`, and every new app gets another copy (the global `app-release` skill), so each fix has to be made once per app. Undecided: how an app consumes them — a submodule, a checkout at a known path, or copies synced from one source — and what stays per app: the name, project and scheme, the version-config path, the releases folder, and the post-export checks (here the helpers, the extensions, the Photos entitlement, and the Finder layout of the DMG). The same item is in `MarkdownPreviewApp`'s `TODO.md`; do it once for both, and after *Release the way every app now releases* above, so there is one flow to share.

## A menu-bar app for shipping

Syd, 2026-09-10: *"make a menubar app for final shipping of this. The full desktop app is useful, but we are probably not going to ship it."* **Needs its own plan document.**

- **The window stays**, as the development instrument it already is — `PLAN.md`, *The Mac app as instrument panel*. It just probably is not what ships.
- **Everything that currently hangs off the app needs a home in it**: the Settings panel for sources, the Help menu's Install and Uninstall items, the wallpaper's pause control, and the About box.
- **The empty state's wording points at "the Photo-Go-Round application"**, which would then mean the menu-bar item.
- **It may be the wallpaper's host, or sit beside a separate wallpaper binary.** `Wallpaper Plan.md` Phase 2 expects the wallpaper to be its own binary, installed per user in `~/Library/LaunchAgents`; a menu-bar app is the other common shape for a rotator. Which one runs the wallpaper is decided there.
- How it starts at login — a login item, or a per-user LaunchAgent like the agent — is open.
- `MacOS/Desktop/FEATURES.md` already sketches *A menu bar app* — a status item, and an item that brings the window up — and is where this starts.

## Metrics in the database

Serve counts and timings belong in the database, not only in the unified log. **Needs its own plan when it is picked up.**

- **The 2026-09-08 overnight run is the argument.** The screensaver's own per-photograph line is `.info`, which is memory-only, so it had evaporated by morning; the run could only be counted because the *agent's* serve line happens to be `.notice`. `Log.swift` says this outright — "state transitions worth reconstructing after the fact must be `.notice` or higher" — and the count that mattered was on the wrong side of it. The saver's line is still `.info` today.
- Raising that line to `.notice` is the cheap alternative and a poor one: ~3,400 lines a night of something entirely routine, burying the lines that are not.
- **There are hooks already.** The `consumer` table carries a `seenAt` heartbeat, and `pgr_ctl` already runs the deck's statistical checks — so there is a place to write and a rig to read with.
- Worth recording: serves per consumer per interval, latency, cache hit or miss, non-200s, and what the queue depth was at the time.
- **The cost is a migration and a write on the serve path**, which is the hot path — 3,034 serves in nine hours from one surface, and every surface shares it.

## Settings endpoints, and preferences as a black box

The agent should answer for its own configuration over HTTP, and its preference domain should stop being something clients read or write. Syd, 2026-09-09: *"We need to add settings endpoints anyway; the agent's preferences should be a black box."* **Needs its own plan.**

- The shape is already set by `PLAN.md`'s *The database is private to the service* — this is the same argument applied to the other durable store. `GET` and `PATCH` alongside `/v1/sources`, and no client touching the domain.
- **One thing has to be designed rather than assumed: how a client finds the agent.** `ServicePort` reads `servicePort` out of the domain, and from inside the screensaver's sandbox reads the `.plist` as a file, precisely because a client cannot ask the agent where the agent is. Sealing the box without answering that breaks every surface at once. Either the port stays a deliberate hole in it, or discovery moves to some other mechanism.
- **It reverses a stated position and that should be recorded in `PLAN.md` when it happens.** *Preferences* there treats `defaults write` as a first-class interface — "two rules follow from `defaults write` being a first-class interface" — and that is what a black box takes away.
- `pgr_ctl` keeps its direct access, as the rig rather than a client. Same exception it already holds for the database.
- The screensaver's Options sheet is the first thing that needs this, and the reason it is parked above.

## `Photo-Go-RoundTests` is not in the default test run

Carried out of `Plans/Xcode - Separate Build and Run.md` when it closed, 2026-09-19.

`xcodebuild test -scheme "Package Tests"` runs the package's five test targets — 1,001 tests — and not the app's bundle. `Photo-Go-RoundTests` was in the test plan when Xcode created it and was taken out: it is the app's own suite, it wants a running agent, and a plain run of it fills the log with `panel: read failed — Photo-Go-Round's agent is not running`.

- **It is still runnable**, through the `Photo-Go-Round` scheme, which has it as a testable. Nothing is lost except that nobody runs it by habit.
- **What to decide** is whether it belongs in the same plan behind a filter, in a second plan of its own, or nowhere — Syd skips GUI tests, and this is the suite closest to being one. `TODO.md`, *No GUI testing* is the standing position.
- `Package Tests.xctestplan` is the file, and a test plan can hold more than one configuration if that turns out to be the shape.

## The screensaver says "Starting…" for a few minutes after a restart

*"Waiting for Photos" when this was written; the words changed 2026-09-26, the delay did not.*

Seen 2026-09-23 on Syd's MacBook Pro, load 78–100 after boot. The lock-screen screensaver started at 19:28:26, 21 s before the agent was listening (`nothing is listening on 20172`); then two serves took 4.4 s and 4.1 s inside the agent, past the saver's 5 s bound (`not answering … within 5 seconds`), so each picture was served after the saver stopped listening and its card was spent. By 19:32 serving took 1.1 s and photos showed. Probably also what plex showed after its restart, though plex's saver logged nothing at all.

## Audit every test for the product rename

Syd, 2026-09-23: "audit ALL of the tests for the product rename." Photo-Go-Round became Photos-Go-Round on 2026-09-22.

## A private support page at `/private`

Syd, 2026-09-19: *"there should be a not-user-documented URL to have an HTML page with all of the command available there"*, and *"this is part of supporting existing users"*. Indeed's "Poodlepants" is what he is describing. `Plans/Private REST API.md` went further than he asked for and is his to keep or delete.

Settled in conversation the same day, before he stopped the design:

- **`pgr_ctl` is not reimplemented over the API and stays standalone.** He retracted his own *"all of the commands that pgr_ctl supports should be reflected in the agent's REST API"* once it was clear that direct access is what makes it work with the agent down — which is when it is wanted. Same exception it already holds in *Settings endpoints* above.
- **Eleven of fifteen command families**: `status`, `sources`, `refresh`, `pool stats`, `queue peek|fill`, `deck stats`, `cache status|evict|clear`, `get|set`, `wallpaper get|set`, `notify`. Dropped: *"ditch shuffle-test, log, register. Keep the cache clear."*
- **A typed URL runs the command**, and `/private` is *"just a button to press which would navigate to the typedURL"*. No forms and no confirmation page.
- **Two namespaces.** `/v2/…` stays RESTful for the app; `/private/…` is the GET-invocable support surface and *"does not have to be completely API-formal"*. `/v2` grows when a client needs it, not for symmetry.
- **Open, and accepted:** a mutating GET can be fired by any page in any browser on the Mac with `<img src="…">`, and no `Origin` check helps. Bounded by what the commands can do.
- **Open, undecided:** `pgr_ctl cache clear` prompts with how much would be cleared, and a GET that just does it has nowhere to put that.

## Settings inside the wallpaper extension and the screensaver bundle

Syd, 2026-09-16: *"explore putting settings directly into both the wallpaper extension and the screensaver bundle."* Today settings change only in the app or through `pgr_ctl`. Nothing is designed.

**This is the next thing after the wallpaper, and it lives here rather than in a plan.** Syd, 2026-09-19: "the next phase is putting the options directly in the system settings panel", and that it "belongs in *Settings inside the wallpaper extension and the screensaver bundle*" — because the same work covers the screensaver's configure sheet too, so neither surface's plan owns it. `Wallpaper Plan.md` Phase 2 is met and that plan does not carry a phase for this.

- **The wallpaper half is what goes first**, and Syd named it twice. 2026-09-15: "The next stage would be to put a sources panel and timing slider directly into the extension." `Wallpaper Plan.md`, *The real extension, inside the app*.
- **The saver half is an Options button in the Screen Saver pane.** Some savers show one. `ScreenSaverView` provides it through `hasConfigureSheet` and `configureSheet`, both of which `PGRScreenSaverView` currently answers `false` and `nil`.
  - **Whether the sheet is presented at all is untested.** `hasConfigureSheet` is queried — it appears in the call sequence on `FB9835060` — so the button probably shows. Whether the sheet displays is unknown, and the preview instance being 0x0 is a reason to check rather than assume.
  - **What would go in it** is open: dwell, fit, an upscale cap. All are `PLAN.md`'s *Beyond 0.1* today, and *Everything user-settable is a user default* is held back with them.
  - **Parked until there is a real setting**, which means until *Settings endpoints* above exists. A sheet with nothing configurable in it is a button that disappoints.
  - When it is built, it can hold what needs no persistence even before then: agent status, the port and whether it was found through the suite or the file, the version, and a pointer to the app's Settings panel — which the empty state carried underneath its words until 2026-09-26, when Syd asked for "No secondary lines of text."
- **The two routes into System Settings are unlike each other.** The saver's is public: `hasConfigureSheet` and `configureSheet`, a sheet of our own. The wallpaper's is the private one the extension already uses: the pane draws whatever the extension answers to `WallpaperAgent`'s `provideSettingsViewModels`, and the extension can call back with `updateSettingsViewModels`, read from Phosphene and not yet called by us. Whether those view models can carry a slider or a list, rather than a section and its items, is unknown and the first thing to find out.
- **The extension should have read-write to its own preferences.** Syd, 2026-09-16. Its own domain is `com.sydpolk.photogoround.wallpaper.{dev|prod}`, where the *Shuffle All* choice lives. Today it reads that domain through `temporary-exception.shared-preference.read-only`, and `Rotation.swift` says a slider "replaces the reading, not the writing". That line goes when this is done.
- **The screensaver should have read-write to its preferences.** Syd, 2026-09-16. **The obstacle is that the saver has no entitlements of its own.** It runs inside `legacyScreenSaver`, under the host's sandbox, and the host names no exception for our domains; that is why the suite reads empty and the port is read from the `.plist` as a file. `Screensaver Plan.md`, *The question the entitlements do not answer*.
  - **Decided, 2026-09-16: over HTTP to the agent.** Syd: "the saver can use http to the agent to read and write prefs." So the saver's half waits on *Settings endpoints* above.
  - Open: where the agent keeps the saver's preferences — its own domain, or a saver domain of their own the way the wallpaper has one.
  - Not taken: `ScreenSaverDefaults`, which is writable but lands in the host's container where the app and `pgr_ctl` would not see it; and an App Group suite, which needs the saver embedded in the app's bundle.
- **Sources are the agent's either way.** They are in the database, not a preference domain, so a sources panel in either surface goes through `/v1/sources`.
- **One design, or two.** Whether both surfaces share one settings model, or each keeps its own, is open. The saver's dwell and the wallpaper's *Shuffle All* interval are different settings today.
- **What becomes of the app's Settings window** once a surface configures itself: whether it keeps the same controls. The app and the extension would both write the wallpaper domain, so the last write wins, and each has to notice the other's change.

## What System Settings › Wallpaper needs from us

Syd, 2026-09-10: *"Add a TODO.md item to see what we need to do in System Settings -> Wallpapers."* Nothing is known yet; these are questions to answer by looking, on macOS 27, since the pane was rewritten in Sonoma.

- **What the pane shows once we have set a file** — our picture as a custom photo, the file's name, something else — and whether anything it offers would quietly undo us.
- **Its own rotation.** If the pane is set to change the picture on a schedule, `WallpaperAgent` rotates on its own and the two would fight. Whether setting a URL turns that off, or the user has to.
- **The fill colour.** The wallpaper uses the colour chosen here: where it lives in the pane on 27, and whether it is per display or per Space. See `Wallpaper Plan.md`, *The fit*.
- **Showing on all Spaces.** Whether the pane has such an option on 27, and whether it reaches a file set through `setDesktopImageURL`. If so it could do more for the per-Space hole than re-applying on every Space change.
- **Dynamic and Aerial wallpapers.** What happens when one is selected and we set a still over it, and whether it comes back on its own — a candidate for the reversions `PLAN.md`'s *Wallpaper is asserted continuously* describes.
- Whatever this turns up goes into `Wallpaper Plan.md` before its Phase 1 is built, since several of these could change what Phase 1 does.

## Build for arm64 only

Syd, 2026-09-15: "don't build arch:x86_64 at all". And the scope of it, the same day: "there is a difference between dev and shipping the product. At this point, macOS 27 supports intel, and if I ever ship this to the public, I will build for it. But for dev purposes, I don't want to waste the time or disk space." **So this is about development builds. Whether a shipping build is universal is Syd's, and undecided.**

**Still open:** whether anything else produces x86_64 — Xcode's own builds go through `ONLY_ACTIVE_ARCH` and were not checked after `Scripts/make-saver-bundle.sh` began passing `-destination "platform=macOS,arch=arm64"` on 2026-09-15, and the local package targets were not checked at all.

- **What builds x86_64 today — measured 2026-09-15 with `lipo -archs` on products under `~/.claude/build/photo-go-round`, before `Scripts/make-saver-bundle.sh` began passing that destination:**
  - Several Debug builds of `Photo-Go-Round.saver` and `Photo-Go-Round.app` from `xcodebuild` are `x86_64 arm64`, although the project sets `ONLY_ACTIVE_ARCH = YES`.
  - Some other Debug builds of the same targets are `arm64` alone, so it depends on how `xcodebuild` was invoked. Which invocation gave which is not recorded.
  - `Scripts/make-wallpaper-extension-probe.sh` built `arm64` alone: its `swiftc` target came from `uname -m`. *Retired 2026-09-15.*
  - `swift build` builds the host's architecture.
  - On Plex the same day, `Scripts/make-saver-bundle.sh` printed `xcodebuild: WARNING: Using the first of multiple matching destinations:`, listing `My Mac` twice, once `arch:arm64` and once `arch:x86_64`. Its `-destination "platform=macOS"` matches both.
- **What is left, if anything still builds x86_64:**
  - `ARCHS = arm64` in the project's build settings — not set, since it would follow a release build too;
  - the wallpaper probe script's `$(uname -m)`, which would build x86_64 on an Intel Mac, and is the right answer for a dev build there.
- **Check the local packages too.** The C++ hardening setting in the project did not reach the local package targets (`PLAN.md`, *Builds with no warnings*), so an architecture setting may not either. Verify with `lipo -archs` on every product after a clean build, not by reading settings.

## The screensaver preview is black when first selected

Syd, 2026-09-22: the preview in System Settings is black when the screensaver is first selected.

## Why the screensaver preview takes so long to show a picture

Syd, 2026-09-22: investigate why the screen saver preview takes so long to show a picture.

- *Claude's note:* this may be the same thing as the item above, seen from the other end — black at first, then a picture once it arrives. Worth checking first.

## Tests for the wallpaper extension's and screensaver's own code

Syd, 2026-09-22: yes, add it. Nothing tests the code in `MacOS/Wallpaper/Sources` or `MacOS/Screensaver/Sources` — `Rotation`, `LastPicture`, `AgentPicture`, the pane models, `DisplayShuffles`, the saver view. What is tested is around them: `PhotoGoRoundDisplay`, the wallpaper's entitlements, the installs, and `pgr_ctl`'s wallpaper commands.

- *Claude's note:* that code is compiled only into the extension and saver targets, so the package tests cannot reach it. Either the logic moves into a library the package tests link, or the two get Xcode test targets of their own. Not GUI tests.

## Removing a wallpaper build leaves its Launch Services record

Syd, 2026-09-22: add it. A deleted build of the wallpaper extension stays listed in System Settings › Wallpaper, because Launch Services keeps a record of it after its files are gone. Found that day: "Photo-Go-Round Wallpaper (Claude)" was listed with no `pkd` registration and no process, from an archive build under `~/.claude/build` that no longer existed; about 40 more such records turned up, one of them from Syd's DerivedData. `lsregister -u` on each missing path cleared them, and the pane entry went.

- **`CLAUDE.md`'s cleanup after building `Photo-Go-Round Wallpaper Host`** runs `pluginkit -r` and deletes the host app. It needs `lsregister -u` on the host app before deleting it.
- **`Scripts/uninstall.sh --wallpaper`**, through `pgr_install uninstall`, unregisters from `pkd` and stops the extension, but leaves Launch Services records behind.

## The package test command needs a workspace git does not track

Syd, 2026-09-22: add it. Since the reorganization put `Photo-Go-Round.xcodeproj` beside `Package.swift`, `xcodebuild test -scheme "Package Tests"` picks the project, and through the project the scheme finds no test bundles — "There are no test bundles available to test", with or without `-project`. Pointing the test plan's targets at `container:.` did not help. What works is `-workspace .swiftpm/xcode/package.xcworkspace`, now the command in `CLAUDE.md`.

- **That workspace is generated and ignored.** `.gitignore` excludes both `.swiftpm/xcode/package.xcworkspace/` and `*.xcworkspacedata`, so a fresh clone does not have it. *Claude's reading, not tested:* Xcode writes it when it opens the package, so the documented command would fail on a fresh clone until that has happened once.

## The app icon on smaller devices

Syd, 2026-09-24: re-examine the icon for smaller devices later. At 32 points the house picture is discernible; at 16 it is hopeless, and a `.icon` file has no per-size artwork. `Plans/App Icon.md`.

## Remove the option to disable a source

Syd, 2026-09-26: "get rid of the disable sources option completely". Today a source is disabled by `pgr_ctl sources disable`, or the `enabled` key in a source list written with `defaults write`; the Settings window has no control for it. Open when picked up: whether `source.enabled` and `photo.source_enabled` go too, since the deck's indexes lead with the second, and a migration to re-enable any source disabled at the time.

## The wallpaper's separate picture pipeline

Syd, 2026-09-26: "This honestly is a surprise to me." The wallpaper extension asks the agent through its own `AgentPicture`, times itself with its own `Rotation`, and keeps its own `LastPicture`, where the window and the screensaver share `PictureClient`, `Shuffle` and `PictureMemory` — so every empty-state behaviour on the `no-photos` branch was built twice, and the second copy is untested. `Wallpaper Plan.md`, *The real extension, inside the app*, said the extension would link the display library "rather than carrying the probe's private copies of `ServicePort` and the picture request".

## A "Check for Updates…" menu item

Syd, 2026-09-26: add a "Check for Updates…" menu item. It depends on the whole infrastructure for shipping an app being in place first, so it waits for that.

## More investigation of the screensaver icon

Syd, 2026-09-27: "add to TODO to do some more investigation of the Screen Saver icon." `Screensaver Plan.md`, *The tile in the Screen Saver pane*, is what exists.

## The commit hash on the dashboard

Syd, 2026-09-27: "add a TODO.md to add the commit hash to the agent dashboard." The app already records it — `PGRGitCommit` in its `Info.plist`, from the *Record Git Commit* phase — and shows it in the About box with Option held; the service's own bundle does not carry it yet. `Plans/Release DMG.md`.

## The main app asks Photos for the correct size

Syd, 2026-10-08: "main app ask photos for the correct size". `PHImageManager.requestImage` takes a target size; the agent fetches the original and shrinks it itself today. `Plans/Photos-Go-Round Widgets.md`, *Photos: asking for a picture at a size*.

## The uninstaller inside the app wrapper

Syd, 2026-10-09: "Figure out a way to package the uninstaller inside the app wrapper itself." A copy is in `Contents/Helpers` today, and the one people are sent to is on the disk image.

## The dashboard says widgets are not counted in it

Syd, 2026-10-09: "Add a line in the agent dashboard somewhere that loads by widgets are not tracked in this dashboard". The widgets read Photos and folders themselves and never ask the agent, so nothing they load shows in its numbers.

## The wallpaper's first registration failed once

2026-10-09, 0.7 (5): on the first launch after an install the app asked for the wallpaper extension to be registered and gave up thirty seconds later, "did not register … in time". `pkd` logged "Failed to find plugin with UUID" at that moment, and nowhere else that day. A relaunch registered it, and an uninstall and fresh install after that registered it on the first launch. Not understood. It came an hour after extension records had been removed by hand and NotificationCenter restarted, which may or may not matter. The app tries once per launch; if this comes back, it should try again before giving up.

## The name is "PhotosGoRound" everywhere

Syd, 2026-10-10: "Name of the application needs to be changed to "PhotosGoRound" everywhere since the hyphenated name does not fit on the iOS springboard, and I want consistency."
