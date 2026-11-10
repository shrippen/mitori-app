# Review guide

Every PR is reviewed before it is merged (rule in `RULES.md`, skill `pr-review`): by a new
Claude agent while PR-Agent is paused (owner, 01.11.2026), otherwise by
PR-Agent, with a new Claude agent for the **Wichtig** of earlier rounds and
when PR-Agent fails. The reviewer knows nothing of the session that wrote the
change: it gets the PR's intent, its diff and the repository, and this file.
The owner does not read code; this review is the second reader.

## What failure looks like here

Mitori is what students use to prepare their exams, and the booklet they
hold in their hands. A bug that matters is one a user sees, or one that
costs data or trust:

- **Wrong programme:** a technique missing, doubled, in the wrong grade or
  order, a wrong name or attack, a video that starts at the wrong place;
  booklet and app disagreeing; data that differs from `quellen/` without an
  entry in `KORREKTUREN.md` (all three in the `mitori-daten` submodule).
- **Loses data:** practice log, ratings, notes, photos or voice notes lost
  on an update, a migration, sync (WebDAV conflict), export or import.
- **Leaks:** videos, bundle keys or codes in the repository, notes leaving
  the device without the user's action, demo code or data in a release.
- **Wrong advice:** a review plan, waiting time or exam hint built on wrong
  dates or grades.
- **Stops the app:** a crash, a player that hangs, a missing bundle that
  breaks a page instead of showing the DVD hint.
- **Lies:** docs, `ROADMAP.md`, `agent.md` or comments the code contradicts.

## What to check in particular

- Data flow (`third_party/mitori-daten/`): programme data only in `daten/*.yaml`,
  checked by `tools/daten.py`; generated files (`daten/shinki-toho-kommentare.yaml`,
  `daten/lexikon.yaml`, `build/`) not edited by hand; every `[ID]` in the
  data has an entry in `KORREKTUREN.md`.
- Layers: QML only through services; services own SQLite, files, network.
  Database changes come with a migration and a test on an old database.
- Texts in both catalogs (de, en). GUI rule: Kante as it is, no hex or
  `px` outside `app/qml/Kante` and `shinki/`, no local copy of a Kante component. Shinki
  follows `shinki/README.md`: values only from `shinki/tokens.json`.
- Bug fixes: a test that failed before the fix, and the cause removed, not
  one case hidden. A release follows `RELEASE.md` (`CHANGELOG.md`, the
  same text in `docs/index.html` `#changes` and the Gitea release notes,
  the footer version, `versions.json` in shrippen.github.io).

## Skip

- `app/qml/Kante/` (`scripts/sync-kante.sh`), `scripts/release-notes.sh`
  (copy from Kante), `third_party/mitori-daten/`, `docs/shots/` and other images, the
  clickdummy in `entwuerfe/` (a design draft, not product code).

## How to report

- Every finding names file and line and the concrete input or state that
  goes wrong. No guess without evidence; if unsure, say so.
- Each finding gets one label: **Wichtig** (a bug from the list above,
  must be fixed or answered before the merge), **Kleinigkeit** (optional,
  at most five) or **Bestand** (the bug was there before this PR; not
  blocking).
- The report starts with the count, e.g. "2 Wichtig, 1 Kleinigkeit" (the
  session puts the heading above it). The count of **Wichtig** holds every
  one still open, also from an earlier round, e.g. "1 Wichtig (offen aus
  Runde 1)". Only when none is open it says plainly: "Nichts zu beheben."
- In a later round: say for each open **Wichtig** of the last round whether
  it is fixed, or whether its answer is accepted, with the reason. PR-Agent
  sees no earlier round: it reports only its own findings with their labels,
  and a new Claude agent closes the open ones (skill `pr-review`).
- Findings in German, code names as they are.
