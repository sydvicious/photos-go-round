# Summary

The iOS and iPadOS app of Photos-Go-Round Widgets: one screen with the controls in the bar, a
preview of a widget at its real size under them, and the Photos collections and the files and
folders under the preview, or beside it when there is no room. The app carries the widget
extension that shows the same pictures on the Home Screen. The Mac's menubar app shows the same
view in its Settings window. Syd, 2026-10-09 and 2026-10-10.

# Rationale

A widget can't be installed by itself, so the app is what carries the widgets onto a phone, and it
is the only place a person can say which photographs they show. Syd wants it before the Mac's
menubar app (`Plans/Photos-Go-Round Widgets.md`, *Phases*). The phone is also where the widget's
hardest limits are expected to be enforced, so building here first finds them first. The view is
written once and the menubar app takes it afterwards.

# Phases

The order is Syd's: the settings view first, in the app alone, the widget extension after it,
and the first-time wizard before the Store (2026-10-09, and 2026-10-11 for the wizard's place).
The app and the extension are built and run on the simulators; what is under each phase is what is
left of it. The to-dos are Claude's unless they say otherwise.

- **Phase 1** — The app. Complete; Syd, 2026-10-11.
- **Phase 2** — The widget extension. Complete; Syd, 2026-10-11.
- **Phase 3** — When a source is wrong. Complete; Syd, 2026-10-11. *When a source goes wrong*.
- **Phase 4** — Files and folders, with adding and removing. Complete; Syd, 2026-10-11. *The
  files and folders*.
- **Phase 6** — The first-time launch wizard. Syd, 2026-10-10: "we need a full-blown first-time
  launch wizard". Moved before the Store on 2026-10-11.
  - The "How to add a widget" page is part of it.
  - What its other steps are was not said; choosing collections is the obvious one.
- **Phase 7** — The App Store: versioning, TestFlight, submission.

# TODO

The iOS app's to-dos are in `TODO.md`, *The iOS app*, since the work reached `main`, 2026-10-16.
Syd, 2026-10-10: `TODO.md` "takes the iOS to-dos once this is in `main`".

# Design Decisions

*The product and its targets*

- **The app is another target in the existing Xcode project.** Not a project or repository of its
  own. Syd, 2026-10-09.
- **Everything of the widgets' is in one folder at the top level, `Widgets`, and nothing else
  moves.** The iOS app, both widget extensions and what they share. The larger reorganization, a
  folder for each binary, is deferred. Syd, 2026-10-09. *Where the code lives*.
- **iOS and iPadOS 27 or later.** Syd, 2026-10-09.
- **The app is `com.sydpolk.photosgoround.widgets`, and its extension
  `com.sydpolk.photosgoround.widgets.extension`.** The Mac's menubar app takes the same identifier
  when it comes. Syd, 2026-10-09. *Identity*.
- **Debug, Release and Claude builds each have their own identifier, by the Mac's suffixes.** A
  development build never replaces the Store's on the phone. Syd, 2026-10-09.
- **The name under the icon is "PhotosGoRound".** It fits whole where "Photos-Go-Round" was cut
  off. Syd, 2026-10-09.
- **The app is not offered on a Mac as an iPad app.** Syd, 2026-10-10: it "should not be availabe
  as an iPad app on the Mac, but that may be moot once I make the menubar app". Set on the iOS
  target (`SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = NO`).
- **Tested in a simulator, and on Syd's phone for iCloud Photo Library.** That is the only reason
  for the phone. Syd, 2026-10-09. *Where it is tested*.
- **The iOS widget extension is a target of its own, with small files of its own.** What a wake
  does and what a widget draws are in shared package targets, where they are tested. The Mac's
  widget target and its files are not touched. Syd, 2026-10-09 and 2026-10-10. *Targets and
  release*.
- **The Photos reading is a shared target of its own, `PhotosGoRoundPhotoLibrary`, carved out of
  the kit.** The Widgets app links that and not the kit. Syd, 2026-10-09.
- **The tree that files collections under their folders is one builder, in
  `PhotosGoRoundAgentAPI`.** The Mac app and the Widgets app both draw from it. Syd, 2026-10-09.
- **The settings view and its models are a package target, `PhotosGoRoundWidgetSettings`, and
  what a widget draws is another, `PhotosGoRoundWidgetFace`.** Both are in
  `Widgets/Shared/Sources`, beside `TinyCache`. The iOS app and the Mac's menubar app both link
  them, and the models are tested by the `Package Tests` scheme. Syd, 2026-10-09.
- **The view is written once, in SwiftUI, for iOS, iPadOS and the Mac.** The sizes the preview
  offers are what differs by platform. *One view for three platforms*.
- **Everything in `Plans/Photos-Go-Round Widgets.md` holds here.** A normal app, Photos the
  expected source, a TinyCache of the app's own for the preview, and the whole Photos library
  never chosen for anyone.
- **The Mac menubar app's Settings window has this same view, and nothing else about it is
  decided until there is a good version of the iOS app.** Its questions wait. Syd, 2026-10-09.

*The screen*

- **One screen: the controls in the bar, the preview under it, and the two lists under the
  preview or beside it.** Syd, 2026-10-09, and 2026-10-10 for the bar. *The screen: controls in
  the bar*.
- **"Liquid Glass all the way".** Syd, 2026-10-10.
- **The bar holds two groups, both at the right: the sizes, then the Photos and Files buttons.**
  Syd, 2026-10-10: "I want the size controls on the right as well".
- **Each size is a rounded rectangle in the widget's proportions, filled when it is the one
  showing.** No words to translate. Syd, 2026-10-10. On a phone each is a name and a picture, so
  the system can move it; on an iPad each group is one item drawn close together, so the bar fits
  the narrowest window.
- **The Photos button is the photo-library symbol and the Files button a folder.** What the Photos
  button brings up goes by the access there is: the collections sheet, the system's picker with
  limited access, or the "No Photos Access" alert. The Files button brings up the Files browser.
  Syd, 2026-10-10.
- **The preview is pinned, and the lists scroll under it.** Tried both ways. Syd, 2026-10-10: "I
  want the pinned behavior".
- **The preview's bounds are as tall as the large size, from the top of the view, with the widget
  centered in them.** Choosing another size moves nothing else. Syd, 2026-10-10. When the view is
  too short for the bounds, the widget is at the top.
- **Nothing of the widget shows outside the preview's bounds, on any side.** A taller size
  scrolled up was drawn on under the bar, to the top of the screen. Syd, 2026-10-11: "the
  preview widget scrolling should not bleed into the navigation bar. Should be bounded by the
  size of the large widget on all four sides". The bounds are as wide as the view, with the
  widget in the middle of them, so on a phone that is the large size's own box. On an iPad the
  width stays the view's, so the extra large shows whole when there is room: Syd, the same day,
  over holding the width to the large size's there too.
- **The lists go under the preview when a heading and one row fit there, and otherwise the
  preview is at the left and the lists beside it.** That is an iPhone on its side, and a short
  iPad window. Syd, 2026-10-10: "Go back to the preview on the left if the bottom text does not
  fit".
- **The smallest an iPad window can be made shows the bar, a small widget whole, the "Photos"
  heading and one row, at the standard text size.** And it is at least 320 points wide. Syd,
  2026-10-10. *iPad*.
- **Any row of a source leaves by a swipe to the left, and a collection also by being unticked
  in the sheet.** "Selected Photos" too. There is no Edit button. Syd, 2026-10-10, and 2026-10-11
  for the swipe on the collections' rows: until then that list was not edited on the screen.
  The widgets carry on as usual with the sources that are left. *Taking a source out of a list*.
- **One line between the preview and the lists says how: "To remove a collection, file, or
  folder, swipe left on it."** It takes the place of the line under the files, scrolls with the
  lists, and is always there. It is over the "Photos" heading, 16 points above it, and not a row
  of its own. Syd, 2026-10-11.
- **The two lines of words about the lists are in the colour of normal text, and the same as
  each other.** That line, and "Include nested folders when checked." under the files. Syd,
  2026-10-11.
- **The room the line takes is not added to what has to fit under the preview.** Syd,
  2026-10-11: "I don't see a problem".
- **No About page, and no button on this screen for the "How to add a widget" page.** The page is
  the wizard's. Syd, 2026-10-10.
- **Nothing in this view sets how often a widget changes.** That is each widget's own
  setting, and it belongs to the widget (`Plans/Photos-Go-Round Widgets.md`, *Design Decisions*).

*The preview*

- **The preview draws the widget's own view**, `WidgetFace`, so what it shows is what a widget
  shows.
- **The preview is drawn at the widget's real size and never shrunk.** Where its bounds are smaller
  than the widget it scrolls, both ways. Syd, 2026-10-09: "I really want them to know what the
  pic actually looks like"; 2026-10-10 for the scrolling.
- **The real size comes from the system: the extension records each size it is handed, and the
  preview reads them.** Apple's table of sizes stands in until then. Widgets differ in size from
  phone to phone, the Duo especially. Syd, 2026-10-09.
- **Every size a family is handed is kept, and the preview uses the ones for the screen it is
  on.** The Duo has two screens, and an iPad two ways up. Syd, 2026-10-10. *The sizes the preview
  can take*.
- **The preview offers the Home Screen sizes this device has, and nothing else.** Four on each,
  and the fourth differs: a phone's is tall, the system's extra large portrait, which every
  phone has had since iOS 26 or 27 whatever the documentation says; an iPad's is wide, the
  extra large. Neither device has the other's fourth, and the iPhone Duo is a phone in this even
  unfolded. Where else a photograph may end up, such
  as StandBy, CarPlay or the Lock Screen, is not previewed. Syd, 2026-10-09, and 2026-10-11 for
  the fourth.
- **A phone offers its tall size from the start, at a size of the app's own until a widget has
  been handed the real one.** As wide as the large, and as tall as a large and a medium and the
  gap between two mediums. Syd, 2026-10-11: "the preview should have the four sizes". *The sizes
  the preview can take*.
- **The Lock Screen's own sizes are not built.** The circle, the rectangle and the line of text.
  Syd, 2026-10-09.
- **The preview starts on the largest size that fits its bounds without scrolling, or the small
  one, and chooses again each time the bounds change until the person picks a size.** Their choice
  is theirs from then on, whatever the bounds. Syd, 2026-10-10.
- **The preview's picture changes by itself every five seconds, and on a tap.** A small slideshow,
  not a widget's five minutes. It stops when the app is not in front. Syd, 2026-10-09.
- **The preview fetches one picture at a time.** Two requests to Photos at once do not come back.
  *One fetch at a time*.
- **When the preview has nothing to show it puts up what costs least, in order:** last time's
  picture from disk, the first source's first picture, then the usual weighed picks. Syd,
  2026-10-10. *The first picture, as fast as possible*.
- **The count on a row is the count the picks are weighed by, and every source is counted again,
  once, behind the pictures, each time the app comes forward.** Syd, 2026-10-10.
- **With nothing chosen, the preview and the widgets show the app icon.** Plain, in full colour,
  with no words. On iOS and iPadOS only; the Mac widget keeps its sentence. Syd, 2026-10-09.
- **Three more faces without a photograph: the icon greyed over with "Scanning…" while the first
  picture is fetched, with "No Photos found" when sources are chosen and no picture is to be
  had, and with "No Photos Access" when Photos access is off and nothing else can be shown.** On
  the preview the last opens the system's settings when tapped. Syd, 2026-10-09 and 2026-10-10.
  "Scanning…" is the preview's only; a widget says "No Photos found" until it has a picture.
- **The app carries a full-resolution picture of its icon, and the faces draw it from a copy no
  bigger than it is shown.** Syd, 2026-10-10.
- **A photograph greyed over with "Scanning…", when Photos has not answered for the next one.**
  In the preview only. Syd, 2026-10-11: "put the scanning overlay over whatever is showing so
  the user knows something is wrong". *When Photos does not answer*.
- **A widget never says "Scanning…".** It shows the picture it had, plainly, whatever has gone
  wrong; with none yet, "No Photos found". Syd, 2026-10-25: "if the widget had a picture before,
  show it plainly", and 2026-10-30: "I don't want to show the user 'Scanning...' in the widgets
  themselves. I would rather show 'No Photos' until we find one." Nothing a person can do makes
  it go away.
- **A placeholder shows the last picture put in the cache**, by any size, whatever its sources;
  "No Photos found" with none. The system asks for a placeholder while it builds a widget's
  first timeline, after an install or after the extension was ended, and gives it the widget's
  size and not its settings. Syd, 2026-10-30, choosing that over "No Photos found" and over the
  plain icon, once his phone's widgets had all said "No Photos found" for 11 seconds with
  pictures in the cache; and then "just use the last picture in the cache", "because we know
  that the last pic in the cache won't trigger memory problems". It was shrunk to a widget's
  size when it was fetched, and has been drawn already. `WidgetPictures.placeholder(in:)`.

*The collections*

- **The collections list shows the collections that are chosen, each with its name and its count,
  red when something is wrong.** Syd, 2026-10-09.
- **The Photos button opens the whole library as a tick-box tree, in a sheet.** Favorites first,
  then the sections, with collections filed under their folders. A folder has a tick box and a
  section heading does not, as on the Mac. Syd, 2026-10-09 and 2026-10-10.
- **What is ticked when Done is pressed is the set of Photos sources.** Cancel changes nothing.
  The Mac picker's rule. Syd, 2026-10-09.
- **Hidden, Recently Saved, and anything with the `wholeLibrary` kind are never offered, here or
  in the Mac app's picker.** Each is told by its kind and never by its name. Syd, 2026-10-10.
  *What the sheet leaves out*.
- **The whole Photos library is never chosen for anyone.** A person's library holds things that
  are not fit to put on a screen; only what they chose is shown. Syd, 2026-10-09.
- **The source list is read again each time the app comes forward.** A collection renamed or
  moved in Photos takes its new name and place; one that has gone is grey, with "(removed)". Syd,
  2026-10-10, and 2026-10-11 for the grey: until then it was red.

*Photos access*

- **At first launch the app asks for Photos access by itself, and the collections sheet comes up
  once the person has said yes.** Nobody has to find the button first. Syd, 2026-10-09.
- **When Photos access is refused, no sheet comes up, and there are three ways to the system's
  settings.** The collections list has one row: a warning icon, "No Photos Access", and a
  "Settings…" button; the bar's Photos button brings up an alert with "Settings…" and "Cancel";
  and the preview's face says "No Photos Access" and opens the settings when tapped. Files and
  folders still work. Syd, 2026-10-09 and 2026-10-10.
- **When Photos access is turned off later, the chosen collections stay, red.** None is removed,
  so turning access back on brings every one of them back. Syd, 2026-10-09.
- **When Photos access has been revoked, an alert offers the way to the system's settings.** Once
  it is dismissed, if Photos still cannot be got into, the collections are in red text. With no
  Photos sources chosen the alert does not come at all. It is one alert, about Photos access,
  and not one for each collection. It comes once in a run of the app: at launch, or the first
  time the app finds access off, and again at the next launch. Syd, 2026-10-11: "the first time
  the app is launched or brought forward after access is turned off, and then once per launch
  until it is fixed, either by opening photos back up or by removing all of the sources".
- **That alert says "PhotosGoRound needs access to Photos to continue serving your pictures.",
  with "Cancel" and "Settings".** The bar's Photos button brings up the same one, in place of
  "No Photos Access" with "Settings…" and "Cancel". Syd, 2026-10-11.
- **With limited Photos access, the photographs the person picked are one source, "Selected
  Photos".** Full or none is what Syd prefers, and the system always offers limited. The bar's
  Photos button changes which are picked, the row has no button of its own and leaves by a swipe
  as any row does (2026-10-11; until then it could not be removed), and the system's ask on every
  run is turned off. Swiped away, the row comes back by the Photos button, and the app does not
  add it by itself until then, whatever access becomes in between. Syd, 2026-10-09, 2026-10-10
  and 2026-10-11. *Limited access*.

*When a source goes wrong*

- **Grey is for trouble that is probably temporary, and red for a problem that needs to be
  addressed.** Syd, 2026-10-11: "grey - something that is probably temporary; red - a problem
  that needs to be addressed".
- **The red is one nearer orange or pink.** Syd is colour blind and cannot tell red from grey.
  2026-10-11: "the red needs to be closer to orange/pink", and "it's a bright, light red with a
  hint of yellow mixed in". It is red 1.0, green 0.39, blue 0.28, `Color.trouble`, Claude's
  pick; of it in a preview, the same day: "that red is perfect for me", and "the red looks good
  in dark mode as well". Every red in the view
  is that one, the "No Photos Access" row's among them: Claude's reading.
- **Trouble that should pass leaves the source in place, grey, with "(unavailable)" beside it,
  until it has passed.** No connection is the example. Syd, 2026-10-09, and 2026-10-11 for the
  grey and the word: until then it was red.
- **A source that has gone is put to the person when the app is opened or brought forward, in an
  alert.** Both lists, and several gone at once get one alert. Syd, 2026-10-09.
- **No picker or Files browser comes up after the alert.** Syd, 2026-10-11: "We have told the
  user that something is gone, and they can see what it is". From 2026-10-09 until then the
  picker was to follow.
- **The alert for files and folders that have gone says "Some files and/or folders are no longer
  available.", with "OK".** It names none of them. Syd, 2026-10-11; on 2026-10-09 one alert was
  to name them all.
- **For collections that have gone it is the same alert with words to match: "Some collections
  are no longer available."** When both lists have lost something, one alert covers both. Syd,
  2026-10-11. Its words then are Claude's, and Syd's to overrule: "Some collections, files
  and/or folders are no longer available."
- **The alert for a source that has gone comes at every launch, and the first time the app is
  brought forward and finds it gone.** Not each time the app comes forward. Syd, 2026-10-11.
- **The app removes nothing.** Syd, 2026-10-11. Until then a source not put right was removed.
- **A list's heading is in red text, and its button in the bar has a red background, only when
  its rows are red.** That is "Photos" and the photo-library button, with Photos access off. Grey
  rows change neither, so "Files and Folders" and the folder button are never red as things are.
  Syd, 2026-10-11.
- **The red "Photos" heading has a warning triangle beside it.** So it is not told from a normal
  heading by its colour alone. The red rows have colour only. Syd, 2026-10-11.
- **A collection, folder or file that has disappeared is drawn in grey, with "(removed)" beside
  it.** Grey though it will not come back by itself. Syd, 2026-10-11: "It's gone from the source,
  but up to the user to remove".
- **A file or folder whose bookmark does not open is "(removed)", when the app cannot tell
  whether it was deleted or is out of reach.** Syd, 2026-10-11. It is looked at again each time
  the app comes forward, so one that is back is drawn as usual again: Claude's, and Syd's to
  overrule.
- **A file or folder is looked at by being counted.** One that cannot be counted is "(removed)",
  unless the failure is one that passes, such as no connection, and then it is "(unavailable)".
  A collection is "(unavailable)" when access is given and the library cannot be read. Both
  Claude's, 2026-10-11.
- **The person takes a removed one out, and the app does not.** A collection goes when the Photos
  picker is opened again and Done pressed; a file or folder by a swipe to the left on its row.
  Syd, 2026-10-11.
- **A source with nothing in it is not wrong.** It shows a count of 0 in the normal colour. Syd,
  2026-10-09.

*Files and folders*

- **Files and folders come before the alerts.** Syd, 2026-10-11: "I think we need to do files and
  folders next, because it colors how we deal with connections to sources not working". Until
  then they were not the priority and might not have been done at all: 2026-10-10, and earlier
  on 2026-10-11, "I could remove them and ship now".
- **The list takes single image files as well as folders, as the Mac's does.** Syd, 2026-10-09.
- **Each folder has its own option for including its subfolders, and it is a checkbox in the
  folder's row.** It starts off, as on the Mac. Syd, 2026-10-09, and 2026-10-11 for the checkbox:
  "a checkbox in the same line as the entry that toggles it on or off". Until then it was to be
  changed by tapping the row, as the Mac's sheet is.
- **One Files browser takes folders and image files.** The Mac app has a menu item for each.
  Claude's, 2026-10-11, and Syd's to overrule. *The files and folders*, *Choosing*.
- **A file or folder is opened through a bookmark, by the app as well as by its widgets, and
  never by its path.** The bookmarks are in the App Group container. Claude's, 2026-10-11.
- **A widget always tries to show something, and says "No Photos found" only when every source
  has been gone through and has none to give.** Syd, 2026-10-11: "I always want to try to show
  something". The order is his: "a random file is determined from a random source like we have
  been doing. If the file is not available, cycle the Sources until we find one. If we don't,
  then go sequentailly through the orignal source", which is "go through the files in that source
  sequentially until you find one, or until we determine that there are zero in that source, and
  only then, show "No Photos Found"". After the first source the others are gone through too,
  in the order they were drawn: Claude's reading of "always". Built for folders; a Photos
  collection is drawn and passed over like any source and is not gone through: Syd, the same
  day, "photos collection not gone through; we already have a mechanism", which is the time
  limit and the waits of *When Photos does not answer*.
- **Finding a picture may take a long time.** Syd, 2026-10-11: "widgets don't change files that
  often, so taking a long time to find one is not a big deal", "we have at least five minutes".
  From memory, not checked: the system gives one wake of a widget less than that, and stops it.
- **What a bookmark cannot be left for is not added, and an alert says so.** "Coins could not be
  added.", with an OK button. Syd, 2026-10-11: "A modal alert saying "%s could not be added."
  where the name of the file or folder or collection is substituted", and "if there is no name,
  simply says "That item"". Several at once are named in the one alert. Nothing can fail to be
  added for a collection as things are, so it is a file's or a folder's alert until something
  can.

*The widgets*

- **The app writes its sources into the App Group container, and the widgets read them there.**
  iOS has no other way, and the menubar app takes what is built. *The App Group comes first on
  iOS*.
- **A widget's one setting is how often it changes: *Change Every*, in the system's Edit Widget
  panel.** Syd, 2026-10-11: "We need to add a settings panel and the item is a menu with
  durations". The durations are those of `Plans/Photos-Go-Round Widgets.md` without one minute,
  and a widget nobody has set changes every five minutes.
- **One minute is not offered.** The system reloaded a 1-minute widget after five, and every
  change of picture is a reload. Syd, 2026-10-11, on the simulator's evidence; his rule of
  2026-10-08 was that it "is dropped if the system won't honour it". Not tried on a phone.
- **The Mac's widgets and these need not offer the same durations.** Syd, 2026-10-11: "The Mac
  and iOS can have different settings". So `Plans/Photos-Go-Round Widgets.md` keeps its list, one
  minute included.
- **The durations are a fixed list, so the menu ticks the one a widget is set to.** Syd,
  2026-10-11: "The tick is more important than the hair-brained scheme to try to have two
  same-size widgets with the same duration showing different pictures". So two widgets of one
  size set to one duration are one widget, and show the same picture at the same moment. The
  scheme was a delay of 1 to 500 milliseconds made up for each line of the menu, his of earlier
  that day; it worked for a widget whose duration had been picked, and it left the menu with
  nothing ticked. *The trial, and what was built*.
- **There is a cache for each setting at each size.** That is as near as the system allows to one
  for each widget. One that no placed widget has any more is cleared away at the next wake: a
  widget set to something else, or taken off the Home Screen, leaves its folder behind. Syd,
  2026-10-11.
- **A request to Photos for a picture is given up on after a time limit, and a new one is made
  after a wait that doubles each time in a row.** Syd, 2026-10-11: "When it times out start a
  new request. Do exponential delays before asking again up to 30 minutes", and "don't stop.
  After exponential delays reaches thirty minutes keep trying every 30 minutes". The limit is 15
  seconds and the first wait 5; both figures are Claude's. *When Photos does not answer*.
- **The app's preview waits a minute at most.** Syd, 2026-10-11: "Previews in the app wait for
  1 minute max".
- **Meanwhile what is showing stays: in the preview with "Scanning…" over it, on a widget as
  it is.** Syd, 2026-10-11: "If there is already a photo loaded just keep displaying it. If not
  use the scanning… overlay on the app icon"; a widget with nothing shown yet says "No Photos
  found" instead, 2026-10-30. The picture kept is the file already in the cache, on disk, and
  so is a widget's wait.
- **A widget starts as the preview does: the first source's first picture, then the weighed
  picks.** Syd, 2026-10-10: "of course, each widget will be doing this as well".
- **In the gallery, a size with no picture of its own shows another size's; with no picture
  anywhere, the plain icon.** Syd, 2026-10-10. *Targets and release*.
- **The app tells the widgets to look again when a person leaves it**, so a change of sources
  shows without waiting for a widget's next turn.
- **A picture of more than a million pixels is shrunk a band at a time, unless it is a HEIC.**
  A widget is ended at 30 MB, and in one piece the largest coin scan took far more. Syd,
  2026-10-12. *A very large picture, in bands*.
- **A JPEG is decoded at an eighth or at its own size, never a half or a quarter.** At those
  two, some photographs are decoded whole behind a picture of the size asked for, and two
  ended a widget that way. *A JPEG at a half or a quarter*.
- **The icon is carried at four sizes, eight bits a channel, and drawn from the smallest
  that will do.** One picture of 1024 pixels at 16 bits took a widget most of the way to its
  30 MB. Syd, 2026-10-13: "Make a version of the icon optimized for widgets". *The icon, made
  for widgets*.
- **A picture reckoned to need more memory than the widget has left is passed over for
  another.** Syd, 2026-10-12: "any picture that fails the guard is skipped". *The guard*.
- **The preview passes over what a widget would, and puts the note up when it does.** Syd,
  2026-10-12: "the preview should use the exact same methodology as the widgets". *The guard*.
- **A source that has had a picture passed over has a warning triangle beside its name.** Syd,
  2026-10-12. *The guard*.
- **When that has happened, the app says so at the foot of its window, until that source goes
  away.** "Some of the Photos in this set are not displayable in widgets." Syd,
  2026-10-12. *The guard*.

*The wizard*

- **A full first-time launch wizard, as a phase of its own, before the Store.** Syd, 2026-10-10,
  and 2026-10-11 for its place. The "How to add a widget" page is part of it. *The wizard, and the
  how-to page*.

# Background

- **What exists, 2026-10-10.** The app target `Photos-Go-Round Widgets iOS` and its extension
  `Photos-Go-Round Widgets iOS Extension`, both in `Widgets/iOS`; the package targets
  `PhotosGoRoundWidgetSettings`, `PhotosGoRoundWidgetFace` and `TinyCache` in `Widgets/Shared`,
  with the first and last tested; and `PhotosGoRoundPhotoLibrary` in `Shared/Sources`. Both run
  on Claude's simulators, and the widgets show photographs there.
- **Where the design came from.** Syd, 2026-10-09: "At the top of the view will be a preview. You
  can change the size of the preview to match the sizes supported by the platform (iOS vs
  iPadOS). Below that is the collection picker like we have in the Mac app, but with only 3 lines
  (iOS)/5 lines (iPadOS) showing (scrollable), and then at the bottom the file/folders picker
  sized the same way. (The Mac Menu Bar Settings window will also have this view)". The screen as
  it is now is his redesign of 2026-10-10, `Plans/ios main view revision 2.md`.
- **The Mac's widget** is still the proof of concept inside Photos-Go-Round.app, in
  `Widgets/macOS/Sources`, with a view and a timeline of its own. It does not draw `WidgetFace`.
- **The Mac app's Settings window** has the two lists already, and *Choose Collections…* opens a
  checkbox tree of the whole library. It does all of that by asking the agent over HTTP. The
  Widgets app has no HTTP and no agent process, so the look carried over and the code underneath
  did not.

# Detailed discussions

Written by Claude from 2026-10-09 on. Where something is from memory rather than checked, it says
so. Audited against the code and the branch's history on 2026-10-11.

## Where it is tested

Syd, 2026-10-09: "the only reason i wanted to test on phone is to test with icloud photo library.
we can test everythingmelse including files and folders and simple photo library on sim".

- **In a simulator:** the layout at iPhone and iPad sizes, files and folders, and a Photos library
  kept on the device, which in a simulator is Apple's few sample pictures and whatever albums are
  made there.
- **On Syd's phone:** iCloud Photo Library, where a picture may not be on the device and has to be
  fetched.
- **Also only on a phone**, by their nature and not by this rule: the extension's memory against
  the 30 MB ceiling, which a simulator is not expected to enforce, and what a widget can do while
  the phone is locked. The memory was Phase 5's, closed 2026-10-16; the locked phone is in
  `TODO.md`.
- **The memory reading has a phone of its own, and an iPad first.** Syd, 2026-10-11: "gonna
  leave it running on my iPad", and then that he will make his mother-in-law's phone, which she
  no longer really uses, a developer phone, for the memory test "tomorrow or the night after".
  An iPad's limit may not be a phone's; the `left of` on each line says what each is held to.
  The iPad's first night is with the coins folder alone, its files copied onto the iPad
  itself, so nothing waits on iCloud. Syd, 2026-10-12: "the iPad widgets froze when I set them
  up", and "many hours later they are still frozen". *What the iPad's first night showed*.
  That phone is signed into his wife's account, whose Photos library is the one they share.
  The coins folder, which has the truly large picture, is to be the main source, with small
  albums and an iCloud Drive folder beside it. Every picture has an equal chance, so the large
  one comes up about once in as many picks as there are pictures chosen; a `fetched` line with
  its size, 33280x20395, is how the log says it did.
- **Whether a widget can open a folder the app chose is the phone's to answer too.** From
  memory, not checked: a simulator does not enforce the sandbox, so a yes there does not say
  what a phone will do. Files and folders are otherwise tested on a simulator, as Syd said.
- **Putting pictures where a simulator's Files browser shows them.** "On My iPhone" is a folder on
  the Mac:
  `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Shared/AppGroup/<UUID>/File Provider Storage`.
  The `<UUID>` is the AppGroup folder whose `.com.apple.mobile_container_manager.metadata.plist`
  names `group.com.apple.FileProvider.LocalStorage`. What is copied there shows at once. A big
  folder is cloned there with `cp -cR`, which takes almost no room on the same volume: Syd,
  2026-10-11, "I did not want to copy a big folder into simulator". A symlink shows as a folder
  and does not open, tried the same day; Syd, on his: "simulator does not like the symlink".
- **Which simulators.** Claude's own, *Claude iPhone* and *Claude iPad* on iOS 27, no more than two
  running at a time. Every other simulator on the Mac is Syd's. The iPhone Duo needs the iOS
  27.1 runtime and Xcode 27.1, and is Syd's to run.

## The sizes the preview can take

**What each platform offers.** Four sizes on a phone and four on an iPad, and the fourth is a
different one on each. iPhone: small, medium, large, and a tall fourth, the system's "extra large
portrait". Syd, 2026-10-09: "the really big widgets won't be on a phone"; and 2026-10-11, of the
tall fourth: it "will always be there", it is there on an iPhone SE 2nd generation, and iOS 26 or
27 added it without the documentation being updated. iPad: small, medium, large, and a wide
fourth, the extra large; Syd, 2026-10-11: "iPad's fourth size is horizontal, and iPhone's is
vertical". The iPad mini's gallery handed its widgets no tall size on 2026-10-10, so neither
device has the other's fourth. The iPhone Duo is a phone in this: it offers the tall one and not
the wide one, even unfolded, when its inner screen is about an iPad mini's size. Syd,
2026-10-11. Mac: all five.

**Apple's two pages disagree about extra-large portrait.** Read 2026-10-09. The design guidelines'
table says extra large is "Not supported" on iPhone, and extra-large portrait is not supported on
iPhone or iPad. The WidgetKit page for `systemExtraLargePortrait` says it "can appear on the Home
Screen on iOS, on the Today View on iOS and iPadOS, on the Desktop on macOS, and on visionOS", from
iOS and iPadOS 27.0. The simulators settled it for the phone: the widget gallery hands the
extension a size for it, 349.7 by 565.7 points on the iPhone 17. Whether an iPad's gallery offers
it is not yet seen.

**The preview is of the Home Screen sizes only.** Syd, 2026-10-09: "the fact that photos may end up
elsewhere is not going to be previewed here". From Apple's design guidelines, read 2026-10-09: the
small widget is also shown in StandBy and CarPlay on an iPhone and on the Lock Screen on an iPad,
and every size is in Today View. None of those is previewed.

**The Lock Screen's own sizes.** iPhone and iPad also have three accessory families for the Lock
Screen: a circle, a rectangle, and a line of text. From memory: the system draws them in one tint,
without colour, and the line of text can't hold a picture at all. Asked on 2026-10-09 whether they
count as sizes for this app, Syd chose "Home Screen sizes only": they are not built.

**Where the real size comes from.** No call gives an app a widget's size. The extension is told
its size each time it is asked for a snapshot or a timeline, and the app has no way to ask what a
medium widget measures on this device. Syd, 2026-10-09, chose the extension writing down each size
it is handed, with Apple's table as the fallback: real size is the point of the preview, and only
the system knows it for certain.

- **Apple's table**, kept in the app by screen size (`WidgetSizes`), read from the design
  guidelines on 2026-10-10. It has ten phone rows and ten iPad rows. A screen it has no row for
  gets the row for the nearest one, and may be a few points out: the iPhone 17's 402 by 874 screen
  is not in it, and the table's nearest row gave 158, 338 by 158 and 338 by 354 where the widgets
  are really handed 164.3, 349.7 by 164.3 and 349.7 by 365. It has no figure at all for the tall
  fourth size, so a phone's is reckoned until the real one is recorded: as wide as the large,
  and as tall as a large and a medium and the gap between two mediums, which a large is two
  mediums and (`WidgetSizes.tall`). For the Duo's two sets it gives what their widgets were
  handed, to the point. It is reckoned from the large and the medium this phone's widgets were
  handed, when they have been, and from the table's when not. Syd, 2026-10-11, of the four
  shapes in previews: "this looks good. I checked big iphone, little iPhone, and iphone duo.
  ipad always had four."
- **The extension writes down each size it is handed** in the App Group's preferences
  (`RecordedWidgetSizes`), and the preview uses a recorded size in place of the table's, reading
  them again each time the app comes forward. The widget gallery asks for every size it offers, so
  opening our widget's page there records them all, with no widget placed.

**Every size a family is handed is kept, and the preview uses the ones for the screen it is on.**
Syd, 2026-10-10. The iPhone Duo has two screens and an iPad two ways up, and each hands a widget a
different size. The system does not say which screen a size is for, so it is worked out
(`RecordedWidgetSizes.chosen`): the sizes handed for one screen share their figures, so one family
is settled by its width and the others follow it. On a phone it is the widest set that leaves room
on the screen as it is turned, across and down, and the narrowest when none does; on an iPad the
narrower for upright and the wider for on its side. Both rules are Claude's.

- **What the iPhone Duo's widgets are handed**, from Syd's log of its simulator, 2026-10-10. Two
  sets, both at once, each time the widgets reload, whichever screen is in use; turning it
  brought the same two again, and folding it brought nothing:
  - small 190 square, medium 402 by 190, large 402 by 426, the tall size 402 by 662;
  - small 158 square, medium 334 by 158, large 334 by 354, the tall size 334 by 550.

  Syd's pictures the same day show where each is used. The cover, 466 points wide, has the
  second set: it keeps a column at the right for the clock and the dock, and its Home Screen
  does not turn ("spring board isn't rotating"). The inner screen upright, 669 wide, has the
  first. The inner screen on its side, 669 high, has the second again: the first set's tall size
  is 662 points high and does not go in.
- **The Duo has no published sizes.** Looked for on 2026-10-10: WidgetKit's declarations in the
  Xcode 27.1 release candidate's SDK are 27.0's, and Apple's table has no row for it. Before its
  sizes were recorded the preview took the nearest row, the 375 by 667 phone's on the cover and
  the 430 by 932 phone's on the inner screen.
- **What an iPad mini's widgets are handed**, from Syd's log of its simulator, 2026-10-10: small
  141 square and extra large 634 by 305, and the same after it was turned. Apple's table had
  given 120 and 540 by 260. So this iPad has one set both ways up, and the iPad half of the rule
  above has nothing to choose between there.
- **The screen can change under a running app.** Unfolding a Duo moves the app from the cover to
  the inner screen without giving it a new window. The app asks its window for its screen each
  time it is laid out (`ScreenReader`); reported once, it went on previewing the cover's widgets
  on the inner screen.

**The sizes do differ from phone to phone.** Syd, 2026-10-09: "I am afraid that the widgets will be
different sizes on each different model phone". They are: Apple's table has six different sets
across ten phone screens, a large widget running from 292 by 311 to 364 by 382 points. From
memory: Display Zoom changes them again on the same phone. So a preview at real size needs this
device's sizes, and one fixed set would be wrong on most phones.

**The preview's bounds are as tall as the large size.** Syd, 2026-10-10: "I think the the
preview's bounding box should be set to the Large widget, because the fourth is very tall. The
preview itself should be the correct size and scrollable." So the tall fourth size is never where
the preview starts, and it is scrolled when chosen. In the bar its shape is a little taller than
the large's and no more: in proportion it would be twice the height of the bar.

## How the preview is drawn

**It draws the widget's own view.** `WidgetFace`, in the `PhotosGoRoundWidgetFace` target, is the
one view for the widget and for the preview: a photograph fitted on black, or one of the faces
without one. Then the fit, the black around the picture and the faces can't drift between the two.
It loads a picture through `UIImage` or `NSImage` by platform.

**At real size, never shrunk; scrolled when its bounds are smaller.** Syd, 2026-10-09: "the preview
should be drawn at scale, centered, and cropped on either side if the view is not big enough. the
user will be able to resize the view, but I really want them to know what the pic actually looks
like". Cropping gave way to scrolling on 2026-10-10: "The preview's scroll area should be the size
of the widget. When the view is big enough, no scrolling is necessary. When it is not, you should
be able to scroll it either way. This will allow the user to see all of the image in landscape on
the phone, and when their iPad window is small". So the widget sits in its bounds when it fits
them, and scrolls both ways when it does not, on top and at the left alike.

**Its bounds are as tall as the large size, from the top of the view.** Syd, 2026-10-10: "Please
have the view surrounding the preview be sized for the largest image (at least on iphone), and
center the preview in it. Having everything jump around is annoying", and later the same day,
once the tall fourth size was known: the bounds are the large size's height, "the preview should
be centered in it. I don't want the text below it to jump around". Where the view is too short
for those bounds: "if the veritcal bounds won't fit, align the preview at the top".

**As wide as the screen.** Syd, 2026-10-10: "The iPhone 17e started with the initial size of
"Small", despite the fact that "Large" fits fine." The preview was then a row in the list, and a
list keeps a margin at each side; a medium or large widget did not fit "without cropping" and the
preview started on small. The Home Screen has room for them, so the preview's bounds run edge to
edge, above the list and not in it.

**Where the preview starts.** Syd, 2026-10-10: "the initial setting for which preview to show is
the largest that will fit without cropping, or the smallest". Then, seeing the iPhone Duo's outer
screen on its side start on a size that had to be scrolled: "the initial one should be the largest
that fits without scrolling if possible, or the small one if none of them fit without scrolling",
and "We should do that for everything". So the largest size no wider and no taller than the
bounds, or the small one, chosen again each time the bounds change: turning the phone, or
dragging an iPad's window. Until the screen and the bounds are known the preview is on the
smallest. A size the person picked is left alone, whatever the bounds; Claude's reading of "a
size the person selects".

**Pinned.** Syd, 2026-10-09: "we should try it having the preview stick and the rest scrollable.
will have to test both ways." A development build had a pin button that switched between the two.
On 2026-10-10, once the preview's width was right: "I want the pinned behavior". So the preview
stays at the top and the two lists scroll under it; the button and the scrolling-away layout are
gone.

**Where its pictures come from.** The app's own TinyCache, in the app's caches, so a preview never
takes a picture a widget was going to show, and the app is not held to the extension's memory.
It is a cache of one: each change takes the picture that is waiting, or fetches one.

**The preview is a small slideshow.** Syd, 2026-10-09: its picture changes by itself every few
seconds, and also when the person taps it. He chose that over changing only on a tap, and over
every five minutes as a widget does. So a person sees many of their pictures in the widget's shape
without waiting, which is what the preview is for. It is five seconds, to be settled when it has
been watched for a while; one picture fades into the next, as in the widget; it starts again when
the sources change, so a newly chosen collection is seen at once; and it stops when the app is not
in front. The preview shows "Scanning…" while its first picture is fetched.

**The icon in the faces is a picture carried with the view.** Syd, 2026-10-10: "include a full
resolution picture of the app icon in the bundle, and use it". The only icon an iOS app can load
of its own is the 120-pixel one the Home Screen uses, which was blurred at a widget's size, and a
widget extension has none at all. So a 1024-pixel picture, exported from
`Artwork/PhotosGoRound.icon` by Icon Composer's own tool, is among the resources of the
`PhotosGoRoundWidgetFace` target, and the app and the extension both have it. `Plans/App Icon.md`
has the command that makes it.

- **A face's icon is drawn from a copy no bigger than it is shown.** At its full 1024 pixels
  every gallery preview showing it was blank on an iPad mini and an iPhone Duo; with the copy,
  made in steps of 64 pixels and kept, they draw. 2026-10-10. Claude's reading of why, from memory
  and not from a log: the system leaves a widget blank when its pictures come to more pixels than
  it allows.

## The screen: controls in the bar

Syd, 2026-10-10, after the count on each row: "I think I want to try out the new design I have in
mind". It is built; his notes are `Plans/ios main view revision 2.md`. His words:

- "Liquid Glass all the way".
- **Nav bar, two groups.** "First group is the size control with proportionately-sized round
  rects for each available size. Second group is Photos/Files buttons".
- **Both groups are at the right of the bar.** After seeing the sizes at the left: "I want the
  size controls on the right as well".
- **Main view.** "Preview in largest size that will hit the view".
- **Below it,** "if there is vertical space below the preview", a scrollable view:
  - "Collections list, non-editable, with photo counts. Same rules about red text, sources not
    available, etc."
  - "Files/Folders list, which we have done noting with."
- **Why.** "This will allow the users a consistent place to have controls. The controls should
  move to the size on that weird view that the Duo has. Should scale with the larger text sizing.
  View is always visible. The info on what is selected will be shown when you can scroll it, but
  is optional."

**What that is on the screen:**

- **The sizes**, one shape for each size the device offers, in the widget's proportions, scaled so
  that the large size is as tall as a line of body text and growing with the text size the person
  has set. The one showing is filled with the tint colour; the rest are outlined. "I want the
  round rect outlines to be darker or thicker", so the line is two points.
- **The Photos button**, the system's `photo.on.rectangle.angled` symbol, Claude's best match from
  memory for the photo-library icon Messages uses. Syd, 2026-10-10: "let's use the same photo
  library icon as things like messages do, and for Files and Folders, let's use a folder". What
  it does goes by the access there is; see *Photos access*. It is greyed out only until the app
  has found that out.
- **The Files button**, the `folder` symbol, greyed out until adding files and folders is built.
  Syd chose that over building it now and over taking the section off the screen.
- **VoiceOver** is told "Choose collections", or "Select photos" with limited access, and "Add
  files or folders".
- **The two lists are one list under the preview**, with a "Photos" section and a "Files and
  Folders" section, scrolling under the pinned preview. An empty section says "No collections
  chosen." or "No files or folders chosen."

**Where the lists do not fit under the preview, the preview is at the left and the lists beside
it.** That is an iPhone on its side, and a short iPad window. It took three tries the same day: at
the left on a phone on its side and never on an iPad; then no layout of its own at all, "now that
the controls are always visible, the special view is on longer necessary"; then, seeing a phone on
its side with no lists, "no, this is worse. Go back to the preview on the left if the bottom text
does not fit". So it goes by whether a heading and one row, 120 points at the standard text size,
fit under the preview's bounds, and not by the device or the window's shape
(`SettingsLayout.listsFitUnderPreview`). At the left the preview's column is as wide as the
widest size and its margins, or half the view if that is less, and the widget is in the middle of
the column when the bounds fit its height and at the top when they do not.

**On a phone every control in the bar is a name and a picture, so the system can move it.** On
the iPhone Duo with the cover closed the system puts the bar's controls in a column at the side.
It moved Photos and Files and left the sizes, which were shapes drawn by a view of ours; a view of
ours is something it cannot rearrange. So on a phone each size is a bar button whose picture is
its shape, drawn with its own colours since a bar colours a picture all in one. Syd, 2026-10-10:
"you should not have to do any work for the nav bar to move on the iphone duo, so don't worry
about it right now".

**Both groups fit in the bar of an iPad's narrowest window.** As a bar button each, the six
controls and the system's window controls were wider than that window, about 373 points, and the
system folded what did not fit into a "…" menu. Syd chose drawing them closer together, over a
wider smallest window and over the menu. So on an iPad each group is one bar item, and the two
smallest shapes are narrower to press than a bar button. At the largest text sizes the shapes grow
and may not fit again; see `TODO.md`, *The iOS app*.

**The screen has no title.** The bar is the controls'.

**What it replaced.** The screen of 2026-10-09: a segmented size control under the preview, a
photo-library button beside the "Photos" heading and a folder button beside "Files and Folders",
each list as tall as the rows it held with the whole view scrolling, no navigation bar, and a
swipe to remove a collection. Each of those is gone, and the rules above are the ones in force.

## The first picture, as fast as possible

Syd, 2026-10-10: "I want to fix the scanning when coming back to foreground again. First of all,
could we show the first photo in the first collection as fast as possible?" Until then the first
picture waited for every chosen source to be counted, so that the pick could be weighed.

**When the preview has nothing to show, it puts up what costs least, in order.** He chose all
three steps:

- **Last time's picture**, which is a file in the app's caches: "we can cache the photo to disk
  so it does not take up ram". No call to Photos. It is kept for each size and each set of
  sources, so it is always from what is chosen now.
- **The first photograph of the first source**: one collection looked up and one picture asked
  for, with nothing counted. The sources are tried in the order they were chosen, and the first
  that gives a picture is the one. A folder has no first, and gives any of its own.
- **Then the usual picks**, each source weighed by how many pictures it holds.

If nothing can be had, last time's picture does not stay up: "No Photos found" does. Coming
forward with a picture already showing starts nothing over; the picture stays until the next
change. A preview showing "No Photos found" goes back to "Scanning…" and fetches at once:
photographs may have been added in Photos meanwhile.

**One count, kept, and refreshed behind the pictures.** Syd, 2026-10-10: "the entire reason I am
doing this is to be as performant as possible with my huge photos sources", and of the other
apps that do these jobs, "Most of the suck." Coming forward used to throw the preview's
remembered counts away, so its next picture waited while every source was counted, and the rows
counted every source again for themselves. He chose both changes:

- **The rows' count is the preview's count.** Each figure a row takes is written where the
  preview's picks read it. `CachedPreviewPictures` is both.
- **The remembered counts are kept when the app comes forward.** The next picture is picked at
  once from what was remembered, and the rows' recount brings the figures up to date behind it.

A row's count and a pick write the same file from threads of their own, so each changes only
its own figures, in one step (`RememberedCounts.update`), and neither loses the other's.

So each source is counted once for each time the app comes forward, and never on the way to a
picture. For the few seconds until a source's new figure is in, a pick is weighed by its old
one.

**A count of none is never remembered**, anywhere. Syd, 2026-10-10: "we need to get the refresh of
the library better. Repro case: Fresh sim. Launch app. Allow access. Choose Favorites (0 photos).
Dismiss chooser. Switch to Photos. Mark two photos as favorites. Switch back to PGR. No Photos
chosen", and "even if I kill the app and relaunch there are no photos chosen". A count stands for
an hour, so Favorites counted at none was not asked again for an hour, through any number of
launches. Now nothing is remembered of an empty source and it is counted again at each pick, in
the shared code (`SeveralSources`), so the widgets have it too. And the sheet reads the library
through a new catalog each time the app comes forward, since a catalog keeps the counts it has
taken.

**A widget starts the same way.** Syd, 2026-10-10: "of course, each widget will be doing this as
well". A widget with nothing shown yet for these sources at this size takes the first source's
first picture; after that each wake takes the weighed pick. `WidgetPictures`.

## The collections

**The Mac has two things, and "the collection picker" could be either.**

- **The list of chosen collections**, in the Settings window: one row for each collection that is
  chosen, filed under its folders, with its state beside it ("not reachable" and the like).
- **The picker**, in a window of its own: every collection in the library as a checkbox tree, with
  twisties, counts, and a mixed state for a folder with some of its albums chosen. What is ticked
  when Done is pressed is the set of Photos sources.

**The list is the first, and the picker is a sheet.** Syd, 2026-10-09, choosing between the two:
the list shows the collections that are chosen, and a button brings up the tree of the whole
library as a sheet. That is the Mac's arrangement made small. The tree itself seen a few rows at a
time would be hard to use on a phone: a library can have hundreds of albums.

**The sheet is a chooser, as the Mac's picker is.** Syd, 2026-10-09. It opens showing what is
already ticked. What is ticked when Done is pressed becomes the set of Photos sources, so unticking
a collection removes it. Cancel leaves the sources as they were, and nothing changes until Done.
Done cannot be pressed until the library has been read once, since with no reading it would take
away every collection that is chosen. A collection that was chosen and has since gone from the
library is not among what Done applies, so it leaves the list.

**A row shows the name and the count, and is red when something is wrong.** Syd, 2026-10-09: "name
and count and red if something is wrong". The Mac's row also shows the folders a collection sits
under and its state in words; here the folders are seen in the sheet, and the colour says there is
trouble.

**The count** is the number of pictures in the source, at the right of its row. Syd, 2026-10-10,
on why the "Selected Photos" row has no button: "we want that space for the count". It is counted
by the code a widget weighs its sources with (`SourceCounts`), so the row and the widget agree on
what is empty.

- **Counted each time the app comes forward**, and after Done in the sheet. A row keeps its old
  figure until the new one is in.
- **No figure where there is none to be had:** a collection that has gone, any collection while
  Photos access is off, a source that cannot be read.
- **A single file shows 1.** Syd, 2026-10-10.

**The sheet's counts arrive behind the names.** The catalog counts each collection in the
background, and the sheet reads it again every second until every count is in. See `TODO.md`, *The iOS app*, for
what that may cost on a real library.

**Tick boxes are where the Mac has them.** A folder has a box, which ticks or clears the albums
under it; a section heading has none. Syd, 2026-10-10: "there is no section tick on the mac".
`CollectionPickerView.twisty` on the Mac draws the box only when the row is not a section. The
box with its third state, for a folder with some of its albums ticked, is a button drawn with one
of three symbols, since SwiftUI's `Toggle` has two.

**One difference that is left.** On the Mac a section heading opens and shuts its section. Here
only folders open and shut. Not said: whether sections should too.

### What the sheet leaves out

Three things, by their kind and never by their name, in the one place both pickers get their
sections, `LibrarySectionGroup.grouped`. A section with nothing left to show has no heading. A
source of any of the three chosen before this stays in the Settings list until it is removed
there; the pickers no longer show it to untick.

- **Hidden.** Syd, 2026-10-10: "Mac has "Recently Saved" and "Hidden"", then "neither one should
  have `Hidden`". So Hidden came out of the Mac's picker as well. It is told by its kind, PhotoKit's
  `smartAlbumAllHidden`, so the device's language does not matter. On Syd's library it does arrive
  with that kind. `Plans/Apple Photos Plan.md` had "Nothing is hidden from the picker"
  and now has Hidden as its one exception.
- **The `wholeLibrary` kind.** It is the collection PhotoKit hands over as `smartAlbumUserLibrary`
  and titles *Recents*; on Syd's Mac it holds 96,306 photographs, most of the library and not all
  of it. Syd, 2026-10-10: "anything that has the `wholeLibrary` tag should be excluded". It is left
  out of both pickers.
- **Recently Saved.** First Syd wanted it kept; then, 2026-10-10: "Ditch "recently saved"".
  PhotoKit has no name for its subtype, so it is told by the number, 1000000218, measured on a Mac
  on 2026-08-26 (`Plans/Apple Photos Plan.md`, *Subtypes this document does not know about*), and
  given a kind of its own, `recentlySaved`. Seen 2026-10-10 on the iPhone simulator: it was in the
  sheet's *Utilities* before the change and not after, so the number is the same on iOS there.
  The other smart albums PhotoKit does not name, such as Captured by Me, are still listed.

## Taking a source out of a list

- **A collection** leaves by being unticked in the sheet and Done pressed, or by a swipe to the
  left on its row. Syd, 2026-10-11: "I think we need to implement swipe left behavior in the
  settings panel like we do for files anyway, and that will give a good way to remove troublesome
  connections". Until then its row could not be swiped: 2026-10-10, "non-editable". The Mac
  keeps what it has: select a row and press the minus button, with unticking
  for collections.
- **The line that says so is between the preview and the lists**, since both lists swipe now.
  Syd, 2026-10-11: "A line between the preview and the sources list. "To remove a collection,
  file, or folder, swipe left on it."" And: "it replaces the other message; it scrolls with the
  list; it is always there". So it shows with no sources chosen too, and "Swipe left to remove
  the file or folder." under the files goes.
  - It is part of the "Photos" heading, over the word. As a row of its own it stood apart from
    the preview and from the lists: Syd, 2026-10-11, "too much space between the preview, and
    the lists". With 8 points under it: "Just a bit more space between text and list". With 16:
    "this looks good".
  - It is in the colour of normal text, as the line about a folder's box is. Syd, 2026-10-11:
    "These should be the same color. I think that they should be black (in light mode), the
    same as normal text. The size is right."
  - It makes the heading taller, and what has to fit under the preview before the lists go
    beside it is reckoned without it (`SettingsLayout`), as is an iPad's smallest window. Asked
    whether to add it, Syd, 2026-10-11: "I don't see a problem".
- **Any row of a source**, "Selected Photos" among them. Syd, 2026-10-11: "you can remove any
  source line with a swipe. the widgets will continue operating as normal when the sources are
  updated". The "No Photos Access" row is not a source and has no swipe: Claude's reading.
- **A file or folder** leaves by a swipe to the left on its row. It has no sheet, so the swipe is
  its one way out. Syd, 2026-10-10: "the only thing that bothers me is how to remove files/folder
  sources, but swipe is probably good enough." A swipe is not something a person is shown, so a line under the
  list says so: Syd, 2026-10-11, "We can just add text for the removal", and the words are his,
  "Swipe left to remove the file or folder." It follows the line about a folder's checkbox, and
  shows whenever the list has anything in it.
- **There is no Edit button.** Offered three ways on 2026-10-09, with an Edit button that put the
  lists into delete mode as the third, Syd said "all three". On 2026-10-10, with the preview
  pinned: "let's ditch the Edit button as well".

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
  putting it right, the source was to be removed; since 2026-10-11 it stays, as below.

**"Source" covers both lists.** Confirmed by Syd, 2026-10-09: a file or folder that is gone, or
can no longer be opened, is treated as a collection that is gone is. The alert comes when the app
is opened or brought forward, then the Files browser so the person can choose it again. It was to
be removed if they did not; since 2026-10-11 it stays, as below.

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
with the capital P. He chose it over the last picture staying up, and over the plain icon. A widget
that already has a picture goes to "No Photos found" at its next change, when it asks for another
and gets none, and not before.

**Phase 3, as Syd set it out on 2026-10-11.** "First of all, if there are any problems with the
sources, the Photos or File Folder will be presented with a red background." And: "Any collection
or folder or file that disappears should be drawn in grey with text "(removed)" drawn next to it.
For Photos, when the picker is selected again, and then the user hits "Done", the entry will go
away in the settings panel. For Files, the user will have to swipe left to remove the entry."

- Both ways out are built. A collection gone from the library is not among what Done applies
  (*The collections*), and a file's or folder's row has its swipe (*Taking a source out of a
  list*). What is new is the grey, the "(removed)" and the red background.
- The alert of 2026-10-09 still comes, and the picker after it does not. First, asked whether
  they still come, Syd, 2026-10-11: "the alert and picker still come up, but they can all be
  dismissed without fixing anything". Then, asked how the Files browser comes up now that the
  alert names nothing: "Don't bring up either picker/browser. We have told the user that
  something is gone, and they can see what it is". The removal went with the first answer: a
  source that has gone stays in its list, grey, until the person takes it out.
- The paragraph above about several wrong at once is as it was on 2026-10-09; of it, the one
  alert stands, and the names, the sheet and the Files browsers do not.
- "The Photos or File Folder" is two things. Asked which, Syd, 2026-10-11: "The heading should
  have Red text, and the bar's button should have a red background". So trouble shows in the bar
  when the lists are scrolled out of sight or beside the preview.
- The colours have one rule. Asked what a row with trouble that should pass looks like, Syd,
  2026-10-11: "grey - something that is probably temporary; red - a problem that needs to be
  addressed".
- Syd cannot see the difference himself: "not that I personally can tell them apart - the red
  needs to be closer to orange/pink. I am color blind." So the view draws no system red:
  every red in it is `Color.trouble`.
- A source that has gone is grey, though it will not come back by itself. Asked which colour,
  Syd, 2026-10-11: "Gray "(removed)". It's gone from the source, but up to the user to remove".
  So red on a row is left for what the app is refused, which is Photos access turned off.
  Claude's reading of where that leaves red. Syd, the same day: "all rows served by photos are
  red if photos access is turned off". With access off the library cannot be read, so no
  collection is called gone then, and none is grey.
- A row with trouble that should pass says "(unavailable)", one word for every such trouble.
  Syd, 2026-10-11, chosen over nothing beside the name and over words for each kind. So the two
  greys are told apart by their words.
- A file or folder is known to the app by its bookmark, and one that does not open may have been
  deleted, or be on a drive that is not plugged in, or in iCloud Drive with no connection. When
  the app cannot tell which, the row says "(removed)": Syd, 2026-10-11, over "(unavailable)"
  unless the system is certain. How well the system tells them apart is not checked. So a folder
  on an unplugged drive may say "(removed)", and since nothing is removed for it, it is there
  when the drive is back. Syd, the same day: "removable media is not a common case for iOS, and
  a little more probably in iPadOS, but not worth doing much about".
- A file or folder is looked at by being counted, which happens each time the app comes forward
  anyway. One that cannot be counted is "(removed)", unless the failure is one that passes:
  any error of the URL loading system, a time-out or an unreachable network or host from the
  file system, or iCloud saying a file or its server is not to be had; and what the file system
  said is looked for under what Foundation says of it. That list is Claude's guess at what the
  system gives, and is not tried on a phone. `SettingsModel.Row.Trouble`.
- Files and folders are counted before Photos is asked anything, and the alert for what has
  gone waits for them. With a large folder that may be some seconds after launch.
- A collection is "(unavailable)" when access is given and the library cannot be read, which is
  when nothing can be called gone. Claude's.
- The heading and the button go red only with red rows. Syd, 2026-10-11, over any row that is
  not normal, and over red and "(removed)" rows. His first note had them red for "any problems
  with the sources"; with gone and unavailable sources grey, that is Photos access off and
  nothing else.
- How often the alert comes, now that a gone source stays. Syd, 2026-10-11: "The first time the
  app is brought forward; everytime it is launched. The only exception is if the launch shows it
  first, don't show again with the app is brought forward. In other words, the first time the
  app is launched or brought forward, and then every time it is launched from them on". Claude's
  reading, which he has not confirmed: a launch alerts for every source gone then, and a coming
  forward alerts only for one found gone since, so nothing is alerted twice in a run and nothing
  is kept between runs.

Then, the same day: "If permissions for photos have been revoked, we need to offer an alert with a
link back to Settings. Once the alert is dismissed, if we still can't get into Photos, the
collections will be displayed with red text." And a collection's row takes the swipe a file's
has, which "will give a good way to remove troublesome connections" (*Taking a source out of a
list*).

- With access off the chosen collections stay, red, under the "No Photos Access" row (*Photos
  access*). The alert comes by itself, and from the bar's Photos button.
- With no Photos sources chosen, the alert for revoked access does not come. Syd, 2026-10-11:
  "if there are no photos sources in the settings, do NOT bring it forward at all". So a person
  who refuses at first launch, and has chosen nothing, gets no alert for it. And it is one
  alert: "it should be once for the collection of sources, not once per source", "it's all about
  photos access", "if there are sources that depend on it, and it's gone, present. otherwise
  don't".
- So a collection that is wrong has two ways out, the sheet and the swipe, and with Photos access
  off, where no sheet comes up, the swipe is the one there is.

- Red has a symbol with it in one place. Asked whether red gets words or a symbol, as each grey
  has its word, Syd, 2026-10-11: "You can put one of those triangles with an exclamation point
  next to "Photos"". The rows under it are red and nothing more; the "No Photos Access" row
  above them has its warning icon already.

**The looking.** Each time the app comes forward:

- What is stored is read afresh.
- Each chosen collection is looked up in the library as it is now. One renamed in Photos, or
  moved to another folder, takes its new name and place, and that is stored. One that is no
  longer there stays in the list, grey, "(removed)". Syd, 2026-10-10: "we need to refresh the source list when
  the app is activated".
- The library itself is asked, not the picker's sections, so a collection the pickers now leave
  out, chosen before they did, is still found.
- When the library cannot be read, nothing is called gone: that is no evidence that anything is.
  Nor with limited access, where no albums of the person's own are listed.
- With Photos access off, no one collection is singled out: every one is red, and the list says
  access is off.

## Photos access

**First launch.** Asked on 2026-10-09 what the preview and the widgets show before anything is
chosen, Syd: "the user will automatically be prompted. The collections selector will come up after
the user asks for photos permission". So the order at first launch is: the app opens, the system's
Photos prompt appears without the person doing anything, and when it has been answered with full
access the collections sheet comes up. A person is led straight to choosing, and the time with
nothing chosen is short. Every time after, the app only reads the answer, which the person may
have changed in the system's settings since. The prompt uses the app's name: "Allow "PhotosGoRound"
to access your photo library?"

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
  Photos-Go-Round." Asked on 2026-10-09 whether the Mac's widget shows the icon too, Syd chose the
  icon on iOS only.
- **It is the plain icon, in full colour, with no words.** Syd, 2026-10-09. A widget waiting for
  its first photograph shows the icon greyed over, with "No Photos found", and the preview with
  "Scanning…", so the faces can't be mistaken for each other.

**When Photos access is refused, no sheet comes up.** Syd, 2026-10-09. Files and folders still
work, since they need no Photos access. With the lists sometimes out of sight under the preview,
Syd chose three ways to the system's settings, 2026-10-10:

- **The row.** "you should leave a grayed out button. And I would combine the row of "Photos
  access is off" with a button that says "Settings...". Should look like the icon, "No Photos
  Access" text, and "Settings..." button". So the collections section has one row: a warning icon,
  "No Photos Access" in red, and the button. The chosen collections stay under it, red.
- **The bar's Photos button** stays pressable and brings up an alert, "No Photos Access", with
  "Settings…" and "Cancel". Since 2026-10-11 it is the alert that comes by itself, with its
  words (*Design Decisions*, *Photos access*).
- **The preview's face** says "No Photos Access" when it has no picture to show, in place of the
  plain icon or "No Photos found", and tapping it goes to the system's settings. A folder's
  pictures still show with Photos access off.

Restricted access, by a parent or a profile, is treated as refused.

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

**The Photos button changes the picked photographs.** Syd, 2026-10-09, wanted a button for it; on
2026-10-10 he made it the one Photos button, and the row has no button: "we want that space for
the count". It calls `PHPhotoLibrary.presentLimitedLibraryPicker(from:)`, and the system's ask on
every run is turned off with `PHPhotoLibraryPreventAutomaticLimitedAccessAlert` in `Info.plist`.
So the person is asked when they want to change it, and not each time the app opens. The library
is read again once the picker has gone.

- **The target links PhotosUI by name** (`OTHER_LDFLAGS`). The picker is an Objective-C category
  in that framework, reached by a message and not by a symbol, so the linker saw nothing of
  PhotosUI in use and left it out. It worked where something else had loaded the framework, and
  on the iPhone Duo simulator, 2026-10-10, it was an unrecognized selector.

**How the selection is kept.** It is a source like any other, of a kind of its own
(`photos_selection`), in the same stored list, so a widget finds it where it finds the rest. The
app adds it when it finds access limited and takes it out when it finds access is anything else,
each time it comes forward. `ChosenSources.keepSelectedPhotos`.

- **Collections chosen with full access stay stored.** They are out of sight while access is
  limited, and back when full access is. Claude's, 2026-10-10.
- **Which photographs were picked is not stored by the app.** The source is only a name,
  "selected"; the system holds the selection. So after limited access, then none, then full,
  the app drops the source, the row goes, and nothing of the selection is left for it to show:
  the person chooses collections, or sees the app icon. Syd, 2026-10-11: "I don't know what we
  will get back from Photos". Not checked: whether the system still has the selection if access
  is made limited again. See `TODO.md`, *The iOS app*.
- **All of that can be done in the system's settings with the app never opened.** Syd,
  2026-10-11. The app reads the access there is when it next comes forward, and sees none of
  the steps between. The widgets are woken meanwhile and read it for themselves, with the stored
  sources as the app last left them. So after limited is made full, a widget whose one source is
  the selection gets nothing from it, and by the rules above shows "No Photos found" until the
  app is opened; then the app drops the source, and it is the plain icon. Reasoned from the
  code, not run.
- **While access is limited a collection gives no pictures.** A limited library still answers for
  a smart album such as Favorites, with the picked photographs that are in it, and those would be
  counted twice. `SystemPhotoLibraryPictures`.
- **With full access the selection gives none**, so it is never every photograph.
- **The row leaves by a swipe, as any row does, and comes back by the Photos button**, when the
  system's picker has gone: Syd, 2026-10-11, "By the Photos button. And if access is denied, we
  already have that case handled". Until then it could not be removed.
- **Swiped away, the selection is still stored, switched off.** A widget shows only from what
  is switched on, and the app adds a selection only when none is stored, so the row stays away.
  It stays stored that way whatever access becomes: asked whether the row should be back when
  access is made limited again after being off or full, Syd, 2026-10-11, chose the swipe
  remembered. `ChosenSources.showSelectedPhotos`.

From memory, not checked: the Mac has no limited answer, so there it is full or none already.

**The extension and Photos.** The app asks for access; an extension can't put up the prompt, and
the widget reads the status and never asks. On the Mac the widget extension shares what the app
was granted (`Plans/Photos-Go-Round Widgets.md`, *Next: the app's sources, then Photos*). On the
simulators, 2026-10-10, the widgets showed photographs under the app's permission the same way.
On Syd's phone they have shown photographs the same way since. A locked phone
is still to be seen, and is a to-do in `TODO.md`.

## One fetch at a time

The preview sat on "Scanning…" for good, twice on 2026-10-10. Both times a debugger showed two
of the app's threads inside PhotoKit's synchronous request for an image, each waiting on the
Photos daemon for leave to open the photograph's file, and neither ever answered. One such request
by itself comes straight back.

Two were being made because three things can ask the preview for its next picture, and two of
them often ask together: the slideshow's turn, and the fetch made at once when sources change or
are looked at afresh. A tap is the third. So the preview now fetches one picture at a time. A
change asked for while one is under way waits for it, and however many ask meanwhile, one more
fetch follows.

Claude had first put the stall down to the simulator's Photos daemon, because restarting the
simulator cleared it. It cleared because that launch happened to make one request.

The iOS widget's wakes do their work one at a time, through `SerialWork`, which keeps its own
requests apart the same way. That was an `NSLock` until 2026-10-11; Syd, 2026-09-17, wants none.
The Mac's widget still holds one across its wake. Whether two processes asking at once, the app and a widget, can do
the same thing was not tried.

## When Photos does not answer

Built 2026-10-11. A request to Photos for a picture had no time limit, so one that Photos never
answered was waited on for ever, by the preview and by a widget.

- **The limit is on the request itself**, in `SystemPhotoLibraryPictures`: 90 seconds, then
  `TimedOut` is thrown. It was 15, then 30 at Syd's "double that 15s timeout", 2026-10-25, and 90
  the same night, once an original from iCloud was found to take 30 to 65 seconds on his phone.
  `TimeLimit` runs the request on a thread that may block and waits for it only so long.
  Counting a source has no limit; on a large library that is slow and not stuck.
- **A photograph on the device first.** A widget asks for each from the device alone; one only
  in iCloud has its download started, nobody waiting, and another is picked. After four of
  those, the next is asked for from iCloud too and waited for. The app's first picture is waited
  for straight away. Syd, 2026-10-25, of passing over and of waiting longer: "do BOTH".
  `PhotosSource`.
- **The request given up on is not stopped.** PhotoKit's synchronous request cannot be
  cancelled. Its thread stays blocked until Photos answers or the process ends, and the new
  request is made beside it. Two at once is what never came back on 2026-10-10, *One fetch at a
  time*, so whether the new one is answered is not known. Syd, 2026-10-11, is not worried by
  that: it is what the doubling waits are for.
- **The wait is `RequestBackoff`**: 5 seconds, doubling, to 30 minutes for a widget and one
  minute for the app's preview, and then that long each time for as long as Photos does not
  answer. An answer ends it, with a picture or with none.
- **A widget keeps its wait in `asking.json`**, beside its pictures, since each wake may be a
  new process. A wake inside the wait asks Photos nothing. The timeline it hands over is due
  again when the wait is over, whatever the widget is set to; the system reloads a widget no
  sooner than five minutes on, so the short waits come to five minutes there.
- **During the wait a widget shows its last picture as it is**, or "No Photos found" with none
  yet; the preview puts "Scanning…" over its picture, or over the icon. Syd, 2026-10-30.
- **The preview keeps its wait in memory**, and other sources chosen end it. During it a
  picture kept from last time is still looked for, so another size chosen shows its own.
- **No other source is asked when one goes unanswered.** Passing over a source in trouble is
  right for a folder that cannot be read, and here it would wait 90 seconds more for each. Its
  count is kept, too: a count is forgotten when a source fails, and counting again is the slow
  part.
- **The cache used to delete the picture on show before fetching the next**, which left nothing
  to keep up when the fetch failed. `TinyCache.take` now clears what was shown only once there
  is something to show in its place. That holds for a source with nothing in it as well: with
  two sources chosen and the first empty, the first's turn was deleting the picture before the
  second was asked.
- **The agent had solved this already, in its own way**, and it was not looked at first: Syd,
  2026-10-11, "didn't we solve this in the PGR service?". `BoundedPhotoLibrary` runs each call to
  Photos against `Deadline`, and `SourceBench` rests a source that only times out, doubling to
  an hour. Neither fits as it is: the widgets ask for a picture at the widget's size through a
  binding of their own, synchronously, and a widget's wait has to last from one wake to the
  next. Bringing the two together is in `TODO.md`.
- **The app lists Photos collections through `BoundedPhotoLibrary`**, since 2026-10-11. It was
  the plain `SystemPhotoLibrary`, with no limit, though the bounded one is in a target the app
  already links. Not tried against the collections sheet: *Claude iPhone* has limited access,
  where the Photos button opens the system's own picker.
- **The Mac's widget does as the iOS widgets do**, since 2026-10-28, when its timeline was
  brought onto `WidgetPictures`: the limit, the waits, and the picture kept as it is.

**How it was tried.** On *Claude iPhone*, with a build whose limit was a billionth of a second,
so that every request was given up on. Both widgets kept their own pictures with "Scanning…"
over them, their waits went 5, 10 and 20 seconds, and the preview asked again 5 and then 10
seconds on. With the real limit back, the next wake got a picture and `asking.json` was gone.
A request that Photos really leaves unanswered has not been seen since the limit went in.

## The files and folders

**Next, before the alerts.** Syd, 2026-10-11: "I think we need to do files and folders next,
because it colors how we deal with connections to sources not working". Before that they were
not the priority: 2026-10-10, asking for the preview next, "We may not even do files and folders.
We probably will but it's not the priority", and earlier on 2026-10-11, "I could remove them and
ship now".

**What there is.** The bar's Files button adds folders and image files, each gets a row with its
count, the preview and the widgets show from them, and a swipe takes one out. A folder's row
has a checkbox for its subfolders.

**Single files as well as folders.** Syd, 2026-10-09: the bottom list takes both, as the Mac's
does, so the shared view is the same everywhere. The Mac app has a menu item for each, *Add
Files…* and *Add Folder…*. A single file is one picture, and one that is no longer there is not
counted as none: it cannot be read. It is a source in its own right, `FileSource`; until
2026-10-11 a file had a row and a count and no picture ever came from it.

**Each folder has its subfolders option, as on the Mac.** Syd, 2026-10-09, choosing that over a
folder always including its subfolders. It is a checkbox at the right of the folder's row, after its
count: Syd, 2026-10-11, "I'm thinking a checkbox in the same line as the entry that toggles it
on or off", and "I want the checkbox to the right of the count so it does not move around". A
single file's row keeps the room a box would take, so the list's counts stay in one column. The
Photos list's counts are at the edge, a box's width further right, and that stays: Syd, the
same day, "this is fine the way it is". The Mac app has a sheet for it, with the folder's name, its location and
one switch, "Add contents of contained folders" (`ConfigureSourceView`); tapping the row to
bring up such a sheet was the plan here until then. A file's row has no box. Ticking it counts
the folder again and starts the preview over, since it is other pictures from then on. The
widget's code reads the option for each folder, as `SourceSpec.recursive`. A newly added folder
starts with it off, as on the Mac: only the pictures directly in the folder, so a folder never
brings in more than was asked for. Syd, 2026-10-09.

**A line under the list says what the box is for.** Syd, 2026-10-11: "needs some text somewhere
explaining what it the checkbox is", and the words are his: "Include nested folders when checked."
It is the list's footer, out of the rows' way, and shows only when the list
has a folder in it. The line about the swipe is under it: *Taking a source out of a list*. VoiceOver reads the box as "Include subfolders".

**Choosing.** SwiftUI's `fileImporter` on both platforms, in place of the Mac app's `NSOpenPanel`.
It puts up the Files browser on iOS and the open panel on the Mac. It is asked for folders and
image files together, several at once, so the one button does for both. On iOS, seen on a
simulator, 2026-10-11:

- An image file has a circle to tick, and several can be ticked.
- A folder is chosen by going into it and pressing Open with nothing ticked. So files and a
  folder are not chosen in the same go.
- Open at the top level chooses the whole of "On My iPhone" as a folder.

**A path is not enough on iOS, for the app as much as for a widget.** The Files browser lets the
app into what was chosen for as long as the app runs. After that the path is refused, and a
bookmark made while the app was let in is what opens it again. So:

- The app leaves a bookmark for each file and folder as it is added, in `WidgetSource` in the App
  Group container, which is where the Mac's app leaves its own. Removing the row removes the
  bookmark.
- The app's preview and counts and the extension's wakes all open through those bookmarks:
  `BookmarkedSources`, in `TinyCache`. Each is opened once in a process and kept open.
- Nothing is read by its path while bookmarks are kept. One whose bookmark does not open cannot
  be read, which is not holding nothing. A simulator would read the path, and so would say a
  widget can open what on a phone it cannot.
- What no bookmark can be left for is not added, and an alert names it.

**The risk is the widget reading what the app chose.** A sandboxed app is given a folder only
because the person chose it, and keeps that with a bookmark. The widget is another process. On the
Mac a bookmark the app leaves is what the widget opens today (`BookmarkedSources`, as on iOS).
From memory, not checked: iOS bookmarks are made without the Mac's security-scope option, and
whether an extension can open one its app made is not something I know. If it can't, a folder's
pictures would have to be copied into the App Group container, or folders would work only in the
preview. If the answer is no, the list stands and what changes is what adding a folder does
underneath.

**On a simulator the answer is yes.** 2026-10-11, *Claude iPhone*, iOS 27: with a folder and a
file added, the extension's next wake logged `opened Coins through its bookmark, and it can be
read: 4 things in it`, and the same for the file. The app, quit and launched again, opened both
the same way. A widget drawing a folder's picture was not looked at. The phone's answer is the
one that counts, and it follows: the same line from the extension's process, or `did not open`
or `cannot be read` in its place.

**On Syd's phone the app shows files from iCloud Drive, and a widget does not.** Syd,
2026-10-11: "This is working well. And on my device, it's working with files from my iCloud
drive", and then of the widget: ""No photos found" for iCloud files". So the app's own bookmark
opens there and the extension gets no picture. Files kept on the phone itself do show in a
widget: "I was able to see files actually stored "On My Phone"". So the extension opens the
app's bookmark for those, on a day the app has been used. And after a restart of the phone they
still do: "I restarted. The widgets are showing the files from the "On My Phone" folder". The
app had not been opened since: "the pictures started showing after a restart without opening
the app".

**For the iCloud Drive folder the extension never found the bookmark.** The phone's log,
2026-10-11: the extension, `no bookmark has been left for Public`, on every wake; the app, the
same minute, `opened Public through its bookmark, and it can be read: 90 things in it`. A
bookmark's file is named for the folder's path, and the name was worked out with
`standardizedFileURL`, which asks the disk and takes `/private` off the front of a path it can
see. The app could see the folder and the extension could not, so they had two names for it.
The name now goes by the path's spelling alone (`FolderBookmarks.fileName`). A file or folder
added before that has to be taken out and added again. With that done on the phone: Syd,
2026-10-11, "Hey! The widgets are working now!", and then "I removed the icloud folder and the
on-device files started showing up". While the iCloud Drive folder was chosen the
widgets said "No Photos found", and the phone's own files did not show either. The phone's log
for those minutes: the extension, `opened Public through its bookmark, and it can be read: 90
things in it`, and no error after it. So iOS lets the extension into an iCloud Drive folder
through the app's bookmark. What a wake then did with the files is not in the log: the folder
was chosen, with its bookmark under the new name, for 75 seconds before it was taken out, and
"No Photos found" may have been left from the minutes before, when neither folder's bookmark
could be found. The extension now logs what each wake came to.

**Then the widgets showed iCloud Drive's pictures.** Syd, 2026-10-11, with the downloads taken
off the folder first, and the phone's own folder taken out of the list: "previews are woking",
and of the widgets, "and I am seeing pictures from iCloud". So "No Photos found" was left over,
and a widget reads an iCloud Drive folder through the app's bookmark. After a restart of the
phone too: Syd, later that day, of the restart that was left to try, "I did the restart, and
things are fine". The log collected then, 14:21 to 14:31, holds no line from the
extension, so no wake fell inside it.

**And a widget added after that said "No Photos found".** Syd, the same day: "I just added
another widget and is says "No Photos found"", with the iCloud Drive folder the only source and
the others still showing its pictures. The phone's log, 14:56 to 14:57, says why: the
extension cannot read a file that is not on the phone. Each wake picks three files; 34 picks
logged `download status NSURLUbiquitousItemDownloadingStatusNotDownloaded; reading it, The file
couldn’t be opened. (NSCocoaErrorDomain 256)`, at once and with no wait. Five wakes of seven
ended in "No Photos found"; two landed on a file that was on the phone and showed it. The app
reads the same files, and reading one fetches it. Syd had it before the log was read: "I think
that it is failing to download pictures, and showing No Photos found", and "when I went to reset
the settings, I started getting No Photos Found". 
**So a folder's pictures are picked from the files that are on the phone, and some of the rest
are asked for.** Syd, 2026-10-11, choosing that over leaving it as a known limit. `DeviceFiles`,
in `TinyCache`:

- A pick is made among the files iCloud Drive has on the phone. A file that is not in iCloud
  Drive always is.
- As many of the others as the pick wanted are asked of iCloud Drive, with nobody waiting for
  them, so that more are there next time. Nothing is copied: what comes is iCloud Drive's own
  and the system's to take away.
- With none on the phone they are tried all the same. The app's reading fetches one; a widget's
  does not, and it says "No Photos found" until one has come.
- A pick tries three files and gives up, and the next source is drawn. When no source has given
  a picture, each folder is gone through file by file until one does, the ones on the phone
  first, then the rest: Syd's rule, in *Design Decisions*, and `SeveralSources` is where the
  order is kept. Every file is tried, the ones not on the phone as well, though a widget's reading
  of one fails at once: Syd, 2026-10-11, "I prefer for the widget to try until the system kills
  it or it runs out of files". One of them may have come since it was asked for.
- The app's preview picks the same way, so it shows what a widget would.
- A row's count, and the weight a folder has among the sources, is of all its pictures,
  wherever they are.

**With the screen kept unlocked and the app left running, every wake showed a picture.** The
phone's log, 2026-10-11, 15:56 to 16:06: thirteen wakes, in bursts about two and a half minutes
apart, each answered with a picture inside a second, and no file passed over. Syd: "This is
working much better". Neither the app nor the extension asked iCloud Drive for anything in those
ten minutes, so by then the whole folder was on the phone; the app, running for twenty minutes
before, is what will have fetched it, three files a pick, and its asking is before the log
begins.

**The extension's asking is honoured, and the files come.** The phone's log, 2026-10-11, 16:05
to 16:25, with the app killed and the downloads taken off the folder: eighteen times the
extension logged `asked iCloud for 3 of 3 files that are not on the device`, with no refusal.
The first wake to find nothing on the phone asked for three, failed to read the three it had
picked, went through the folder, and had a picture inside a second: one had come already. All
twenty wakes in the log showed a picture, and no line is the app's. So a widget shows an
iCloud Drive folder by itself, without the app, and nothing more is needed from the app or from
iOS.

What a widget shows while a folder has nothing on the phone is "No Photos found", by Syd's rule:
it has been gone through and has none to give. It looks again at its own time, like any other change: Syd,
2026-10-11, "the widget looks again when the system pings it", choosing that over the quarter of
an hour it was. And the system may not ask even then: the phone's log for 15:01 to 15:23 that
day, with the app killed and the screen locking, holds no wake of any widget.

**A folder in Dropbox shows nothing.** Syd, 2026-10-11, on his iPad: "I added a folder in my
Dropbox folder on my iPad, and it is not showing anything", and "I wonder if there is a way to
ask Dropbox to download files for us". Not looked into: whether it is the app or the widgets,
and what the log says. What is asked for files not on the device is asked of iCloud Drive, and
Dropbox is another provider. `TODO.md`, *The first release: PhotosGoRound Widgets*, "Cloud storage such as Dropbox".

**If the pictures have to be copied, the copies need a bounded cache.** Syd, 2026-10-11: "if we
have to download files at new sizes, it sounds like we have to reproduce the caching that we do
in the PGR Service", "so we don't fill up the phone". Nothing is copied as things are: a widget
keeps the picture it is showing and one more, at its own size, for each setting at each size.
A widget reads iCloud Drive through the bookmark and asks for what is not on the phone, above,
so nothing has to be copied.

**What iOS downloads from iCloud Drive to be read is not ours to bound.** The app's preview
shows files that are not downloaded, so reading one fetches it. Syd, 2026-10-11: "the phone will
undowload things 1. if it runs out of space; 2. opporunistically. I am not worried about iCloud
downloads filling up the phone too terribly much", and "Much more concerned with copying files
to app's filesystem". Copies of ours are the ones nothing evicts, which is the case against the
copying route.

**Folders in iCloud Drive** may not be downloaded. From memory: reading one can mean waiting for
it, which a widget extension has little time for.

**What the web says, 2026-10-11.** Apple's forums and two scripting apps' forums; no Apple
document covers a widget opening a bookmark its app made. Nothing here has been tried on the phone.

- iOS has no security-scope option; a plain bookmark is what keeps access. Apple DTS, forum
  threads 766646 (Oct 2024) and 797469 (Aug 2025). This was "from memory" above and is now checked.
- Another process opening it is not promised. DTS, thread 797469, Dec 2025: a plain bookmark
  carries an "implicit ephemeral" scope that gives access to any process that resolves it, lasting
  "until reboot at the latest", believed to hang on the access of the app that made it, and "not
  formally documented nor something that can really be relied on". So it can work in the extension
  on the day the app was used and fail after a restart.
- The one report of this exact case on iOS failed. Thread 693819, Nov 2021: a bookmark made in the
  app with no options, passed through the App Group, gave "you don't have permission to view it" in
  a Share Extension. Nobody answered it.
- On the Mac, DTS said the same of app-scoped bookmarks: valid only in the app that made them
  (thread 66259, 2018). Its way round, each process making its own bookmark from a URL handed to it,
  needs the extension to be handed a URL, and a widget cannot show the Files browser.
- Scriptable keeps its bookmarks by process for this reason: one made in the app's settings works
  "in the app and not from the Share Sheet, Siri and Shortcuts", and one for Shortcuts has to be
  made by a Shortcuts action. Its documentation does not mention widgets.
- An app's own iCloud container is a different thing from a folder chosen in iCloud Drive, and a
  widget with the iCloud entitlement can reach it, with trouble: `url(forUbiquityContainerIdentifier:)`
  began returning nil in a widget in the iOS 16.1 beta (thread 715078, FB11529890, no answer).
- A file in iCloud Drive that is not downloaded is the other way a widget gets nothing. Scriptable
  and Pythonista widgets go blank or are refused on such files while the app reads them; the
  download has to be asked for and waited on.
- Where everyone ends up: the app reads what was chosen and puts small copies in the App Group
  container, and the widget reads only those.

What this does not settle is which of the two it is on Syd's phone, the bookmark or the download.
A file kept on the phone itself shows in a widget, and after a restart too, above. So the
bookmark is not what fails there, whatever DTS will promise of it. For the iCloud Drive folder
it was neither of the two: the extension looked for the bookmark under another name, above.

**It matters least here.** Syd, 2026-10-08: on an iPhone hardly anyone will use a folder, on an
iPad slightly more will.

### What Widgetsmith does instead

Syd, 2026-10-15, having looked at it the night before: Widgetsmith "does not have support for
files", and pictures chosen one by one from the library are "limited to 10", copied "to the app
folder from Photos as you set it up".

- **So files and folders are something it does not do at all.**
- **Pictures chosen one by one are copies made once**, at setting up, rather than read from
  Photos at each wake. Ten copies fit any memory limit.
- **An album can be chosen instead**, Syd, the same day; how Widgetsmith deals with large
  pictures in one is not known.
- **Not a competitor.** Syd, the same day: "I will never compete with widgetsmith. but it's
  good to know", and "This app is for more than just your Photos Library": files and folders
  are sources in their own right, not an addition to Photos.

## The App Group comes first on iOS

The Mac widget reads the app's sources from the app's preferences, through an entitlement the
Store does not accept; moving them into the App Group container is a to-do under the menubar app
in `Plans/Photos-Go-Round Widgets.md`. iOS has no such entitlement at all, so the iOS app and its
widget use the container from the start, and the menubar app then takes what is already built.

- **The group's name is in each `Info.plist`**, as `PGRWidgetAppGroup`, because it differs by
  configuration. The app writes the source list there (`ChosenSources`), and each wake of the
  extension reads it (`PhotoTimeline`). The sizes the widgets are handed are kept in the same
  preferences.

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
- `Widgets/Shared` — what both platforms' widgets use, as package targets with tests beside them:
  Syd, 2026-10-09, choosing that over plain files added to each app target. The models are
  written test-first.
  - `Sources/TinyCache` and `Tests/TinyCacheTests`, from the top-level `Shared/`.
  - `Sources/PhotosGoRoundWidgetSettings` and `Tests/PhotosGoRoundWidgetSettingsTests`: the
    settings screen, its models, the collections sheet, the preview, the sizes, and what a wake
    does (`WidgetPictures`). The name is in the style of the package's longer names: Syd,
    2026-10-09, over the shorter `WidgetSettings`.
  - `Sources/PhotosGoRoundWidgetFace`: what a widget draws, depending on nothing, so an extension
    links it without the settings. The icon picture is among its resources.
- `Widgets/iOS` — the iOS app, in `App`, and its widget extension, in `Extension`. Each has
  `Sources`, and `Resources` with its `Info.plist` and its entitlements.

**One copy of what the Mac already has.** Asked on 2026-10-09 how the Widgets code should get the
tree-building and the Photos reading, both of which were tied to the Mac, Syd chose one copy that
everything uses over new code beside the old.

- **The tree builder**, `Foldered` and `FolderNode`, is in `PhotosGoRoundAgentAPI`, which the Mac
  app and the Widgets settings both link. It was in the Mac app's own target.
- **The Photos reading was in the kit**, about 1,900 lines, with collections, assets and image
  data behind one protocol, `PhotoLibrary`, and one PhotoKit type, `SystemPhotoLibrary`. The kit
  compiles for iOS as it is, checked 2026-10-09, so the Widgets settings could have linked the
  whole kit. Syd chose the other way: the Photos reading carved out into a shared target of its
  own, `PhotosGoRoundPhotoLibrary`, in `Shared/Sources`, which the Widgets app links and the kit
  depends on. It holds the protocol, `SystemPhotoLibrary`, `BoundedPhotoLibrary`,
  `LibraryCollection`, `PhotosCollectionCatalog` and `RequestBudget`; the kit keeps
  `PhotosCollectionSourceProvider`, which is its own.
- **Two small helpers went to `PhotosGoRoundAgentAPI`**, because the kit and the new target both
  use them: `BlockingWork`, and `Duration.milliseconds`.
- **Its tests are still in the kit's test target**, so that the move only moved. A test target of
  its own is a later tidying.

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
the ios app". So these are not asked until then:

- Whether its Settings window lays itself out as this screen does, with the controls in a bar.
- Whether it has the first-launch flow, the wizard, and the alerts when a source goes wrong.
- Whether its preview is pinned as this one is.
- Whether its widget shows the icon faces, as the iOS one does, or keeps its sentences.

What is already decided about it stands: it shows this same view, and it takes the same bundle
identifier.

## One view for three platforms

The menubar app's Settings window is to show the same view, so the view and its models are in
`Widgets/Shared/Sources`, where an iOS target and a Mac target can both compile them. What differs
by platform is small, and each place says so in the source: the sizes the preview offers, the
backdrop colour, the "Settings…" button and the way to the system's settings, which are iOS's.
The tick box with its mixed state is drawn from three symbols on both. The Mac app's own
`CollectionPickerView` imports AppKit for the mixed-state checkbox, and is not shared.

The existing Photos-Go-Round.app keeps its own Settings window. It talks to an agent and this view
does not.

## iPad

The same screen as on a phone. An iPad's window can be dragged to almost any shape, and Syd,
2026-10-10: "We need to worry about people resizing the app on iPad". So:

- **The layout goes by the room there is, each time the window changes.** The lists are under
  the preview when a heading and one row fit there, and beside it when they do not; the size shown
  is chosen again for the new bounds until the person picks one. *The screen: controls in the
  bar*, and *Where the preview starts*. An earlier rule by the window's shape, and before it one
  by the height class, both went: the first kept one column in a short wide window with almost no
  height for the preview.
- **The smallest window.** Syd, 2026-10-10: "The minimum size of the window should be large enough
  for a small widget preview to completely show, the size controls, and the "Photos" title and the
  "Choose..." button, plus one row, at the standard text size. At larger sizes, the text will be
  cut off, but at least you can get to the button." Asked twice whether the redesign changes it:
  as it was, and "the smallest iPad window does not change". So the window's smallest height is
  the bar, a small widget, its padding, and the heading and one row, 120 points at the standard
  text size; its smallest width is 320 points, or the small widget and its margins if that is
  more. The window's own margins are added, and it is asked of the system through the window's
  scene (`sizeRestrictions`). From memory, not checked: an iPad honours that in its resizable
  windows. At that size the lists are beside the preview, since its bounds are as tall as the
  large size.
- **The bar at that width** holds both groups only because each is one item drawn close
  together; see *The screen: controls in the bar*.
- **A widget's size goes by the screen, not the window.** The app asks its window scene for the
  screen, and the preview's sizes are for that screen whatever the window is dragged to.

## The wizard, and the how-to page

**A wizard, before the Store.** Syd, 2026-10-10: "we need a full-blown first-time launch wizard.
Add a stage after everything else for that in the plan"; on 2026-10-11 it moved before the App
Store, as Phase 6. Until then first launch is what is built: the Photos prompt by itself, then the
collections sheet. What its other steps are was not said; choosing collections is the obvious one.
Not said: whether a person can see it again after the first launch.

**How to add a widget.** A short page for a person who has just installed the app and does not
know how a widget gets onto the Home Screen. The steps differ a little between iPhone, iPad and
the Mac, so the page's words are one of the things that differ by platform. Syd, 2026-10-09. It is
part of the wizard: Syd, 2026-10-10, "the "how to add a widgets page" is part of the launch-time
wizard". So the settings screen has no button for it.

**No About page.** On 2026-10-09 Syd chose both a "How to add a widget" page and an About page
with the version, over an About page only and over the one screen being the whole app. On
2026-10-10: "at this point, I think we are going to drop the about". So nothing in the app shows
its version and build; the system's own settings and the App Store listing do.

From memory of the review guidelines, not checked: App Review rejects an app that is only a shell
for its extension. The settings, the preview and the wizard are what this app is besides its
widgets.

## Telling one widget from another

Looked up 2026-10-10, before building a cache for each widget.

- **The system has no name or number for a placed widget.** A timeline provider is told the
  widget's kind, its size, and its settings, and nothing else. Apple's page on the provider says
  a person can add several of one widget and the provider "needs a way to differentiate which
  instance" is asked about, and that the settings are that way.
- **Two widgets with the same settings are, to the system, one.** From a reply on Apple's
  developer forum, not from Apple's documentation: there is no way to tell them apart "by
  design", and the system appears to feed both from one timeline. So they would show the same
  picture at the same moment whatever the extension kept for each.
- **So a cache for each widget can only be a cache for each set of settings.** Widgets set
  differently are different widgets, and ones set alike are not.

**Two settings, then.** Syd, 2026-10-10, chose that widgets of one size differ by the interval
and by "a second setting whose only job is to make a widget different", so that two with the
same interval can still show different pictures. He chose it over the interval alone and over
leaving one cache for each size. Two widgets showing the same picture by chance is fine: "Each
widget does have its own cache. But if each widget ends up with the same picture by happenstance,
that's ok".

**What he hopes the second setting is: an invisible random seed.** "I was kind of hoping we would
have some kind of invisible random seed as a setting". So nothing for a person to see or set:
each widget gets a seed of its own when it is placed, and keeps it. Whether the system allows a
setting that is both hidden and different for each placed widget is not known; what was found
above says it gives a widget no identity of its own. Tried 2026-10-11, and it does not: *The trial, and what was built*.

Sources: Apple, [AppIntentTimelineProvider](https://developer.apple.com/documentation/widgetkit/appintenttimelineprovider);
Apple Developer Forums, [Is it possible to uniquely identify a widget during timeline
creation?](https://developer.apple.com/forums/thread/738251).

### Whether anyone has made a setting that is hidden and different for each widget

Looked up 2026-10-11. Nobody was found who has. Every answer found, from 2020 to 2024, says a
placed widget has no identity besides its settings, and each way of slipping one in has a report
against it. None of it is from Apple's documentation, and none was tried here.

- **`WidgetInfo.id` is not one.** Apple's page calls it "the stable identity of the widget", but
  its type is `WidgetInfo`: the value is its own identity, which is the kind, the size and the
  settings again. It is also what the app gets from `WidgetCenter`, not something a timeline
  provider is handed.
- **A default made fresh for each widget is the nearest thing, and is reported not to work.** A
  setting's default can come from code: `defaultResult()` on an entity's query, which is how
  Apple's Notes widget arrives already set to a note. A seed made there would be invisible until
  someone opened Edit Widget. But a developer reported in October 2024 that `defaultResult()` is
  called when the first widget is placed and not for the ones placed after it, which get the
  first one's value. An Apple engineer asked for a bug report, FB15592256; the thread ends there
  with no fix. If that still holds, every widget would get the same seed. Not tried on 26 or 27.
- **A value set in the provider is not kept.** Reported in 2020, of the older kind of settings: a
  provider that fills in a missing setting draws correctly, but the widget's stored settings do
  not change.
- **Nothing was found that lets the app write a placed widget's settings.** It can read them.
- **Whether a setting can be kept out of Edit Widget is not known.** A settings type can say which
  of its settings the panel lists, and show some only when another has a given value. No source
  found says a setting left off the list is hidden.
- **What apps do instead is a choice the person makes in Edit Widget.** Widgetsmith is the usual
  example: the app holds named designs, and the placed widget is set to one of them. That is the
  named settings of `Photos-Go-Round Widgets.md`, *Telling widgets apart*.
- **Reloading goes by the settings too.** Reported on Apple's forum: a reload reaches the other
  widgets only where their settings are exactly equal.

Three Stack Overflow questions ask the same thing. The site would not let them be read; the one
excerpt seen says "you don't get any id for the widget so you cannot distinguish two widgets with
the same configuration".

**What this does to the invisible seed.** It is not ruled out, because the one report against it
is from 2024 and of unknown system version. It is unlikely enough that the trial comes first: a
setting whose default is a fresh value each time it is asked for, two widgets placed, and the log
read for whether they got different values.

### The trial, and what was built

Tried 2026-10-11 on *Claude iPhone*, iOS 27: two small widgets side by side, each with its
settings drawn across its face, and the log read.

- **A setting left out of the panel's summary is hidden.** Edit Widget listed the two settings
  the summary named and not the two it left out.
- **A default made in code is asked for once, and every widget gets it.** `defaultResult()` ran
  when the app was installed, and not when a widget was placed. The second widget got the first
  one's value. So the report of 2024 holds on iOS 27, and there is no invisible seed.
- **A value made up when the settings are created is not kept.** It was a new one each time the
  extension was asked.
- **Widgets set alike are fed from one timeline.** The second widget was never asked about. It
  showed the first one's entry, down to a number made up two minutes before. The extension is
  asked once for each different setting at each size: not once for each widget, and not once for
  each size.
- **What a person picks from a menu is stored as it was listed.** The menu is listed afresh each
  time it opens. So a value made up for each line of it is a different one at each pick, and
  that is what the delays rode on.
- **A widget placed before there were settings takes the default** and goes on working, which is
  what the widgets on Syd's phone will do.
- **A widget whose settings type is gone stops reloading**: "Returned view collection was either
  nil or empty". So `PhotoWidgetSettings` and its `changes` keep their names once widgets are
  out.
- **One minute was reloaded after five.** The 1-minute widget was asked at 11:02:29 and next at
  11:07:32; the system had scheduled it so.
- **Not found out:** whether a widget left at the default keeps the value it was placed with when
  the default later changes.
- **The menu cannot tick a duration that carries a delay.** The system ticks the line whose
  value is the one stored, and every line was made up afresh. Listing the stored value needs the
  widget's own settings where the menu is made; a query that asks for the settings it belongs
  to, `@IntentParameterDependency` on its own parameter, never answered, and the menu stayed on
  "Loading…" through two installs. So it was the tick or the delays.
- **A fixed list is ticked by the system**, and its row in the panel is drawn just as the
  made-up list's was: the duration in blue, with nothing to say a menu is behind it. Syd,
  2026-10-11, had wanted that "a control that brings up a menu should look like a menu, not a
  button"; the panel is the system's and nothing found changes the row, and of looking further
  he said it "is not important".
- **A widget whose stored setting is of a kind that is gone takes the default.** The two widgets
  set under the delays went on working when the setting became a fixed list under another name.

**What was built on it.** First, Syd's delays: a menu of durations, each with a delay of 1 to
500 milliseconds, "and for now, we add that delay to the default". Then, the same day, the fixed
list in its place, for the tick.

- `PhotoWidgetSettings.swift`, in the extension: the one setting, *Change Every*; and
  `ChangeEvery`, the durations it offers, each by its length in seconds, kept since 2026-10-28 in
  `EditWidgetChoices.swift`, shared with the Mac's widget.
- The cache's folder is named for the size and the duration, as in `systemSmall-300`.
- **The extension target extracts App Intents metadata**, which the project otherwise switches
  off; without it the system cannot find the settings. `Plans/Build Plan.md`. On a simulator the
  first install after the settings change may still not find them, Apple's own widgets failing
  alike in the same log, and a second install does.

## Reading the logs

The app and its widget extension log to the unified log, under the project's subsystem and the
category `widget`, through `Log.widget` as everything else in the project does. Each of their
lines begins `[PGR-Widgets]`; Syd, 2026-10-10, asked for "a tag on the logs that I can filter
for". A test run logs under the tests' subsystem, apart from a real one. `Plans/Logging.md` has
the rule for each line's level.

**Two processes.** The app's lines show in Xcode's console when it is run from Xcode; type the tag
in the console's filter. The extension is a process of its own and its lines do not, unless Xcode
is attached to it (Debug, Attach to Process). Console.app shows both, for a simulator or a
connected phone.

**From a terminal, for a phone or an iPad.** With the device unlocked and on a cable, and its
identifier from `xcrun devicectl list devices`:

```bash
sudo log collect --device-udid "<UDID>" --last 1d --output "$HOME/Desktop/ipad.logarchive"
```

and then, by the project's subsystem, which is far quicker than searching every line's text in
an archive of most of a gigabyte:

```bash
/usr/bin/log show "$HOME/Desktop/ipad.logarchive" --info --style compact --predicate 'subsystem == "com.sydpolk.photosgoround"'
```

- **It needs the cable.** Xcode reaches a paired device over Wi-Fi and builds and runs on it;
  `log collect` does not, and says `Device not configured (6)`. 2026-10-13.
- **After a migration to a new Mac, or a new system, the Mac may be refusing the device.**
  System Settings › Privacy & Security › Allow accessories to connect. Set to ask, it asked,
  and the collection then worked. The sign was an iPad that did not charge and was not in the
  Finder.
- **A device keeps only some hours of lines**, three one day and twelve another. A
  process's last line carries the most it has ever held, so that figure outlasts the rest.
- **How a process ended** is in the system's own lines, not ours: search the archive for
  `Process exited` with the extension's bundle identifier. Ended for memory, it reads
  `domain:jetsam(1) code:per-process-limit(7)`.

**From a terminal, for a simulator.** `booted` is enough when one simulator is running; otherwise
its name or identifier, from `xcrun simctl list devices`:

```bash
xcrun simctl spawn booted log show --last 10m --info --style compact --predicate 'eventMessage CONTAINS "[PGR-Widgets]"'
```

`--info` is needed for the lines marked so below; without it only the others print.

**What is logged:**

- `timeline asked, systemLarge, 350x365 points, 2 sources, every 300 seconds` — the extension,
  once for each reload of a widget, with the size the system handed it and what the widget is
  set to.
- `timeline answered, systemLarge, picture …, after 2 seconds, memory now 11.5 MB, peak 14.0 MB,
  18.5 MB left of 30.0 MB` — the extension, when a wake has its face, with how long it took and
  what the extension holds. A `timeline asked` with none after it is a wake the system
  stopped, or one still waiting on a source.
- `fetched, systemLarge, photos 4032x3024 → 1092x819, 212 KB, memory now …` — the extension,
  once for each picture it fetches, the wake's own and the one made ready for next time: what
  was read, what was written, and the memory as the fetch ends. A file's line has its size on
  disk too: `public.tiff 6000x4500, 54.1 MB → …`.
- `shrinking “DSC_0815.JPG”, taken 2024-09-21 18:03, public.jpeg 4000x6000 to 227x340, in bands
  at 1/8, reckoned at 14 MB, memory now …` — the app or the extension, before each picture from
  a file or from Photos is shrunk: its name and when it was taken, when known; its kind and
  size, the size wanted, the way, and what the guard reckons it needs. Named since 2026-10-14,
  at Syd's asking. The last of these with no
  `fetched` after it, in a process that was ended, is the picture that was being shrunk.
- `asking Photos for a 3000x2002 photograph at 1014x1062, memory now …` — the app or the
  extension, before each photograph is asked of Photos: its size, and the size wanted. What a
  `shrinking` line is to a file.
- `did not ask Photos for now: a photograph at 1590x757 needs about 22 MB, memory now …` — the
  extension, when *The guard* finds no room for a fetch from Photos. The picture showing stays.
- `asking Photos for the file of “IMG_1234.HEIC”, taken 2024-09-21 18:03, a 4032x3024
  photograph, public.heic, memory now …` — the extension, before a photograph's file is
  taken from Photos.
- `passed over a picture too large to shrink: “scan.png”, public.png 12000x9000 needs about 56 MB, memory
  now …; no wake could show it` — the extension, when *The guard* refuses a picture, with the
  kind and size of the picture and never its name. Without the last words it was refused only
  for now.
- `asked iCloud for 3 of 3 files that are not on the device` — the app or the extension, on a
  pick from a folder that has files iCloud Drive has not fetched. `; the first refusal: …`
  after it when asking was refused.
- `went through a folder for a picture: N files gave none, and then one did` — the app or the
  extension, when no source gave a picture to a pick and a folder was gone through. `…, and none
  did` when it has nothing to give.
- `a file gave no picture: download status …; reading it, …` — the app or the extension, for a
  file with a picture's name that would not decode: whether iCloud has it on the device, and
  what reading its first bytes gave. The file is not named.
- `snapshot, systemLarge, 350x365 points, picture …, memory now …` — the extension, each time
  the gallery asks for a preview, with the face it was given: a picture and whether its file
  was still there, or the plain icon, or no photos. A notice while the memory is measured,
  since a device does not keep an info line; *Info* otherwise.
- `placeholder, systemLarge, memory now …` and `drawing, systemLarge, picture …, memory now …` —
  the extension, when the system asks for a placeholder, and each time it has a face drawn.
  There only while the memory was measured, for Phase 5; to come out, a to-do.
- `sizes the widgets were handed: …` — the app, the first time it looks and whenever they have
  changed: every size recorded for each family. It is how a new device's sizes are read.
  *Info.*
- `no picture from any of N sources … and no error either` — nothing was found and nothing went
  wrong, as with an empty album. *Info.*
- `could not get a picture: …` and `no first picture from a … source: …` — a pick failed, with
  the error.
- `Photos gave no picture for a … photograph asked for at …: …` — Photos listed a photograph and
  would not hand it over, with its reason.
- `Photos did not answer in time for a … photograph asked for at …: …` — the request was given
  up on at its time limit. *When Photos does not answer*.
- `Photos did not answer, asking again in N seconds` — the extension, on a wake that got no
  answer or came inside the wait.
- `cleared away N caches no widget has: …` — the extension, when a wake found caches for
  settings no placed widget has, with their folders' names. *Info.*
- `opened Coins through its bookmark, and it can be read: N things in it` — the app or the
  extension, the first time a process opens a chosen file or folder; a file's line ends at
  `read`. `…, and it cannot be read: …` when the bookmark resolved and the process is still
  refused. Which process it was is in the log's process column. *The files and folders*.
- `the bookmark for Coins did not open: …` and `no bookmark has been left for Coins` — the same
  opening, failed. Asked again at the next count or pick.
- `no bookmark could be left for Coins, so it was not added: …` — the app, when something chosen
  in the Files browser could not be bookmarked.

### The memory on a line

The memory reading of Phase 5, closed 2026-10-16. Syd, 2026-10-11, chose log lines in the extension over Xcode's gauge on a
tethered phone: the widget runs for hours with nobody watching, and the log is how its wakes
are read already.

- **`now`** is the footprint, which is what the kernel charges against a limit.
- **`peak`** is the kernel's own mark of the most the process has ever held, so a fetch's worst
  moment is in it though no line was written then. It is the process's: a new extension
  process starts again, and the log's process column tells one from the next.
- **`left of`** is what the kernel says is left before the limit, and the limit is that and
  `now` together. So the ceiling is read and not assumed to be 30 MB.
- **Without `left of`, the kernel gave no limit.** From Apple's header, not tried: its answer
  is zero for a process that "is not an app". Whether a phone answers a widget extension is
  for the first log to say, and a simulator is not expected to enforce a limit at all.

All of it is `Footprint` in the shared package, which the agent, the screensaver and the Mac's
widget log their memory through.

### What the iPad's first night showed

Syd's M4 iPad Pro, 2026-10-12, with one source: a folder of 32 coin scans, on the iPad itself.
Four widgets, one of each size. He found them frozen. The log was collected with
`sudo log collect --device-udid … --last 1d` and read by the project's subsystem, which is
far quicker than searching every line's text.

- **The limit is 30.0 MB, and it is a hard one.** Every line's `left of` gave 30.0 MB, and the
  system's own line for each process says `Memory Limits: active 30 inactive 30`.
- **Every extension process the log shows start was ended for memory, two to seven seconds
  after it started.** Five are in what was read, at 05:18, 10:19 and 11:26, each with
  `Process exited: … domain:jetsam(1) code:per-process-limit(7)`. The sixth started six seconds
  before the lines stop.
- **Each was ended in the middle of a fetch.** Its last line is a `timeline asked` with no
  `fetched` after it. A `fetched` line is written when a fetch ends, so the picture that did it
  is never named.
- **What it could fetch.** A 5960x7160 JPEG took the peak to 21.1 MB and a 6288x6032 one to
  18.9 MB; a process that has fetched nothing holds about 4 MB. *Claude's estimate from those
  two, not measured: a JPEG past about 65 million pixels crosses the limit.* The folder has
  scans of 170 million and more.
- **One picture ends every widget's wake.** The wakes of all the sizes are one process, doing
  one piece of work at a time, so a fetch that ends the process takes with it whatever was
  waiting behind it. The next process picks at random again, with nothing to say which file did
  it.
- **Thirteen wakes in six hours, seven answered.** Nothing was asked between 05:18 and 10:19,
  or between 10:19 and 11:26. Whether the system asks less of an extension that keeps being
  ended, or the idle iPad's screen was off, is not in what was read.
- **Nothing before 05:18 is in what was read**, so the evening the widgets were set up is not
  accounted for.

### A very large picture, in bands

Syd, 2026-10-12, offered a guard first and the large pictures after: "Do the giants now."

**A picture of more than a million pixels is shrunk a band at a time, unless it is a HEIC.**
`PictureResizer`. It is decoded at an eighth, a quarter or a half of its size, whichever is
the smallest that is no smaller than what is wanted, and a strip of that a couple of megabytes
deep is cut, drawn at the widget's size, and let go before the next. A smaller picture, and a
HEIC of any size, is shrunk in one piece as it always was.

**What each kind adds, in megabytes, for an iPad's extra large widget.** A Mac, 2026-10-12,
each in a process of its own, with pictures made for the tests:

| | In one piece | In bands |
|---|---|---|
| JPEG, 12 million pixels | 24 | 4 |
| JPEG, 24 million | 16 | 5 |
| JPEG, 49 million | 6 | 4 |
| JPEG, progressive, 108 million | 17 | 9 |
| HEIC, 12 million | 10 | 38 |
| HEIC, 24 million | 12 | 23 |
| HEIC, 49 million | 10 | 19 |
| PNG, 12 million | 24 | 22 |
| PNG, 24 million | 20 | 18 |
| TIFF, 12 million | 17 | 14 |
| TIFF, 24 million | 12 | 10 |

- **An ordinary JPEG was the nearest to the limit.** Twelve million pixels is a phone's
  photograph, and in one piece it added 24 MB for the largest widget: it is decoded at a half
  when a quarter would be too small, and held twice.
- **A HEIC is worse in bands**, so it is left alone. In one piece it is about the same at
  every size.
- **A PNG or a TIFF gains little.** What either costs past 24 million pixels is not known,
  and is what the guard is for.

- **Why the old way could not hold.** One call made the whole small picture. Measured on a Mac
  with pictures made for the tests, it held about two copies of the eighth-size picture and,
  it seems, the file's own bytes: 20 MB for a hundred million pixels in a small file, 86 MB for
  679 million.
- **Asked for the whole picture, ImageIO reads the whole file.** Drawing the eighth-size
  picture in one piece added 296 MB for 679 million pixels in a file of 223 MB. Cut into
  strips, the same picture added 10 MB. So the strips are what matters, and the fraction
  alone does nothing.
- **The real largest scan**, 33280 by 20395 and 66.5 MB on disk, on a Mac: 11.4 MB added for
  an iPad's extra large widget in 1.4 seconds, and 8.4 MB for a small one. An extension holds
  4 to 7 MB before it starts. Looked at afterwards: the right way up, and no seam.
- **A band is cut a little deep and drawn inside its own edges**, which is what keeps a seam
  from showing where two meet.
- **A picture stored on its side or mirrored** is turned as it is drawn. The old call did that
  itself; the tests hold the two ways to the same answer for all eight orientations.
- **On the iPad, with the coins alone**, Syd, 2026-10-12: "the widgets are all showing coins
  now, which is better". Its log has not been read, so the peaks there are not known; the
  measurements above are a Mac's.
- **A progressive JPEG shrinks in bands too**: 9 MB for 108 million pixels. Claude had
  expected it could not.

**Syd's ladder, and why it cannot be climbed by trying.** Syd, 2026-10-12: "if you can recover
from an attempt, I would try full, then 80%, then 40%, then 20%, then give up and move on to
the next picture". An attempt cannot be recovered from: going over the limit is not an error
the extension is handed, the system ends the process with no warning. So the choice has to be
made before decoding, from the picture's size and what the kernel says is left, both of which
are read already. ImageIO's fractions are a half, a quarter and an eighth. For a JPEG the
bands make the ladder unnecessary. For a picture that still would not fit, "give up and move on
to the next picture" is *The guard*, below.

### What the iPad showed with bands

Syd's M4 iPad Pro, 2026-10-12, 12:03 to 12:41, the coins alone, on the build that shrank in
bands from sixteen million pixels and had no guard.

- **Every large scan was shrunk.** One extension process lived 37 minutes and made 37
  fetches, among them both scans of about 679 million pixels and many of 300 million and
  more. The system asked every five minutes, as set, and 36 of its 37 wakes were answered.
- **The most it held was 26.3 MB**, and 23.5 to 23.7 MB with only scans shrunk in bands. The
  26.3 came after a JPEG of 11 million pixels, shrunk in one piece for the large widget.
- **It was ended for memory twice all the same**, at 12:41:21 and, its successor, seven
  seconds later, each at the start of a fetch for the extra large widget. *Claude's reading,
  not proved:* an ordinary JPEG of 8 to 12 million pixels, of which the folder has four,
  shrunk in one piece at a half of its size. On a Mac that added 24 MB. The successor had
  23.2 MB left. The build since shrinks those in bands, for about 4 MB.
- **What it holds between fetches crept up**: 4.6 MB at the start, 11.8 MB after the first
  scan shrunk for the extra large widget, 14.6 MB at the end. A fetch after that added less,
  so some of it is kept and used again, not lost. What keeps it is not known.
- **A Mac's figures run low for the iPad.** The first scan shrunk for the extra large widget
  took the process from 6.1 MB to a peak of 23.5 MB, 17 MB more, where the Mac's was 11 MB.

### The iPad with bands from a million pixels

Syd's M4 iPad Pro, 2026-10-12, 12:58 to 13:51, the coins alone, on the build with bands from
a million pixels, the guard, and the line written before each shrink.

- **Nothing was ended.** One extension process ran the 53 minutes and was still running: 56
  wakes, 56 answered, 56 pictures shrunk, four to a burst every five minutes.
- **Every JPEG of more than a million pixels went in bands**, 52 of them, the largest scans
  for the extra large widget among them. Four of 640 pixels across went in one piece.
- **The guard refused nothing**: every picture was a JPEG, reckoned at 12 MB, and there was
  never less than 14.6 MB left.
- **The peak was 24.1 MB, and no shrink made it.** It was reached between 12:58:48 and
  12:59:20, and the line written before the next shrink already carries it. In the 50 minutes
  of shrinking after, at rest on 12 to 15 MB, it never rose: so no shrink added more than
  about 9 to 12 MB.
- **What it rests at went up in two steps, and no shrink made those either**: 6.8 MB to
  12.3 MB in the same half minute as the peak, and to 15 MB between 13:41 and 13:46. The app
  had been open from 12:58:40 to 12:59:15, and leaving it tells the widgets to look again.
- **Both steps fell where the extension wrote nothing**, for 31 seconds and for five
  minutes. What it does without writing: it answers for a placeholder, which had no line, and
  for a snapshot, whose line is an info one that the iPad did not keep, and it draws the
  faces. *Claude's guess: the drawing, either of a photograph at the extra large widget's
  size or of the icon, whose picture is 1024 pixels square before it is made smaller.*

### The iPad overnight

Syd's M4 iPad Pro, 2026-10-12 23:26 to 2026-10-13 11:16, on the build with the guard, the
note, and the lines for a placeholder, a snapshot and each drawing of a face. Two sources by
the end: the coins folder and one photograph. This time the iPad had kept twelve hours of
lines.

- **The widgets ran all night.** 327 wakes, 325 answered, about 24 an hour, which is four
  widgets every five minutes.
- **What the extension rests at does not keep climbing.** It sat at 9 MB for most of the
  night, went as high as 16 MB, and came back. The steps of the day before were the icon,
  below, and not something lost at each fetch.
- **Two processes were ended for memory, at 04:10 and 08:33, each with one picture half
  shrunk and about 21 MB left.** The line written before each shrink named them: JPEGs of
  2680 by 3345 and 2922 by 3660 pixels, to be shrunk in bands at a quarter. Both are
  photographs from an iPhone, cropped, baseline, in Display P3. The widgets carried on in a
  new process each time.
- **On a Mac the same two files add 44 MB and 48 MB in bands**, each in a process of its own,
  where a photograph of 4032 by 3024 from the same set adds 3 MB. That is the whole picture
  decoded at its full size, four bytes a pixel. *Claude's reading, not proved: neither
  picture's sides divide by four, 3345 being odd and 2922 twice an odd number, and ImageIO
  then gives the full-size picture for the fraction asked, as its header says it may, and
  decodes all of it for the first strip.* **That reading was wrong**: a picture of the same
  size made another way takes 3 MB. *A JPEG at a half or a quarter*.
- **The guard let both through**, having reckoned each at 12 MB as it does every JPEG in
  bands. So a JPEG is not always 12 MB, and the reckoning has to know which are not.
- **The icon is what took the extension to 25 MB with no picture being shrunk.** At 11:06,
  after a new build was installed, the system asked for a placeholder at each size. Between
  the drawing of the large one and the next line, 183 thousandths of a second, the extension
  went from 8 MB to a peak of 25.1 MB and was left resting on 12.5 MB. The small and medium
  ones had added about a megabyte. A placeholder's face is the icon, greyed over.
- **Why the icon costs that.** `PhotosGoRoundIcon.png` is 1024 pixels square, 16 bits a
  channel with alpha, in Display P3: 8 MB decoded, before the copy at the size wanted is made
  from it, and a large widget on the iPad wants 768 pixels. A copy of each size asked for is
  then kept for the life of the process. On a phone, at three pixels a point, a large widget
  would want all 1024. Syd, 2026-10-10, asked for the full-size picture, because the only
  icon an app can load of its own was too small; that was for how it looks, and what it costs
  an extension was not known then.
- **On a phone's sizes it goes past the limit.** An iPhone 17 Pro simulator, 2026-10-13, with
  no widget placed: the placeholder for the medium widget took the extension from 8.2 MB to
  15.8 MB with a peak of 19.0 MB, and the one for the tall extra large widget from 15.8 MB to
  23.9 MB with a peak of 39.9 MB. A simulator does not enforce the 30 MB; a phone would end
  the extension there.
- **The same simulator's preview was frozen, and that was Photos.** From 12:04 to 12:12 every
  request the app made for a photograph of 3000x2002 was given up on at 15 seconds. Nineteen
  simulators had been booted in the twenty minutes before, on Syd's new Mac, and their
  processes were using twelve of its eighteen processors, with 62 of 64 GB of memory in use.
  With the Mac quiet again, its load about 10 where it had been 950, the preview worked.
  Syd, 2026-10-13: "the preview is working now; every thing looks good".

### A photograph from Photos, as a file

Syd, 2026-10-14, choosing it after *The Photos guard on the devices*.

**A photograph is taken from Photos as the file Photos keeps, written to the widget's cache a
little at a time, and shrunk from there as a file is**: weighed by its own size and kind,
shrunk in bands, and the file let go. `PhotosSource`, `SelectedPhotosSource`.

- **The edited photograph when there is one**, which is what Photos shows, and the original
  when not. From iCloud when it is not on the device.
- **A RAW photograph is still drawn by Photos**, weighed first by the old reckoning of five
  times the picture asked for. Nothing has measured `ImageIO` shrinking a RAW file in bands.
- **As a folder does with its files, three photographs are tried** before giving up. One too
  large for what is left just now is passed over, and if every one was, the widget keeps its
  picture. One no widget could ever shrink is recorded against the collection, and its row
  gets the triangle and the app the note, as a folder's does.
- **New in the log**: `asking Photos for the file of a 4032x3024 photograph, public.heic,
  memory now …`, then the `shrinking` line a file gets.
- **In a simulator, the same day**, the tall extra large widget on a photograph of 4288 by
  2848: drawn by Photos it added 8.1 MB; taken as a file, 5.4 MB, and 10.7 MB for the next one
  taken straight after, while the widget was still drawing the first.
- **On the iPad and the phone, 15:53 to 16:00**: nothing ended, nothing refused, 12 and 17
  wakes all answered. Writing the file cost nothing to speak of: 8.8 MB before, 8.9 MB after,
  for a file of 16.7 MB.
- **Shrinking a camera's JPEG at an eighth is what cost.** On the iPad a photograph of 4000 by
  6000, its file 16.7 MB, for the medium widget: from 8.9 MB to a peak of 28.3, of 30. On the
  phone one of 6720 by 4480, 7.1 MB, for the small widget: from 9.2 MB to 20.9. A scanner's
  JPEG at an eighth, the coin scans, costs little.
- **A picture of 4000 by 6000 made for the tests, its file 12 MB, adds 1 MB at an eighth on a
  Mac**, so it does not show this; nor did the iPhone's cropped photographs, 9 MB at an
  eighth. The same kind of thing as *A JPEG at a half or a quarter*, then: some JPEGs are not
  given their fraction, and which is not known.
- **Two camera JPEGs of 4000 by 6000 from Syd's Dropbox, files of 16.6 and 17.0 MB, add 2 to
  3 MB at an eighth on a Mac, and about 6 MB at their own size.** So the Mac does not show it
  with a camera's JPEG either, and decoding at its own size would not have been cheaper there.
  What the iPad did with its photograph is not known.
- **So the log names each picture now**, which it never did: Syd, 2026-10-14, "it would be
  good to log titles if there, and filenames if there. capture dates are a bonus". A file's
  name and the date in its EXIF; for a photograph from Photos, its file's name and the date
  Photos has for it. Photos gives an app no title.

### The Photos guard on the devices

Syd's iPad and iPhone, 2026-10-14, each with Photos sources and files, on the build with the
guard for Photos from 14:20 on the iPad and 14:18 on the phone, until about 15:40.

- **Nothing was ended on that build**, on either. The iPad: 48 wakes, all answered, peak
  24.1 MB of 30. The phone: 56, all answered, peak 40.1 MB of 60.
- **The guard refused 15 times on the iPad and 3 on the phone, always for now**, and each
  widget went on to show a picture.
- **On the iPad the extra large widget is all but never let have a photograph from Photos.**
  It is reckoned at 22 MB, and an extension resting on 9.5 MB has 20.5 left. It shows files,
  or keeps the picture it had.
- **Before that build, the iPad's extension was ended twice in a second, at 14:10, each in
  the middle of a fetch from Photos**: photographs of 6752 by 4192 and 6736 by 4175, for the
  large widget, with 14.1 MB and then 21.2 MB left. `jetsam`, `per-process-limit`, both. The
  guard reckons that fetch at 10 MB and would let it through. So what a fetch costs does not
  go only with the size asked for; *Claude's guess, not looked into: what kind of photograph
  those are, RAW or edited.*
- **Other photographs as large were fetched for the same widget without trouble**, 28 and 30
  million pixels among them, so it is not their size alone either.

### Photos on the iPad

Syd's M4 iPad Pro, 2026-10-14 12:41 to 13:17, with Photos collections as well as files.

- **Nothing was ended**: 36 wakes, all answered, 40 pictures, 31 of them from Photos.
- **One fetch from Photos came within 1.9 MB of the limit.** A photograph of 3880 by 2688
  for the extra large widget, asked for at 1590 by 757: the extension held 9.6 MB before it
  and peaked at 28.1 MB, of 30. That is 18.5 MB for one fetch. A file shrunk for the same
  widget costs it about half a megabyte.
- **No later fetch went higher**, a photograph of 5712 by 4284 for the same widget among
  them; the peak stayed at 28.1 MB.
- **It was resting on 9.6 MB when it did that.** In the same half hour it rested as high as
  16.5 MB, and the same fetch from there would have gone past 30.
- **No Photos request went unanswered or was refused.**

### The phone

Syd's iPhone 17 Pro, 2026-10-14, with the widgets on Photos collections and on the folder of
large pictures, and the app sometimes in front and sometimes behind Music. On a build from
before the JPEG rule until about noon, and the current one from 12:53.

- **A widget extension on the phone is held to 60 MB**, twice the iPad's 30. Every line from
  the extension ends `left of 60.0 MB`.
- **Fetches from Photos are the costly ones on the phone**, where on the iPad, with only
  files, nothing was. A photograph of 3504 by 2336 for the large widget took the extension
  from 7.7 MB to a peak of 28.8 MB; one of 1336 by 2436 for the tall extra large widget took
  it to 46.0 MB. In a simulator the same kind of fetch had added about 8 MB.
- **It rests higher too**: up to 28 MB between wakes after a few Photos fetches.
- **Nothing ran out**: on the current build 41 wakes, all answered, and 45 pictures shrunk or
  fetched, the two photographs that had ended the iPad's extension among them, six times.
- **The four placeholders drawn with the icon made for widgets added nothing**: the peak stood
  at 28.8 MB before them and after.
- **One process on the old build stopped in the middle of shrinking a JPEG of 3472 by 3472
  at a quarter**, at 11:34, with 51 MB left. The phone's log has nothing from the system about
  why; the next process started 39 minutes later.
- **The guard only weighs files.** A fetch from Photos is never refused, whatever it will
  cost.

### The two photographs on the iPad

Syd's M4 iPad Pro, 2026-10-14 11:44 to 12:27, with a source of its own: an iCloud folder holding
the two photographs that had ended the extension and six more from the same set.

- **Both were shrunk, many times, and nothing was ended.** The one of 2680 by 3345 ten times
  and the one of 2922 by 3660 three, each followed by its `fetched` line. The extension was
  the same process that had started at 18:40 the day before.
- **For the large widgets they went at their own size**, and added about half a megabyte.
- **For the small and medium they went at an eighth**, and the process held about 7 MB more
  for a moment afterwards: 9.7 MB before, 16.8 MB after. It was back to 9.8 MB by the next
  shrink.
- **The guard refused, for the first time on a device, three times in those moments.** Each
  time a JPEG of 4032 by 3024, reckoned at 14 MB, with 13 MB left. Each was refused for now,
  so another picture was shown and nothing was recorded or put on the screen. Which is what
  it is for.
- **Still no placeholder or snapshot was asked for.**

### The iPad on the build with the JPEG rule

Syd's M4 iPad Pro, 2026-10-13 18:40 to 2026-10-14 01:09, the coins folder, on the build with a
JPEG decoded at an eighth or at its own size, the widgets' icons, and the line before each
fetch from Photos. Collected while it was still running.

- **Nothing was ended.** One extension process ran the six and a half hours: 196 wakes, 196
  answered, 196 pictures shrunk, among them both largest scans ten times and eleven.
- **The most it held was 21.9 MB**, and between wakes it rested on 9 to 13 MB.
- **The guard refused nothing.**
- **Neither of the two photographs that had ended the extension came up.** The folder and
  the folders in it hold well over a hundred pictures, and 196 picks missed both, which
  happens about one time in fourteen. So the iPad has not shown them shrunk; the tests and
  the Mac have.
- **No placeholder or snapshot was asked for**, so the icon made for widgets was not drawn
  on a device in this run either.

### A JPEG at a half or a quarter

The two photographs that ended an extension on the iPad overnight, looked into on a Mac on
2026-10-13, each shrink in a process of its own. Both are on the Mac, in the coins folder.

**A JPEG is decoded at an eighth where that leaves it large enough, and at its own size where
it does not. Never at a half or a quarter.** `PictureResizer.fraction`. Any other kind still
takes the smallest of the three that is enough.

- **What the one of 2922 by 3660 added, by the fraction asked for**, before the change:

  | Wanted | Fraction | Added |
  |---|---|---|
  | 340 pixels | an eighth | 9 MB |
  | 756 | a quarter | 48 MB |
  | 1200 | a half | 31 MB |
  | 2000 | none | 17 MB, of which 13 MB is the picture written |

  At a quarter and a half the strip is decoded at the picture's full size and made smaller
  afterwards, so it costs sixteen times, or four times, what it was cut to cost. At an eighth
  it is decoded at an eighth. ImageIO's header says a fraction may not be given; it does not
  say the cost is then hidden behind a picture of the size asked for.
- **After the change**: 7 MB at 756 pixels, 9 MB at 1200, 12 MB at 1590, and for the other
  photograph 7 MB and 13 MB. A photograph of 4032 by 3024 from the same set, which had taken
  3 MB at a quarter, takes 5 MB at its own size.
- **What it is about those two files is not known.** None of these is it, each tried by
  taking it away or by making a like file without it:
  - their size: a picture of 2922 by 3660 made for the tests takes 3 MB at a quarter;
  - the second picture inside each, a half-size one of one channel that an iPhone adds;
  - the table of restart offsets, the Photoshop segment, and the EXIF and XMP;
  - colour at every pixel, a restart at every row, quantization tables of all ones, and the
    Huffman tables, all of which a file that behaves has too.
- **Rewritten without loss by `jpegtran`, the same picture takes 3 MB at a quarter**, with
  the same tables and the same picture data, byte for byte in length. So it is in how the
  file's first few segments are laid out, and that was not run down.
- **The two photographs themselves are in the tests.** Syd, 2026-10-13: "you can just copy the
  pictures you just optimized for into the test repo and right tests with them".
  `Widgets/Shared/Tests/TinyCacheMemoryTests/Photographs`, 4.7 MB and 6.0 MB. The test shrinks
  each for an iPad's extra large widget and holds it to what a JPEG is reckoned to need. With
  the old rule put back it fails, at 41 MB against 14.
- **Their location is not in them.** Each carried where it was taken, and the repository is
  public. The EXIF and XMP, the Photoshop segment and the second picture were taken out before
  they were copied, which leaves what they do unchanged.
- **Only the first of the two fails under the old rule in one run.** A case run after another
  reads low, as in the rest of that test target: the process keeps what the first took.
- **The first reading was wrong.** *The iPad overnight* has it as the sides not dividing by
  four.
- **A JPEG is reckoned at 14 MB now, not 12.** Decoded at its own size it costs the picture
  written and about 5 MB: 13 MB for a picture 1590 pixels square, which no widget asks for.
- **Slower, and not measured on a device.** A photograph of twelve million pixels is decoded
  whole now, a strip at a time, where a half or a quarter of it was. On a Mac that is not
  seen in the tests' times.

### A scan at full colour

**A JPEG at full colour is reckoned like any other, and a grey one is decoded like any
other since 2026-10-16**: what a grey scan cost was its being drawn in one band, *The iPad
overnight with every source*. Until then a grey JPEG was decoded at its own size, told by
reading how a file's colour is sampled from its frame header. What ended the iPad's extension was a grey
scan. A rule that reckoned a JPEG at full colour as decoded at a quarter was built on a
reading of the wrong file, 2026-10-14, and taken out the next day with the measuring build's
lines, once the iPad had shrunk the colour scans: Syd, 2026-10-15, "1".

- **What ended the iPad's extension**, 2026-10-14: “1973-11-18 Xeroxed Faces 31.jpeg”, from
  Photos, a scan of 9920 by 12925 from a Brother MFC-L8850CDW, 59 MB. Shrinking it at an
  eighth for the large widget, with 21.9 MB left, the extension was ended by the system and
  wrote nothing more. It was the only attempt at it in either device's log.
- **On a Mac it takes 6 MB**, in a process of its own: 5.9 MB for the large and medium
  widgets, 4.5 MB for the small one.
- **It keeps its colour at every pixel, and restarts at every row.** A phone's or a camera's
  JPEG samples its colour at a half each way; the coin scans do, and they are shrunk at an
  eighth on the devices at up to 679 million pixels. The two photographs of *A JPEG at a half
  or a quarter* keep it at every pixel too, and restart at every row. On a Mac neither was
  found to be the cause there.
- **A quarter is a guess.** Decoded at a quarter the scan is 32 MB, which fits what the iPad
  did. Reckoned so, it needs more than any wake has, and is passed over for good, with the
  note and the triangle. A photograph of twelve million pixels at full colour is still
  reckoned at 14 MB. What the device really takes has not been measured.
- **The iPad may not shrink the scanner's file at all.** Shown the album of the scans, the
  app's preview reckoned them at 14 MB, so what Photos handed it was not read as full
  colour. An edited photograph is taken as Photos' edited version, which is a file Photos
  wrote. The log says which version it was given since the same day. So full colour may not
  be what ended the extension.
- **What ended it was grey, not colour.** Shown an album of the scans only, the extension was
  ended twice, 2026-10-14, each time in the first band of “1973-11-18 Xeroxed Faces 23.jpeg”,
  with 23 MB left. Photos gave the original, and it is one channel: grey, 9920 by 12925,
  36 MB. The copies of three of the scans on Syd's Mac are in colour, and are not what Photos
  holds.
- **A grey JPEG is decoded at its own size, a strip at a time, since the same day.**
  `PictureResizer.fraction`. Photos' grey scan, exported by Syd and measured on a Mac: 42 MB
  at an eighth, the same through ImageIO's thumbnail, and 11 to 13 MB at its own size, in
  about a second. A grey picture of that size made for the tests takes 30 MB at an eighth,
  and is one of the kinds `ShrinkingMemoryTests` holds to what a JPEG is reckoned at.
- **On the iPad it holds.** 2026-10-15, on the album of the scans: one extension process
  shrank 22 grey scans at their own size over 16 minutes, about 2 seconds each, and was not
  ended. Each added about 6 MB, from 8.4 MB to 14.4 MB; the most the process ever held was
  16.4 MB of its 30.
- **A full-colour scan on the iPad takes 6 MB at most at an eighth**, 2026-10-15: the three
  colour copies of the scans, 9920 by 12925 and 59 to 64 MB, from a folder in iCloud Drive,
  shrunk 16 times unguarded for every size of widget. Held 10.3 MB before, 12.3 MB at most
  after a band, and the most the process ever held stayed at 16.4 MB. Reckoned at 30 MB by the
  rule for full colour, which is far too much; as any other JPEG, at 14 MB, it is enough.
- **The first reading on the iPad**, 2026-10-14: “Jumpstart-5478E.jpg”, 3062 by 5663 at full
  colour, decoded at an eighth for a small widget, took about 11.5 MB at its most, while the
  picture at an eighth is 1 MB. Nothing is decoded until a band is drawn.

### The iPad overnight with every source

2026-10-15 to 16, 21:35 to 09:30, the build without the measuring lines, every source Syd uses
plus the album of grey scans and the folder of colour ones.

- **No extension was ended.** Four processes, each ended by the system in the ordinary way;
  302 shrinks, 299 of them fetched.
- **38 pictures were passed over, every one for now**, with the process holding 17 to 23 MB
  at the moment: nothing was recorded against a source.
- **What a process holds at rest rises, then stays**: about 4 MB at its start, 8 MB once it
  has drawn a picture and asked Photos, and about 12 MB within half an hour, where it stays for
  hours. Not a leak. The guard reads the real figure, so it is no danger; it is why more is
  passed over later in a process's life. Where the last 4 MB come from is not known.
- **So `heldIdle` is 12 MB, not 6, since 2026-10-16**: a picture reckoned at more than 18 MB
  is refused for good, recorded against its source and marked, where it was 24 MB. Today that
  is only a PNG or a TIFF; the preview judges by the same. Syd: "1".
- **One shrink took more than it is reckoned at**: “DSC_3023-Edit.jpg”, 6016 by 4016, at an
  eighth for a picture of 509 by 340, added 18.7 MB against 14, to a peak of 27.7 MB of 30.
  Four album covers of about 3700 pixels a side added 11 to 13 MB. Their sampling is not
  known: the line that said it went with the measuring build.
- **On a Mac the same photograph takes 2.2 MB** for that widget, and 9 MB at most for the
  largest. Syd exported it, 2026-10-16: a Nikon D750 photograph from Lightroom, 16.1 MB, at
  full colour with a restart at every row.
- **On the iPad, the rise followed the file's size**: 18.7 MB for its 16.1 MB, 13.1 MB for a
  file of 10.9 MB, 11.3 for 9.7, 11.5 for 8.8, 4.2 for 3.9, from Photos and from folders
  alike. Not proved: the three colour scans of 59 to 64 MB added 6 MB at most, and drawing
  goes on in the same process while a fetch runs.
- **It was the band, not the file.** Measured on the iPad, 2026-10-16, with an album of that
  photograph alone: Photos writing the file added nothing, and asking for the picture at an
  eighth nothing. Drawing its one band, all 502 rows of it, took the peak from 21.0 MB to
  28.2 MB with 9.5 MB held: 18.7 MB. The colour scans, drawn at an eighth in four bands, took
  under half a megabyte a band; the grey scan that ended the extension was one band too.
- **So a picture is never drawn in one band, since the same day.**
  `PictureResizer.bandRows`: never more than half the picture. On a Mac a grey scan of that
  size at an eighth took 30 MB in one band and passed under 14 MB in two. On the iPad the same
  day, the photograph at an eighth in two bands: under half a megabyte a band, and the peak did
  not move from 14.5 MB, over a dozen fetches for every size of widget.
- **A grey JPEG is decoded at an eighth again**, in two bands at least, since the same day:
  the rule that decoded it at its own size is out, Syd's "2", to be seen on the iPad with the
  album of grey scans. On a Mac the grey test of that size passes under 14 MB at an eighth.
  On the iPad the same day: nine grey scans at an eighth in two bands, for every size of
  widget, under 2 MB a band, the peak unmoved at 14.8 MB, about half a second each where at
  their own size they took two.
- **The measuring lines are out**, and with them the reading of a JPEG's sampling, which
  nothing else used.

### The icon, made for widgets

Syd, 2026-10-13: "Make a version of the icon optimized for widgets".

**The icon is four pictures, of 256, 512, 768 and 1024 pixels a side, at eight bits a channel,
and a face is drawn from the smallest that is no smaller than it needs.** `WidgetFace`. The
picture is read as it is: there is no larger one decoded first, and no copy made from it.

- **What it was.** One picture of 1024 pixels at 16 bits a channel: 8 MB decoded, eight bytes
  a pixel, and then a copy at the size wanted, at 16 bits too. For an iPad's large widget
  that is 8 MB and 4.7 MB before anything is drawn. *The iPad overnight*.
- **What it is.** Four bytes a pixel and one picture: 4 MB for the largest, 2.4 MB for the
  768 an iPad's large widget draws from, 1 MB and a quarter of one for the others. A test
  holds reading the largest to under 6 MB.
- **Still in Display P3, with clear corners.** Only the depth changed.
- **Each size is Icon Composer's own drawing at that size**, not one picture made smaller.
  `Scripts/make-widget-icons.sh` makes all four, to be run whenever the icon changes; Icon
  Composer exports at 16 bits, and `Scripts/eight-bit-png.swift` writes each again at eight,
  which `sips` will not do.
- **The picture of each size drawn from is still kept for the life of the process.** At most
  four, and on any one device the two or three its widgets need.
- **The app's preview draws from the same four**, since the face is one view for both.
- **In a simulator, the same day, on the iPhone 17 Pro that had shown 39.9 MB.** The gallery
  asked for a snapshot at every size, with nothing chosen, which is the plain icon. The
  extension went from 8.4 MB to 11.9 MB, with a peak of 15.9 MB once the 1024-pixel picture had
  been read for the large widget. With the old picture the same sizes had left it on 23.9 MB
  with a peak of 39.9 MB. Those were placeholders, the icon greyed over, so the two are the
  same picture and not quite the same face.
- **The 26.2 MB that followed was the first fetch from Photos, not the drawing.** Found on
  *Claude iPhone*, iOS 27, 2026-10-13, with the line now written before each photograph is
  asked of Photos, and one tall extra large widget on Favorites:

  | When | Held | Peak |
  |---|---|---|
  | Before any snapshot | 8.5 MB | 8.5 MB |
  | After the icon at every size | 12.0 MB | 16.0 MB |
  | 15 seconds on, as Photos is asked for 4288x2848 at 1049x1697 | 14.6 MB | 16.0 MB |
  | That fetch done, 94 thousandths of a second later | 15.5 MB | 23.0 MB |
  | The fetch made ready for next time, done | 15.7 MB | 23.0 MB |

  So the system drawing what it had been handed moved the peak not at all, and the first
  fetch added about 8 MB at its most. On Syd's simulator it had been 10 MB, for a photograph
  of 3000x2002. The second fetch added less than the first.
- **Of the 15 MB it rests on by then**, 8.5 MB is the extension before it has done anything,
  3.5 MB came with the icons, which are kept, and the rest came in the 15 seconds before the
  fetch, with nothing written to say what.
- **Not seen on a device.**

### The guard

Syd, 2026-10-12: "I do think we need a guard, and any picture that fails the guard is skipped.
And if the guard is ever triggered, we should add a note at the bottom of the apps windows that
says that some of the pictures in your choices may not be able to appear in widgets." Asked
nothing, he added how long the note stays: "until that source goes away".

**Before a picture is decoded, what shrinking it is reckoned to need is held against what the
kernel says the extension has left.** `PictureResizer`. More than is left, and it is not
started on: the source passes it over and tries another, as it does a file that is not a
picture. Where the kernel tells of no limit, as on a Mac and in the app, nothing is refused.

- **What a shrink is reckoned to need**, each the most measured in the table above and a
  little over: 14 MB for a JPEG in bands, whatever its size; 14 MB for a HEIC; for a PNG, a
  TIFF or any other kind, the picture at the fraction it is decoded at, four bytes a pixel,
  and 14 MB. A test holds each kind to its figure.
- **Refused for now, or for good.** A picture that would fit in an extension holding nothing
  else, taken as 6 MB, is only passed over this time: the process is holding what an earlier
  fetch left. One that would not fit even then can be shown by no wake, and that is what is
  recorded.
- **The record is of the source, not the file**, in the App Group's preferences, where the
  extension writes and the app reads. `SkippedPictures`.
- **The note**, at the foot of the app's window, with a warning triangle: "Some of the Photos
  in this set are not displayable in widgets." The words are Syd's, 2026-10-12, in place of
  the ones he first gave. It is looked for each time
  the app is opened or brought forward, and goes when the source it was recorded for is
  removed, which forgets the record too.
- **The app's preview refuses what a widget would.** Syd, 2026-10-12: "the preview should use
  the exact same methodology as the widgets, rather than just drawing the picture directly",
  and "that way if the preview stumbles across an image that can cause a problem, it can put
  in the warning text". The preview already picked, shrank and drew as a widget does; what
  differed was the guard, which had nothing to refuse in an app with gigabytes. So the
  preview's pictures are judged by a widget's limit, 30 MB with 6 MB taken as held: one no
  widget could shrink is passed over there too and recorded as a widget would record it, and
  the screen looks for the record each time the preview's picture changes, so the note
  comes up then.
- **A warning triangle beside each source it happened in.** Syd, 2026-10-12: "we should put a
  triangle with an exclamation point icon next to the sources with offending images", and
  "that same icon should lead the text we put up. Kind of like a footnote". So the triangle
  after a source's name is the mark, and the note at the foot, led by the same triangle, is
  what the mark means. In the colour of the words around it: "I don't think it should be red.
  This is not fatal", and "It's just information".
- **A fetch from Photos is weighed too, and only ever refused for now.** Syd, 2026-10-14:
  "shouldn't the guard be there first?", and "yes, build it". Photos decodes the photograph
  in the widget's own process, at 15 to 21 MB a fetch, and once took the iPad's extension to
  28.1 MB of 30. *Photos on the iPad*.
  - **Reckoned at five times the picture asked for**, four bytes a pixel: 23 MB for an iPad's
    extra large widget, 11 MB for its large. **That is too little for some photographs**: two
    of 28 million pixels ended the iPad's extension when asked for at the large widget's
    size, with 14 and 21 MB left. *The Photos guard on the devices*.
  - **Weighed before Photos is asked**, so a refusal costs nothing.
  - **Never for good.** The reckoning says nothing about any one photograph, so nothing is
    recorded and no note or triangle goes up.
  - **The picture showing stays, with nothing over it**, and the next wake asks again. With
    nothing shown yet the widget says "No Photos found". Unlike Photos not answering, there is
    no wait.
  - **Not in the app's preview.** It stands in for a 30 MB widget so that a file no widget
    could shrink is found there too; a refusal for now is about the process making the
    fetch, and the app has room, and a phone's widget has 60 MB.
- **What it does not catch.** A picture that takes far more than it is reckoned at ends the
  extension as before, since the reckoning is all there is to go by. Noting which file was
  being shrunk when a process ended, and passing that file over afterwards, would catch it,
  and is Syd's "recover from an attempt" done across two processes. Not built, and it would
  have to tell a process ended for memory from one the system ended for its own reasons.
- **A process ended while it shrank a photograph from Photos leaves its copy behind.** The
  original is copied beside the cache, as a hidden `.photograph-` file, and deleted once it is
  shrunk; ended in between, the deletion never runs. Each wake deletes any it finds, at every
  size, before it fetches: `LeftCopies`. Syd, 2026-10-30, choosing that each wake do it. The
  app's preview keeps its own cache and does not.
- **Not tried on a device.** The figures are a Mac's. A PNG of twelve million pixels is
  reckoned at 25 MB for an iPad's largest widget, which is all a fresh extension has left, so
  it may be passed over there more often than not.

**Seen on the iPad, 2026-10-16**, with a folder of one PNG screenshot of 2560 by 1440:

- **The extra large widget passed it over for good**: "needs about 28 MB … no wake could show
  it", and showed the icon with "No Photos Found". The small, medium and large widgets, which
  decode it at a quarter or a half, reckoned 14 to 17 MB and showed it. Syd, of the icon:
  "arguably correct behavior".
- **The app's preview found it first**, judging as the extra large widget, and recorded it:
  the triangle beside the folder's row and before the note, both seen. Syd: "triangle on
  both".
- **The preview then asked for it every five seconds while the app was open.** Since the same
  day, nothing found is looked for again after 5 seconds, twice as long each time, a minute
  at most, and at once for other sources or when the app comes forward. It does not stop,
  since nothing found may be pictures still coming down from iCloud. Syd: "1".
- **TIFF and HEIC are trusted to the unit tests**, not tried on a device. Syd, the same day:
  "I am tired of this, so I am going to trust this code works". `TooLargeTests`: a TIFF of
  4000 by 3000 is refused for good for the extra large widget and shrunk for the large, a
  folder of them says which, and a HEIC is shrunk in one piece for any widget.
  `ShrinkingMemoryTests` measures a TIFF of 8000 by 6000 on a Mac.

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
- **The Photos prompt uses the same name.**
- **The widget's name in the gallery is "PhotosGoRound"** with the build's suffix, from the
  extension's `Info.plist`.
- **Not seen:** a narrower phone, or an iPad.

Syd, 2026-10-10, has since asked for the name to be "PhotosGoRound" everywhere in the project;
`TODO.md`, *The name is "PhotosGoRound" everywhere*.

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
  widget carries the suffix in its gallery name; a Home Screen label has no room for it after
  "PhotosGoRound".

## Targets and release

- **Two Xcode targets, one scheme.** `Photos-Go-Round Widgets iOS` is the app, for iPhone and
  iPad, iOS 27 or later; `Photos-Go-Round Widgets iOS Extension` is its widget extension, and the
  app's scheme builds it and puts it in the app. Syd, 2026-10-09: "this is another target in the
  existing Xcode project. iOS 27 or later". The package already lists iOS 27, so the shared
  targets need no change for that.
- **The extension has small files of its own, and shares the rest.** Syd, 2026-10-09, first chose
  a second extension target compiling the Mac's source files, over making the Mac's target build
  for both. On 2026-10-10, with the shared faces and the App Group decided since, he chose again:
  the iOS extension has `PhotoTimeline` and `PhotoWidget` of its own in `Widgets/iOS/Extension`,
  what a wake does is in the shared package (`WidgetPictures`) where it is tested, what it draws
  is `WidgetFace`, and the Mac widget's files are not touched. The Mac's has an identifier for
  each build configuration, Mac sandbox entitlements, and a place in Photos-Go-Round.app's
  release, and none of that is disturbed.
- **What a wake does.** Each wake shows one picture and keeps one more, as on the Mac. It records
  the size it was handed, takes the face for these sources at this size, hands over a timeline of
  one entry with the next reload the widget's own duration on, and then fetches one more so the next wake has
  it. With nothing to show it asks again at the same time as with a picture; the app also
  reloads the widgets when a person leaves it. It declares all five families; the system offers what the
  device has.
- **In the gallery, a size with no picture of its own shows another size's.** Until a widget of a
  size has been placed, that size has shown nothing, and its preview said "Scanning…" (since
  2026-10-30 that would be "No Photos found"). It borrows
  the last picture another size showed, the one made for the most pixels. Syd, 2026-10-10.
  With no widget placed at all there is nothing to borrow, and the previews show the plain app
  icon: "just the app icon without an overlay", which he chose over a neutral photograph of his
  own and over leaving "Scanning…". The system keeps the previews it has drawn and asks for new
  ones in its own time; Syd saw them catch up a little while after placing widgets.
- **A wake that fails shows why.** Photos refusing is the one failure a person can do something
  about, and the widget says "No Photos Access"; anything else is "No Photos found".
- Debug, Release and Claude builds carry different identifiers, as on the Mac. See *Identity*.
- The version is the project's, in `Config/Version.xcconfig`. A release on iOS is an archive
  uploaded to App Store Connect, not a DMG, so `Scripts/release-build.sh` does not cover it;
  until there is TestFlight or the Store the app's package goes on the DMG, see `TODO.md`, *The iOS app*.
- Tested in a simulator, and on Syd's own phone for iCloud Photo Library. See *Where it is
  tested*.

# References

- `Plans/Photos-Go-Round Widgets.md` — the product this app belongs to, and the Mac proof of
  concept's record. Closed 2026-10-11; its decisions still hold, and its to-dos are in `TODO.md`.
- `Plans/ios main view revision 2.md` — Syd's notes for the screen as it is now, 2026-10-10.
- `Plans/Product Strategy.md` — names the product.
- `Plans/Project Source Reorg.md` — the layout this app's `iOS` folder belongs to.
- `Plans/Project Source Reorg 2.md` — a folder for each binary; deferred.
- `Plans/Logging.md` — the logging rules, and the iOS lines' levels.
- `Plans/App Icon.md` — the command that exports the icon picture the faces draw.
- `Plans/Apple Photos Plan.md` — the collection kinds, and Recently Saved's number.
- [Delivering an Enhanced Privacy Experience in Your Photos App](https://developer.apple.com/documentation/photokit/delivering-an-enhanced-privacy-experience-in-your-photos-app)
  — the limited library: no user albums, and no way to remove it from the prompt.
- [Widgets, Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/widgets)
  — the table of widget sizes by screen, and which sizes each device supports.
- [`WidgetFamily.systemExtraLargePortrait`](https://developer.apple.com/documentation/widgetkit/widgetfamily/systemextralargeportrait)
  — says the family appears on the Home Screen on iOS.
- `MacOS/Desktop/Sources/SourcesSettingsView.swift`, `CollectionPickerView.swift`,
  `CollectionTree.swift` — the Mac app's lists and picker.
- `Widgets/macOS/Sources` — the widget as it is on the Mac.
