# Summary

Launching `Photos-Go-Round.app` stops restarting and reinstalling services that
are already there and running. A launch compares version numbers: an installed
agent, wallpaper extension or screensaver whose version is equal or greater is
left alone, and one that is lesser, missing, unreadable or not running is
installed again.

# Rationale

Every launch restarts the agent, in every configuration, whether or not anything
changed. On 2026-09-24 opening the app at 17:08 restarted a healthy agent and
the Photos albums went unavailable; a cold album walk takes 40–60 seconds, so
each needless restart costs that. Syd, 2026-10-05: "Don't reinstall or relaunch
any of the services if they are already running when running the app." Opening
the app to change a setting should not disturb a desktop that is working.

# Phases

What is left is on Syd's Mac, since launching the app is his.

- **Phase 1 — Launch it.**
  - The first launch installs once, since nothing has a version recorded yet.
  - The second leaves the agent's pid and the wallpaper's unchanged.
  - A build with a higher build number, put in place and launched, installs
    all three once.
  - The `install` log category has a line per product each time.
- **Phase 2 — Measure the wallpaper's process.** Whether a chosen wallpaper
  always has an extension process: across a locked screen, a sleeping display
  and a fast user switch. If it does not, the "chosen but not running" check
  registers on every launch, and has to go or change.

# Design Decisions

- **Always version numbers.** Syd, 2026-10-08: "you should always use version
  numbers. if the running thingie has an equal or greater version, leave it
  alone. If it is lesser, or missing/unreadable, reinstall."
- **The screensaver too.** Syd, 2026-10-08: "this goes for the screensaver as
  well".
- **Another copy of the app is judged the same way.** Equal or greater is left
  alone, whichever copy installed it; Syd, 2026-10-08, of an equal one: "leave
  them alone".
- **Not running is acted on.** Syd's rule, 2026-10-05, is for services that
  "are already running".
- **The version is recorded at install, not read from the bundle later.** An
  app replaced at the same path has the new version on disk under an agent
  still running the old code, so the bundle would always read as equal.
  *Claude's choice.*
- **A rebuild that keeps its version and build is left alone.** It follows from
  the rule. After a ⌘R that changes the agent, the running agent is the old
  one until the build number moves or the Help menu installs it.
- **A chosen wallpaper with no extension process counts as not running.** A
  rebuild makes `pkd` drop the running extension and the desktop goes grey;
  this replaces the date test that caught it. Syd, 2026-10-08: "chose but not
  running check". *Unmeasured.*
- **A stopped agent is started with the restart that exists.** `kickstart -k`
  starts a job that has no process.
- **The Help menu and `pgr_install` still always install**, and record the
  version as they do.
- **Each product is judged by itself.**
- **Tests first.** Every judgement is a pure function over injected facts, as
  `StandingTests` and `LaunchInstallTests` already are.

# Background

`Plans/Release App Installer.md`, closed 2026-09-22, built the launch install.
It decided "differs" by content and path, never by version, and restarted the
agent on every launch: Syd, 2026-09-21, "yes, restart the agent on every app
launch". This plan reverses both. The wallpaper and the screensaver already
leave a current install alone at launch; what changes for them is how current
is decided.

# Detailed discussions

## What a launch did before

`LaunchInstall.run`, in order, until 2026-10-08:

1. **The agent.** Installed when its plist was not the one this bundle would
   write or launchd had not loaded it. Otherwise restarted with `launchctl
   kickstart -k`, every time, in every configuration.
2. **Wait for it to answer**, up to ninety seconds.
3. **The wallpaper.** Registered again when the running extension ran from
   another appex or started before this appex last changed, when its
   registration was older than the appex, or when it was unregistered but
   still chosen. A Release build also registered it when it was missing or
   registered from another copy.
4. **The screensaver, Release only.** Linked when nothing was at its name;
   anything already there was left.

## What a launch does

"Installed version" below is the recorded one for the agent and the wallpaper,
and the version of the saver at its name for the screensaver.

**Agent**, every configuration

| Installed agent | Launch does |
|---|---|
| No plist | Install |
| A plist with no version in it | Install |
| Installed version lesser | Install |
| Its program is no longer on disk | Install |
| Not loaded | Install |
| Equal or greater, loaded, no process | Start |
| Equal or greater, running | Nothing |

**Wallpaper**

| Installed extension | Launch does |
|---|---|
| Not registered, Release | Register, as now |
| Not registered, still the chosen wallpaper, any build | Register, as now |
| Registered from a bundle that is gone | Remove it and register, as now |
| Registered, no version recorded | Register |
| Registered, installed version lesser | Register |
| Registered, chosen, no extension process | Register |
| Registered, equal or greater, running or not chosen | Nothing |

**Screensaver**, Release only

| At the saver's name | Launch does |
|---|---|
| Nothing | Link, as now |
| A link whose target is gone | Link |
| A saver with no readable version | Link |
| A saver whose version is lesser | Link |
| A saver whose version is equal or greater | Nothing |

A real bundle at the saver's name, rather than a link, is judged like a link:
by the version in it. A lesser one is removed and replaced by the link, which
is what `applyLink` already does with whatever it finds.

## Why the version is recorded at install

The obvious reading of "installed version" is the `Info.plist` of the bundle
the install points at: the Server app the job runs, the appex `pkd` has, the
saver the link names. It fails for the ordinary update. Dragging a new app over
the old one in `/Applications` leaves the job's plist and the registration
exactly right, pointing at a bundle that now holds the new version. Read from
there, the installed version always equals the carried one, nothing is
installed, and the agent goes on running the old code until the next login.
The wallpaper is worse off: `pkd` drops a running extension whose bundle
changes and `WallpaperAgent` does not start it again, so the desktop goes grey.

So the version has to be written down when the install happens.

- **The agent's goes in its job description**, which the install writes and
  the uninstall removes, so the record cannot outlive what it describes.
  `EnvironmentVariables` is the place: launchd defines the key, so nothing
  unknown is added to the plist, and the agent could log it. Every route that
  installs goes through `JobDescription`, so every route records.
- **The wallpaper's goes in this build's preferences.** `pkd`'s own record has
  no version to read: `pluginkit -m -D -v` printed `…wallpaper.extension((null))`
  for the Release registration on 2026-10-08. Each configuration has its own
  preference domain, so the three do not collide, and scrubbing the data
  removes it.
- **The screensaver needs none.** Nothing of it stays running between uses, so
  the saver at its name is the installed one, and a replaced app is picked up
  the next time the system loads it.

The alternative for the agent was to have the running agent report its own
version, on `/v1/alive`. That is the truth about the process rather than a
record of the install. It was passed over because it adds to the agent's API,
needs the agent to be answering before anything can be judged, and gives the
wallpaper nothing. The record can be wrong in one direction only: an agent
restarted by launchd after its binary was replaced runs newer code than its
plist says, and the next launch installs once more than it needed to.

## Comparing versions

- **Marketing version first**, split on dots and compared component by
  component as integers, so 0.10 is above 0.9. A missing component counts as
  zero.
- **Build number second**, as an integer.
- **The carried product's own `Info.plist`** gives what the app carries.
  `Config/Version.xcconfig` is the project's base configuration and all three
  products' plists name `$(MARKETING_VERSION)` and `$(CURRENT_PROJECT_VERSION)`.
- **A carried product with no readable version** is a broken build, and its
  standing throws, as a missing label does now.
- **An installed one with no readable version is installed again.** That is
  every install made before this, once.

## Greater

- **An older app opened beside a newer install** leaves all three alone. Its
  windows then talk to the newer agent.
- **An app replaced in place by an older one** also reads as greater and is
  left alone: the agent runs the newer code until the next login, when launchd
  starts the older binary under a plist that still records the newer version.
  The Help menu's Install puts it right. Not guarded against.

## Not running

- **Agent.** `Launchctl.pid(of:)` gives the job's process. `KeepAlive` restarts
  a job whose process dies, so loaded-with-no-process is a job being throttled
  after repeated exits. `kickstart -k` starts it and has nothing to kill.
- **Wallpaper.** The extension is not a job; `WallpaperAgent` starts it. The
  case that matters is the one measured on 2026-09-21: a rebuild, `pkd` drops
  the running extension, and the desktop stays grey. The date test that caught
  it — the registration older than the appex — goes with the rest of the
  dates. In its place: the store says this extension is the chosen wallpaper,
  and no process of it is running.
  - **Unmeasured:** that a chosen wallpaper always has a process. If the
    system suspends or drops it in ordinary use — a locked screen, a sleeping
    display — this would register on every launch, restarting
    `WallpaperAgent` each time. On 2026-10-08 the Release extension was
    running as pid 748, since login. Phase 2 measures it.
- **Screensaver.** Runs only when shown. Nothing to start.

## What is not changed

- **The Help menu's Install and Uninstall**, `pgr_install`, the `Install …`
  schemes and `Scripts/install.sh`: they install when asked.
- **Waiting for the agent to answer** before the wallpaper and screensaver. An
  agent left alone answers at once.
- **The order**: agent, wallpaper, screensaver.
- **Which builds install at launch**: the agent in every configuration, the
  other two in Release.
- **Dead registrations** are still removed, and another configuration's
  products are still not this one's business.
- **`CLAUDE.md`'s rule that an agent never launches a built app.** A launch
  still installs on a Mac that has none.

# References

- `Plans/Release App Installer.md`: *"Differs", product by product*, *Two
  copies of the app*, *What happens at launch, in order*.
- `MacOS/Shared/Sources/PhotosGoRoundInstall/`: `LaunchInstall.swift`,
  `AgentInstall.swift`, `WallpaperInstall.swift`, `SaverInstall.swift`,
  `Standing.swift`, `JobDescription.swift`, `CodeIdentity.swift`,
  `Launchctl.swift`.
- `MacOS/Shared/Tests/PhotosGoRoundInstallTests/`: `StandingTests.swift`,
  `LaunchInstallTests.swift`.
