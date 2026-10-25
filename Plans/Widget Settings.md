# Summary

Two new settings for the iOS and Mac widgets. **How a photograph sits in a widget:** *Fit*, whole
with black around it, as today, or *Fill*, with its edges cropped toward faces or the subject. **Whether a widget that is not
square shows only photographs of roughly its shape:** landscape ones in a wide widget, portrait
ones in a tall one. Each is set in the app, for every widget, and in a widget's own Edit Widget
panel, where it starts at "As in the app". Syd, 2026-10-25.

**A plan.** Nothing here is built. A decision marked *proposed* is Claude's and waits for Syd;
every other is Syd's, 2026-10-25, or agreed by him. What is still to be found out is under *TODO*.

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

- **Phase 1** — Fill, set in the app. *Fit or fill*.
  - The setting is stored in the App Group's preferences, which the extension already reads.
  - `WidgetFace` draws a picture fitted or filled; the preview and the widgets follow the setting.
  - A filled picture is fetched to cover the widget and cropped to it when it is written, so the
    file is the widget's shape at its pixels. *The crop is made when the picture is written*.
  - Cropped about the middle first; then toward faces, or else the subject. *Fit or fill*.
  - Whether a local model finds faces or the subject better than Vision, looked into apart from
    the build. *A local model for the crop*.
  - The cache folders are named for the setting.
  - A control for it on the settings screen. *Where the settings go in the app*.
- **Phase 2** — Matching the widget's shape, set in the app. *Matching the widget's shape*.
  - What shape a widget is, from its size's name.
  - Photos: picking among the photographs of the right shape.
  - Files and folders: the same, from what a file's header says of its size.
  - With none of the right shape, any photograph.
  - Each picture's size kept once it is learned, in the widgets' store and the agent's library.
    *Picture sizes, kept*.
- **Phase 3** — Each widget's own. *In Edit Widget*.
  - Two settings in `PhotoWidgetSettings`, each starting at "As in the app".
  - The widget's cache folder and the clearing away go by them.
- **Phase 4** — The Mac. *On the Mac*.
  - The *Pictures* section in the Mac app's Settings window, stored where the Mac widget already
    reads the sources.
  - The Mac widget draws and fetches by the settings, through the same TinyCache sources.
  - The Mac widget gets an Edit Widget panel: *Change Every*, and the two settings at "As in the
    app".

# TODO

- Look into a local model for faces or the subject. *A local model for the crop*.
- Find out what the app is told on an iPad, and on the iPhone Duo, when it is on screen and not
  in focus, and when the Duo's cover closes. *When the app gives up focus*.
- Measure what Vision's two requests add to a widget extension's memory, on a phone, against its
  30 MB. *Fit or fill*.
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
- **Fit stays the default.** A photograph is fitted whole with black around it "as everywhere
  else in Photos-Go-Round" (`WidgetFace.swift`). A widget placed before the setting existed goes
  on as it was. Syd, 2026-10-25.
- **Fill crops toward faces, or else the subject.** Syd, 2026-10-25, chose that over cropping
  about the middle. How, as below, Syd agreed the same day:
  - **Vision is asked of the covering picture, not the original.** It is already at the widget's
    pixels, so what Vision holds is bounded by the widget and not by the photograph.
  - **Faces first** (`VNDetectFaceRectanglesRequest`): the crop holds as many of them as it can,
    centred on them. **With none, the subject** (`VNGenerateAttentionBasedSaliencyImageRequest`),
    centred on its bounds. **With neither, the middle.**
  - **The crop is kept inside the picture**, so a face at an edge moves the crop to that edge and
    no further.
  - **Vision failing is the middle**, not a picture passed over.
  - **Built after the middle.** The middle crop is tried on a phone first, and the faces and the
    subject come next in the same phase.
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
- **What covering costs.** Covering a widget takes more pixels than fitting it, and with no limit
  for a long panorama: a 1:3 photograph covering a 2:1 widget is six times the widget's pixels
  before the crop. The guard that refuses a picture too large for an extension
  (`PictureResizer.refuseFromPhotosIfTooLarge`, `needsFromPhotos(fitting:)`) is asked about the
  covering size. A picture whose covering size the guard refuses is fitted instead, with black
  around it, rather than passed over. Syd, 2026-10-25.
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
  has each asset's size, so a walk fills them for the photographs it passes. Nothing in the
  agent picks by shape yet; the wallpaper and the screensaver are not in this plan.
- **The widgets' store is in the App Group**, so the app and the extensions share it, on iOS and
  on the Mac. What a pick reads once, it does not read again; and a file in iCloud Drive that the
  app has read is a known shape to a widget that cannot read it. Each picture is known by its
  source's name, as in the counts, and its own: a Photos identifier, or a file's path in its
  folder.
  - **SQLite,** since the app and an extension may write at once, and a library holds tens of
    thousands of pictures, which a JSON file like `counts.json` would be read whole for. Syd,
    2026-10-25, chose that over a JSON file.
    The agent's `Database` is in `PhotosGoRoundKit`, on the Mac alone; whether it moves to the
    shared code or the store has its own is to be decided when it is built.
- **The crop found for a picture is kept with its size.** Faces and the subject are the picture's
  and not the widget's, so a region found once, kept as fractions of the picture, serves every
  widget, and Vision runs once for each picture. *Proposed.*

*A local model for the crop*

- **To be looked into: a local model finding faces or the subject.** Syd, 2026-10-25: "We should
  investigate using local LLM to find faces or subject". Vision is the plan until then.
- **Not in a widget.** An extension is held to 30 MB, which no model of that kind fits in. It
  would run in the app, or the Mac's agent, ahead of a widget, and the region it finds would be
  kept with the picture's size for the widget to read.
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
  - Fit or fill: *As in the app*, *Fit*, *Fill*.
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
  written to the widgets' store.** Syd, 2026-10-25: "We may need to update when app surrenders
  focus", and then both, adding "Have to worry about this on Duo and iPad as well". On the Mac
  it is as well as the reload at once.
- **Giving up focus is not leaving the screen.** On an iPad the app can be in Split View or
  Stage Manager beside another that has the focus, and on the iPhone Duo its cover can close.
  The reload today goes by the scene's phase being anything but active (`WidgetsApp.swift`), which
  should take in an app that is on screen without the focus; what each device says in each case
  is not known. *TODO*.
- **What the app learns is written as it is learned too**, so a widget woken while the app is in
  front still has it. Losing focus is when whatever the app is holding is written. *Proposed.*

*Where the settings go in the app*

- **A section first in the list, above *Photos* and *Files and Folders*, headed *Pictures*:** a
  two-way control, *Fit* and *Fill*, and a switch, *Match the widget's shape*. Directly under the
  preview, so a change is seen at once. Syd, 2026-10-25, chose that over the same section after
  the lists and over a menu in the bar. The bar is left alone: its two groups only just fit an
  iPad's narrowest window (*The screen: controls in the bar*). Where the lists are beside the
  preview, the section is there too, first.
- The switch says when it does nothing to the size the preview is showing.

*On the Mac*

- **The iOS and Mac widgets both, and nothing else.** Not the screensaver or the wallpaper. Syd,
  2026-10-25, chose that over the iOS widgets alone with the Mac's to come with the menubar app,
  and over every product that shows pictures.
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
