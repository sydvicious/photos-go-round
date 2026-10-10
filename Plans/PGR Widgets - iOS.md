# Summary

The iOS and iPadOS app of Photos-Go-Round Widgets: one screen with a preview of a widget on top, the
Photos collections under it, and the files and folders at the bottom. The Mac's menubar app shows
the same view in its Settings window. Syd, 2026-10-09.

# Rationale

A widget can't be installed by itself, so the app is what carries the widgets onto a phone, and it
is the only place a person can say which photographs they show. Syd wants it before the Mac's
menubar app (`Plans/Photos-Go-Round Widgets.md`, *Phases*). The phone is also where the widget's
hardest limits are expected to be enforced, so building here first finds them first. The view is
written once and the menubar app takes it afterwards.

# Phases

The order is Syd's, 2026-10-09: the settings view first, in the app alone, and the widget extension
after it. The to-dos under each phase are Claude's.

- **Phase 1** — The app, with the settings view and no widget.
  - Limited Photos access: the "Selected Photos" row and its button.
  - The count on each row, and red for a source that is wrong.
  - The alert, and the picker again, when a source is wrong at opening.
  - The files and folders list, with adding and removing.
  - The sources are written into the App Group container.
  - The preview, at Apple's table of sizes, and the control that changes its size.
  - Try the preview both ways: scrolling off with the lists, and stuck at the top.
  - The "How to add a widget" page and the About page.
- **Phase 2** — The widget extension.
  - An iOS widget extension target, compiling the Mac's source files.
  - The widget reads the sources from the App Group container.
  - The extension records each size it is handed, and the preview uses them.
  - Spike: can the extension open a folder the app chose?
- **Phase 3** — What can only be found out on the phone. The to-dos are the ones under *iOS and
  iPadOS* in `Plans/Photos-Go-Round Widgets.md`.
- **Phase 4** — The App Store: versioning, TestFlight, submission.

# TODO

The iOS app's to-dos are kept here while the work is on its branch. `TODO.md` at the top level is
the project's, and takes the iOS to-dos once this is in `main`. Syd, 2026-10-10.

- **Hidden, in other languages.** Hidden is left out of the pickers by its kind, which PhotoKit
  gives, and not by the name "Hidden". Check on a real library, and with the phone in another
  language, that Hidden always arrives with that kind. If it ever has to be found by name, the
  name is localized and every language's has to be searched for. Syd, 2026-10-10.

# Design Decisions

- **The app is another target in the existing Xcode project.** Not a project or repository of its
  own. Syd, 2026-10-09.
- **Everything of the widgets' is in one folder at the top level, and nothing else moves.** The
  iOS app, both widget extensions and what they share. The larger reorganization, a folder for
  each binary, is deferred. Syd, 2026-10-09.
- **iOS and iPadOS 27 or later.** Syd, 2026-10-09.
- **The app is `com.sydpolk.photosgoround.widgets`, and its extension
  `com.sydpolk.photosgoround.widgets.extension`.** The Mac's menubar app takes the same identifier
  when it comes. Syd, 2026-10-09.
- **The name under the icon is "PhotosGoRound".** It fits whole where "Photos-Go-Round" was cut
  off. Syd, 2026-10-09.
- **Debug, Release and Claude builds each have their own identifier, by the Mac's suffixes.** A
  development build never replaces the Store's on the phone. Syd, 2026-10-09.
- **Tested in a simulator, and on Syd's phone for iCloud Photo Library.** That is the only reason
  for the phone. Syd, 2026-10-09.
- **The iOS widget extension is a target of its own, compiling the same source files as the
  Mac's.** The Mac's target and its release are left alone. Syd, 2026-10-09.
- **One screen, three parts, top to bottom: the preview, the collections, the files and folders.**
  Syd, 2026-10-09.
- **Besides it: a short "How to add a widget" page, and an About page with the version.** Reached
  from a button on the settings screen. Syd, 2026-10-09.
- **The preview's size can be changed, among the sizes the platform's widgets come in.** iPhone and
  iPad offer different ones. Syd, 2026-10-09.
- **The collections list shows the collections that are chosen.** As in the Mac app's Settings
  window. Syd, 2026-10-09.
- **Each list is as tall as the rows it holds: 1 for 1, 10 for 10, 100 for 100.** Neither list
  scrolls by itself; the whole view does. This replaces 3 rows on iPhone and 5 on iPad. Syd,
  2026-10-09.
- **At first launch the app asks for Photos access by itself, and the collections sheet comes up
  once the person has answered.** Nobody has to find the button first. Syd, 2026-10-09.
- **When Photos access is refused, no sheet comes up.** The collections list says access is off,
  with a button to the system's settings; files and folders still work. Syd, 2026-10-09.
- **With limited Photos access, the photographs the person picked are one source, "Selected
  Photos".** Full or none is what Syd prefers, and the system always offers limited. A button
  beside the row changes which are picked; the system's ask on every run is turned off. Syd,
  2026-10-09.
- **The whole Photos library is never chosen for anyone.** A person's library holds things that
  are not fit to put on a screen; only what they chose is shown. Syd, 2026-10-09.
- **With nothing chosen, the preview and the widgets show the Photos-Go-Round app icon.** Plain,
  in full colour, with no words. On iOS and iPadOS only; the Mac widget keeps its sentence. Syd,
  2026-10-09.
- **A button opens the whole library as a checkbox tree, in a sheet.** That is where collections
  are chosen, as in the Mac app's picker. Syd, 2026-10-09.
- **Hidden is never offered, here or in the Mac app's picker.** Syd, 2026-10-10: "neither one
  should have `Hidden`".
- **"Recently Saved" is offered in both.** Syd, 2026-10-10.
- **Anything with the `wholeLibrary` kind is never offered, here or in the Mac app's picker.**
  That is the collection PhotoKit titles *Recents*. Syd, 2026-10-10: "anything that has the
  `wholeLibrary` tag should be excluded".
- **A folder has a tick box and a section heading does not, as on the Mac.**
- **What is ticked when Done is pressed is the set of Photos sources.** Cancel changes nothing.
  The Mac picker's rule. Syd, 2026-10-09.
- **A row shows the source's name and its count, and is red when something is wrong.** Syd,
  2026-10-09.
- **With sources chosen and no picture to be had, the preview and the widgets show the app icon
  greyed over, with "No Photos found".** Every source red, or every source empty. Syd, 2026-10-09.
- **A source is removed by a swipe on its row, by an Edit button's delete mode, or, for a
  collection, by unticking it in the sheet.** All three. Syd, 2026-10-09.
- **Trouble that should pass leaves the source in place, red, until it has passed.** No connection
  is the example. Syd, 2026-10-09.
- **Any other trouble is put to the person when the app is opened or brought forward: an alert,
  then the picker again.** If they don't put it right, the source is removed. Both lists; and
  several wrong at once get one alert that names them all. Syd, 2026-10-09.
- **The files and folders are at the bottom, in a list that works the same way.** It takes single
  image files as well as folders, as the Mac's does. Syd, 2026-10-09.
- **Each folder has its own option for including its subfolders, changed by tapping its row.** It
  starts off. As on the Mac. Syd, 2026-10-09.
- **The Mac menubar app's Settings window has this same view.** Syd, 2026-10-09.
- **Nothing about the menubar app is decided until there is a good version of the iOS app.** Its
  questions wait. Syd, 2026-10-09.
- **A widget changes every five minutes, until there are settings for it.** As on the Mac. Syd,
  2026-10-09.
- **Nothing in this view sets how often a widget changes.** That is to be each widget's own
  setting, and it belongs to the widget (`Plans/Photos-Go-Round Widgets.md`, *Design Decisions*).
- **Everything in `Plans/Photos-Go-Round Widgets.md` holds here.** A normal app, Photos the
  expected source, and a TinyCache of the app's own for the preview.
- **The Photos reading is a shared target of its own, `PhotosGoRoundPhotoLibrary`, carved out of
  the kit.** The Widgets app links that and not the kit. Syd, 2026-10-09.
- **The tree that files collections under their folders is one builder, in
  `PhotosGoRoundAgentAPI`.** The Mac app and the Widgets app both draw from it. Syd, 2026-10-09.
- **The settings view and its models are a package target, `PhotosGoRoundWidgetSettings`, in
  `Widgets/Shared/Sources`, beside `TinyCache`.** The iOS app and the Mac's menubar app both link it, and its models are tested by
  the `Package Tests` scheme. Syd, 2026-10-09.
- *Proposed:* **the view is written once, in SwiftUI, for iOS, iPadOS and the Mac.** The preview's
  sizes are what differs by platform.
- *Proposed:* **the preview draws the widget's own view**, so what it shows is what a widget shows.
- **The preview is drawn at the widget's real size, centered, and cropped on either side when the
  view is too narrow.** It is never shrunk: a person is to see what the picture actually looks
  like. The view can be resized. Syd, 2026-10-09.
- **The preview shows the Home Screen sizes and nothing else.** Where else a photograph may end
  up, such as StandBy, CarPlay or the Lock Screen, is not previewed here. Syd, 2026-10-09.
- **The Lock Screen's own sizes are not built.** The circle, the rectangle and the line of text.
  Syd, 2026-10-09.
- **The real size comes from the system: the extension records each size it is handed, and the
  preview reads them.** Apple's table of sizes stands in until then. Widgets differ in size from
  phone to phone, the Duo especially. Syd, 2026-10-09.
- **The layout is the same on an iPad in landscape: one scrolling column.** Not the preview beside
  the lists. Syd, 2026-10-09.
- **The view scrolls vertically.** The preview is never cropped in height; a person scrolls down
  to the settings when they don't fit under it. Syd, 2026-10-09.
- **Whether the preview stays at the top while the lists scroll is to be tested both ways.** Syd,
  2026-10-09.
- **The preview's picture changes by itself every few seconds, and on a tap.** A small slideshow,
  not a widget's five minutes. Syd, 2026-10-09.
- **When Photos access is turned off later, the chosen collections stay, red.** The list says
  access is off, with the button to the system's settings; none is removed. Syd, 2026-10-09.
- **On a phone the sizes are small, medium and large, and all three fit.** The really big widgets
  are not on a phone. Syd, 2026-10-09.

# Background

- The widget exists on the Mac only, inside Photos-Go-Round.app, in `Widgets/macOS/Sources`.
- The Mac app's Settings window has the two lists already: chosen collections with a floor of 4
  rows, and files and folders with a floor of 5. *Choose Collections…* opens a second window with a
  checkbox tree of the whole library.
- The Mac app does all of that by asking the agent over HTTP. The Widgets app has no HTTP and no
  agent process, so the look carries over and the code underneath does not.
- `TinyCache` is in `Widgets/Shared/Sources` and `PhotosGoRoundAgentAPI` in `Shared/Sources`, and
  `Package.swift` already lists iOS 27. The kit, which reads the library's collections, is under
  `MacOS/`.

# Detailed discussions

Written by Claude on 2026-10-09 from the first description of the app. Where something is from
memory rather than checked, it says so.

## The order of the work

Asked on 2026-10-09 which order the phases take, Syd chose the settings view first, in the app
alone, with the widget extension added after it. The other two orders offered both began with a
widget on the phone from a fixed source.

What that order means for the pieces below:

- **The preview starts on Apple's table.** The real sizes come from the extension, and there is
  none in Phase 1. The table is the fallback already decided on, so nothing is thrown away when
  the extension arrives.
- **The preview still draws the widget's own view.** The view's source file is compiled into the
  app from the start, and into the extension when there is one.
- **The app writes its sources into the App Group container from the start**, though nothing reads
  them until Phase 2.
- **The folder question is answered after the folders list is built.** See *The files and
  folders*.
- **A simulator does for everything except iCloud Photo Library.** Syd, 2026-10-09: "the only
  reason i wanted to test on phone is to test with icloud photo library. we can test everythingmelse
  including files and folders and simple photo library on sim". See *Where it is tested*.

## Where it is tested

Syd, 2026-10-09: "the only reason i wanted to test on phone is to test with icloud photo library.
we can test everythingmelse including files and folders and simple photo library on sim". This
replaces "tested on his own phone, not in a simulator", which `Plans/Photos-Go-Round Widgets.md`
had under its iOS phase.

- **In a simulator:** the layout at iPhone and iPad sizes, files and folders, and a Photos library
  kept on the device, which in a simulator is Apple's few sample pictures and whatever albums are
  made there.
- **On Syd's phone:** iCloud Photo Library, where a picture may not be on the device and has to be
  fetched.
- **Also only on a phone**, by their nature and not by this rule: the extension's memory against
  the 30 MB ceiling, which a simulator is not expected to enforce, and what a widget can do while
  the phone is locked. Both are to-dos under the iOS phase of `Plans/Photos-Go-Round Widgets.md`.
- **Which simulators.** Claude's own, *Claude iPhone* and *Claude iPad* on iOS 27, no more than two
  running at a time. Every other simulator on the Mac is Syd's.

## What Syd said

2026-10-09: "At the top of the view will be a preview. You can change the size of the preview to
match the sizes supported by the platform (iOS vs iPadOS). Below that is the collection picker like
we have in the Mac app, but with only 3 lines (iOS)/5 lines (iPadOS) showing (scrollable), and then
at the bottom the file/folders picker sized the same way. (The Mac Menu Bar Settings window will
also have this view)". And then: "This should be a new plan called "PGR Widgets - iOS.md"".

## The sizes the preview can take

The Mac widget supports five families today: small, medium, large, extra large, and extra-large
portrait. What each platform offers, as far as is known:

- **iPhone**: small, medium and large. Syd, 2026-10-09: "the really big widgets won't be on a
  phone".
- **iPad**: small, medium, large and extra large.
- **Mac**: the five it supports now.

**Apple's two pages disagree about extra-large portrait.** Read 2026-10-09. The design guidelines'
table says extra large is "Not supported" on iPhone, and extra-large portrait is not supported on
iPhone or iPad. The WidgetKit page for `systemExtraLargePortrait` says it "can appear on the Home
Screen on iOS, on the Today View on iOS and iPadOS, on the Desktop on macOS, and on visionOS", from
iOS and iPadOS 27.0. The phone and an iPad settle it: declare the family and see whether the widget
gallery offers it. The preview offers a size only where the gallery does.

**The preview is of the Home Screen sizes only.** Syd, 2026-10-09: "the fact that photos may end up
elsewhere is not going to be previewed here". A widget's photograph can turn up in other places.
From Apple's design guidelines, read 2026-10-09: the small widget is also shown in StandBy and
CarPlay on an iPhone and on the Lock Screen on an iPad, and every size is in Today View. None of
those is previewed.

**The Lock Screen's own sizes.** iPhone and iPad also have three accessory families for the Lock
Screen: a circle, a rectangle, and a line of text. From memory: the system draws them in one tint,
without colour, and the line of text can't hold a picture at all. Asked on 2026-10-09 whether they
count as sizes for this app, Syd chose "Home Screen sizes only": they are not built.
`Plans/Photos-Go-Round Widgets.md` said "Widgets in every size the platform offers. No families
left out", written about the Mac, where there are none of them; it now says every Home Screen
size.

**The control.** A segmented control under or over the preview, one segment for each size the
device offers. On the Mac the same control shows the Mac's five.

## How the preview is drawn

**It draws the widget's own view.** `PhotoWidgetView` is plain SwiftUI and takes an entry; the app
can show it in a frame of the widget's shape. Then fit, the black around the picture, and the
"Scanning…" face are the widget's own code and can't drift from it. The view loads its picture
through `NSImage` today, so it needs the same two-platform treatment `PhotosSource` already has.

**At real size, centered, cropped at the sides.** Syd, 2026-10-09: "the preview should be drawn at
scale, centered, and cropped on either side if the view is not big enough. the user will be able to
resize the view, but I really want them to know what the pic actually looks like". So the preview
is never shrunk to fit. When the view is narrower than the widget, the widget stays centered and
its left and right edges are cut off equally; widening the view shows more of it. That is the case
for an extra-large widget on an iPad in a narrow window, and for the Mac's Settings window drawn
narrow. An earlier proposal of Claude's, to scale the widget into a space of fixed height, is
dropped.

**The whole view scrolls vertically.** Syd, 2026-10-09: "and they can scroll vertically to get to
the settings". So the preview is never cropped in height: its space is as tall as the size chosen,
the lists come after it, and when the view is too short for all of it a person scrolls down to
them. Width is cropped; height is scrolled.

**The lists do not scroll by themselves.** First the lists were 3 or 5 rows and scrolled inside
the scrolling view, which meant one scrolling thing inside another. Since each list is now as tall
as its rows, there is one thing that scrolls, the whole view, and a drag anywhere moves it. See
*The lists are as tall as their rows*.

**On a phone all three sizes fit across.** From the table in Apple's design guidelines, read
2026-10-09, in points:

| Phone screen | Small | Medium | Large | Height left under a large widget |
|---|---|---|---|---|
| 375×812 | 155×155 | 329×155 | 329×345 | about 390 |
| 393×852 | 158×158 | 338×158 | 338×354 | about 405 |
| 430×932 | 170×170 | 364×170 | 364×382 | about 455 |

"Height left" is the screen less the system's top and bottom margins, which are from memory, and
the widget. With a large widget chosen that is room for the size control, the two headings with
their buttons, and about six rows between the two lists at 44 points a row. More sources than
that and the lists run off the bottom, and the person scrolls. The table as read has no row for
the 402×874 screen of Claude's simulators' iPhone 17; the page was not read to its end.

**The sizes do differ from phone to phone.** Syd, 2026-10-09: "I am afraid that the widgets will be
different sizes on each different model phone". They are: Apple's table has six different sets
across ten phone screens, a large widget running from 292×311 to 364×382 points, and the three rows
above are only a sample of it. From memory: Display Zoom changes them again on the same phone, and
an iPad's differ between portrait and landscape. So a preview at real size needs this device's
sizes, and one fixed set would be wrong on most phones.

**"Especially the Duo."** Syd, 2026-10-09. Nothing about the iPhone Duo's widgets has been read
for this plan; *Investigate how widgets work on iPhone Duo* is a to-do in
`Plans/Photos-Go-Round Widgets.md`. If its widgets are one size closed and another open, then one
phone has two sets of sizes, and it may offer sizes other phones don't. That is a reason to take
the sizes from the system as they are handed over, and to keep them by the screen they were handed
for, rather than one set for the device.

**Where the real size comes from.** From memory, not checked: no call gives an app a widget's size.
The extension is told its size each time it is asked for a snapshot or a timeline, and the app has
no way to ask what a medium widget measures on this device. Two ways to know it:

- **Apple's table**, kept in the app, by screen size. It has to be kept up as phones change.
- **The extension writes down each size it is handed**, in the App Group container, and the app
  reads them. On the Mac the widget gallery asked for all five sizes at once the first time it was
  opened (`Plans/Photos-Go-Round Widgets.md`, *What else the first run showed*), so the real sizes
  would be known from then on. Until then the table stands in.

Syd chose the second, with the first as its fallback, on 2026-10-09. Real size is the point of the
preview, and only the system knows it for certain.

**What the fallback costs.** Until the extension has been asked for a size, the preview uses the
table, looked up by the screen's size, which the app does know. A phone newer than the table gets
the row for the nearest screen, and may be a few points out until the widget gallery is first
opened. Whether the gallery on iOS asks for every size at once, as the Mac's did, is to be seen on
the phone.

**Where its pictures come from.** The app's own TinyCache, as already decided, so a preview never
takes a picture a widget was going to show. The app is not held to the extension's 30 MB.

**The preview is a small slideshow.** Syd, 2026-10-09: its picture changes by itself every few
seconds, and also when the person taps it. He chose that over changing only on a tap, and over
every five minutes as a widget does. So a person sees many of their pictures in the widget's shape
without waiting, which is what the preview is for. It draws from the app's own TinyCache, so it
takes nothing from the widgets, and the app is not held to the extension's memory.

**Claude's reading, not said:**

- It also starts again when the sources change, so a newly chosen collection is seen at once.
- The number of seconds is settled when it is seen running; 5 is the proposal.
- One picture fades into the next, as in the widget, since the preview is to show what a widget
  looks like.
- It stops when the app is not in front.

**Not yet said:**

- Whether the preview shows the "Scanning…" face while the first picture is fetched.

## The collections

**The Mac has two things, and "the collection picker" could be either.**

- **The list of chosen collections**, in the Settings window: one row for each collection that is
  chosen, filed under its folders, with its state beside it ("not reachable" and the like). Its
  floor is four rows.
- **The picker**, in a window of its own: every collection in the library as a checkbox tree, with
  twisties, counts, and a mixed state for a folder with some of its albums chosen. What is ticked
  when Done is pressed is the set of Photos sources.

**The list is the first, and the picker is a sheet.** Syd, 2026-10-09, choosing between the two:
the list shows the collections that are chosen, and a button brings up the tree of the whole
library as a sheet. That is the Mac's arrangement made small. The tree itself seen three rows at a
time would be hard to use on a phone: a library can have hundreds of albums.

**The sheet is a chooser, as the Mac's picker is.** Syd, 2026-10-09. It opens showing what is
already ticked. What is ticked when Done is pressed becomes the set of Photos sources, so unticking
a collection removes it. Cancel leaves the sources as they were, and nothing changes until Done.

**A row shows the name and the count, and is red when something is wrong.** Syd, 2026-10-09: "name
and count and red if something is wrong". The Mac's row also shows the folders a collection sits
under and its state in words; here the folders are seen in the sheet, and the colour says there is
trouble.

## The lists are as tall as their rows

Syd, 2026-10-09: "lets make the list dynamically resize to show the correct number of rows for both
pickers". Asked what the correct number follows, with three readings offered, he gave a fourth: "1
for 1, 2 for 2, ..., 10 for 10, ... 100 for 100, etc. the entire view be be vertically scrollable".

- **Both lists**, the collections and the files and folders, are exactly as tall as the rows they
  hold. There is no cap, and neither scrolls by itself.
- **The whole view scrolls**, preview and both lists together.
- **This replaces the first description**, "only 3 lines (iOS)/5 lines (iPadOS) showing
  (scrollable)". Nothing now differs between iPhone and iPad in the lists.

What follows from it:

- **The files and folders can be a long way down.** With forty collections chosen, the second
  list starts forty rows below the first, and the preview has scrolled off the top by the time a
  person reaches it.
- **Whether the preview scrolls away with the rest is to be tried both ways.** Syd, 2026-10-09:
  "we should try it having the preview stick and the rest scrollable. will have to test both
  ways." One way the preview scrolls off with the lists; the other it stays at the top and the
  lists scroll under it. With the preview stuck, a large widget leaves about six rows of a phone's
  screen for the lists, and a tall one on an iPad or the Mac leaves less than it sounds.
- **An empty list** has no rows. It still needs its heading and its add button, and perhaps a line
  saying nothing is chosen.
- **In SwiftUI** a `List` takes whatever height it is given and scrolls inside it, so rows that
  simply stack in the scrolling view, or one `List` for the whole screen with the preview as its
  first row, fit this better than a `List` for each. To be decided when it is built.

## Taking a source out of a list

Offered three ways on 2026-10-09, Syd: "all three". So on iOS and iPadOS a source leaves its list
by any of these:

- **A swipe to the left on its row**, in both lists.
- **An Edit button**, which puts the lists into delete mode with a red minus beside each row.
- **Unticking it in the sheet**, for a collection, and pressing Done.

Claude's reading: "all three" is all three ways together, so a collection can be swiped away or
deleted in Edit mode as well as unticked. The Mac keeps what it has, select a row and press the
minus button, with unticking for collections. In SwiftUI one `onDelete` on a list's rows gives the
swipe and the Edit button's delete mode together.

**Not said:** whether removing a source asks "are you sure". The Mac app does not ask.

## When a source goes wrong

Syd, 2026-10-09: "when the use opens/brings the app forward, if something is wrong (other than no
connectiv or other conditions that should be temporary), we present an alert and the picker is
invoked again. if they don't fix the problem, the source will be removed. source will stay red
until temp condition resolved".

So there are two kinds of trouble, and the app checks for them each time it is opened or brought
to the front:

- **Trouble that should pass**, such as no connection. The source stays, its row is red, and it
  goes back to normal when the condition has passed. No alert, and nothing is removed.
- **Trouble that will not pass by itself.** The app puts up an alert saying what is wrong, and
  then brings up the picker again so the person can put it right. If they leave the picker without
  putting it right, the source is removed.

**"Source" covers both lists.** Confirmed by Syd, 2026-10-09: a file or folder that is gone, or
can no longer be opened, is treated as a collection that is gone is. The alert comes when the app
is opened or brought forward, then the Files browser so the person can choose it again, and it is
removed if they do not.

**The count**, Claude's reading: the number of pictures in the source; the widget already counts each source to weigh
its picks (`Plans/Photos-Go-Round Widgets.md`, *Seen with 0.7 (5) installed*), and the Mac's picker
shows a count beside each album.

**Which trouble is which, proposed:**

- *Will not pass:* a collection that is no longer in the library; a file or folder that is no
  longer where it was, or whose bookmark no longer opens.
- *Should pass:* no connection, for photographs kept in iCloud and for folders in iCloud Drive or
  on a server; a drive that is not plugged in.

**Photos access turned off is neither kind.** If a person turns Photos access off in the system's
settings after choosing collections, every collection is wrong at once, and the rule as written
would alert and then remove them all. Syd, 2026-10-09: they stay, red, and the list says access is
off, with its button to the system's settings. Nothing is removed, so turning access back on
brings every one of them back.

**Several wrong at once get one alert.** Syd, 2026-10-09. The alert names all of them. Then the
collections sheet comes up once, if any collections are among them, and then the Files browser for
each file or folder in turn. One interruption, where an alert and a picker for each source would
be several. A collection that is gone can't be ticked again in the sheet, so "putting it right"
there means choosing others or pressing Done without it; either way it leaves the list.

**A source with nothing in it is not wrong.** Syd, 2026-10-09. An album with no photographs, or a
folder with no images, shows a count of 0 in the normal colour. No alert, and it is not removed:
an empty album is often one the person means to fill.

**With sources chosen and no picture to be had, the preview and the widgets show the app icon
greyed over, with "No Photos found".** Syd, 2026-10-09. That is every source red, as with no
connection, or every source empty. It is the "Scanning…" face with other words. The words are his,
with the capital P: first "No photos found", then "No Photos found". He chose it over
the last picture staying up, and over the plain icon.

So there are three faces without a photograph, on iOS and iPadOS:

| When | What is shown |
|---|---|
| Nothing is chosen | The app icon, plain, in full colour, no words |
| Waiting for the first photograph | The app icon greyed over, "Scanning…" |
| Sources chosen, no picture to be had | The app icon greyed over, "No Photos found" |

Claude's reading, not said: a widget that already has a picture goes to "No Photos found" at its
next change, when it asks for another and gets none, and not before.

**Not said:**

- Whether the Mac's menubar app does the same. It is to show this same view.

**First launch.** Asked on 2026-10-09 what the preview and the widgets show before anything is
chosen, Syd: "the user will automatically be prompted. The collections selector will come up after
the user asks for photos permission". So the order at first launch is: the app opens, the system's
Photos prompt appears without the person doing anything, and when it has been answered the
collections sheet comes up. A person is led straight to choosing, and the time with nothing chosen
is short.

**With nothing chosen, the preview and the widgets show the Photos-Go-Round app icon.** Syd,
2026-10-09, asked what they show if the sheet is closed with nothing ticked: "the pgr app icon".
He chose it over a message telling the person to choose some photographs, and over showing the
whole Photos library.

**Never the whole library.** Claude had offered the whole Photos library as what to show until
something is chosen, twice. Syd, 2026-10-09: "we never choose the whole photo library. people have
all kids of shit that's not appropriate". A widget is on the Home Screen, in StandBy and in the
car, where other people see it. So nothing in the app falls back to everything, no control offers
everything in one tap, and a picture reaches a widget only from a collection, file or folder the
person chose. The same holds for the rest of Photos-Go-Round, and is written in
`Plans/Photos-Go-Round Widgets.md` too.

- **The Mac widget keeps its words.** With no sources it shows "No sources are set in
  Photos-Go-Round." (`PhotoTimeline.nothing(in:)`). Asked on 2026-10-09 whether the Mac's widget
  shows the icon too, Syd chose the icon on iOS only. The iOS extension compiles the same file, so
  this is one of the places where the shared source differs by platform.
- **It is the plain icon, in full colour, with no words.** Syd, 2026-10-09. A widget waiting for
  its first photograph shows the icon greyed over, with "Scanning…", so the two faces can't be
  mistaken for each other.
- **Where the icon comes from on iOS.** The Mac's widget asks `NSWorkspace` for the icon of the app
  that carries it. iOS has no such call, so there the icon is a picture in the extension's own
  assets.

**When Photos access is refused, no sheet comes up.** Syd, 2026-10-09. The collections list says
that Photos access is off, with a button that opens the system's settings, where it can be turned
on. Files and folders still work, since they need no Photos access. The Mac's picker has the same
kind of face for a library it may not read (`CollectionPickerView.unauthorized`).

**What the sheet leaves out.** Two things, and a section with nothing left to show has no heading.

- **Hidden**, in every picker. Syd, 2026-10-10: "Mac has "Recently Saved" and "Hidden"", then
  "neither one should have `Hidden`", and "Both should have "Recently Saved"". So Hidden came out
  of the Mac's picker as well, in the one place both get their sections,
  `LibrarySectionGroup.grouped`. It is told by its kind, which is PhotoKit's
  `smartAlbumAllHidden`, and not by its name; see *TODO* for what that leaves to check.
  `Plans/Apple Photos Plan.md` had "Nothing is hidden from the picker" and now has Hidden as its
  one exception. A Hidden source somebody chose on the Mac before this stays in the Settings list
  until they remove it there; the picker no longer shows it to untick.
- ***Recents***, here only, and Claude's doing, in question. It is the collection PhotoKit hands
  over as `smartAlbumUserLibrary`, which this code calls `wholeLibrary`, and "Recents" is
  PhotoKit's title for it. Claude left it out of the sheet as the whole library, and wrote that an
  iPhone calls it *Recents* and that it is every photograph. Neither was checked. Syd, 2026-10-10:
  "there is no "Recents" in the GUI for Photos on iPhone. And it would not be the entire library
  anyway." `Plans/Apple Photos Plan.md` already says as much: it "is not quite "everything"", since
  it excludes what is hidden and its relation to shared content varies. On his Mac it holds 96,306
  photographs, against 38,136 in Recently Saved and 8,452 in Favorites, so it is most of the
  library and not all of it.
  Then, the same day: "I take that back. I see it in PGR Mac, and it has 93K items in it." So it
  is in the Mac's picker, as the agent's list said.
- **It is left out of both pickers, by its kind.** Syd, 2026-10-10: "anything that has the
  `wholeLibrary` tag should be excluded". It went the way Hidden did: one rule, in
  `LibrarySectionGroup.grouped`, and the iOS sheet's own copy of it is gone. A *Recents* source
  somebody chose on the Mac before this stays in the Settings list until they remove it there.
- **"Recently Saved" stays in both.** It is one of the smart albums PhotoKit does not name, so it
  arrives as an unnamed kind and is listed under *Utilities*. On Syd's Mac it held 37,550
  photographs when it was measured on 2026-08-26 (`SystemPhotoLibrary.kind(of:)`), which is close
  to everything; it is offered because he asked for it.

**Asked of the running agent, 2026-10-10.** Syd sent the Mac picker's *Utilities* section as it
was that morning, with Hidden in it: "You are wrong. This is from Photos-Go-Round on the mac right
now". He was right that it was there. The rule that leaves Hidden out was written at 08:51 and
was not committed or installed; the agents serving his picker had started at 08:00 and 08:07.
Claude had reported it as done in both pickers when it was done only in the source.

The Release agent's own list, `GET /v2/photos/albums`, 440 collections:

| Title | Kind |
|---|---|
| Hidden | `hidden` |
| Recents | `wholeLibrary` |
| Recently Saved | `otherSmartAlbum` |
| Captured by Me, Dual Capture, Recovered, Reference | `otherSmartAlbum` |
| Unable to Upload | `unableToUpload` |
| Favorites | `favorites` |

- **Hidden does arrive with its own kind** on this library, so leaving it out by kind works here
  once the agent is built from this source. Another language is still to be checked; see *TODO*.
- **The Mac's picker does list *Recents***, with 96,306 photographs. Its kind files it under
  *Albums*, among 350 albums sorted by name. What each picker should do with it is asked the same
  day.

**Tick boxes are where the Mac has them.** A folder has a box, which ticks or clears the albums
under it; a section heading has none. Claude first wrote that the Mac's section headings had a
box and that leaving it off was a difference. Syd, 2026-10-10: "there is no section tick on the
mac". He is right: `CollectionPickerView.twisty` draws the box only when the row is not a
section.

**One difference that is left.** On the Mac a section heading opens and shuts its section. Here
only folders open and shut. Not said: whether sections should too.

**Not said about first launch:**

- Whether the Mac's menubar app does the same at its first launch. It is to show this same view.

**One copy of what the Mac already has.** Asked on 2026-10-09 how the Widgets code should get the
tree-building and the Photos reading, both of which were tied to the Mac, Syd chose one copy that
everything uses over new code beside the old.

- **The tree builder**, `Foldered` and `FolderNode`, is in `PhotosGoRoundAgentAPI`, which the Mac
  app and the Widgets settings both link. It was in the Mac app's own target. The Mac app keeps
  only which of its types are laid out that way.
- **The Photos reading was in the kit**, and it was not a small piece: about 1,900 lines, with
  collections, assets and image data behind one protocol, `PhotoLibrary`, and one PhotoKit type,
  `SystemPhotoLibrary`. About 25 files of the agent, the kit and their tests use it.
- **The kit compiles for iOS as it is.** Checked 2026-10-09, for the simulator. So the Widgets
  settings could have linked the whole kit and moved nothing. Syd chose the other way: the Photos
  reading carved out into a shared target of its own, which the Widgets app links.
- **The new target is `PhotosGoRoundPhotoLibrary`**, after the `PhotoLibrary` protocol at its
  centre, in `Shared/Sources`. Syd, 2026-10-09. It holds the protocol, `SystemPhotoLibrary`,
  `BoundedPhotoLibrary`, `LibraryCollection`, `PhotosCollectionCatalog` and `RequestBudget`. The
  kit depends on it and keeps `PhotosCollectionSourceProvider`, which is the kit's own.
- **It was to be on a separate branch for its size**, and was done on the iOS branch: Syd,
  2026-10-09, "not doing a new branch; don't need it".
- **Two small helpers went to `PhotosGoRoundAgentAPI`**, because the kit and the new target both
  use them: `BlockingWork`, and `Duration.milliseconds`.
- **Its tests are still in the kit's test target**, so that the move only moved. A test target of
  its own is a later tidying.

**What else carries over.**

- `CollectionPickerView` imports AppKit for one thing, the checkbox with a mixed state, which
  SwiftUI's `Toggle` doesn't have. On iOS that is a button drawn with one of three symbols.
- `CollectionsModel` asks the agent for the library over HTTP. Here the library is read in the
  app's own process, through the carved-out target.

**Limited access: the picked photographs are one source.** On iOS the Photos prompt has three
answers: full access, none, and limited, where the person picks particular photographs for this
app. Syd, 2026-10-09: with limited access the collections list shows a single row, "Selected
Photos", and the widgets show those. They are photographs the person chose for this app. The row
exists only while access is limited, so it is never a way to the whole library.

**Full or none would be better, and the system does not allow it.** Syd, 2026-10-09: "if we can
just have full or none, and not have limited, that is what i prefer." Apple's article on the
limited library, read 2026-10-09, describes no way for an app to take the limited answer out of the
prompt: "The limited Photos library affects all apps that use PhotoKit in iOS 14, including those
already published to the App Store." So the limited case has to be built. From the same article:

- **Albums can't be listed.** "You can't create or fetch user albums."
- **The older calls don't tell limited from full.** `authorizationStatus()` answers "authorized"
  for both; the app has to ask with `authorizationStatus(for:)`.
- **The system asks the person to change their selection once each time the app runs**, unless
  the app turns that off with an `Info.plist` key and brings up the system's picker itself, from a
  button.

**A button of ours changes the picked photographs.** Syd, 2026-10-09: a button beside the
"Selected Photos" row brings up the system's picker
(`PHPhotoLibrary.presentLimitedLibraryPicker(from:)`), and the system's ask on every run is turned
off with `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` in `Info.plist`. So the person is
asked when they want to change it, and not each time the app opens.

From memory, not checked: the Mac has no limited answer, so there it is full or none already.

**The extension and Photos.** The app asks for access; an extension can't put up the prompt. On
the Mac the widget extension turned out to share what the app was granted
(`Plans/Photos-Go-Round Widgets.md`, *Next: the app's sources, then Photos*). Whether it is the
same on iOS is to be seen on the phone, with the locked-phone question already listed.

## The files and folders

**Single files as well as folders.** Syd, 2026-10-09: the bottom list takes both, as the Mac's
does, so the shared view is the same everywhere. The Mac app has a menu item for each, *Add
Files…* and *Add Folder…*.

**Each folder has its subfolders option, as on the Mac.** Syd, 2026-10-09, choosing that over a
folder always including its subfolders. Tapping a folder's row brings up its options, where the
Mac app has a sheet with the folder's name, its location and one switch, "Add contents of
contained folders" (`ConfigureSourceView`). The widget's code already reads the option for each
folder, as `SourceSpec.recursive`. A newly added folder starts with it off, as on the Mac: only
the pictures directly in the folder, so a folder never brings in more than was asked for. Syd,
2026-10-09.

**Choosing.** SwiftUI's `fileImporter` on both platforms, in place of the Mac app's `NSOpenPanel`.
It puts up the Files browser on iOS and the open panel on the Mac, and can be asked for folders or
for image files.

**The risk is the widget reading what the app chose.** A sandboxed app is given a folder only
because the person chose it, and keeps that with a bookmark. The widget is another process. On the
Mac a bookmark the app leaves is what the widget opens today (`Widgets/macOS/Sources/OpenedFolders`).
From memory, not checked: iOS bookmarks are made without the Mac's security-scope option, and
whether an extension can open one its app made is not something I know. If it can't, a folder's
pictures would have to be copied into the App Group container, or folders would work only in the
preview. The spike needs an extension, so with the settings view first it comes in Phase 2, after
the list is built. If the answer is no, the list stands and what changes is what adding a folder
does underneath.

**Folders in iCloud Drive** may not be downloaded. From memory: reading one can mean waiting for
it, which a widget extension has little time for.

**It matters least here.** Syd, 2026-10-08: on an iPhone hardly anyone will use a folder, on an
iPad slightly more will.

## The App Group comes first on iOS

The Mac widget reads the app's sources from the app's preferences, through an entitlement the
Store does not accept; moving them into the App Group container is a to-do under the menubar app
in `Plans/Photos-Go-Round Widgets.md`. iOS has no such entitlement at all, so the iOS app and its
widget use the container from the start, and the menubar app then takes what is already built.
`Settings.sources()` in the widget is the one place that reads them.

## Where the code lives

**In one folder at the top level, with everything else of the widgets'.** Syd, 2026-10-09, in two
steps. First: "just make an ios folder and continue with what we are doing. i'm good if you can
work it." Then: "however, let's go ahead and put all of the widget stuff in one folder at the top.
Don't move anything else". So the widgets get the folder his larger reorganization would have
given them, and every other binary stays where the first reorganization put it.

**The folder is `Widgets`, with `macOS`, `iOS` and `Shared` inside it.** Syd, 2026-10-09, choosing
Apple's spelling of macOS over the `MacOS` of the existing top-level folder.

- `Widgets/macOS` — the Mac's widget extension: `Sources`, and `Resources` with its `Info.plist`
  and its entitlements. It was `MacOS/Widget`.
- `Widgets/Shared` — what both platforms' widgets use. `Sources/TinyCache` and
  `Tests/TinyCacheTests` are there, from the top-level `Shared/`. The settings view and its models
  go there too, as a package target of their own with a test target beside it: Syd, 2026-10-09,
  choosing that over plain files added to each app target. The models are written test-first.
  The target is `PhotosGoRoundWidgetSettings`, in the style of the package's longer names, and its
  tests are `PhotosGoRoundWidgetSettingsTests`: Syd, 2026-10-09, over the shorter `WidgetSettings`.
- `Widgets/iOS` — the iOS app and its widget extension. It is made when the first file goes into
  it; an empty folder is nothing to git.

**What stayed**, though it has "widget" in its name: `WidgetFolderBookmark.swift` in
`MacOS/Desktop/Sources` is Photos-Go-Round.app's own file, and the plans stay in `Plans/`.

**The larger reorganization is deferred.** The question of where the settings view goes first
drew this from Syd, 2026-10-09: "I am thinking we need to reorganize the project into a folder for
each binary: agent, app, menubar, wallpaper, screensaver, widget, pgr_ctl, global. The only one of
those that is cross platform is widget, and that would have macOS, iOS, ans Shared. That's a lot of
work, but for me, will pay off over time." It was written up as `Plans/Project Source Reorg 2.md`,
and the same day he set it aside: "let's not do that source reorg", and "Keep the plan, but put at
the top "DEFERED"". That plan is marked deferred and nothing in it is under way.

## The menubar app's questions wait

Syd, 2026-10-09: "we are not answering question about menubar app until we have a good version of
the ios app". So these, which the sections above mark as not said, are not asked until then:

- Whether its Settings window grows and scrolls as this view does.
- Whether it has the first-launch flow, and the alerts when a source goes wrong.
- Where its About and "How to add a widget" pages are reached from.
- Whether its preview is tried stuck at the top as well.

What is already decided about it stands: it shows this same view, and it takes the same bundle
identifier.

## One view for three platforms

The menubar app's Settings window is to show the same view, so the view and its models go where
both an iOS target and a Mac target can compile them: `Widgets/Shared/Sources`, beside
`TinyCache`. What
differs by platform is small: the sizes the preview offers, and the checkbox. The lists are as
tall as their rows on every platform, so no row count differs. Whether the menubar app's window
does the same, growing and scrolling as this one does, was not said.

The existing Photos-Go-Round.app keeps its own Settings window. It talks to an agent and this view
does not.

## iPad

The same view, and the same order top to bottom, whichever way the iPad is held. Syd, 2026-10-09:
in landscape too it is one scrolling column, the preview on top and the lists under it. He chose
that over the preview on the left with the lists scrolling on the right. A landscape iPad is wide
and short, so a large preview takes most of its height and the lists begin near the bottom; the
trial of the preview stuck at the top is where that gets looked at.

In a narrow window, where the app is as narrow as a phone, a widget wider than the view is cropped
at its sides, as above.

## Besides the settings screen

Syd, 2026-10-09: the app has two more pages, reached from a button on the settings screen.

- **How to add a widget.** A short page for a person who has just installed the app and does not
  know how a widget gets onto the Home Screen. The steps differ a little between iPhone, iPad and
  the Mac, so the page's words are one of the things that differ by platform.
- **About.** The app's name, its version and build, and whatever else the Mac app's About window
  says that applies here (`MacOS/Desktop/Sources/AboutView.swift`).

He chose both over an About page only, and over the one screen being the whole app. From memory of
the review guidelines, not checked: App Review rejects an app that is only a shell for its
extension, and these pages with the settings and the preview are what the app is besides its
widgets.

**Not said:** what the button looks like and where on the screen it is; whether the two are one
page or two; and whether the Mac's menubar app has them in its Settings window or in its menu.

## Identity

**The bundle identifier is `com.sydpolk.photosgoround.widgets`.** Syd, 2026-10-09. The widget
extension is `com.sydpolk.photosgoround.widgets.extension`; an extension's identifier has to begin
with its app's. The Mac's menubar app takes the same identifier when it comes. From memory, not
checked: one App Store listing covers an iPhone app and a Mac app only when the two have the same
bundle identifier.

- **It is not Photos-Go-Round.app's.** That app is `com.sydpolk.photosgoround`, with its widget
  extension at `com.sydpolk.photosgoround.widget`. The Widgets app is a different product, and on
  a Mac the two can be installed together.
- **The App Group follows from it.** The Mac widget's group is already
  `<team>.com.sydpolk.photosgoround.widgets`, with the configuration's suffix. On iOS a group's
  name has to begin with `group.`, so there it is `group.com.sydpolk.photosgoround.widgets`. The
  two platforms spell the same group differently, and the code that asks for the container has to
  allow for that.

**The name under the icon is "PhotosGoRound".** The product is "Photos-Go-Round Widgets", which is
too long for a Home Screen label; the App Store listing can carry the full name. In Xcode this is
the target's display name, `CFBundleDisplayName`. Syd, 2026-10-09, in two steps:

- First "Photos-Go-Round", over "PGR Widgets". On the iPhone 17 simulator, whose screen is 402
  points wide, it was cut off, as "Photos-Go-Rou…".
- Then: "Let's have the app name be "PhotosGoRound" and see if it fits." It does, on that
  simulator, whole.
- **While the app is newly installed it is still cut off**, as "PhotosGoR…": the system puts a
  blue dot beside the name until the app has been opened once, and the dot takes room.
- **The Photos prompt uses the same name**: "Allow "PhotosGoRound" to access your photo library?"
- **Not seen:** a narrower phone, or an iPad.

**Each configuration has its own identifier, as on the Mac.** Syd, 2026-10-09, choosing that over
one identifier for all three. The project already sets `STORAGE_ID_SUFFIX` for each
configuration: nothing for Release, `.debug` and `.claude`. So:

| | Release | Debug | Claude |
|---|---|---|---|
| App | `…photosgoround.widgets` | `…widgets.debug` | `…widgets.claude` |
| Extension | `…widgets.extension` | `…widgets.debug.extension` | `…widgets.claude.extension` |
| App Group | `group.…widgets` | `group.…widgets.debug` | `group.…widgets.claude` |

- **A Debug build from Xcode sits beside the Store's build on Syd's phone** as a second app with
  its own settings, and never replaces it.
- **The Claude build goes only on Claude's simulators.**
- **Each identifier is an App ID in the developer account, and each group an App Group.** Xcode's
  automatic signing makes them for a development build; the Release ones are made for the Store.
- **Not said:** how a person tells the Debug app from the Release one on the Home Screen. The
  Mac's widget carries "(Debug)" in its name in the gallery; a Home Screen label has no room for
  it after "Photos-Go-Round".

## Targets and release

- Syd, 2026-10-09: "this is another target in the existing Xcode project. iOS 27 or later". The
  package already lists iOS 27, so the shared targets need no change for that.
- A widget is an extension, so the app target needs a widget extension target to carry. Syd,
  2026-10-09, chose a second extension target for iOS, compiling the same source files as the
  Mac's, over making the Mac's target build for both. The Mac's has an identifier for each build
  configuration, Mac sandbox entitlements, and a place in Photos-Go-Round.app's release, and none
  of that is disturbed.
- The source files are in `Widgets/macOS/Sources` today. Two of them are the Mac's alone as they
  stand: `PhotoWidget.swift` loads its picture through `NSImage`, and `Settings.swift` reads the
  Mac app's preferences. Where files shared by the two targets should live was not said.
- Debug, Release and Claude builds carry different identifiers, as on the Mac. See *Identity*.
- The version is the project's, in `Version.xcconfig`. A release on iOS is an archive uploaded to
  App Store Connect, not a DMG, so `Scripts/release-build.sh` does not cover it.
- Tested in a simulator, and on Syd's own phone for iCloud Photo Library. See *Where it is
  tested*.

# References

- `Plans/Photos-Go-Round Widgets.md` — the product this app belongs to; its *iOS and iPadOS* phase
  holds the to-dos that need the phone.
- `Plans/Product Strategy.md` — names the product.
- `Plans/Project Source Reorg.md` — the layout this app's `iOS` folder belongs to.
- `Plans/Project Source Reorg 2.md` — a folder for each binary; deferred.
- [Delivering an Enhanced Privacy Experience in Your Photos App](https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app)
  — the limited library: no user albums, and no way to remove it from the prompt.
- [Widgets, Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets)
  — the table of widget sizes by screen, and which sizes each device supports.
- [`WidgetFamily.systemExtraLargePortrait`](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait)
  — says the family appears on the Home Screen on iOS.
- `MacOS/Desktop/Sources/SourcesSettingsView.swift`, `CollectionPickerView.swift`,
  `CollectionTree.swift` — the Mac app's lists and picker.
- `Widgets/macOS/Sources` — the widget as it is on the Mac.
