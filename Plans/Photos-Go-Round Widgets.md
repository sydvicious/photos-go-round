# Summary

Photos-Go-Round Widgets.app: a self-contained App Store app for macOS, iOS, iPadOS and visionOS, with
watchOS widgets served by the iPhone app. It shows your photographs in widgets of every size the
platform offers, and it must pass App Store review. Syd, 2026-09-26.

# Rationale

The App Store can take the widgets but not the screensaver or the wallpaper, so the widgets are the
Store product (`Plans/Product Strategy.md`). A Store app is sandboxed and can't count on our agent
running beside it, so it carries its own agent inside rather than asking one over HTTP. That makes one
design that works the same on the Mac and on devices that never had an agent.

# Phases

- *macOS* — Photos-Go-Round Widgets.app on the Mac App Store.
  - Proof of concept first: the widget is built into the existing Photos-Go-Round app, for testing.
    The menubar app is built separately once that works. Syd, 2026-10-08.
  - Take the proof-of-concept widget out of Photos-Go-Round.app when there is a menubar app to
    carry it.
  - For now the settings are hard-coded: 1 minute, and `~/Documents/Coins/Raw Coin Images`, read
    recursively, as the source.
  - Find out how a widget that has been placed keeps its name.
  - Find out whether the sandboxed extension can read the hard-coded folder, and how.
  - Spike: does a widget change its photograph every minute, and does the extension's memory stay
    flat as a timeline gets longer?
  - Measure a picture at the extra-large widget's size, to set TinyCache's space for 30.
  - Measure what asking Photos for a picture at that size costs the extension in memory.
- *iOS and iPadOS* — the same app on the iOS App Store.
  - Investigate how widgets work on iPhone Duo.
  - Find out whether the widget can query Photos while the phone is locked.
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
- **All the widgets share one database and one set of settings.** Each has its own TinyCache, not
  its own settings.
- **Widgets may show the same picture as each other.** Nothing is done to prevent it.
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
- **TinyCache has space for 30 pictures and fills at most 20.** The space is measured with pictures
  at the extra-large widget's size, and the room for 30 is in case pictures turn out bigger. It
  could instead follow each widget's own size.
- **The widget extension fills its own TinyCache.** It asks the source for its first picture and
  shows it, then keeps one more; there is probably only one picture in the cache at a time. While it
  stays running it can fill up to 20.
- **A widget works with a cache of one, or with none.**
- **On iPhone, TinyCache's files are not protected.** They can be read while the phone is locked,
  which is how it is in the car and on the nightstand.
- **The extension asks Photos for a picture at the size it wants.** `PHImageManager.requestImage`
  takes a target size and can match it exactly. What that costs in the extension's memory is to be
  measured.
- **The menubar app has a second TinyCache of its own, for previews of the widgets.** A preview
  never takes a picture from the queue the widgets draw from. Syd, 2026-10-08.
- **Widgets in every size the platform offers.** No families left out.
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
- Nothing is built. `ConsumerKind.widget` and `Log.widget` exist and are unused.

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
- **`~/Documents` has a privacy prompt of its own on macOS.** Whether that prompt can be raised for
  an extension, or has to be answered through the app, is not checked.
- **Photos is the same kind of question.** The extension needs Photos access of its own, or the
  app's. Not checked.

So the first build finds out whether the extension can read the folder at all. If it can't, the
widget should say so on its face instead of showing nothing.

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
