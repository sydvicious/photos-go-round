# Summary

Photos-Go-Round Widgets.app: a self-contained App Store app for macOS, iOS, iPadOS and visionOS, with
watchOS widgets served by the iPhone app. It shows your photographs in widgets of every Home Screen
size the platform offers, and it must pass App Store review. Syd, 2026-09-26.

# Rationale

The App Store can take the widgets but not the screensaver or the wallpaper, so the widgets are the
Store product (`Plans/Product Strategy.md`). A Store app is sandboxed and can't count on our agent
running beside it, so it carries its own agent inside rather than asking one over HTTP. That makes one
design that works the same on the Mac and on devices that never had an agent.

# Phases

- *macOS, in the existing app* — the widget is carried by Photos-Go-Round.app and released in it.
  Syd, 2026-10-09: "there is no menubar app yet, so this is the vehicle."
  - Release it, as 0.5 (3). `Scripts/release-build.sh` checks the widget extension with the other
    bundles. The first attempt, on 2026-10-09, built 0.5 (2), and was lost: the script writes its
    DMG into Xcode's DerivedData and copies it nowhere, and DerivedData was cleared before the DMG
    was copied out. The releases folder already held a `Photos-Go-Round 0.5 (2).dmg` from
    2026-09-27, built before any widget work, and that is what was then installed. So the build
    number goes up first, and the new DMG is copied to the releases folder as soon as it exists.
  - At the next release, read that the installed app states the shared signing requirement.
  - The interval is hard-coded, at 5 minutes, until there are individual settings panels. Make it
    each widget's own setting.
  - Find out how a widget that has been placed keeps its name.
  - Find out why an occasional Photos fetch costs far more memory than its neighbours.
  - Later: find out which transitions between pictures a widget can really show, and offer them
    as a setting.
- *iOS and iPadOS* — the same widgets in an app on the iOS App Store. Before the Mac's menubar
  app: Syd, 2026-10-09, "I want to do the iOS app before the menubar app". Tested in a simulator,
  and on his own phone for iCloud Photo Library. The app itself is planned in
  `Plans/PGR Widgets - iOS.md`.
  - Investigate how widgets work on iPhone Duo.
  - Find out whether the widget can query Photos while the phone is locked.
  - Read the extension's memory on the phone, where the 30 MB ceiling is expected to be enforced.
  - Shrink a very large picture without the whole of it in memory. On the Mac one coin scan took
    the extension to 155 MB. Syd, 2026-10-09: "Let's worry about the peak when we do the iOS app."
    *Seen with 0.7 (5) installed*, below.
- *macOS menubar app* — Photos-Go-Round Widgets.app on the Mac App Store.
  - Take the widget out of Photos-Go-Round.app when the menubar app carries it.
  - Have the app write its sources into the App Group container: the Store does not accept the
    entitlement by which the widget reads the app's preferences today.
- *watchOS* — watch widgets, with the iPhone app as their agent.
- *CarPlay* — the iPhone's small widget, shown in the car.
  - Spike: how does a photograph look there, and how often may it change on the road?
- *StandBy* — the iPhone's small widget, shown while the phone charges on its side.
- *HomePod* — whatever Apple announces for it, once it can be built for.
- *visionOS* — the same app on the visionOS App Store. Last, and it probably won't happen.

# Design Decisions

- **Above everything else: it must be submittable to the App Stores.** Any decision below that would
  fail review gives way. No fights with App Review: if they object to a feature, we change it or drop
  it rather than argue.
- **Version 27.0 or later on every platform.** macOS, iOS, iPadOS, visionOS and watchOS 27, the
  same floor as the rest of the project.
- **Same source tree and Xcode project as the rest of Photos-Go-Round.** Not a separate repository
  or project.
- **`PLAN.md` only points here.** When this work changes code in the rest of the system, `PLAN.md` is
  updated then, not before.
- **The app contains the agent; there is no HTTP.** The widgets get their photographs through
  TinyCache in their own process, not from a separate agent process.
- **On the Mac it is a menubar app, and all of the settings are reached through it.**
  `Plans/Product Strategy.md` already calls it a menubar app. Syd, 2026-10-08.
- **On the Mac, the widgets go on the desktop and in Notification Center.** Nothing of ours goes in
  Control Center, which takes only buttons and toggles. Syd, 2026-10-08. See *Control Center and
  Notification Center on the Mac*.
- **On iOS and iPadOS it is a normal app.** There is no menubar there; the settings are reached
  through the app. Syd, 2026-10-08.
- **Its settings are its own.** It can't share settings with the rest of the product line.
- **The Photos library is the expected source; folders are the lesser case.** On an iPhone hardly
  anyone will use a folder, on an iPad slightly more will, and on every platform the Photos library
  is what people are expected to choose. Syd, 2026-10-08.
- **The whole Photos library is never chosen for anyone.** Only what a person chose is shown, and
  nothing falls back to everything. Syd, 2026-10-09: "we never choose the whole photo library.
  people have all kids of shit that's not appropriate". `Plans/PGR Widgets - iOS.md`.
- **The widgets share the app's sources.** Every widget shows pictures from the sources set in the
  app that carries it. Syd, 2026-10-08.
- **The only setting a widget has is how often it updates.** Each widget has its own interval and
  its own TinyCache, and nothing else of its own. Later it gains a second, the transition between
  pictures; and fill against fit is to be an option too, at some point.
- **All the widgets share one database.**
- **Widgets may show the same picture as each other.** Nothing is done to prevent it.
- **The Store app is `com.sydpolk.photosgoround.widgets` on every platform.** The iOS app has it
  first, and the Mac's menubar app takes the same identifier when it comes. Syd, 2026-10-09.
  `Plans/PGR Widgets - iOS.md`, *Identity*.
- **The menubar app and the widgets share through an App Group.** They are separate processes, so
  the settings and the database live in the group's shared container.
- **"Agent" names the concept, whichever process it runs in.** The term stays.
- **Each widget has a name: a common string with the last 4 characters of a UUID appended.**
- **The widgets ship inside the app's bundle.** A widget is an app extension and can't be installed
  by itself, so the menubar app is also what carries the widgets.
- **It has its own cache and queue, and the cache is called TinyCache.** It doesn't share them with
  the agent.
- **TinyCache is classes and objects, called directly.** A caller gets its answer returned to it;
  nothing reaches TinyCache over HTTP.
- **Each widget has its own TinyCache.**
- **Each wake shows one picture and keeps one more, and fetches nothing further.** The widget
  extension asks the source for a picture, shows it, and keeps one for next time, so there is one
  picture in the cache at a time. Syd, 2026-10-09, choosing this over a cap on fetches: go back to
  the original rule exactly. It replaces filling toward 20 while the extension stayed running,
  which made a wake's memory follow how much the wake did. See *A longer run*.
- **So every change of picture is a reload.** How often a widget changes is how often the system
  will reload it, whatever interval is asked for.
- **The interval is five minutes for now.** Syd, 2026-10-09: "set the value for widget refresh to
  five minutes until we have individual settings panels." At one reload for each change that is
  288 a day for each widget, against the 1,350 of the one-minute night.
- **Space for 30 pictures at the extra-large size, measured, is about 12 MB.** That figure was for
  a cache that filled to 20. With one picture waiting it is far more than is used; it is kept as
  the measured ceiling should filling come back.
- **A widget works with a cache of one, or with none.**
- **On iPhone, TinyCache's files are not protected.** They can be read while the phone is locked,
  which is how it is in the car and on the nightstand.
- **The extension asks Photos for a picture at the size it wants.** `PHImageManager.requestImage`
  takes a target size and can match it exactly. What that costs in the extension's memory is to be
  measured.
- **The menubar app has a second TinyCache of its own, for previews of the widgets.** A preview
  never takes a picture from the queue the widgets draw from. Syd, 2026-10-08.
- **Widgets in every Home Screen size the platform offers.** The Lock Screen's own sizes on iPhone
  and iPad, a circle, a rectangle and a line of text, are left out. Syd, 2026-10-09.
- **A widget waiting for its first photograph shows the app's icon, greyed over, and
  "Scanning…".** Syd, 2026-10-09. When something has gone wrong it says what instead.
- **One photograph fades into the next.** Syd, 2026-10-08: "I want the fade transition". Later, a
  person chooses the transition in the widget's settings, from whatever the system actually
  supports.
- **A photograph is fitted inside the widget, whole, with black around it.** As everywhere else in
  Photos-Go-Round. Eventually every fill and fit option is supported on every surface; fit is the
  one built now. Syd, 2026-10-08.
- **The intervals offered are 1, 5, 10 and 30 minutes, and 1, 2, 4, 8 and 24 hours.** Ten seconds
  isn't feasible: Apple's guidance is entries about 5 minutes apart. One minute is dropped if the
  system won't honour it. Syd, 2026-10-08.
- **The widget extension has one picture in memory at a time, two at most.** It runs under about
  30 MB of RAM, which is a limit on memory and not on storage. See *Spike: a 1-minute refresh, and
  the extension's memory*.
- **The watch uses the iPhone app as its agent.** The watch has no agent of its own; it gets its
  photographs from the iPhone app.
- **The Pro app's widgets: to be decided.** Whether they share this design or ask Pro's agent is
  open.
- **Our small widget is the CarPlay widget.** CarPlay has shown the iPhone's small widgets since
  iOS 26, so nothing extra is built. If App Review objects, CarPlay is dropped rather than argued
  for.

# Background

- `Plans/Product Strategy.md` (2026-09-22) names this product: *Photos-Go-Round Widgets* on macOS, and
  on iOS, iPadOS, visionOS and watchOS.
- What exists: the `TinyCache` package target with its tests, and the proof-of-concept widget
  extension, `Photos-Go-Round Widget`, embedded in `Photos-Go-Round.app`. It has not been run.
- `ConsumerKind.widget` and `Log.widget` in the kit exist and are unused; the widget links
  `TinyCache` and not the kit.

# Detailed discussions

Syd, 2026-10-08: "everything we talk about here goes in the plan". So this section holds the two
spikes, what was said about how the pieces fit together, and the research at the end. Where
something is from memory rather than checked, it says so.

## Spike: a 1-minute refresh, and the extension's memory

**The questions.** Design Decisions offers a 1-minute interval, and says the extension has one
picture in memory at a time, two at most. Does the system change a widget's photograph every minute?
And does the extension's memory stay flat as a timeline gets longer?

**How a widget changes at all.** WidgetKit decides when a widget redraws. A widget asks for a
*reload* — the system waking the extension to build a new timeline — and those are rationed, to 40
to 70 a day for a widget that is looked at often. So a photograph can't change by reloading. It
changes because one timeline holds many entries, each dated one interval after the last, which the
system shows in turn without waking the extension.

**Why 1 minute is in doubt.** Apple's guide says entries should be at least about 5 minutes apart.
One minute is the only interval offered that is below that. A 2020 forum test of one-minute entries
did change, but ran a few minutes late. A timeline's dates are a request; whether the system honours
a minute, or coalesces, is what the spike has to observe.

**What the reload budget allows.** Five minutes and longer are at or above Apple's spacing, and the
budget covers them. A timeline can show only pictures that are already in TinyCache, so at most 20.
At 5 minutes, 20 pictures last 100 minutes, which is about 14 reloads a day. At 1 minute they last 20
minutes, which is 72 reloads a day, just over the 40 to 70 the guide gives. With a cache of one or
none, every change is a reload, so a widget changes every 20 to 35 minutes at best, whatever its
setting.

**How the extension keeps to one picture.** These are ours to control:

- **An entry carries a file's path, not a picture.** A timeline of 200 entries is then 200 short
  strings, whatever the interval.
- **Each file is written at the widget's pixel size.** From Photos the extension asks for that
  size. Whether a full-size original passes through the extension's memory on the way is to be
  measured. A decoded picture costs about width × height × 4 bytes whatever its size on disk, so a
  1000 × 1000 pixel picture is about 4 MB.
- **The view opens its file only when it is drawn**, and keeps nothing afterwards. The extension has
  no cache of decoded pictures.

**Why memory is still in doubt.** WidgetKit draws each entry's view ahead of time and archives the
result, which is why the extension isn't running when an entry appears. If it draws one entry,
archives it and lets go before the next, one or two pictures in memory holds. If it draws a batch
before releasing any, memory grows with the number of entries. The documentation doesn't say which,
and a forum report of a photo-rotation widget killed at 30 MB fits the second.

The worry is about making the system's copies, not about the copies. Once the system has archived
an entry, that archive is the system's and isn't expected to count against the extension. What
counts is the short peak while a timeline is being turned into archives, because the drawing is
believed to run in the extension's own process, with each entry's picture decoded in memory at that
moment. Where the drawing runs is from memory, not checked.

**What else could get in the way:**

- **A covered widget.** On the Mac, a desktop widget behind windows may not be redrawn at all. That
  is fine. When it's uncovered it fetches one photograph and shows it; the entries it missed are
  skipped, not replayed.
- **Battery**, on iPhone, iPad and watch. A redraw every minute may be something the system
  throttles, or something App Review questions.
- **Xcode.** A widget run from Xcode is reported not to be held to the limits, so the widget has to
  be installed and watched with Xcode out of the picture.

**What the spike does.** A widget on the Mac with a timeline of entries a minute apart, each a
different solid colour, then each a different photograph from a file at the widget's size. Watch it
for an hour, and count redraws against entries and how late each one is. Then hand over timelines of
5, 10 and 20 photograph entries and read the extension's peak memory for each from the unified log.
Read it too while the extension asks Photos for a picture at the extra-large widget's size, and note
the size of that picture's file, which sets TinyCache's space. Then the same on an iPhone.

**What the answers change.** If 1 minute is honoured, the list of intervals stands. If it runs late
or skips, 1 minute is dropped and 5 minutes is the shortest. If memory stays flat as entries go up,
one picture at a time holds by design. If it climbs, the climb gives the longest timeline the
extension can hand over, and a short interval gets more reloads of fewer entries each.

**First measurements, 2026-10-08**, from Syd's Debug build with a small and an extra-large widget
on the desktop, reading coin scans through the bookmark. One process served everything.

- **The extension went far past 30 MB and was not killed.** Its peak read 34.7 MB after the first
  picture, 113.1 MB after the fourth and 116.4 MB a few seconds later, and it went on running. So
  on this Mac, in this build, there is no 30 MB ceiling in force. Whether that is the Mac, or a
  build run from Xcode, is not known. An iPhone is expected to kill it.
- **The peak comes from fetching, not from drawing.** It rose while a picture was being fetched
  and resized, and one line caught the footprint at 62.3 MB mid-fetch. Between fetches it sat at 7
  to 8 MB.
- **So "the original is never decoded whole" does not hold for these files.** Resizing one coin
  scan cost tens of megabytes, up to about 100. What the scans are, in format and in pixels, was
  not logged and needs to be. This is the thing to fix before an iPhone: it argues for asking the
  source for a small picture where the source can give one, as Photos can.
- **Drawing runs in the extension**, which settles "from memory, not checked" above: the `drew`
  lines come from the extension's own process.
- **Entries are drawn when the timeline is handed over, not when they are due.** A two-entry
  timeline had both entries drawn in the same second it was handed over, a minute before the second
  was due. So a picture's file is needed at handover and not after.
- **Drawing cost almost nothing.** `now` moved from 7.6 to 7.7 MB across two entries, and the peak
  did not move. That is two entries; 5, 10 and 20 are still to be read.
- **The widget gallery fetches a picture for each of the five sizes** to show its previews, which
  is five fetches before anything is placed.
- **Still to read**: whether a picture changes each minute and how late, which needs the widgets
  left up for a while.

**Memory, read again at 22:56 the same evening**, across three extension processes and 74 drawn
entries, the last process alive for eight minutes with the app quit and one agent running.

- **A fresh process starts at 4.6 MB.**
- **One fetch takes the peak to about 110 MB.** In each fresh process the peak went from 4.6 MB to
  108.6 or 114.0 MB on the first picture fetched. Readings caught mid-fetch were 45 to 68 MB.
- **It does not grow with the number of pictures.** After dozens of fetches the peaks were 113.5,
  116.4 and 120.1 MB. So the cost is one picture's resize, paid each time and given back, not
  something that builds up.
- **Between fetches it sits at 6 to 10 MB.**
- **Timelines of up to 13 entries were handed over at 7 to 10 MB.** 1, 2, 5, 8, 11 and 13 entries
  read 7.3, 7.6, 9.6, 7.4, 7.4 and 8.2 MB. That is the flat line the spike was looking for, as far
  as it goes.
- **Drawing is not yet separated from fetching.** The extension goes on filling while the system
  draws, so the readings at the moment of drawing, 7.5 to 45.9 MB, include a fetch in progress. The
  peak never rose at a handover that had no fetch in it.
- **Nothing was killed**, at 120 MB.

**What is still to measure for memory.**

- **What a coin scan is**: its format and its size in pixels, logged at each fetch, to say why one
  resize costs 110 MB and whether another way of resizing costs less.
- **The size on disk of a picture at each widget size**, logged at each fetch, for TinyCache's
  space for 30.
- **Drawing by itself**, with filling held off while a timeline is drawn.
- **The same on an iPhone**, where the ceiling is expected to be enforced. On Syd's own phone, and
  after Photos works on the Mac.

**Timing, from the same read.** The extra-large widget's timeline asked to be reloaded at 22:53:41
and was reloaded at 22:53:43. The small widget's was not due until 22:56:42 and was reloaded with
it, at 22:53:44: the system reloaded both widgets together. The extension is not filling far
between wakes; the most waiting was 3 and 4 pictures, so timelines are 4 or 5 entries and a reload
comes about every five minutes.

### Seen with 0.7 (5) installed, 2026-10-09

Thirty-five minutes of the release build's widgets, five placed, on two folders and two Photos
collections. 65 pictures fetched: 31 from Photos, 34 from the folders, none with trouble.

- **A very large picture costs far more than any budget so far.** The peak followed the original's
  size, not the widget's: a 14464×11728 JPEG took it to 47 MB, a 25088×15424 one to 107 MB, and a
  33280×20395 one, 68 MB on disk, to 151 MB and then 155 MB. All were coin scans from a folder.
  Afterwards the process was back at 10 to 15 MB each time, and it was not stopped.
- **One Photos picture came up 18 times out of the 31**, by its size, 4284×4284. The widget picks a
  collection at random and then a picture in it, so a collection with one picture in it is shown
  as often as one with thousands. *Claude's reading of the code; which collection it was is not
  checked.* The same holds between sources: each is as likely as the others, whatever it holds.

The peak waits for the iOS app, where it is listed in *Phases*.

**Every picture is as likely as every other, whichever source or collection it is in.** Syd,
2026-10-09: "I thought we already had pictures drawn alike from all sources. That's what I want."

- *A source is chosen in proportion to how many pictures it holds*, and the picture inside it at
  random. Each Photos collection is a source of its own.
- *The counts are remembered*, in `Caches/TinyCache/counts.json` in the extension's container, one
  file for widgets of every size. Syd chose that over counting every source on every pick. A
  source is counted when it has no count, or one an hour old.
- *A folder is counted by the walk that chooses from it.* Syd chose that over a walk of every
  folder each hour. A folder that goes on being chosen is walked once a pick and never just to be
  counted. A Photos collection gives its count without a picture being fetched.
- *A source that fails, or gives no picture though its count said it had some, is forgotten*, and
  counted again next time.
- *A photograph in two chosen albums counts twice.*
- *A source that grows or shrinks is weighed by its old size for up to an hour*, or, a folder,
  until it is next chosen.
- *Each counting is logged*, as `counted <source>, <n> pictures in <t> s`. A count taken by the
  walk that chooses is not: it cost nothing more.

- *The counts stand in for a database.* The screensaver and the wallpaper ask the agent, which
  draws uniformly from its catalogue, a row for every photograph. The widget asks no agent and has
  no catalogue, so it weighs its sources instead. Syd, 2026-10-09, asked whether the widget could
  draw from the agent's database, and left it: "this is fine for now, I guess". When the widgets
  have the shared database this plan calls for, a widget draws from that and the counts go.
  Reading the agent's own database from today's widget would take a read-only sandbox exception
  for its path, and would work only where there is an agent. *Not checked: whether SQLite can open
  the agent's live database read-only from inside the sandbox.*

**Measured 2026-10-09, a Debug build of 0.8**, on the widget gallery's first asking. Each source was
counted once: the two Photos collections at 8452 and 80 pictures, in 0.18 s and 0.15 s, and the
two folders at 436 and 115, in 0.06 s and 0.01 s. So 9083 pictures, of which 551, about one in
sixteen, are in the folders, and the first seven fetched were all from Photos.

To do:

- [ ] See a Photos collection counted again after an hour, in the `counted` lines.

## Spike: CarPlay widgets

**The question.** CarPlay shows iPhone widgets. What does it do to a photograph, and how often may
one change on the road?

**What is known, verified 2026-10-08.** iOS 26 added widgets to CarPlay, showing the iPhone's own
widgets in the small size. The WWDC25 CarPlay session says "In iOS 26, CarPlay features widgets",
and "All you need to do is support the systemSmall widget family." `WidgetLocation.carPlay` is
marked as introduced in iOS 26.0. Apple's current guide still describes the small family only, and
a rundown of iOS 27's CarPlay changes lists nothing about widgets. No CarPlay app is needed: drivers
see "your app's supported widgets, even if you don't have a CarPlay app."

**What is not known.**

- **How a photograph looks.** CarPlay removes the widget's background when the widget allows it,
  and sets its own margins. A photograph that fills the widget may be treated as background.
- **How often it may change.** Nothing Apple has published says. CarPlay draws widgets in the
  StandBy style, where the system redraws at a rate of its own.
- **A locked phone.** The session says most people use CarPlay with the iPhone locked, and that a
  widget relying on data protection classes A or B "likely won't work in CarPlay". TinyCache's files
  are not protected, so they can be read. Whether Photos can be asked for a picture while the phone
  is locked is a to-do under the iOS phase.

**What the spike does.** Put the widget on a CarPlay screen — the CarPlay Simulator in Xcode, or a
car. Check how the photograph is drawn, and whether it changes at the interval set, with the phone
locked and unlocked.

**What the answer changes.** Our small widget is the CarPlay widget and nothing extra is built. If
CarPlay has rules of its own (for example, no changing pictures while the car moves), those become
design decisions here. If the widget is a poor fit, it can be marked so with
`.disfavoredLocations([.carPlay], for: [.systemSmall])`; a driver can still add it, grouped apart in
CarPlay Settings, with interaction disabled.

## StandBy

StandBy is Apple's name for what an iPhone does while it charges on its side: it shows widgets
full-screen, as on a nightstand. Syd called it "nightstand mode", 2026-10-08.

- **It takes the small widget only**, the same as CarPlay. Apple's guide covers the two together.
- **The system redraws at its own rate there**, and that doesn't count against the reload budget.
- **From memory, not checked:** in a dark room StandBy tints everything red. That would matter for
  photographs.

## Control Center and Notification Center on the Mac

Syd, 2026-10-08: "on mac, I also want to be able to put widgets in the Control Center". Then, once
the findings below were in: "nothing in control center then, but we will support Notification
Center". The findings are from Apple's guide to controls and from coverage of macOS 26, read the
same day.

- **Since macOS 26, an app can put things in Control Center.** Apple's documentation: "On Mac,
  people place controls from your macOS app in Control Center or as menu bar items." A person adds
  them with Edit Controls at the bottom of Control Center.
- **What goes there is a control, not a widget.** "Controls can be buttons or toggles: buttons
  perform an action, and toggles perform an action and switch between two states."
- **A control shows a symbol and text.** The guide says to make its icon "using a symbol image, such
  as one from SF Symbols", and a toggle can show a label for its state. It doesn't say a control can
  show a photograph, and gives no way to.
- **A control has no timeline.** It updates "when someone interacts with it, when the app asks to
  reload it", or on a push notification. So nothing in Control Center changes every few minutes by
  itself.
- **Controls are built with WidgetKit and live in the widget extension**, so ours ships in the same
  bundle as the widgets.
- **A picture widget on the Mac goes on the desktop or in Notification Center.** Those are the two
  places macOS puts ordinary widgets.
- **A bug seen in macOS 26's beta**: third-party controls didn't show in Control Center until the
  widget gallery had been opened once. Not checked whether it is fixed.
- **Nothing found about a change in macOS 27.**

So anything of ours in Control Center would have to be a button or a toggle, and nothing goes there.

**Notification Center is supported.** It takes the same widgets as the desktop, so supporting it is
mostly a matter of checking how ours look and behave there. From memory, not checked:

- **A widget on the desktop fades when a window is in front of it**, to a muted or single-colour
  look, depending on a setting in System Settings. In Notification Center a widget is in full
  colour. A photograph is the worst case for the faded look.

**Which sizes Notification Center takes**, checked 2026-10-08 against Apple's page for each widget
family:

- **Small, medium and large: yes.** For small: "In macOS, the small system widget can appear on the
  desktop or in Notification Center." The pages for medium and large say the same, by a search
  summary; I did not open those two.
- **Extra-large, the landscape one: not said.** `systemExtraLarge` has been on macOS since 14.0 and
  its page says only that it is "available in iPadOS and macOS", with no place named.
- **Extra-large portrait, new in 27: the desktop only, as documented.** Its page says it "can
  appear on the Home Screen on iOS, on the Today View on iOS and iPadOS, on the Desktop on macOS,
  and on visionOS". Notification Center is not in the list.
- **So the Mac has two extra-large shapes**, landscape and portrait, and a person switches a desktop
  widget between sizes from its menu. Measuring TinyCache's space "at the extra-large widget's
  size" means the larger of the two.
- **Still to see on a Mac**: whether Notification Center offers either extra-large size. It is a
  narrow column, so probably not, but that is a guess.

## The app, the extension, and what they share

**A widget ships inside an app.** A widget is an app extension. It can't be distributed or installed
by itself; it lives in a containing app's bundle, at `Contents/PlugIns/` on the Mac, and the App
Store accepts only the app. Once the app is installed — on the Mac, usually once it has been
launched — its widgets appear in the widget gallery. Deleting the app removes them. This project
already has the shape once: `Photos-Go-Round Wallpaper Host.app` exists to carry the wallpaper
extension.

**The app has to be a real app.** From memory of the review guidelines, not checked: App Review
rejects an app that is only a shell for its extension. The menubar app, with its settings and
previews, is what the app is for.

**On iOS and iPadOS the app is a normal app.** What this section says of the menubar app holds for
it too: it carries the widgets, holds the settings, and has a TinyCache of its own for previews.

**One extension serves every widget.** Every widget the app offers, in every size and however many
are placed, is served by the one widget extension. They all run with the same sandbox container, so
they see the same files, preferences and database with no extra work.

**The app and the extension are two processes.** They have separate sandboxes and separate
containers. Objects don't cross between them, so each has its own TinyCache objects; that is why
the menubar app has a TinyCache of its own for previews. A preview needs only a few pictures per
size, so the app's can be very small.

**What two processes can share is files.** For the menubar app to write settings that the widgets
read, both belong to one App Group, and the settings and the database live in that group's shared
container. This is the usual arrangement. On macOS the group's name is spelled with the team
identifier in front; `Plans/PLAN.md`, *Widgets on macOS, and where the store actually lives*, has
the spelling.

**What the shared store holds.** The settings, and whatever each widget needs to remember about
itself. Nothing the widgets have to agree on: they may show the same picture as each other, and
each draws from the source by itself.

**What it has to survive.** The system can ask for several widgets' timelines at about the same
time, and the menubar app may be writing settings while the extension reads them. So the database
has to be safe across threads and across two processes. The kit's SQLite code was written for that,
with an agent and other processes on one file.

**"Agent" stays as the word.** With TinyCache in each process, there is no one process that is the
agent. Syd, 2026-10-08: "agent is the concept; going to keep the term".

**The extension fetches for itself.** The first question about this design was who fills a widget's
TinyCache when the menubar app isn't running. The extension does, each time the system wakes it:
the first picture is fetched and shown, one more is kept, and it goes on to 20 only while it is left
running. At widget size 20 pictures are a few megabytes on disk.

**On iPhone, two settings let a file be read while the phone is locked.** One is no protection at
all. The other, the default for an app's files, protects them only until the first unlock after a
restart. Apple's CarPlay warning names only the two stricter settings, so either would do. The
decision is the first: not protected.

## Telling widgets apart

**Each widget has a name**: a common string with the last 4 characters of a UUID appended. It is
what a person sees, for example in the menubar app, and it is what gives a widget its own TinyCache.
Four characters is 65,536 names, so a clash among a handful of widgets is very unlikely, and one
can be caught when the name is made.

**The open part is where a placed widget keeps its name.** All of this is from memory, not checked
against the 27 documentation:

- **The extension is handed a widget's size and its configuration** each time it is woken, and
  nothing else that is unique to that one widget. Two widgets of the same size with the same
  configuration look the same to it.
- **An app can read a widget's configuration but can't write it.** The only place a person changes
  it is the system's Edit Widget panel. The app can list the widgets that are placed and see what
  each is set to.
- **So the configuration is the one place a name could live.** How a fresh name would get into a
  newly placed widget's configuration without the person choosing it is not known.
- **The usual way round it is named settings**: the app keeps a list, and in Edit Widget the person
  picks one. With all widgets sharing one set of settings that isn't needed for settings, but the
  same mechanism could carry the name.

Finding this out is a to-do under the macOS phase.

## The proof of concept, in the existing app

Syd, 2026-10-08: "for testing, let's build the widget in the existing app. once we have our proof of
concept, we can build the menubar app separately".

So the first thing built is one new target, the widget extension, embedded in `Photos-Go-Round.app`
beside the agent, the wallpaper extension, the screensaver and the uninstaller that app already
carries. No new app target yet. What that means, from reading the project file the same day:

- **The existing app is not sandboxed; the extension is anyway.** A widget extension is always
  sandboxed, whatever its host is. That is the same pair the wallpaper extension and its host are.
- **The extension's identifier has to start with the app's.** The app is
  `com.sydpolk.photosgoround` in all three configurations, so the widget extension takes a name
  under that, with the configuration's suffix on the end so that Debug, Release and Claude builds
  don't register as the same extension. The wallpaper extension does this already.
- **Building the app will register the widget extension.** Xcode registers an app's extensions when
  it builds the app, which `CLAUDE.md` already records for the wallpaper host. So a `Claude` build
  of the app puts a `Claude` widget in the widget gallery until it is unregistered with `pluginkit
  -r`. `CLAUDE.md` needs that written into it when the target lands.
- **Running it is Syd's.** Launching `Photos-Go-Round.app` installs its agent, so the build an
  agent makes is only checked for compiling. Syd runs his Debug build from Xcode and places the
  widget.
- **Release builds carry it too.** The extension is embedded in every configuration, and it comes
  out of the existing app when there is a menubar app to carry it. Syd, 2026-10-08: "take it out
  when *we have a menubar app*". A release made before then ships the widget inside
  `Photos-Go-Round.app`.
- **No App Group is needed yet.** The settings are hard-coded, so the app and the extension share
  nothing in the proof of concept.
- **What moves later.** The extension's code goes over to the menubar app's target unchanged; only
  where it is embedded, and its identifier, change.

## Running the proof of concept

**What it is.** One widget, *Photos-Go-Round* with the build's suffix, in all five sizes. It shows
one photograph filling the widget. When it has no photograph it says why on its face: "Can't read
…" with what the system said, or "No pictures in …".

**To run it.** Syd runs the `Photos-Go-Round` scheme from Xcode, which launches the app and so
installs its agent as any launch does. Then Edit Widgets on the desktop, and add *Photos-Go-Round
(Debug)*. To check only that it compiles, build the `Photos-Go-Round Widget` scheme, which registers
nothing.

**What each wake does.** It takes everything waiting in TinyCache, up to 20, as entries a minute
apart; with nothing waiting it fetches one picture and shows that. It then keeps one more, hands the
timeline over, and goes on filling to 20 for as long as the system leaves it running. It asks to be
reloaded one interval after its last entry. With nothing to show it asks again in 15 minutes.

**What to read.** Every line the extension logs carries its memory, `now` and `peak`:

    /usr/bin/log show --info --last 1h --predicate 'subsystem == "com.sydpolk.photosgoround" AND category == "widget"'

- `timeline asked` and `timeline handed over, N entries` — how often the system reloads, and how
  long each timeline was.
- `filled, N waiting` — how far the extension got before it was stopped.
- `drew <file>` — when an entry's view was drawn, and in which process: the line appears only if the
  drawing runs in the extension. That settles what the memory section calls "from memory, not
  checked".

**What the first run answers.**

- Whether the sandboxed extension can read the folder at all.
- Whether a photograph changes each minute, and how late.
- Whether `peak` stays flat as timelines go from 1 entry to 20.

**While a widget waits.** Syd, 2026-10-09: "I want the app icon with a grey overlay, with
'Scanning...' in the widgets while they wait for their first pictures." Seen on 2026-10-09, with
0.7 (5) freshly installed: "I saw the starting... graphic in the widgets... looked good".

- *When it shows.* In the system's placeholder, which is what stands in a widget's place while its
  first timeline is being built, and for any entry that has no photograph and no trouble to
  report. With Photos allowed to download, that first wait can be long.
- *When it does not.* "No sources are set", "Photos access is denied" and the like are still said
  in words, since those want something done.
- *Where the icon comes from.* The extension asks the system for the icon of the app that carries
  it, by the app's path, so it is whatever icon the app has. Whether a sandboxed widget extension
  is given the real icon or a generic one is to be seen. On iOS it will have to come from the
  extension's own assets.
- *The placeholder is normally blanked out by the system*, text and pictures both. This one is
  marked to be drawn as it is.
- *It did not show on Syd's Mac.* The widgets there already had a picture waiting, so there was
  nothing to wait for. It is up only for as long as a widget's first fetch takes, which is a
  fraction of a second from a folder or from a photograph already on the Mac, and longer only
  when Photos has to download. It is to be looked for on a Mac that has never run the widget.

**The change between pictures.** Syd asked, 2026-10-08, whether the widget animates between
images. It does nothing of its own: whatever is seen when a picture changes is the system's own
transition between one timeline entry and the next. From memory, not checked on 27: since macOS 14
the system animates entry changes by default, and a widget can choose the transition for a view,
such as a fade or a push, though not run an animation of its own.

Syd chose the fade. The widget's view now gives each entry's picture an identity of its own and a
fade for its coming and going, over one second. Syd saw it on the desktop the same evening: "it's
fading". So a widget's view can choose its transition between entries, by giving the changing view
an identity and a transition.

Then: "actually, the user should be able to choose between the two in the widget settings, but
that's later", and: "I want the user to choose from whatever the system actually supports". So the
choice is not between two, but among every transition a widget can really show. The fade is what
is built; the choice is not.

Which those are is to be found out, by reading the documentation and by trying each on the
desktop. From memory, not checked: SwiftUI offers fade, push from an edge, move, slide, scale and a
blur-replace, and a widget may not honour all of them.

**What it leaves out.**

- **The space for 30.** Only the fill limit of 20 is enforced; no size ceiling is, until a picture
  at the extra-large size has been measured.
- **A TinyCache per widget.** There is one per size, so two widgets of one size share. A widget has
  no name yet.
- **Walking the folder once.** Each picture fetched walks the whole folder again to choose one at
  random, holding only the one path. Fine for a folder of thousands; not looked at beyond that.
- **The release script.** `Scripts/release-build.sh` checks the nested bundles it knows by name,
  and has not been taught the widget extension.

**Measured while building it, 2026-10-08.** A `Claude` build of the `Photos-Go-Round` scheme took
the widget extension's registration count from none to one, and `pluginkit -r` on the embedded
`.appex` took it back. Building the `Photos-Go-Round Widget` scheme alone registered nothing.

**Timing, undisturbed**, 22:48 to 22:58, one extension process throughout, one agent running, no
prompts.

| Widget | Handed over | Entries | Reload asked for | Reloaded | Off by |
|---|---|---|---|---|---|
| Extra-large | 22:48:41 | 5 | 22:53:41 | 22:53:43 | 2 s late |
| Small | 22:48:42 | 8 | 22:56:42 | 22:53:44 | 3 min early |
| Extra-large | 22:53:44 | 4 | 22:57:44 | 22:58:00 | 16 s late |
| Small | 22:53:45 | 5 | 22:58:45 | 22:57:58 | 47 s early |

- **Reloads come when asked, within seconds.** Two were 2 and 16 seconds late.
- **The system reloads both widgets together.** Whichever is due first brings the other with it,
  early. The early one loses nothing: pictures it was handed and had not shown yet go back to
  waiting.
- **A reload about every five minutes** is 288 a day, far over the 40 to 70 the guide gives. The
  system is allowing it for now; the guide says a widget gets more reloads than usual in its first
  days. Longer timelines are what would bring it down, and those need the cache fuller than the 3
  to 7 pictures it reaches between wakes.
- **When each picture actually appeared is not in the log.** The extension is not awake for that.
  Syd watched them change.

**The second build of the proof of concept** adds what the memory reading lacked:

- **`fetched for <size>, <type> <pixels> <MB> → <pixels> <KB>`** on every fetch: what the original
  is and what was written.
- **Filling waited two seconds after a timeline was handed over**, so that the memory read at each
  `drew` line was the drawing's alone. Taken out once it had answered that; see below.

**What the second build showed, 23:01.**

- **Drawing costs next to nothing.** With no fetch in progress, four small entries took the
  extension from 8.1 to 8.5 MB and six extra-large ones from 8.6 to 9.5 MB. The peak did not move.
  So a timeline's length is not what threatens the ceiling, and one picture in memory at a time
  holds for drawing.
- **A 38-megapixel JPEG resized for almost nothing.** `public.jpeg 6288×6032 7.4 MB → 342×328 72
  KB`, with the process's peak at 11.9 MB afterwards. So the 110 MB peaks are not what every coin
  scan costs. They came from particular files, of a kind or size not yet caught by the new line.
- **A small widget's picture is about 72 KB on disk**, at 342×328. An extra-large widget's has not
  been measured: the one caught was a 640×401 original, smaller than the widget, written as it was
  at 99 KB.
- **The extension is stopped within two seconds of handing over.** The fill that waited two
  seconds never began: no line from the process after its handovers, half a minute on. So "if the
  extension survives and is still running" does not happen in the way the design hoped. Earlier
  fills ran only in the second or two before the system stopped the process, mostly while the other
  widget's timeline was still being built.
- **So the two-second wait is taken out again.** It answered the drawing question and then starved
  the cache.

**The first builds filled the widget and cropped the photograph.** That was the agent's choice and
not asked for. Syd, 2026-10-08: "I noticed that the photos are not fitting inside the widget", and
of fit against fill, "at some point that will be an option for all of this". The third build fits
the whole photograph inside the widget, and TinyCache writes each picture at the size that fits
and no larger.

- **The figures above were taken at the fill size**, which for a squarish coin in the wide
  extra-large widget is about twice the fit size each way: 1408×1351 against roughly 717×688. So
  the 691 KB on disk and the 37 MB peak for one extra-large fetch should both come down, and are to
  be read again.
- **The fill figures are kept, as the fill case.** Syd, 2026-10-08: "eventually, I want to support
  all of the fill/fit options everywhere, so your measurements are still worth something". When
  fill is an option, a filled picture is the larger one, and TinyCache's space has to be sized for
  it: 400 to 720 KB at the extra-large size, against 144 to 268 KB fitted.
- **Pictures already cached at the fill size are still shown**, scaled to fit, until they have had
  their turn.

**Where the 110 MB comes from, read at 23:09 from the third build.** The per-fetch line caught it.

- **The coin scans are enormous.** Of 49 fetches in twelve minutes, 26 were of originals over 40
  megapixels, and many were around 300: `public.jpeg 23024×13488 57.0 MB`, `22656×13312 67.3 MB`.
  The largest was 33280×20395, 678 megapixels, in a 68 MB file. All were JPEG.
- **One such fetch is the whole peak.** In a fresh process, fetching a 23024×13488 scan for the
  small widget took the peak from 5.0 to 97.8 MB, and the next, 22656×13312 for the extra-large,
  took it to 112.3 MB.
- **The cost follows the original's size in pixels, not the widget's.** That 310-megapixel scan
  cost about 93 MB to write a 328×192 picture. A 38-megapixel JPEG written at about the same size
  cost about 4 MB. Roughly a third of a megabyte per megapixel of original.
- **So an ordinary photograph is cheap.** At that rate a 12-megapixel picture is about 4 MB and a
  48-megapixel one about 15 MB, inside 30 MB with the 5 to 8 MB the extension holds anyway. The
  coin scans are the unusual case, not the widget. That is an estimate from two points and wants
  checking against real photographs.
- **Fit made the pictures on disk smaller, as expected.** Small: 22 to 73 KB. Extra-large, fitted:
  144 KB at 552×688, 172 KB at 852×688, 268 KB at 1171×688. Filled, it had been 400 to 720 KB. So
  space for 30 at the extra-large size is about 9 MB, on these few. Extra-large portrait is not
  measured; no one has placed one.
- **The cache does get deep.** The timelines handed over at 23:09 had 19 and 15 entries, from
  pictures fetched during earlier wakes.

**An undisturbed run after the identity fix, 23:24 to 23:40.** One extension process for sixteen
minutes with both agents up. The extra-large widget's timelines were 20 entries each, the fill
limit; the small widget's were 7 and 10. Reloads came at 23:24:21 and 23:31:52. The process's peak
reached 152.6 MB and it was not killed.

**What Syd's point about sources does to the memory question.** Syd, 2026-10-08: "it is highly
unlikely that anybody will use folders on iPhones. Slightly more likely to use on an iPad. On the
other hand, photos library is the expected use case". Everything measured so far is the cost of
shrinking a file from a folder inside the extension. On an iPhone, where the 30 MB ceiling is
expected to bite, the source will nearly always be Photos, and Photos can be asked for a picture
at the size wanted. So the figure that matters for the phone is what a Photos request at
extra-large size costs the extension, which is not yet measured. The folder figures matter for the
Mac, where nothing has been killed at 120 MB.

**What that leaves open for the design.** A wake is the only time the extension reliably runs. If
the cache is to get deeper than one or two pictures, the fetching has to happen before the timeline
is handed over, for a bounded time or a bounded number of pictures. How long the system waits for a
timeline before giving up is not known. Not decided.

## Next: the app's sources, then Photos

Syd, 2026-10-08: "we really should get photos working on mac before we try phone. I don't want to
have to copy a bunch of photos into a simulator image. I will use my real device to test". So the
order is Photos on the Mac first, and the iPhone is tested on his own phone, not in a simulator.
On 2026-10-09 he narrowed that: the phone is for iCloud Photo Library, and everything else can be
tested in a simulator. `Plans/PGR Widgets - iOS.md`, *Where it is tested*.


Syd, 2026-10-08: "the next step, when we get there, is the read the app's preferences for sources,
and then we can test photos access".

- **What the sources are.** The existing app keeps its list of folders and Photos albums in its
  preferences, `com.sydpolk.photosgoround` with the configuration's suffix. The widget would take
  its sources from that list in place of the one hard-coded folder.
- **How a sandboxed extension can read them.** The wallpaper extension already reads those
  preferences, by an entitlement that names the domain. That is fine for the proof of concept and
  not for the Store. The other way is for the app to write the list into the App Group container.
- **A folder in the list still needs a bookmark.** Knowing a folder's path is not being let into
  it; that is today's finding. So for each folder source the app leaves a bookmark, as the probe
  does for the one folder now.
- **Photos is the open question.** A Photos source needs the extension to be allowed into Photos,
  by its own permission or by the app's. The privacy system would not prompt for the widget over a
  folder; whether it will over Photos is what the test finds out.
- **What it takes, from reading the code, 2026-10-08.**
  - *The list.* The app's sources are `SourceSpec` values in its preferences: a kind (folder or
    Photos collection), a locator (a path or a collection's identifier), whether it is recursive,
    and whether it is enabled. `Preferences` in `PhotosGoRoundAgentAPI` reads them, and the
    wallpaper extension already links that and reads the same domain. The widget does the same.
  - *Folders.* The app leaves a bookmark for each folder source, where the probe leaves one for the
    one hard-coded folder. The app is what changes the sources, so it leaves the bookmark as it
    adds the folder, at the moment the person has just chosen it in the open panel; nothing extra
    has to run. Syd, 2026-10-08: "the app is making the changes". Two cases fall outside that:
    folders already in the list before this is built, which the app can bookmark when it next
    launches, and a folder added with `pgr_ctl`, which gets no bookmark until the app next runs.
  - *Photos.* A new kind of source in TinyCache that asks Photos for a picture at the widget's size
    and writes it, so the extension never holds an original. Today a source hands TinyCache a file
    and TinyCache shrinks it; that has to turn round, so that a source writes a picture at a size.
    The extension needs the Photos entitlement and a usage description.
- **The shared privacy identity will muddy the Photos test.** When the widget was first refused
  the folder, the privacy daemon logged `Failed to match existing code requirement for subject
  com.sydpolk.photosgoround` in the same second. So the widget's request may be judged against the
  app's permission, and have failed because the widget is Debug-signed and the permission was
  given to a Release-signed build. If so, a Debug widget asking for Photos fails for the same
  reason, and that says nothing about whether a widget can use its app's Photos permission. Fixing
  the shared identity first makes the Photos test mean something. It is fixed; see below.
- **The fix for the shared identity, tried without changing the project, 2026-10-08.** Syd chose
  to fix it first, with one signing requirement that every configuration's build states.
  - *Why the two builds disagree.* Each signature states a requirement of its own by default. The
    Release app's asks for a Developer ID certificate of team `R5PQPZARC5`; the Debug app's asks
    for the certificate named "Apple Development: Sydney Polk". Neither build meets the other's.
  - *A requirement both meet.* `anchor apple generic and certificate leaf[subject.OU] =
    R5PQPZARC5`: signed with any Apple-issued certificate of this team. Checked with `codesign
    --verify -R` against the Release app in `/Applications` and the Debug app in Xcode's build
    folder; both pass.
  - *It can be stated at signing.* A trial build of the agent with `OTHER_CODE_SIGN_FLAGS` set to
    `--requirements "=designated => anchor apple generic and certificate leaf[subject.OU] =
    $(DEVELOPMENT_TEAM)"` produced a bundle that states exactly that, is valid on disk, and
    satisfies it.
  - *It must not name the identifier.* The first trial also required the bundle's identifier, as
    the default does. Xcode signs a Debug build's helper libraries with the same flags, their
    identifiers differ, and the bundle then failed `codesign --verify --strict`. The privacy
    system files a permission under the identifier separately, so the requirement loses nothing by
    leaving it out.
  - *How it is expected to end the prompts.* The permission records the requirement of whichever
    build was allowed. Once it is allowed through a build that states the shared one, every other
    build of the team meets it, whatever that build states itself. Not yet seen happen.
  - *Built, on `pgr-widgets`.* Syd, asked whether it should go to `main` first: "why does it need
    to be in main?" It does not: the fault needs a Debug or Claude build running beside a Release
    one, which is his Mac only. `OTHER_CODE_SIGN_FLAGS` is set at project level in all three
    configurations, and `BuildVariantTests` fails if a configuration loses it or names an
    identifier in it. In a clean `Claude` build the app, the agent, the widget and wallpaper
    extensions, the screensaver and the uninstaller each state the shared requirement, and the app
    passes `codesign --verify --deep --strict`.
  - *How it is to be shown working.* With the Release agent running, the Debug app is run once so
    that its agent starts. One Documents prompt is expected, for the Debug build, since the
    permission on record was given to a Release build that states the old requirement. After that
    one is allowed, both agents should refresh every five minutes with no prompt.
  - *Shown working, 23:24 to 23:40.* Syd ran the Debug app with the Release agent already up. The
    Debug agent started at 23:24:11 and was prompted once, at 23:24:16, with `Failed to match
    existing code requirement`; Syd allowed it. Both agents then refreshed at 23:29, 23:34 and
    23:39, eight refreshes in all, with no prompt and no failure to match. Before the fix each such
    round raised two or three prompts. The Release agent in `/Applications` was not rebuilt and
    still states its old requirement; it meets the shared one now on record, as expected.
  - *The same fault came back for Photos, 08:24 on 2026-10-09, and why.* Syd opened the Release
    app from `/Applications`. Its agent was refused Photos, he allowed it at the prompt, and the
    Debug widget then showed "Photos access is denied." The privacy daemon's lines:
    - 08:23:50, the Release agent: `Failed to match existing code requirement for subject
      com.sydpolk.photosgoround and service kTCCServicePhotos`, then a prompt at 08:24:05.
    - 08:24:07, the permission is written again, for the Release build.
    - 08:24:09, the Debug widget: `Failed to match`, then `Preventing prompt from Avocado widget`.
  - *What the fix does and does not do.* A permission records the requirement stated by the build
    it was given to. The fix makes new builds state one that every build of the team meets. It
    does nothing for a permission already on record from an older build, and the Release app in
    `/Applications` is an older build: it still states the Developer ID requirement. So:
    - The Photos permission on record last night had been given to a Debug build before the fix.
      The Debug widget met it. The Release agent, started afresh this morning, did not.
    - Allowing Photos for the Release app wrote its old requirement, which no Debug build meets.
    - Documents did not go wrong because its last answer, at 23:24, was given to a new Debug build.
  - *How it settles.* The permission has to be given once more through a build made after the
    fix. The Debug agent can ask; a widget cannot. Once the shared requirement is the one on
    record, the old Release build meets it too and is not asked again, as happened with Documents.
  - *Rerunning the Debug app did not settle it, 08:50.* The widgets restarted with it and were
    refused again in the same second. No prompt came, because nothing that can prompt was checked
    afresh: the Debug app shows photographs through its agent, and that agent had been running
    since 03:45, let in before the permission was rewritten at 08:24. A running process is not
    checked again. So the Debug app still "has access" while the permission on record no longer
    covers any Debug build. It takes a freshly started Debug agent, and then Photos granted in
    the Debug app, to put the shared requirement on record.
  - *Settled at 08:54.* With the Debug agent restarted and so refused, Syd used *Allow Access…* in
    the Debug app's album picker. The agent was prompted at 08:54:12 and allowed at 08:54:14. Both
    widgets showed photographs again at 08:54:16, and the agent re-read its three Photos sources
    by 08:54:27. No failure to match has been logged for Photos since. The Release agent had been
    started at 08:51 and let in under the earlier answer, so it has not been checked against the
    new one; the next time it starts is the test of that.
  - *What the Settings window did.* After the grant its sources list went on showing "Photos access
    has not been granted yet" beside two albums, while the agent had already read them. The album
    picker re-reads after a grant; nothing tells the sources list to. An existing fault in the app,
    not the widget's.
  - *What was changed in the app for it, 2026-10-09.* The entry in `TODO.md` this answered, "After
    granting Photos access from the picker, the albums chosen before still do not work", is
    removed.
    - *Done in the album picker always works.* It was held back until a tick changed, so after a
      grant the only way out was Cancel. Syd: "make the Done button always work, not gated on my
      changing anything. this will allow me to fix photos access without having to change which
      collections are selected."
    - *A grant tells the sources list to read again*, as choosing albums does.
    - *The app holds the permission, and the red words come from it.* Syd: "since the app has to
      ask the permissions, the app should have the state of permissions. That red string should
      be based on that value. Everything else about the agent updating sources, etc., does not
      have to change", and "all the agent can do is complain back to the app that it does not have
      permissions". The app reads the agent's Photos permission with every read of the list. An
      album says it is refused when that value says so; and when access has been given, an album
      the agent still has down as refused says "scanning…" until the agent's next scan counts it.
    - *The agent is not changed.* A first attempt put this in the agent, had its list answer with
      today's permission, and had a grant make it read its sources again. That was taken back out
      when Syd said where it belonged. So after a grant, the albums are read again at the agent's
      next scan, which can be up to five minutes; the list says "scanning…" for that long.
    - *The app's tests for this pass.* They are hosted by the app, whose launch installs an
      agent, so running them is Syd's; he ran them in Xcode on 2026-10-09. The first run failed
      four, all faults in tests: two new ones expected the app's one shared change counter to rise
      by exactly one while other tests were raising it too, and three older ones counted every
      `GET` as a read of the list, which the new read of the permission doubled.
    - *A read in flight when the panel closes asks for nothing more.* The read of the list is
      followed by the read of the permission, and with the panel closed between the two the second
      was still made. One of the failing tests showed it. The agent first left it as harmless;
      Syd had it fixed: "that just accrues tech debt". The model now skips the permission read once
      the panel's polling has been cancelled, and a test holds a list read open, closes the panel,
      and checks that nothing more is asked.
  - *Folders are the agent's to be asked about, and the app's.* Syd, 2026-10-09: "the agent
    controls the file system access permissions since it can trigger the system to ask", and "I
    suppose we could have the app list out the files in the sources, which should trigger
    filesystem permissions." The app already lists each folder source, at launch and whenever its
    sources change, before it leaves that folder's bookmark for the widget; that read is where the
    app is asked. What is not known is what the app does with the answer: it logs a folder it
    could not read and shows nothing.
  - *What ends it for good.* A Release built after the fix, so that no installed build states an
    old requirement. Until then, each kind of permission can go wrong once, the first time an old
    Release build and a new Debug build meet over it.
  - *A Release export does not keep it.* Read on the installed 0.5 (3), 2026-10-09: the app, the
    agent and the widget each stated the default Developer ID requirement, though the archive they
    were exported from was built with the setting. The export signs everything again and drops it.
    That does no harm while only the Release build is installed. It matters when a Debug build
    next runs beside it: a permission answered for the Release build is recorded in a form no
    Debug build meets.
  - *So a release signs once more, itself.* `Scripts/sign-shared-requirement.sh` signs an app and
    the code inside it again, inside first, stating the shared requirement and keeping each
    signature's identifier, entitlements and flags. `release-build.sh` runs it on what the export
    produced, then refuses to go on unless all six bundles state the requirement. Tried on a
    `Claude` build with the development certificate: sixteen pieces signed, identifiers, flags and
    entitlements unchanged on all of them, the app passing a deep strict check, and the default
    requirement put back on two of them replaced. On a release it is unrun; the next release is
    its first.

- **Built, and not run.** Syd, 2026-10-08, with the identity fix committed: "go ahead with
  sources and photos".
  - *The widget reads the app's sources on every wake*, from the app's preferences, and shows the
    folders and the Photos collections that are switched on. A Debug widget reads the Debug app's
    list. The hard-coded coin folder is gone; it is shown only if it is one of the app's sources.
  - *A source now writes its own picture*, at the size that fits, where before it handed TinyCache
    a file to shrink. A folder shrinks an original. Photos is asked for the picture at that size,
    exactly, and what comes back is written as it is.
  - *A source is chosen in proportion to how many pictures it holds*, so that every picture has an
    equal chance. *Seen with 0.7 (5) installed*, above.
  - *One source's trouble does not stop the others.* A folder that can't be read is passed over.
    The widget says what went wrong only when no source gave it a picture.
  - *Photos is not asked to download.* A photograph that is only in iCloud comes back as whatever
    smaller copy is on the Mac, or not at all. That was the agent's choice, for fear of a download
    of unknown length inside a widget's wake. Syd, 2026-10-08: "After this run, I do want the pics
    downloaded in Photos." So it changes after the first run, to let Photos download.
  - *The widget reads its Photos permission and does not ask.* If Photos has not said yes, the
    widget's face says "Photos access is denied", or "not determined", and so on. That line is the
    answer to whether a widget can use its app's permission.
  - *The app leaves a bookmark for every folder source*, at launch and whenever its sources
    change, in place of the one for the coin folder. The naming of the bookmark files and the
    leaving and opening are in `TinyCache`, tested, so the app and the extension cannot disagree.
  - *The extension's entitlements* now name the app's preferences, as the wallpaper extension's
    do, and Photos. The first is not something the Store accepts.
  - *Not built*: a source that is a single file or a single Photos asset, and Google albums. They
    are counted and said to be "of other kinds not shown".
- **The first run, 23:52.** Syd ran the Debug app, which rebuilt the widget; the widgets were
  already showing the new build when he wondered about restarting them.
  - *A sandboxed widget can read the app's sources.* Its first timeline logged `1 folders, 0
    Photos collections`: the Debug app's list held the coin folder.
  - *The bookmark for a listed folder works as the probe's did.* The widget logged `the app has
    left no bookmark` at 23:52:32, the app left one at 23:52:34, and the widget opened the folder
    through it in the same second.
  - *A source added in the app reaches the widget at once.* Syd added a Photos album at 23:52:52.
    The app left its bookmarks again and reloaded the widgets, and the next timeline logged `1
    folders, 1 Photos collections`.
  - *Photos let the widget in, under the app's permission.* The widget's first Photos picture came
    two seconds later: `fetched for systemSmall, photos 2272×1704 → 328×246 30 KB`. The privacy
    daemon's lines for it are the answer to whose permission: the request came from the widget's
    process, and was looked up under `subject=com.sydpolk.photosgoround`, the app's identifier, not
    the widget's own. The result was `authValue=2`, allowed, by consent the person had already
    given. So a widget uses its app's Photos permission, and needs none of its own.
  - *That is the opposite of a folder.* The widget's request for the Documents folder was judged
    under the widget's own identifier, where there is no permission and no way to be asked.
  - *Photos handed back exactly the size asked for*: 328×246 for the small widget's 328×328 box.
  - *Not read yet: what a Photos picture costs in memory.* Coin scans were being fetched in the
    same second, and the peak is the process's, so the two can't be told apart in this run.
  - *Photos now downloads.* With the run done, the request lets Photos fetch from iCloud, as Syd
    asked. What a download costs a wake in time is not measured.
- **Read again at 23:56**, with the folder and one Photos album both in the list.
  - *Photos pictures are a quarter of the fetches, not half.* 13 from Photos and 39 from the
    folder in seven minutes, though each source has an equal chance. That build did not let Photos
    download, so a photograph only in iCloud came back as nothing and the widget fell back to the
    folder.
  - *A Photos picture does not move the peak.* Across eight Photos fetches in a row, small and
    extra-large, from photographs of up to 6048×4024, the process's peak stayed where the last coin
    scan had left it. It rose only on coin scans, to 174.6 MB on a 33280×20395 one.
  - *But the extension sits higher once Photos is in use.* Between fetches it had been at 8 to 12
    MB. After the Photos fetches began it climbed in steps of half a megabyte to three, and sat at
    24 to 31 MB. On an iPhone that is the whole of the 30 MB before any picture. Whether it keeps
    climbing, and what it is on iOS, is to be measured.
  - *Photos pictures on disk*: 19 to 45 KB for the small widget, 99 to 300 KB for the extra-large.
  - *Syd still saw only coins.* Each widget had just been handed a 20-entry timeline from a cache
    filled mostly with coins before the album was added, and three of four new fetches were coins.
  - *A gap this shows: the cache outlives a change of sources.* Pictures already fetched from a
    source go on being shown after the source is switched off or removed, up to 20 waiting and 20
    more in the timeline. Nothing cleared TinyCache when the list changed.
  - *Syd hit it at once.* He removed the coin folder from the Debug app's sources, the app went
    over to Photos, and the widgets went on showing coins. Two faults, both fixed in the next
    build:
    - *The cache.* TinyCache is now kept per list of sources. When the list a widget is showing is
      no longer the one in force, the pictures cached for it are deleted, and the widget starts
      again from the sources that are left.
    - *The app did not tell the widgets.* It asked them to reload only when a Photos collection was
      chosen in the picker. Adding or removing a folder went through another path that said
      nothing, so the widgets kept their 20-entry timelines. Every change of sources in the app now
      leaves bookmarks again and asks the widgets to reload.
- **Photos alone, 00:00 on 2026-10-09.** Syd ran the build with both fixes; the widgets reloaded
  on launch and showed photographs from the album, no coins. One fresh extension process, every
  fetch from Photos.
  - *The app's reload reached the widgets*: `app asked the widgets to reload, 0 folder sources`,
    and timelines logged `0 folders, 1 Photos collections`.
  - *A small widget's Photos picture costs almost nothing.* The process started at 7.5 MB; the
    first fetch took it to 11.8 MB, which is Photos itself loading, and the next five moved the
    peak from 12.1 to 13.2 MB.
  - *An extra-large one can cost a great deal.* `photos 6639×4256 → 1073×688` moved the peak from
    13.2 to 21.3 MB. `photos 7983×4490 → 1223×688`, a 36-megapixel photograph, moved it to 71.2 MB.
    Ordinary 12-megapixel photographs at the same widget size did not move it again. So asking
    Photos for a size does not keep a big original out of the extension's memory: the shrinking is
    done in the extension's own process, and a large photograph at a large widget size goes well
    past 30 MB.
  - *The extension climbed between fetches*, from 12.9 to 28.2 MB across about twenty fetches in
    two seconds, with no step to match any one picture. That looks like things made during a fetch
    not being released until the whole wake is over. Each fetch now runs in a release pool of its
    own; whether that flattens it is to be read.
  - *Photos pictures on disk at the extra-large size*: 132 to 428 KB.
- **The climb, before and after the release pool, 00:02 and 00:23.**
  - *Before.* The old build's last wake, about forty Photos fetches in three seconds: the
    extension went from 33.6 to 56 MB with the peak unmoved. Each fetch left behind about one
    decoded picture, some 3 MB for an extra-large one and half a megabyte for a small one.
  - *After.* The rebuilt widget was first woken at 00:23, when the old timelines ran out. In 27
    fetches it went from 4.4 MB to a highest of 22.8 MB and ended at 20.7 MB, with a peak of 23.9
    MB. It rose over the first fetches and then held at about 22 MB for the last ten, dipping once.
    The old build had reached 28 MB by the same count and was still rising.
  - *So the pool helps, and one wake does not prove it flat.* The figure to watch is whether the
    next wakes start from 20 MB and stay there, or add to it.
  - *No large photograph came up in that wake*, so the 71 MB case was not met again.
- **A longer run, 00:23 to 00:45, read at 01:04.** One extension process the whole time, Photos
  only, a small and an extra-large widget, 98 fetches over four wakes.

  | Wake | Fetches | Memory at its start | at its end | Peak so far |
  |---|---|---|---|---|
  | 00:23 | 21 | 11.2 MB | 20.7 MB | 23.9 MB |
  | 00:32 | 15 | 13.7 MB | 23.3 MB | 24.8 MB |
  | 00:36 | 30 | 14.4 MB | 29.0 MB | 33.9 MB |
  | 00:44 | 32 | 17.8 MB | 33.6 MB | 38.3 MB |

  - *Memory rises through a wake and falls back before the next.* It ended the four wakes at 21,
    23, 29 and 34 MB and began the next ones at 14, 14 and 18. So most of what a wake piles up is
    given back while the extension is stopped.
  - *How high a wake goes follows how much it does.* About half a megabyte a fetch: 15 fetches
    added 10 MB, 32 added 16. The two busiest wakes each handed over 20-entry timelines as well.
    So the release pool did not make a wake flat; it made the pile smaller and let it go afterwards.
  - *The level it falls back to is creeping up*: 11.2, 13.7, 14.4, 17.8 MB. About 2 MB a wake.
    Four wakes do not say whether that goes on.
  - *A busy wake goes past 30 MB without any large photograph.* The last one peaked at 38.3 MB.
    That is the amount of work, not one picture, and the amount of work in a wake is ours to set:
    two widgets share the one process, each fills toward 20, and nothing limits how many pictures
    a single wake fetches.
  - *The 71 MB photograph was not met again.* In 98 fetches the largest originals were 44, 35, 35
    and 27 megapixels, and none moved the peak by more than 5 MB, including a 27-megapixel one at
    the extra-large size. So whatever made a 36-megapixel photograph cost 50 MB the first time is
    not simply its size. Its format is not logged; Photos reports only pixels.
  - *Reloads came 15 to 31 seconds after they were asked for*, three times out of three, both
    widgets together each time. So the last picture of a timeline stays up that much longer.
  - *The gaps between reloads grew as the cache did*: 8½ minutes, 4, 8½, and then 20, once both
    timelines had 20 entries. Twenty minutes is 72 reloads a day, at the top of what the guide
    allows.
  - *What Syd chose.* Offered a cap on the fetches in a wake, the original rule, or leaving it for
    the phone, he chose the original rule: show one, keep one more, no further filling. The widget
    now takes one picture for each timeline and fetches one to replace it. A wake fetches one
    picture, two the first time. Built; not yet run.
  - *What that costs.* A timeline is one entry, so every change is a reload, about 1,440 a day at
    a one-minute interval against the 40 to 70 the guide allows. The system has been generous so
    far; when it stops, a widget will change only as often as it is reloaded, which the guide puts
    at every 15 to 60 minutes.
  - *The original rule's first twelve minutes, 01:27 to 01:39.* The rebuilt widget was first woken
    at 01:27:58, when the old build's timelines ran out. Each widget was reloaded every 64 seconds,
    twelve times, each timeline one entry. For the first ten minutes it only worked through the
    pictures the old build had cached, and sat at 7.1 MB with a peak of 7.6 MB. Its first Photos
    fetches came at 01:38 and 01:39, both extra-large, and took it to 13 or 14 MB with a peak of
    18.1 MB. Syd left it running overnight.
  - *Two hours of it, 01:27 to 03:36.* One extension process throughout, nothing on either
    widget's face but photographs.
    - *The system reloaded each widget every 64 seconds, 121 times, without a break.* No gap
      longer than 65 seconds. So for the first two hours a one-minute interval was honoured by
      reloads alone, about 56 an hour for each widget. The guide's 40 to 70 a day was passed in the
      first hour and nothing was held back. Whether that lasts beyond a widget's first days is not
      something one night shows.
    - *Memory after a wake's one fetch held at 15 to 16 MB*: 14.9 MB at 01:49, 16.2 MB at 03:25.
      About a megabyte of creep in two hours.
    - *The peak held at 20.5 to 21.8 MB, until one fetch.* At 03:18:40, `photos 4608×2592 →
      1223×688` took the process to 26.4 MB and its peak to 40.0 MB. A 12-megapixel photograph,
      like dozens of others that moved nothing.
    - *A guess at why, not checked.* The earlier outlier, a 36-megapixel photograph, added about
      50 MB; this one, 12 megapixels, added about 18. That is the same 1.4 to 1.5 MB a megapixel
      both times, which is what holding the whole original decoded would cost. Both came after
      Photos was allowed to download, and none came before. So a photograph that has to be fetched
      from iCloud may arrive as its original and be shrunk in the extension, where one already on
      the Mac is served from a smaller copy Photos keeps. If so, letting Photos download is what
      makes an occasional wake expensive.
  - *Four hours and forty minutes of it, to 06:07.* Still one process and still every 64
    seconds: 263 reloads for each widget, 56 or 57 an hour, no gap over 65 seconds, nothing on
    either face but photographs. Memory after a wake stayed between 13 and 19 MB in every hour. The
    peak did not move again from the 40.0 MB of 03:18.
  - *The whole night, 01:27 to 08:22, just under seven hours.*
    - *One extension process the whole time.* It was never killed and never restarted.
    - *390 reloads for each widget, one every 64 seconds, with no gap longer than 67 seconds.* 56 or
      57 an hour, every hour. The system never rationed it. That is about 1,350 reloads a day for
      each widget, some twenty times what the guide gives as typical.
    - *756 fetches from Photos, one a wake for each widget, and never a failure.* Nothing but
      photographs was ever on either widget's face.
    - *Memory after a wake averaged 15 to 16 MB in every hour from 02:00 on*: 15.2, 16.0, 15.8,
      15.4, 15.6, 15.8, 16.3. No creep.
    - *The peak was 20.5 to 21.8 MB except for one fetch*, the 40.0 MB of 03:18. A few other
      fetches took the process to 23 to 25 MB for a moment without passing that peak.
    - *No privacy prompt all night*, with the Release and Debug agents both running.
    - *On disk*: 380 extra-large pictures averaged 182 KB, largest 459 KB; 376 small ones averaged
      37 KB, largest 228 KB.
    - *What it does not show.* What the system does after a widget's first days, when the guide
      says the extra reloads stop. What an iPhone does. And why one photograph in 756 cost 18 MB
      more than its neighbours.
  - *On disk*: the small widget's 51 pictures averaged 35 KB, largest 54 KB. The extra-large
    widget's 47 averaged 204 KB, largest 394 KB. Space for 30 at the extra-large size, fitted, is
    about 12 MB at the largest and 6 MB on average.
- **What the first run answers.**
  - Whether a sandboxed widget can read the app's preferences at all.
  - Whether Photos lets the widget in, and under whose permission.
  - What a Photos picture at the extra-large size costs the extension in memory, which is the
    figure that matters for an iPhone. The `fetched` line reads `photos`, the photograph's own size
    in pixels, and the size written.
- **Whose sources.** Syd came back to this the same day: "the widgets sharing the app's sources.
  the only setting a widget would have is how often it updates." Read here as: the sources belong
  to the app that carries the widgets, which is the existing app in the proof of concept and the
  menubar app later. Design Decisions still says the widgets product's settings are not shared
  with the rest of the product line; that line is left as it is, and now speaks of the menubar
  app's sources.
- **Where a widget's one setting would live.** A widget's interval is its own, so it has to be kept
  per placed widget. The system's Edit Widget panel is made for exactly that: a widget declares a
  choice, the system keeps each placed widget's answer and hands it to the extension on every wake.
  Against that, Design Decisions says all of the settings are reached through the menubar app,
  which would need the app to tell placed widgets apart. Not decided.
- **No controls go on the widget's face.** Syd, 2026-10-08: "I don't want to have to cram the
  controls into the small of an extra-small widgets available space". The Edit Widget panel is not
  drawn in the widget's space, and not by us: the widget declares one choice, "Update every", and
  the system draws a panel of its own for it, opened by right-clicking the widget. From memory, not
  checked on 27: the panel is the system's own size, larger than a small widget.

## Uninstalling the widgets

Syd, 2026-10-09: "we also need the uninstaller to remove widgets", and then: "or does that happen
automagically when the app is removed?" Partly, and his own Mac showed which part: he had deleted
the Debug build that morning.

- **The registration goes by itself when the app is deleted**, as `pluginkit` shows it. After
  DerivedData was removed the Debug widget extension was no longer listed. LaunchServices kept a
  record of it all the same; see *Run for real* below.
- **The widget's data does not.** Both of the deleted build's folders were still on disk: the
  extension's container, with the pictures TinyCache had cached, and the App Group's, with the
  bookmarks the app had left.
- **A running extension process does not either.** One was still alive from the deleted bundle
  until it was killed.
- **Not known**: whether the system drops a widget extension when its app is moved to the Trash,
  which is what the uninstaller does, or only when the Trash is emptied.

So the uninstaller now does it by name, as it does for the wallpaper extension. Run for real on
2026-10-09; what that showed is below.

- **A fourth part to an uninstall, `widget`.** It finds the widget extensions registered for the
  builds it was asked about, unregisters each, and stops each one's process by its bundle's path.
  `Scripts/uninstall.sh` and `pgr_install uninstall` take `--widget`; with no part named they
  remove all four.
- **The scrub removes the widgets' two folders**: `Data/Library/Caches/TinyCache` in the
  extension's container, and `WidgetSource` in the App Group's. They are tried and not reported,
  as the wallpaper's and the screensaver's remembered pictures are.
- **The uninstaller app lists "Photos-Go-Round Widgets"** among what it found.
- **`BuildVariant` names the widget extension and its App Group** for each configuration, and a
  test holds them to the project's suffix and team.
- **A dry run against Syd's Mac found the Release widget extension** in `/Applications`, and
  nothing for Debug, whose build had been deleted.
- **Placed widgets cannot be removed one by one**; no API does that. The system removes them, and
  only under the condition below.
- **`uninstall.sh --widget` on an app left in place does not last**: the app registers its
  extension again the next time it is built or launched.

### Run for real: the placed widgets stayed

Syd ran the 0.6 (4) uninstaller on 2026-10-09, and his five placed widgets were still on the
desktop afterwards. Everything else had gone: the app, the registration, the processes.

- **The system removes placed widgets only when LaunchServices has no record left for the
  extension's identifier.** NotificationCenter, twenty seconds after the extension went: "Not
  removing instance associated with: com.sydpolk.photosgoround::com.sydpolk.photosgoround.widget
  because LS still has an extension record for it."
- **The record it found was stale, and a build had left it.** Xcode registers an app's extensions
  when it builds the app. The release build's archive step then moves the app out of
  `ArchiveIntermediates`, and the record for the path it was built at stays. A Debug build leaves
  the same thing when DerivedData is deleted: a `…widget.debug` record was there too.
- **`pluginkit` does not show these records.** It listed nothing for either identifier.
  `lsregister -dump` does.
- **`lsregister -u <app path>` removes one, even when the path is gone.** Measured.
- **The system asks once.** Removing the stale record afterwards did not remove the widgets, and
  NotificationCenter logged nothing more. So stale records have to go *before* the live extension
  is unregistered.
- **Other copies of the app carried no extension record**: the mounted image, the copy in the
  Trash, the release script's export copy.
- **Restarting NotificationCenter does not make it ask again.** `killall NotificationCenter`
  brought the five widgets back with all-white content: their drawn pictures were gone, and the
  system then gave up on reloading them, "Disallowing reloads due to extensive failures". Left
  like that, a widget is removed by hand, with Remove Widget.
- **Not known**: whether a Mac that only ever installed from the image keeps its widgets. It has
  one record, which the uninstaller removes, so it should not.

Syd chose the uninstaller for the fix: "the uninstaller's primary audience is other users, but
it should work for me in development as well."

- **The uninstall reads `lsregister -dump Plugin`**, and takes every record of its widget's
  identifier whose bundle is no longer on disk. `Plugin` alone takes under a second; the whole
  database took seven.
- **It forgets those first**, with `lsregister -u` on the app each was in, and unregisters the
  live extension after.
- **A dry run on Syd's Mac found the stale Debug record**, and nothing else.

- **Run for real with a Debug build, 2026-10-09**: Syd placed a widget and ran the Debug
  uninstaller, and "the widget disappeared as it should." That round had no stale record: a new
  Debug build lands on the path the old record named.

- **Run for real with a release, 2026-10-09**: the 0.7 (5) uninstaller, with five widgets placed.
  NotificationCenter logged "Remove widgets belonging to extension … from storage", and twenty
  seconds later "instance removed" for each of the five. No record of the extension was left in
  `pluginkit` or LaunchServices.
- **The 0.7 (5) release build left no stale record**, where 0.6 (4)'s had. Not understood. So the
  step that forgets one has found a real one only in a dry run.

To do:

- [ ] See it with a stale record present: a dry run of `uninstall.sh --variant release --widget`
  lists a record to forget, and the uninstall then takes the placed widgets away.

## The hard-coded folder, and the sandbox

For now the source is `~/Documents/Coins/Raw Coin Images`, read recursively. A widget extension is
always sandboxed, and a sandboxed process can't read a folder in `~/Documents` just because it knows
the path. This was not discussed with Syd before 2026-10-08; it came up while reading how the
wallpaper extension is built.

- **For a development build**, an entitlement can name a path under the home folder and let the
  extension read it. The wallpaper extension already uses that kind of entitlement, for preference
  files. The App Store doesn't accept it.
- **For the Store**, the person chooses the folder in the menubar app, which keeps a bookmark to it.
  Whether a bookmark the app makes can be used by its extension is not checked.
- **`~/Documents` has a privacy prompt of its own on macOS, and a widget is never shown it.**
  Measured 2026-10-08; see below.
- **Photos is the same kind of question.** The extension needs Photos access of its own, or the
  app's. Not checked.

**The first run, 2026-10-08: the extension cannot read the folder.** Syd ran his Debug build and
placed a medium widget. It showed "Can't read /Users/jazzman/Documents/Coins/Raw Coin Images/: The
file “Raw Coin Images” couldn’t be opened because you don’t have permission to view it." The log
says why:

- **The sandbox entitlement worked.** There is no denial from the extension's own sandbox for the
  folder.
- **The refusal is macOS's privacy protection of `~/Documents`.** The kernel's line is `System
  Policy: Photos-Go-Round Widget deny(1) file-read-data /Users/jazzman/Documents/Coins/Raw Coin
  Images`, and "System Policy" is the privacy system, not the sandbox.
- **The system will not ask on a widget's behalf.** The privacy daemon logged `Preventing prompt
  from Avocado widget` for `com.sydpolk.photosgoround.widget.debug`, each time. So no prompt
  appears, and there is nothing for a person to allow.
- **The widget is judged by itself.** The request is attributed to the widget extension alone, not
  to the app that carries it, so the app being allowed into `~/Documents` would not obviously help.
  Not tested.

So a widget extension cannot read a folder in `~/Documents`, `~/Desktop` or `~/Downloads` by its
path, whatever entitlement it has. That bears on "the widget extension fills its own TinyCache"
for any folder a person is likely to choose. The ways forward, none decided:

- **A folder macOS doesn't protect**, for the proof of concept only. A copy of the pictures
  somewhere like `~/Pictures` would let the rest of the spike run. Whether `~/Pictures` is
  unprotected is from memory, not checked.
- **The app does the reading.** An app can be shown the prompt. It reads the folder and writes
  widget-sized pictures where the extension can read them, in an App Group container. That gives up
  the extension fetching for itself, for folders like this one.
- **A bookmark from the app.** A person chooses the folder in the app, and the app passes the
  extension a security-scoped bookmark to it. A folder a person chose is treated differently by the
  privacy system. Whether an extension can use a bookmark its app made is not checked.

**Could the app ask, and the widget honour it, with an App Group between them?** Syd's question,
2026-10-08. What follows is reasoning from the log and from memory; none of it is tested.

- **By permission alone, probably not.** The privacy system keeps its permissions per program, by
  identifier. The log shows the widget's request judged under the widget's own identifier, with no
  app named as responsible for it. So the app being allowed into `~/Documents` is a permission the
  widget doesn't hold.
- **An App Group doesn't change that.** It gives the two a shared folder of their own. It says
  nothing to the privacy system about any other folder.
- **A bookmark is the one way a permission might travel.** The app, once allowed, makes a
  security-scoped bookmark to the folder and leaves it in the shared container. If the extension
  can resolve it, the system hands the extension access to that one folder, and access given that
  way isn't subject to the prompt. The doubt is that such a bookmark is normally tied to the program
  that made it, and an extension is a different program from its app.
- **What works for certain is the shared folder itself.** The app reads the pictures and writes
  widget-sized copies into the App Group container; the extension reads them there. As far as is
  known this is what photo widgets generally do.

**The bookmark test.** Syd chose to try it, 2026-10-08. It is built and has not been run.

- **An App Group joins the two**: `R5PQPZARC5.com.sydpolk.photosgoround.widgets`, with the
  configuration's suffix, in the entitlements of the app and of the extension. The extension's
  `Info.plist` states the name, and the app reads it from there.
- **The app's half** runs at launch. It reads the folder, which is where the app is shown the
  privacy prompt for `~/Documents`. Then it leaves two bookmarks to the folder in the group's
  container, `scoped` made with a security scope and `plain` made without, and asks the widgets to
  reload.
- **The extension's half** tries each bookmark before every timeline until one opens the folder:
  resolve it, start access, list the folder. A folder that opens becomes the source.
- **The path entitlement is gone.** The extension no longer names the folder in its entitlements,
  as a Store build could not. So a refusal can now come from the sandbox or from the privacy
  system, and the kernel's log line says which: `Sandbox:` or `System Policy:`.
- **How it reads.** If it works the widget shows a coin. If not, its face says what happened to
  each bookmark: "not there", "did not resolve", or "resolved but unreadable". The same is in the
  log under `widget: bookmarks:`, and the app's steps are under `widget: app …`.
- **It is a probe.** `WidgetFolderBookmark` in the app and `BookmarkedFolder` in the extension go
  once the question is answered, and have no tests: what they find out can only be seen with the
  extension running under the system.

**The bookmark test worked, 2026-10-08.** Syd ran his Debug build and placed a small and an
extra-large widget; both showed coins.

- **The plain bookmark opened the folder.** The extension's line: `plain bookmark: opened, 32
  entries, access started true, stale true`. It listed the same 32 entries the app had.
- **The security-scoped one did not resolve**: "The file couldn’t be opened because it isn’t in the
  correct format." So the kind made for the purpose is the one another program can't use, and the
  ordinary kind carries the access.
- **No refusal was logged**, from the sandbox or from the privacy system, though the extension no
  longer names the folder in its entitlements.
- **"Stale" was true.** The system is saying the bookmark should be made again. It worked anyway;
  what stale costs over time is not known.

So the answer to Syd's question is yes: the app asks, leaves a bookmark in the App Group
container, and the widget extension reads the folder for itself. "The widget extension fills its
own TinyCache" stands for a folder in `~/Documents`.

**What this run does not show.**

- **A sandboxed app.** The app that made the bookmark is the existing one, which is not sandboxed.
  The Store's menubar app will be, and will get the folder from a person choosing it in an open
  panel. Whether a plain bookmark from a sandboxed app opens in its extension is a separate test.
- **An app that a person allowed.** The app's own read of the folder at 22:37:29 raised no prompt
  and no privacy check was logged for it. It was launched from Xcode, and may have been let in on
  Xcode's permission. So the bookmark came from an app that was let in, but not shown to be one a
  person had allowed.

**With the app quit, a fresh extension process opened the bookmark by itself.** Syd quit the app
and Xcode at about 22:42 and left both widgets up. At 22:43:32 a new extension process started and
logged `plain bookmark: opened, 32 entries, access started true, stale true`, then handed over
timelines of 6, 8, 11 and 13 entries. So the extension fetches for itself with no app running.

**The Documents prompts Syd saw were not the widgets'.** He saw prompts for the Documents folder
and took them for the two widgets asking. The privacy daemon's log names who asked:

- **Five prompts**, at 22:38:08, 22:38:15, 22:38:24, 22:43:26 and 22:43:30, all for the Documents
  folder, all for the subject `com.sydpolk.photosgoround`, the app's own identifier.
- **Each was raised by an agent**, `Photos-Go-Round Server`: alternately the Release one in
  `/Applications`, running since 19:39, and the Debug one from Xcode's build folder, running since
  22:27:39 when the Debug app was first launched.
- **Each came with `Failed to match existing code requirement`.** The two agents answer to one
  privacy identity, the app's, and are signed differently: Developer ID and Apple Development.
  Allowing one rewrites the permission for its signature, and the other no longer matches. They
  fall on the agents' five-minute refresh.
- **The widget was restarted by the answer, not by asking.** The system's widget host listens for
  permission changes; the new extension process at 22:43:32 started two seconds after the prompt
  was answered.
- **Each answered prompt disturbs the widget test.** A sixth prompt came at 22:48:35, from the
  Release agent, and six seconds later the widget host started a third extension process, which
  replaced both widgets' timelines part-way through. So a timeline never runs its course while the
  two agents alternate, and the 1-minute reading needs the alternation stopped first.
- **Turning off the wallpaper and the screensaver does not stop it.** Syd did, at about 22:49. The
  prompts come from the agents' own refresh every five minutes, which runs whether or not anything
  is showing pictures; both agents were still running afterwards.
- **Not explained**: why these began at 22:38 and not at 22:28 or 22:33, when the Debug agent was
  already running. The app's bookmark probe first ran at 22:37:29, 39 seconds before the first
  prompt, so it is the likeliest trigger; how is not established.
- **This is the existing product's, not the widgets'.** Release and Debug builds of the app share
  the identifier `com.sydpolk.photosgoround`, so the privacy system cannot keep their permissions
  apart. It is fixed, with one signing requirement stated by every build; *Next: the app's
  sources, then Photos* has the fix and the run that showed it working.
- **Lasting.** Whether the bookmark still opens after a restart, after the app is rebuilt, or after
  the folder moves.
- **iOS.**

Photos is a separate permission, and may not behave the same way; that is still to be found out.

**What else the first run showed.**

- **The widget gallery asked for a snapshot in all five sizes at once**, then for the timeline of
  the one placed: medium, 344×164 points.
- **With no picture loaded the extension holds about 8 MB.** `now 7.9 MB, peak 8.0 MB`. That is the
  floor the 30 MB ceiling is measured from.
- **The extension shows its trouble on its face**, as intended.

## Research: what Apple's documentation says, 2026-10-08

Desk research only: Apple's WidgetKit documentation, WWDC sessions and the developer forums, read on
2026-10-08. Nothing here was measured. The links are under References.

I read Apple's two guides and two forum threads myself: the August 2026 photo-album thread and the
November 2020 every-minute thread. The other forum claims, and what the WWDC sessions say, come from
search summaries of pages I did not open.

### How often a widget can change

- **Apple's guide says timeline entries should be "at least about 5 minutes apart".** It also says to
  keep the interval between entries "as large as possible for the content you display". That is
  guidance rather than a stated hard limit, but it is the opposite of a timeline of entries 10
  seconds apart.
- **WidgetKit "imposes a minimum amount of time before it reloads a widget"**, and "may coalesce
  reloads across multiple widgets". The guide gives no number for the minimum.
- **Entries closer together have been seen to work, late.** In a 2020 forum thread a developer built
  60 entries one minute apart. The widget did change, but lagged by a few minutes. No one from Apple
  answered.
- **The limits are not imposed under Xcode.** A forum answer, which I have only from a search
  summary, says a widget run from Xcode is not held to them, and that outside Xcode it stops
  updating. So a spike has to be watched with the widget installed and Xcode out of the picture.
- **The guide never mentions macOS.** It speaks of iPhone, iPad, Apple Watch and StandBy. Whether a
  desktop widget on the Mac is treated differently is not documented.
- **In StandBy the system redraws at its own rate**, which doesn't count against the budget. CarPlay
  shows widgets in the StandBy style, so the same may hold there; the documentation doesn't say.

### The reload budget

- **40 to 70 reloads a day** for a widget the user looks at often, which the guide puts at one every
  15 to 60 minutes. The budget covers 24 hours and doesn't necessarily reset at midnight.
- **Each widget on screen has its own budget.** Two of the same kind have one each.
- **It depends on use**: how often and when the widget is visible, when it last reloaded, and whether
  the containing app is active. For the first few days the system is learning and a widget may get
  more reloads than it will later.
- **Some reloads are free.** Those made while the containing app is in the foreground, has an audio
  or navigation session, or is the Now Playing app; those caused by an app intent in the widget, such
  as a button; and those caused by an animation, a locale change or an accessibility change.
- **A widget on a rarely visited page gets fewer reloads**, and may be reloaded when the page comes
  into view.
- **Showing the next entry of a timeline is not a reload.** The guide says the extension "is not
  continually active, even if the widget is onscreen", and that WidgetKit draws each entry as its
  date arrives. It does not say outright that drawing an entry never wakes the extension.

### Memory, and how many entries

- **The extension's ceiling is about 30 MB.** Apple engineers say so on the forums; the
  documentation doesn't give a figure. Going over it kills the extension, and reloads after that
  come later than they otherwise would.
- **A photo-rotation widget has hit it.** A thread from August 2026 describes a widget that rotates
  through an album on a timer and is killed at 30 MB with albums of several hundred photos, after
  downsampling and after cutting the number of entries. It has no replies.
- **No maximum number of entries is documented.** Forum reports differ: one saw a widget stop
  updating past about 400 entries, another calls 200 safe and saw odd behaviour at 2,000. At 10
  seconds, 200 to 400 entries is 33 to 66 minutes.
- **The ceiling may be shared by all of an app's widgets.** One forum user concluded so; Apple
  hasn't confirmed it.
- **Not answered anywhere I found**: whether every entry's picture is in memory at once when a
  timeline is handed over, and whether an entry can refer to a file on disk instead.

### CarPlay

- **CarPlay shows iPhone widgets.** First in CarPlay Ultra, and in every CarPlay car since iOS 26.
  They sit in one or more stacks to the left of the Home Screen.
- **The small size only**, in full colour, with the widget's background removed.
- **No CarPlay app is needed.** Supporting the small family is enough. The driver picks the widgets
  in Settings → General → CarPlay on the iPhone.
- **Tapping does nothing for us.** A tap opens the app's CarPlay template, and only certain kinds of
  app are allowed one. Without it the system dims the widget to show a tap has no effect.
- **A widget can be marked a poor fit for CarPlay** with
  `.disfavoredLocations([.carPlay], for: [.systemSmall])`. That doesn't remove it; it tells people
  the location isn't the best one for it.
- **Apple's advice for CarPlay is "glanceable information"** in large type. The page says nothing
  about how often a widget may change there, or about pictures changing while the car moves.
- **The CarPlay Simulator can show a widget**, so the spike doesn't need a car.

### New in 27

- **A new family, `systemExtraLargePortrait`**, on macOS, iOS and iPadOS 27: a 4×6 widget. "Every
  size the platform offers" now includes it. The Mac already had a landscape extra-large,
  `systemExtraLarge`, since macOS 14; where each can be placed is under *Control Center and
  Notification Center on the Mac*.
- **No change to timelines or reloads was announced** that I could find. WWDC26 session 277 covers
  reload policies and testing budgeted reloads; I read the coverage of it, not its transcript.

### Photos: asking for a picture at a size

Read from Apple's reference pages for `PHImageManager` and `PHImageRequestOptions`.

- **`PHImageManager.requestImage(for:targetSize:contentMode:options:resultHandler:)`** takes a
  target size and a fit, aspect fit or aspect fill. Photos "loads or generates an image of the asset
  at, or near, the size you specify", and may give one "slightly larger" because it is cached or
  cheaper to make.
- **`resizeMode` decides how close.** `.exact`: "Photos resizes the image to match the target size
  exactly." `.fast`: "a size similar to, or slightly larger than, the target size." `.none`: no
  resizing.
- **`isNetworkAccessAllowed`** says whether Photos may download from iCloud to answer.
- **`normalizedCropRect`** asks for a cropped part of the picture.
- **An asynchronous request may answer twice**: first a low-quality picture, marked with
  `PHImageResultIsDegradedKey`, then the good one. `deliveryMode` controls that.
- **It is on every platform here**: macOS 10.13, iOS 8 and visionOS 1, and later.
- **It returns a decoded picture in memory**, an `NSImage` or `UIImage`, not a file. Keeping one in
  TinyCache means encoding it to disk ourselves.
- **Not stated**: where the resizing happens, and so whether the full original passes through the
  caller's memory. Inside the extension's 30 MB that has to be measured.
- **The agent does it another way today.** It streams the original to a file with
  `PHAssetResourceManager` and shrinks it with ImageIO; `Plans/Apple Photos Plan.md` has the
  reasons. `Plans/PLAN.md` already lists as unmeasured whether `requestImage` at display size is
  served from a derivative Photos holds locally.

### What this means for the two spikes

- **The refresh spike.** Ten seconds has Apple's guidance against it and is dropped; the intervals
  offered are in Design Decisions. One minute is the only one below the guidance, and a report says
  one-minute entries ran late, so the spike is now about that and about memory. The guide is silent
  on macOS, so a spike is still the only way to learn what the Mac does.
- **The CarPlay spike** is mostly answered: widgets appear, small only, in colour. What is left is
  how a photograph looks with the background removed, and how often it changes on the road.

# References

- `Plans/Product Strategy.md` — the four products, and this one's place among them.
- `Plans/PGR Widgets - iOS.md` — the iOS and iPadOS app, planned separately. Syd, 2026-10-09.
- `Plans/PLAN.md`, Phase 8 (Mac widget) and Phase 5 (iOS widget).
- `Plans/PLAN.md`, *Widgets on macOS, and where the store actually lives* — the App Group analysis.
- `Plans/Logging.md` — the logging rules every binary follows.
- [Keeping a widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date)
  — Apple's guide to timelines, reloads and the budget.
- [Adding StandBy and CarPlay support to your widget](https://developer.apple.com/documentation/WidgetKit/adding-standby-and-carplay-support-to-your-widget).
- [What's new in widgets, WWDC25](https://developer.apple.com/videos/play/wwdc2025/278/) — widgets
  in every CarPlay car.
- [Turbocharge your app for CarPlay, WWDC25](https://developer.apple.com/videos/play/wwdc2025/216/)
  — widgets in CarPlay in iOS 26, the small family, and the locked phone.
- [WidgetLocation.carPlay](https://developer.apple.com/documentation/widgetkit/widgetlocation/carplay)
  — introduced in iOS 26.0.
- [Creating controls to perform actions across the system](https://developer.apple.com/documentation/widgetkit/creating-controls-to-perform-actions-across-the-system)
  — what a control is and how it updates.
- [ControlCenter](https://developer.apple.com/documentation/widgetkit/controlcenter) — available
  from macOS 26.0.
- [WidgetFamily](https://developer.apple.com/documentation/widgetkit/widgetfamily), and its pages
  for [systemSmall](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemsmall),
  [systemExtraLarge](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralarge)
  and [systemExtraLargePortrait](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait)
  — where each size can be placed.
- [MacStories: why third-party apps vanished from the Mac's Control Center](https://www.macstories.net/stories/mystery-solved-why-third-party-apps-vanished-from-the-macs-control-center/).
- [WWDC26 session 277](https://developer.apple.com/videos/play/wwdc2026/277) — WidgetKit
  foundations, and `systemExtraLargePortrait`.
- [Forum: timeline crashes at 30 MB with a large photo album](https://developer.apple.com/forums/thread/842805),
  August 2026, unanswered.
- [Forum: widget crashing with EXC_RESOURCE, limit 30 MB](https://developer.apple.com/forums/thread/713561).
- [Forum: why do popular widgets update every minute?](https://developer.apple.com/forums/thread/667017),
  November 2020.
- [PHImageManager.requestImage](https://developer.apple.com/documentation/photos/phimagemanager/requestimage(for:targetsize:contentmode:options:resulthandler:))
  and [PHImageRequestOptionsResizeMode](https://developer.apple.com/documentation/photos/phimagerequestoptionsresizemode).
- `Plans/Apple Photos Plan.md` — why the agent fetches originals with `PHAssetResourceManager`.
