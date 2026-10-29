# Summary

Two new settings for the iOS and Mac widgets, and the Mac's wallpaper, screensaver and app
windows. **How a photograph sits:** *Fit*, whole with black around it, as today; *Fill*, with
its edges cropped toward faces or the subject; or *Actual Size*, never drawn larger than it is. **Whether a place that is not square shows only
photographs of roughly its shape:** landscape ones where it is wide, portrait ones where it is
tall. For the widgets, each is set in the app, for every widget, and in a widget's own Edit
Widget panel, where it starts at "As in the app". Syd, 2026-10-25. The wallpaper, the screensaver
and the windows: *The wallpaper, the screensaver and the windows*.

**A plan, with Phase 1 and part of Phase 3 built.** Fit, Fill and Actual Size are set in the app,
and on iOS in each widget's Edit Widget too. On Syd's phone, a widget filled from a HEIC crops
toward faces, or else the subject; a picture shrunk in bands is still cropped about the middle.
Not yet tried on the iPad. Every decision in the plan is Syd's, 2026-10-25, or agreed by him.
What is still to be found out is under *TODO*.

# Rationale

Syd, 2026-10-25: "we need to add two settings. One: crop vs fill Two: on rectangular widgets,
limit photos shown to roughly match aspect ratio of the widget. User needs to be able to set these
in both widget settings and app."

A medium widget is about twice as wide as it is tall. A portrait photograph fitted into one is a
narrow strip with most of the widget black, and cropped to fill one it loses two thirds of itself.
The two settings are the two ways out: show only photographs that suit the widget, or let the
photograph fill it. Together, a wide widget shows landscape photographs edge to edge.

# Phases

Each phase is small enough to try on a phone before the next is started, and each leaves the
widgets working as they do today until the setting is changed.

- **Phase 1** — Fit, Fill and Actual Size, set in the app. *Fit or fill*. Built, and tried on
  Syd's phone; to be tried on the iPad.
  - The setting is stored in the App Group's preferences, which the extension already reads
    (`Preferences.widgetFraming`, `Framing`).
  - A filled picture is fetched to cover the widget and cropped to it when it is written, so the
    file is the widget's shape at its pixels, and `WidgetFace` draws it as it draws any picture.
    *The crop is made when the picture is written*. At Actual Size, `WidgetFace` draws a picture
    no larger than its own pixels.
  - Cropped toward faces, or else the subject, for a picture shrunk in one piece (built); for one
    shrunk in bands, still about the middle. *Fit or fill*.
  - Whether a local model finds faces or the subject better than Vision, looked into apart from
    the build. *A local model for the crop*.
  - The cache folders are named for the setting: `systemMedium-300-fill`, `1014x474-fill`. Fit and
    Actual Size write the same pictures, and keep the folders there were before.
  - A control for it on the settings screen, *Fit*, *Fill*, *Actual Size*, in a *Pictures* section
    first in the list. *Where the settings go in the app*.
  - **A RAW photograph from Photos is fitted, not filled**, in this phase: Photos draws it at the
    size asked for (`SystemPhotoLibraryPictures`), and that drawing is not yet asked to cover.
- **Phase 2** — Matching the widget's shape, set in the app. *Matching the widget's shape*.
  - What shape a widget is, from its size's name.
  - Photos: picking among the photographs of the right shape.
  - Files and folders: the same, from what a file's header says of its size.
  - With none of the right shape, any photograph.
  - Each picture's size kept once it is learned: in each widget cache's own database, moved with
    the caches to the App Group, and in the agent's library.
    *Picture sizes, kept*.
- **Phase 3** — Each widget's own. *In Edit Widget*.
  - Two settings in `PhotoWidgetSettings`, each starting at "As in the app". Fit or fill is built
    for iOS (`framing`, *Pictures*); the shape's comes with Phase 2.
  - The widget's cache folder and the clearing away go by them.
- **Phase 4** — The Mac. *On the Mac*.
  - The *Pictures* section in the Mac app's Settings window, stored where the Mac widget already
    reads the sources.
  - The Mac widget draws and fetches by the settings, through the same TinyCache sources.
  - The Mac widget gets an Edit Widget panel: *Change Every*, and the two settings at "As in the
    app".
- **Phase 5** — The wallpaper, the screensaver and the windows. *The wallpaper, the screensaver
  and the windows*.
  - The agent keeps each photograph's size, and its crop region, in its library.
  - The agent serves a picture to fill when asked, cropped toward faces or the subject.
  - The agent serves a picture of the asker's shape when asked, from what is queued.
  - The two settings in the Settings window's *Screensaver* and *Wallpaper* panels, and in
    Window Settings.

# TODO

- Look into a local model for faces or the subject. *A local model for the crop*.
- Find out what the app is told on an iPad, and on the iPhone Duo, when it is on screen and not
  in focus, and when the Duo's cover closes. *When the app gives up focus*.
- Try Fill on the iPad, whose widget is held to 30 MB: whether Vision ever fits there, and what
  is fitted instead of filled. *Fit or fill*.
- Decide how a picture shrunk in bands is cropped toward faces, when only its crop is ever drawn.
  *Fit or fill*.
- Decide whether the app's preview reckons against the device's own widget limit. Reckoned as a
  30 MB widget, it fits a Large where the phone's widget fills, and never asks Vision. *Fit or
  fill*.
- Find out how the system finds an `AppEnum` kept in a package target, for both extensions.
  *On the Mac*.
- Find out whether Photos takes a fetch predicate comparing `pixelWidth` with `pixelHeight`.
  *Picking among Photos*.
- Find out whether `PHAsset.pixelWidth` and `pixelHeight` are the photograph as shown or as
  stored, for one taken on its side. *Which way up*.

# Design Decisions

*Fit or fill*

- **Fit is the whole photograph with black around it, and Fill is no black with the edges
  cropped.** Those are the words for the control. Syd, 2026-10-25, of "crop vs fill": "Yes that is
  what I meant", and "Fit and fill are better terms".
- **A third choice, Actual Size: never drawn larger than it is.** Syd, 2026-10-25: "we should
  also have an option not to expand the picture at all of it fits", and then a third choice over
  a switch beside Fit and Fill. A photograph that fits is shown at its own size with black around
  it; a larger one is shrunk to fit, as with Fit. So Fit and Actual Size write the same picture,
  and differ only in how it is drawn. The name, *Actual Size*, is Claude's.
- **Fit stays the default.** A photograph is fitted whole with black around it "as everywhere
  else in Photos-Go-Round" (`WidgetFace.swift`). A widget placed before the setting existed goes
  on as it was. Syd, 2026-10-25.
- **Fill crops toward faces, or else the subject.** Syd, 2026-10-25, chose that over cropping
  about the middle. How, as below, Syd agreed the same day:
  - **In the widget, at its wake.** A widget runs for months with the app never opened, so
    nothing the app finds reaches the pictures a widget picks. Syd, 2026-10-25: "Normal use case
    for a widget is that once it is setup, the app won't run again for months."
  - **Vision is asked of the covering picture shrunk to 512 pixels on its long side**
    (`CropFocus.shownToVision`). Syd, 2026-10-25, over asking it of the whole covering picture.
    Vision answers in fractions, so the answer lies on the covering picture as it is. Asked of
    the whole picture, the extension on Syd's phone found subjects and never faces, where the app
    found faces in the same photographs; at 512 it found them.
  - **Faces first** (`VNDetectFaceRectanglesRequest`): the crop holds as many of them as it can,
    centred on them, and of as many, the larger. **With none, the subject**
    (`VNGenerateAttentionBasedSaliencyImageRequest`), centred on its bounds. **With neither, the
    middle.** `CropFocus`.
  - **The crop is kept inside the picture**, so a face at an edge moves the crop to that edge and
    no further.
  - **Vision failing is the middle**, not a picture passed over.
  - **Vision is asked only when it fits.** The guard counts it at 16 MB beyond the shrink
    (`PictureResizer.visionNeeds`): on Syd's phone a fill from a HEIC added 8 to 26 MB with
    Vision, and two processes were ended asking it on top of a large fill. When the shrink and
    Vision do not fit in what is left, the crop is the middle.
  - **Only for a picture shrunk in one piece.** One shrunk in bands has only its crop drawn, so
    there is no covering picture to ask; it is cropped about the middle. *TODO*.
  - **In a simulator, Vision runs on the CPU.** Left to choose, it failed there: "Could not create
    inference context".
- **One view still draws both.** `WidgetFace` takes the setting, so what the preview shows is
  what a widget shows, as Syd asked on 2026-10-09.

*The crop is made when the picture is written*

- **A filled picture's file is the widget's shape, at the widget's pixels.** Fetching it to fit, as
  today, and enlarging it to fill would blur it: a portrait photograph fitted into a medium widget
  is about a third of its width, and would be drawn three times larger. So it is fetched big enough to
  cover the widget and cropped to it before it is written. The widget then decodes no more than
  it shows, which is what its 30 MB allows.
- **Photos:** asked with `.aspectFill` instead of `.aspectFit` at the widget's size
  (`SystemPhotoLibraryPictures.request`), then cropped.
- **Files:** `PictureResizer` shrinks to cover and not to fit, then crops.
- **The crop is drawn into a bitmap of its own, not cut with `cropping(to:)`.** On *Claude
  iPhone*, 2026-10-25, a HEIC from Photos shrunk in one piece and cut that way showed a quarter of
  the photograph's width, enlarged; the Mac cut it right. Drawing costs a bitmap the crop's size,
  which the guard counts.
- **What covering costs.** Covering a widget takes more pixels than fitting it, and with no limit
  for a long panorama: a 1:3 photograph covering a 2:1 widget is six times the widget's pixels
  before the crop. The guard that refuses a picture too large for an extension
  (`PictureResizer.refuseFromPhotosIfTooLarge`, `needsFromPhotos(fitting:)`) is asked about the
  covering size. A picture whose covering size the guard refuses is fitted instead, with black
  around it, rather than passed over. Syd, 2026-10-25.
- **A HEIC holds two copies of what covering adds.** On Syd's phone, 2026-10-25, a 5712 by 4284
  HEIC covering the Extra Large Portrait, 2263 by 1697, took 34 MB before its crop was drawn, and
  three processes were ended drawing it. Reckoned at two copies, about 44 MB, it is fitted
  instead, and the process lives.
- **The cache folders are named for it.** A picture made to fill is never shown fitted, or the
  other way round. A widget's folder becomes `systemMedium-300-fill`, and the preview's sized
  folder `1014x474-fill`. With the defaults the names stay as they are now, so the pictures
  already cached are kept.

*Matching the widget's shape*

- **Small and Large are square, and show every photograph.** Syd, 2026-10-25: "“Large” is
  square. All photos displayed in square widgets." The setting does nothing to them; Edit Widget
  and the app say so.
- **Medium and Extra Large are wide; Extra Large Portrait is tall.** By the size's name, not by
  the points it is handed, so a Large is square on every device. Claude's reading of "“Large” is
  square".
- **"Roughly" is which way the photograph is longer, by 1.2 times.** A wide widget shows
  photographs at least 1.2 times as wide as they are tall, and a tall one the same the other way.
  Syd, 2026-10-25: "1.2 is good". Matching the ratio itself would leave almost nothing: a medium
  widget is about 2.1 to 1, and most photographs are 4 to 3 or 3 to 2.
- **With none of the right shape, any photograph.** A wide widget over an album of portraits
  shows them, rather than "No Photos found". Syd, 2026-10-25, chose that over "No Photos
  found".
- **Counts are not changed.** A source is still weighed by all its pictures, so a source with few
  of the right shape is asked as often and gives way to any photograph more often. Counting each
  shape would double the counting, which is already the slow part.
- **Picking among Photos.** A `PHAsset` knows its size without anything being fetched, so a pick
  can try indices until one is the right shape, up to a few tries, before it falls back. If Photos
  takes a predicate comparing `pixelWidth` with `pixelHeight`, the fetch can leave out the wrong
  shapes instead, and the count of what is left is the source's for this widget. Not tried.
- **Picking among files.** `FolderSource` already picks three at random and tries each in turn.
  It would pick more, and read each one's size from its header (`CGImageSourceCopyPropertiesAtIndex`,
  nothing decoded) before shrinking it. A file iCloud Drive has not fetched has no header to read
  in a widget; it is taken as the right shape there, and may turn out not to be. Syd,
  2026-10-25, chose that over taking it as the wrong shape.
- **Which way up.** A file's size is read with its EXIF orientation, so one taken on its side is
  the shape it is shown at. Whether Photos' `pixelWidth` and `pixelHeight` already are is not
  known; *TODO*.

*Picture sizes, kept*

- **Each picture's size is kept once it is learned, in the agent's library and in a store of the
  widgets' own.** Syd, 2026-10-25: "It might be good to store picture dimensions in the
  database. This can happen on the fly with existing databases", and then both, over the
  widgets' store alone and the agent's library alone.
- **Filled on the fly.** Nothing walks a library ahead to fill them: a size is written when a pick
  learns it, from a `PHAsset` or a file's header. An existing library or store starts with none
  known and fills as pictures are seen. Unknown is not a size of none.
- **In the agent's library:** a new schema version adds two columns to `photo`, `pixel_width` and
  `pixel_height`, empty until known, so no library is scanned again. A walk of Photos already
  has each asset's size, so a walk fills them for the photographs it passes. The wallpaper, the
  screensaver and the windows pick by them (*The wallpaper, the screensaver and the windows*).
- **Each widget cache has a database of its own, and the app's preview has its own.** Syd,
  2026-10-25: "Widgets have to have their own database(s)", and then one for each widget cache,
  over one for each App Group and one for each process. So it is in the cache's folder, beside
  the pictures (`systemMedium-300-fill`), and goes when `clearAway` takes the folder away. Never
  the agent's library, on the Mac either.
  - **The widgets' caches move to the App Group's container**, out of each extension's own
    caches, on iOS and on the Mac, so the app can write into their databases. Syd, 2026-10-25,
    chose that over the app reloading the widgets and leaving each to learn for itself. Both
    already have a container: the bookmarks are in it (`WidgetFolderBookmark.swift`,
    `BookmarkedSources`). The caches left in the extensions' own folders are deleted once, by
    the first wake after the move. What a pick reads once, that widget does not read
  again. Each picture is known by its source's name, as in the counts, and its own: a Photos
  identifier, or a file's path in its folder.
  - **What one widget learns, another learns again**, unless the app has learned it: two sizes,
    or two settings, each read a picture's size and find its crop for themselves.
  - **What the app learns, it writes into every widget cache's database**, as well as its
    preview's: a picture's size and its crop are the picture's, whatever the widget. So a file in
    iCloud Drive the app has read is a known shape to a widget that cannot read it.
  - **Two writers: the app and the wake.** A cache is used by one wake at a time (`SerialWork` in
    the iOS extension's timeline, a lock in the Mac's), but the app may write while a wake does,
    so each database is opened to wait its turn, and what the app writes is only ever a size or
    a crop, never a picture.
  - **SQLite,** since a library holds tens of thousands of pictures, which a JSON file like
    `counts.json` would be read whole for. Syd, 2026-10-25, chose that over a JSON file.
    The agent's `Database` is in `PhotosGoRoundKit`, on the Mac alone; whether it moves to the
    shared code or the widgets' have their own wrapper is to be decided when it is built.
- **The crop found for a picture is kept with its size.** Faces and the subject are the picture's
  and not the widget's, so a region found once, kept as fractions of the picture, serves that
  cache from then on, and Vision runs once for each picture in each cache. Syd, 2026-10-25, chose that over finding it at
  each fetch. The covering picture Vision is asked of is the whole photograph, so the fractions
  are of the whole.

*A local model for the crop*

- **To be looked into: a local model finding faces or the subject.** Syd, 2026-10-25: "We should
  investigate using local LLM to find faces or subject". Vision is the plan until then.
- **Not in a widget.** An extension is held to 30 MB, which no model of that kind fits in. It
  would run in the app, or the Mac's agent, ahead of a widget, and the region it finds would be
  written with the picture's size into the widget caches' databases, or the agent's library.
  **In the app it reaches only the pictures the app has seen**: a widget runs for months with the
  app never opened (*Fit or fill*). The Mac's agent runs all the time, so there it would serve
  every picture.
- **What to compare, against Vision:** how well it frames, how long it takes, the memory, and the
  battery. What on-device models there are to try, and whether Apple's own takes pictures on
  iOS 27, is not known.

*In Edit Widget*

- **Each setting is a menu with "As in the app" first, and it is the default.** The app cannot
  write a placed widget's settings (*Telling one widget from another*, in `PGR Widgets - iOS.md`),
  and a default made in code is asked for once for every widget. So "the same setting in both
  places" can only be the app's setting, and a widget's own choice when it has made one. Syd,
  2026-10-25, chose that over each widget's setting alone with the app's only for its preview,
  and over the app's alone for now.
  - Fit or fill: *As in the app*, *Fit*, *Fill*, *Actual Size*. Titled *Pictures*, as the app's
    section is; the name is Claude's.
  - The shape: *As in the app*, *Any shape*, *The widget's shape*.
- **Their names are kept once widgets are out.** A widget whose settings type has changed stops
  reloading (*The trial, and what was built*), so the two parameters, like `every`, keep their
  names for good.
- **Two widgets of one size are told apart by these too.** The system feeds widgets set alike
  from one timeline; a medium set to fill and one set to fit are two widgets with two caches.
- **The widget's cache folder is named for what it resolves to**, not for "As in the app": a
  widget following the app and one set to the same thing share pictures. `clearAway` keeps the
  folders of every placed widget's resolved settings.
- **The widgets take a change to the app's setting when the person leaves the app**, as they take
  a change of sources. Syd, 2026-10-25, chose that over reloading them at once.
  - **On the Mac, as its sources do too**, which is at once: the Mac app reloads the widgets when
    the sources change (`WidgetFolderBookmark.swift`). Syd, 2026-10-25, chose that over reloading
    when the Settings window closes.
- **The preview follows the app's settings.** It cannot know a placed widget's own.

*When the app gives up focus*

- **When the app gives up focus, the widgets are reloaded and what the app has learned is
  written to every widget cache's database.** Syd, 2026-10-25: "We may need to update when app surrenders
  focus", and then both, adding "Have to worry about this on Duo and iPad as well". On the Mac
  it is as well as the reload at once.
- **Giving up focus is not leaving the screen.** On an iPad the app can be in Split View or
  Stage Manager beside another that has the focus, and on the iPhone Duo its cover can close.
  The reload today goes by the scene's phase being anything but active (`WidgetsApp.swift`), which
  should take in an app that is on screen without the focus; what each device says in each case
  is not known. *TODO*.
- **What the app learns is written as it is learned too**, so a widget woken while the app is in
  front still has it. Losing focus is when whatever the app is holding is written. Syd,
  2026-10-25, chose that over writing only when it loses focus.

*Where the settings go in the app*

- **A section first in the list, above *Photos* and *Files and Folders*, headed *Pictures*:** a
  three-way control, *Fit*, *Fill* and *Actual Size*, and, with Phase 2, a switch, *Match the
  widget's shape*. Directly under the
  preview, so a change is seen at once. Syd, 2026-10-25, chose that over the same section after
  the lists and over a menu in the bar. The bar is left alone: its two groups only just fit an
  iPad's narrowest window (*The screen: controls in the bar*). Where the lists are beside the
  preview, the section is there too, first.
- The switch says when it does nothing to the size the preview is showing.

*On the Mac*

- **The iOS and Mac widgets both.** Syd, 2026-10-25, chose that over the iOS widgets alone with
  the Mac's to come with the menubar app. The wallpaper, the screensaver and the windows came
  later the same day: *The wallpaper, the screensaver and the windows*.
- **The Mac gets both places, as iOS does: the app, and Edit Widget.** Syd, 2026-10-25, chose that
  over the Mac app's setting alone with the widget's own to come with the menubar app.
- **The Mac app's setting is in its Settings window**, in a *Pictures* section above the sources,
  as on iOS. Syd, 2026-10-25, chose that over below the sources and over a tab of its own. It is
  stored in the Mac app's preferences, whose domain carries the build variant, which is where the
  Mac widget already reads the sources (`Settings.sources()`).
- **The Mac widget moves from `StaticConfiguration` to `AppIntentConfiguration`**, with a settings
  type of its own whose parameters are the iOS one's. The enums are shared, in a target both
  extensions take, so their names, cases and wording cannot drift apart. Syd, 2026-10-25, chose
  that over a copy in each extension.
  - **The system must still find them.** An `AppEnum` outside the extension's own target is
    found only when its package says so (`AppIntentsPackage`), and the extension's target extracts
    the metadata (*The trial, and what was built*, in `PGR Widgets - iOS.md`). *TODO*.
- **Its panel has *Change Every* as well, with the same durations as iOS.** The five minutes
  hard-coded in `Settings.interval` goes. Syd, 2026-10-25, chose that over keeping five minutes
  until the menubar app.
- **Its cache is named for the settings too.** It is one folder for each size today
  (`TinyCache/systemMedium`); it becomes one for each size and resolved settings, as on iOS.
- **The crop and the shape are TinyCache's**, in `PhotosSource`, `FolderSource` and
  `PictureResizer`, which the Mac widget uses directly, so the Mac does not build them twice.
- **Building `Photos-Go-Round` registers the widget**, as `CLAUDE.md` says; a build to try the
  panel is unregistered afterwards.

*The wallpaper, the screensaver and the windows*

- **They get both settings too.** Syd, 2026-10-25: "Add this to wallpaper and screensavers and
  application windows as well."
- **They get their pictures from the agent, so the agent does the work.** Each asks
  `GET /v1/next` with its size in pixels (`PictureClient`), and the agent serves from one queue
  for every surface and shrinks the picture to fit. So the crop and the shape are the agent's,
  and the surfaces say what they want with the size they already send. Syd, 2026-10-25, chose
  that over each surface cropping and picking for itself from a larger picture and a region.
- **Fill is a picture made to cover, and cropped by the agent.** Asked to fill, the agent makes
  its resized copy to cover the box and crops it to the box's shape, toward faces or the subject,
  and keeps it as a resized copy of its own (`resized`, `ResizedCopies`) beside the fitted one.
  The surface then draws it whole, as now.
  - **The agent finds the crop region on the Mac, with no extension's limit.** Vision runs where
    the agent shrinks the photograph, and the region is kept with the photograph's size in its
    library, as for the widgets. The local model, if it is better, runs there too.
- **The shape is picked from what is queued.** Asked for a shape, the agent serves the first
  queued photograph of it, by the sizes kept in its library, and the first of any shape when none
  is. A photograph whose size is not yet known is taken as the right shape, as for the widgets.
  Syd, 2026-10-25, chose that over dealing the queue by shape from the start.
  - **What is queued is a few photographs and not the library**, so a shape that is rare in the
    library is often not in the queue, and any shape is served. Whether the queue should be dealt
    with the shapes asked for in mind is for when it has been watched. *TODO*.
- **A screen or a window is square, wide or tall by its size, with the photographs' rule:**
  square when its long side is less than 1.2 times its short side. Almost every display is wide;
  one turned on its side is tall; a window is whatever it has been dragged to, asked again for
  each picture. Syd, 2026-10-25.
- **Each has its own, as for every setting they have.** Syd, 2026-09-14: "the wallpaper,
  screensaver, app window, and agents preferences should all be separate." Syd, 2026-10-25,
  chose that over one setting all three follow:
  - **The screensaver and the wallpaper**: in their panels of the Settings window, under
    *Shuffle All*, stored in their own domains (`ScreensaverPreferences`,
    `WallpaperPreferences`), which the saver and the extension already read.
  - **A window**: in its Window Settings sheet, a copy of the screensaver's taken when the
    window is made and never stored, as its *Shuffle All* is. Syd, 2026-09-14, of the interval:
    "the app window will read the current screensaver internal when it is created, and it will
    stay there with its own copy of the setting".
- **The pan.** A fitted photograph was to slide through its own black (`Pan`), and a filled one
  has no black to slide through. But nothing pans today. Syd, 2026-10-25: "There is no panning
  right now. Or if there is, it's not working. That's a todo item". So it is in `TODO.md`, *The
  slow pan does not run*, and what a filled photograph does waits for it.
- **The defaults are Fit, and any shape**, so the screensaver, the wallpaper and the windows look
  as they do today until the settings are changed. Syd, 2026-10-25.

*Open questions for Syd*

None left. Syd answered each, 2026-10-25.

# Background

- `WidgetFace` draws a picture `scaledToFit` on black, for the widget and the app's preview.
- A widget's picture is fetched at the widget's size in pixels, to fit inside it: from Photos by
  `requestImage(… contentMode: .aspectFit …)`, from a file by `PictureResizer`.
- A widget's own settings are `PhotoWidgetSettings`, with one parameter, `every`. Its cache folder
  is named for its size and that, as in `systemSmall-300`.
- What every widget shares (the sources) is in the App Group's preferences, written by the app.

# Detailed discussions

None yet.

# References

- `Plans/PGR Widgets - iOS.md`: *How the preview is drawn*, *The screen: controls in the bar*,
  *Telling one widget from another*, and *The guard* for the memory a fetch may take.
- `Plans/Photos-Go-Round Widgets.md`, for the Mac's widget.
