# Architecture

How this repository is meant to be built. Where the code differs today is listed under
"Known deviations". Change this file in the PR that changes the structure.

## What it does

Mitori is the app for the examination programmes of Aikido Shinki Rengo, Daitoryu and
Itto-den Shinki Toho, for Android and Linux (Plasma Mobile, desktop): tap a technique
and its place in the examination video plays, with slow motion and loop; rate
yourself, take notes, practise in exam mode, keep course records, sync between devices.
The programme data come from the repository `mitori-daten`, which the printed booklet
uses too.

## Building blocks

| Path | Its one task |
|---|---|
| `app/qml/` | The pages and their components: display only. Small display helpers without state in `*.js`. |
| `app/qml/Look/` | The one way from a page to a style: one component per element, with a Kante and a Shinki form (`+shinki/`). |
| `app/qml/Kante/`, `shinki/` | The two styles. Kante is a synced copy, never edited here. Shinki is this project's own: values in `tokens.json`, components in `qml/Shinki`, rules in `README.md`. |
| `app/services/` | What QML talks to: one C++ object per topic (programme, practice, notes, exam, courses, glossary, videos and bundles, backup, sync, appearance, storage). The logic of the app. |
| `app/catalog/` | The programme data, read from the built-in `mitori-daten.json`, and the questions about them (discipline, grade, lesson). |
| `app/store/` | Everything kept or exchanged: the two databases (practice log, course book), files and archives, the bundle shelf with its decryption, secrets, the WebDAV client, readers and writers of formats (calendar, subtitles, zip). No logic of the app. |
| `app/player/` | Playing: which decoders exist, speaking a word. |
| `app/platform/` | What differs by platform, one name with a form per platform: device calendar, brightness and volume, share, storage places, system bars, QR reader. |
| `app/main.cpp`, `app/demo/` | Start of the app; the demo mode for screenshots (build option, off). |
| `app/tests/`, `tests/`, `qa/` | C++ tests per service and store, the interface test that loads every page, the style test; Python checks of packages, texts, icons and licences; test sessions with personas. |
| `app/android/`, `packaging/`, `scripts/`, `app/icons/`, `app/i18n/` | The Android package; Flatpak and AppImage; build, check and sync scripts; the icons the app brings along; translations. |
| `third_party/mitori-daten/` | Submodule: the one source of the programme data, pinned to a tag. |
| `app/third_party/` | Foreign code the app ships. Not edited here. |
| `tools/`, `demo/`, `docs/`, `entwuerfe/` | Shinki's generators and the structure check (synced copy); demo start and shot list; landing page; concept, decisions and the click dummy (a template, no product code). |

## Layers

```
 app/qml/  pages ─► Look ─► Kante | Shinki        (display only)
     │
     ▼
 app/services/          one object per topic, the logic
     │
     ├─────────────┬───────────────┬──────────────┐
     ▼             ▼               ▼              ▼
 app/catalog/   app/store/     app/player/    app/platform/
 programme      databases,     decoders,      one form per
 data           files, WebDAV  speech         platform
     │             ▲
     └─────────────┘  (which lessons have a video: the bundle shelf)
```

- QML never touches a database, a file, the settings or the network; it asks a
  service. A page holds layout and wiring, no rule.
- A page reaches a style through `Look` only, never Kante or Shinki directly. No
  colour or font outside the styles.
- Something several pages show the same way (a technique's name, playing a
  chapter, holding the layout while typing) is built once and used by all.
- A service never reaches up to QML and knows no page. Two named exceptions:
  `LookPreview` is an item that draws the style sample, and `Appearance` switches
  the engine's style. `store`, `player` and `platform` know no service and none
  of each other.
- `store` owns databases, files, archives and the network: a service says what it
  wants (this file from that address, both databases copied), never how. A service
  may remember a small setting of its own.
- `catalog` is the one place that knows the shape of the programme data. Services
  ask it by question, not by field name, and it tells them when the language changes.
- Programme data come from `mitori-daten.json` only, never from code.
- What differs by platform sits behind one name in `platform`; no service branches
  by platform.
- Videos, bundle keys and codes are never in this repository.
- The demo mode is in no release; the release check proves it.

## Where new things go

| Change | Touch |
|---|---|
| Any new file | Its entry in `app/CMakeLists.txt` |
| A new page | `app/qml/`, built from `Look` components; a case in `app/tests/qml/tst_ui.qml`; texts in `app/i18n/` |
| A new element of the interface | `app/qml/Look/` in both forms; for Kante first in Kante, for Shinki in `shinki/` |
| Something a page needs to know or do | A service in `app/services/`, with a test in `app/tests/` |
| Something new to store | `app/store/` (a schema step for a database), used by a service |
| A new format to read or write | `app/store/`, with a test |
| A new question about the programme | `app/catalog/` |
| A change of programme data | The repository `mitori-daten`, then the submodule pin here |
| Something only one platform does | `app/platform/`, one form per platform |
| A new icon | A Breeze name, entered in `scripts/sync-icons.sh` |
| A release | The steps in `RELEASE.md` |

## Known deviations

- The build lists the source files of every test by hand (`AUDIT.md`, finding 1).
- Backup and sync each open, copy and merge the two databases themselves
  (`AUDIT.md`, finding 2).
- Courses and bundles each build "load from the network and keep on the device",
  inside the service (`AUDIT.md`, finding 3).
- A technique's name is put together in eight pages, already differently
  (`AUDIT.md`, finding 4).
- The small player builds playing a chapter a second time (`AUDIT.md`, finding 5).
- The page "All notes" stores its filter itself (`AUDIT.md`, finding 6).
- The programme page has its own guard for typing (`AUDIT.md`, finding 7).
- The catalog hands the data on raw; six services search them by field name, and
  seven listen for the language themselves (`AUDIT.md`, finding 8).
- Services handle files themselves beyond that: `Bundles` downloads the videos
  and swaps the folders, `Backup` opens and copies archives, the sync job writes
  what it downloaded, `Storage` creates folders (not in `AUDIT.md`).
- The practice schedule (what is due when) and the search key live in `store`,
  though they keep nothing (not in `AUDIT.md`).
- `Main.qml` and `LookSample.qml` import Kante directly; services branch by
  platform in four places (not in `AUDIT.md`).
