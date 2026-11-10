# Working rules for this repository

The rules for all shrippen repositories are in `RULES.md` (writing, code, commits, bug
fixes, repository, GUI). It is a synced copy from the rules repository; do not edit it
here. This file holds only what is particular to this repository. A Claude Code session on
the owner's machine has the rules through the global `CLAUDE.md` already and reads
`RULES.md` only for its GUI rule, before work on a user interface.

## Rules of this project

- Every visualization (chart, graph, heatmap) in a popup or page has axis labels or a legend; without them it is useless. Give it hover tooltips where possible. Tiles stay without axes and legends, so they read at a glance; their popup carries the details.

## Mitori – Projekt-Wissen

## Zweck
Prüfungsprogramme von Aikido Shinki Rengo, Daitoryu und Itto-den Shinki Toho aus einer Quelle:
(a) das gedruckte Heft (LaTeX), (b) die App Mitori für Android und Plasma Mobile (Qt 6, Kirigami):
Technik antippen, die Stelle im Prüfungsvideo läuft, Zeitlupe, Schleife, einschätzen, Notizen,
Prüfungsmodus, Lehrgänge. Plan: `ROADMAP.md`. Entscheidungen zur App: `entwuerfe/app-entscheidungen.md`;
Vorlage der Oberfläche: der Clickdummy `entwuerfe/clickdummy/index.html` (Telefon und Tablet quer).

## Aufbau
```
third_party/mitori-daten/   Submodul: daten/*.yaml die eine Quelle, tools/daten.py, KORREKTUREN.md
                kommentare.py, lexikon.py lesen PDFs aus quellen/ → daten/*.yaml (erzeugt)
                bundle.py (Video-Bundle-Encoder)
app/           die App (CMake, C++, QML); app/qml/Kante ist eine Kopie aus ../Kante
                Look-Schicht über Kante und Shinki
shinki/        der Stil Shinki: Bibel, tokens.json, qml/Shinki, fonts/
tools/         shinki_style.py, shinki_fonts.py, shinki_chars.py
entwuerfe/     Konzept, Entscheidungen, Clickdummy (Vorlage, kein Produktcode)
(mitori-heft: eigenes Repo, das gedruckte Heft; pinnt ebenfalls mitori-daten)
KORREKTUREN.md  liegt im Submodul: offene und geklärte Fragen zu den Daten (IDs A-…, D-…, S-…)
```

## Schichten der App (nur zum direkten Nachbarn darunter)
```
qml/            Seiten und Komponenten (Kirigami + Kante), nur Darstellung
  ↓
services/       C++ QObjects für QML: Programm, Übungsstand, Notizen, Prüfung, Lehrgänge, Bundles, Abgleich
  ↓
store/          SQLite (Übungsprotokoll, Notizen, Einschätzungen)   catalog/  mitori-daten.json (Ressource)
  ↓                                                                 player/   QtMultimedia, Kapitelzeiten
platform/       eine Implementierung je Plattform (Bildschirm wach, Helligkeit, Lautstärke, Dateien)
```
- QML ruft nie SQLite, Dateien oder Netz direkt auf, immer über einen Service.
- Programmdaten nur aus `mitori-daten.json` (Build aus `third_party/mitori-daten/` über `-DMITORI_DATA_DIR=…`), nie im Code.
- Eine Datenversion wird durch das Submodul-Pin festgelegt. Neuer Datenstand: im Submodul-Repo PR, dann hier Submodul-Pointer erhöhen (PR). Heft- und App-Release hängen am selben Tag.

## Konventionen
- Der Daten-Pin zeigt auf `main` auf ein Tag `v<Stand>` von mitori-daten (CI prüft es); App und Heft ziehen zusammen nach.
- Programmdaten nur in `third_party/mitori-daten/daten/*.yaml` ändern, dann
  `python3 third_party/mitori-daten/tools/daten.py`; offene Fragen als `[ID]`, jede ID
  steht in `third_party/mitori-daten/KORREKTUREN.md`.
  `daten/shinki-toho-kommentare.yaml` und `daten/lexikon.yaml` sind erzeugt
  (`third_party/mitori-daten/tools/kommentare.py`, `…/lexikon.py`), nie von Hand bearbeiten.
- **Videos kommen nie ins Repo**, weder roh noch verschlüsselt, auch keine Ausschnitte. Ebenso keine
  Inhaltsschlüssel und Codes der Bundles (`mitori-bundle-geheim/` außerhalb des Repos).
- Texte der App deutsch und englisch, nur über Übersetzungskataloge.
- Demo-Modus nur zum Erstellen von Screenshots (Build-Option `MITORI_DEMO`, aus), nie in einer Auslieferung.
  `demo/start.sh [de|en] [stil]`: Emi Hartmanns Übungsstand aus `demo/world.json` (Abschnitt `dojo`, Kopie aus
  `shrippen.github.io/demo/`, nie von Hand ändern), eigene Ordner, keine Videos, kein Netz; `demo/shots.json` die Bilder.
- `scripts/check.sh` vor jedem Commit (Daten, Release-Notes, Tests, Build, qmllint).
- **Lokal bauen geht vor Warten auf die CI:** `scripts/build-all.sh [check|apk|appimage|flatpak]` baut alles, was die
  CI baut, nach `dist/`; eine Änderung an Build oder Paketen wird lokal gebaut und gestartet (APK per `adb` auf ein
  angeschlossenes Telefon, `.dev`-ID), bevor sie gepusht wird. Die CI läuft zusätzlich bei jedem Push.
- Icons: nur Breeze-Namen; ein neuer Name kommt in `scripts/sync-icons.sh` (Android und AppImage haben kein
  Icon-Theme, die App bringt die verwendeten mit).
- Videostellen: `python3 third_party/mitori-daten/tools/kapitel.py` liest die Kapitel der Videos
  (`../Mitori Videos`) nach `third_party/mitori-daten/daten/videos.yaml`; Einträge mit `pruefen: true`
  sind von Hand zu prüfen. Die CI kann das nicht (keine Videos im Repo).
- Oberflächentest `app/tests/qml/tst_ui.qml` (ctest `ui`): lädt jede Seite offscreen und legt Bilder nach
  `<build>/ui-shots`; mit `MITORI_VIDEOS` spielt er auch ein Video. Neue Seiten bekommen dort einen Fall.
  Wechsel von Stil und Sprache: `app/tests/qml-look/tst_look.qml` (ctest `look`, `look_shinki`), nur dort: `tst_ui.qml`
  hielte Seitentypen im Cache der Engine fest.
- Texte: Englisch im Code (`qsTr`), Deutsch in `app/i18n/mitori_de.ts` (`--target update_translations`); ein Test
  prüft, dass keine Übersetzung fehlt. `mitori_en.ts` hält nur englische Pluralformen (und lässt Englisch vor Deutsch
  gewinnen, wenn es in den Spracheinstellungen vorne steht).

## Gelernte Fehler
- LuaLaTeX: `require` findet keine lokalen Module, der Renderer lädt per `dofile`.
- pdftotext entfernt Trennstriche am Zeilenende, auch in Komposita; `third_party/mitori-daten/tools/kommentare.py`
  setzt sie wieder.
- Browser spielen HEVC meist nicht; die Videos der DVDs sind HEVC (Android dekodiert in Hardware).

## QML lint

- `scripts/qmllint.sh`, also in CI (reports, does not block). A finding in `app/qml/Kante` is fixed in Kante, then `scripts/sync-kante.sh`.
- **`var` in blocks, review when you touch a file:** `block-scope-var-declaration` is off in the script. When you change a file anyway, switch its `var`s to `let`/`const`, but check each: if the variable is read after its block or by a closure relying on function scope, `let` breaks it, at runtime only. A file's cases: `/usr/lib/qt6/bin/qmllint -I app/qml --json - <file>`.

## GUI (this project)

- Exception (owner, 02.11.2026): Mitori's second style **Shinki** (the club's newspaper) is
  separate from Kante, not a variant of it. Its values live in `shinki/tokens.json`, its
  components in `shinki/qml/Shinki`, its rules in `shinki/README.md`. Pages move to reach
  Kante and Shinki through `app/qml/Look`; once `app/qml/Look` exists, a new or changed page
  uses it (the bible's section 6). The styles: Breeze, Material, Kante (also Leinen), Shinki. Kante stays as it is; Shinki follows its own bible.

## Release

Release steps: `RELEASE.md`. Before a release, load the skill `release-changelog`. A release
is published, so the owner confirms it in words.

## Repository (this project)

- CI runs on the GitHub mirror (`.github/workflows/checks.yml`) and reports back to Gitea as the commit status `github / test`. Release files are built and attached on GitHub only (`.github/workflows/release.yml`).
- The merge waits for: CI is green on the PR's latest commit: every CI check that runs on each push (such as `github / test` from the GitHub mirror) shows success there. No status there yet means wait, not merge; if it never comes, check the mirror or ask the owner. PR-Agent's status does not count here. Without CI, the local checks count (here `scripts/check.sh`).
- The owner also confirms: a PR that changes `packaging/`.
- Everything else: `RULES.md` (Repository) and the skill `pr-review`.
