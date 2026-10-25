# Summary

Two new settings for the widgets. **How a photograph sits in a widget:** fitted whole with black
around it, as today, or filling the widget with its edges cropped. **Whether a widget that is not
square shows only photographs of roughly its shape:** landscape ones in a wide widget, portrait
ones in a tall one. Each is set in the app, for every widget, and in a widget's own Edit Widget
panel, where it starts at "As in the app". Syd, 2026-10-25.

**An outline.** Nothing here is built. Where a decision is marked *proposed*, it is Claude's
reading and waits for Syd; the open questions are at the end of *Design Decisions*.

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
  - The cache folders are named for the setting.
  - A control for it on the settings screen. *Where the settings go in the app*.
- **Phase 2** — Matching the widget's shape, set in the app. *Matching the widget's shape*.
  - What shape a widget is, from its size's name.
  - Photos: picking among the photographs of the right shape.
  - Files and folders: the same, from what a file's header says of its size.
  - With none of the right shape, any photograph.
- **Phase 3** — Each widget's own. *In Edit Widget*.
  - Two settings in `PhotoWidgetSettings`, each starting at "As in the app".
  - The widget's cache folder and the clearing away go by them.
- **Phase 4** — The Mac's widget, if Syd wants it there before the menubar app. *Open questions*.

# TODO

- Every *proposed* decision below, and the open questions, for Syd.
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
  on as it was. *Proposed.*
- **Fill crops about the middle.** Nothing is done to find a face or a subject. *Proposed.*
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
  covering size. *Proposed:* a picture whose covering size the guard refuses is fitted instead,
  rather than passed over.
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
  shows them, rather than "No Photos found". *Proposed.*
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
  in a widget; it is taken as the wrong shape there. *Proposed.*
- **Which way up.** A file's size is read with its EXIF orientation, so one taken on its side is
  the shape it is shown at. Whether Photos' `pixelWidth` and `pixelHeight` already are is not
  known; *TODO*.

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
- **Changing the app's setting reloads the widgets at once**, rather than when the person leaves
  the app. *Proposed.*
- **The preview follows the app's settings.** It cannot know a placed widget's own.

*Where the settings go in the app*

- **A section first in the list, above *Photos* and *Files and Folders*, headed *Pictures*:** a
  two-way control, *Fit* and *Fill*, and a switch, *Match the widget's shape*. Directly under the
  preview, so a change is seen at once. Syd, 2026-10-25, chose that over the same section after
  the lists and over a menu in the bar. The bar is left alone: its two groups only just fit an
  iPad's narrowest window (*The screen: controls in the bar*). Where the lists are beside the
  preview, the section is there too, first.
- The switch says when it does nothing to the size the preview is showing.

*Open questions for Syd*

1. **With nothing of the right shape**, any photograph, or "No Photos found"?
2. **The Mac.** Its widget has no Edit Widget panel yet and reads the Mac app's preferences. Does
   it get these now, or with the menubar app? And are these for widgets alone, and not the
   screensaver or the wallpaper?

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
