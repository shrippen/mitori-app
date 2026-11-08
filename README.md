# Mitori 見取り

App für Android und Plasma Mobile: Technik antippen, die Stelle im Prüfungsvideo läuft, in Zeitlupe
und als Schleife; danach abhaken und einschätzen. Prüfungsprogramme von Aikido Shinki Rengo,
Daitoryu und Itto-den Shinki Toho. Gedrucktes Heft im Schwester-Repo `mitori-heft`,
Programmdaten und Stil im Submodul `third_party/mitori-daten`.

Die Videos sind nicht Teil dieses Repos. Sie gehören zu den DVDs des Shinkiryu-Verbands und werden
in der App mit dem Code der DVD freigeschaltet.

## Aufbau

| Ordner | Inhalt |
|---|---|
| `app/` | die App (Qt 6, Kirigami, Design System Kante + Stil-Layer Look) |
| `entwuerfe/` | Konzept, Entscheidungen und Clickdummy der App |
| `packaging/` | Flatpak (`io.github.shrippen.Mitori.yml`), AppImage, metainfo, icons |
| `scripts/` | Build-Skripte: App, Android-App, AppImage, Flatpak, qmllint, Release-Notes, sync-kante |
| `shinki/` | der Stil Shinki: Bibel, Tokens, QML-Bausteine, Schriften |
| `tools/` | Werkzeuge von Shinki (Singleton, Schriften) |
| `third_party/mitori-daten/` | Submodul: Programmdaten, Quellen, Video-Bundle-Encoder |
| `tests/` | Python-Tests (Shinki, Übersetzungen, Android, Icons) |

Andere Repos:

| Repo | Inhalt |
|---|---|
| `mitori-heft` (Schwester) | gedrucktes Heft (LuaLaTeX) |
| `third_party/mitori-daten` (Submodul) | Daten, Quellen, Werkzeuge, Bundle-Encoder; Pin auf ein Datentag |

Plan: [ROADMAP.md](ROADMAP.md). Regeln für die Arbeit am Repo: [agent.md](agent.md).
Daten-Submodul: [mitori-daten](third_party/mitori-daten/README.md).

## Bauen

```sh
# Submodul beim ersten Klon:
git submodule update --init

./start.sh                                 # App bauen und starten, Videos aus ../Mitori Videos
cmake -S app -B build-app -G Ninja && cmake --build build-app && build-app/mitori
scripts/check.sh                           # alle Prüfungen wie in der CI
scripts/build-android.sh                   # APK → dist/android/
```

Daten prüfen und erzeugen läuft automatisch beim App-Build (CMake ruft
`third_party/mitori-daten/tools/daten.py` auf). Wer die Daten separat prüfen will:

```sh
python3 third_party/mitori-daten/tools/daten.py
```

## Lizenz

GPL-3.0-or-later. Texte und Listen aus `third_party/mitori-daten/quellen/` und die daraus
übernommenen Kommentare gehören ihren Verfassern (Shinkiryu-Verband).

Die App enthält außerdem ZXing-C++ (Apache-2.0) mit librscpp (Apache-2.0) und libzueci (BSD-3-Clause)
sowie Monocypher (BSD-2-Clause oder CC0-1.0). Ihre Lizenztexte liegen in `app/third_party/` und stehen
ebenfalls unter „Über Mitori“.

Das APK enthält zusätzlich OpenSSL (Apache-2.0) für HTTPS und libomp aus dem Android NDK (Apache-2.0 mit
LLVM-Ausnahmen) für Kirigami; ihre Texte liegen ebenso in `app/third_party/` und unter „Über Mitori“.

Die App enthält QtKeychain (auch in APK, AppImage und Flatpak; dort steht der Text unter „Über Mitori“):

```
QtKeychain
Copyright (C) 2011-2015 Frank Osterfeld <frank.osterfeld@gmail.com> and contributors

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to
   endorse or promote products derived from this software without
   specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
