# Shinki – Style-Bibel

Shinki ist der zweite Stil von Mitori, neben Kante. Er übernimmt die Gestaltung der **Shinki News**, der
Vereinszeitung von Shinkiryu (Vorlage war die No. 45): weißes Papier, schwarze
Tusche, ein einziges Rot. Vorlage für die App ist der Clickdummy (`entwuerfe/clickdummy/`). Er zeigt jede
Ansicht im Stil Shinki.

Shinki ist **kein Unterthema von Kante**, sondern ein eigener Stil mit eigenen Farben, Schriften und
Bausteinen (Owner, 02.11.2026). Er ist eine Ausnahme von der GUI-Regel. `agent.md` (GUI (this project)) und
`REVIEW.md` nennen sie. Shinki gehört zur App und liegt in diesem Ordner.

```
shinki/
  README.md        diese Bibel: Grundsätze, Farben, Schrift, Formen, Bausteine, Umsetzung
  tokens.json      die Werte der Bibel, maschinenlesbar (eine Quelle für QML und Web)
  qml/Shinki/      der Stil für Qt Quick: ShinkiStyle (erzeugt aus tokens.json von tools/shinki_style.py),
                   später Controls-Stil und eigene Bausteine
  fonts/           die Schriften (OFL), Japanisch als Teilmenge
```

## 1 Grundsätze

1. **Papier, Tusche, Rot.**
   - Die Fläche ist weiß wie eine Seite, der Text tiefschwarz.
   - Es gibt genau eine Farbe, das Shinki-Rot `#CE171E`. Es markiert, was gewählt, wichtig oder zu tun ist,
     und nie bloß zur Zierde.
2. **Ruhe vor Effekt.**
   - Keine Schatten, Verläufe oder Rundungen an Flächen. Die wenigen Ausnahmen nennt Abschnitt 4: das Blatt
     wirft einen Schatten, rund ist nur, was rund gemeint ist (Abspielknopf, Schieberpunkt, Stufenpunkte,
     Griff, Symbolknopf).
   - Kanten sind 1 px feine Linien.
3. **Die Tuschelavierung ist das einzige Ornament.**
   - Ein grauer Pinselnebel oben rechts auf Seiten mit Kopf, wie hinter dem „No. 45“ der Zeitung.
   - Er ist leise (höchstens 10 % Schwarz) und liegt nie unter Text, den man lesen muss.
4. **Drei Stimmen der Schrift.**
   - Die Bedienung spricht serifenlos (PT Sans).
   - Ordnende Überschriften stehen schmal, in Versalien und rot (PT Sans Narrow), wie die Kolumnentitel der Zeitung.
   - Was man liest und übt, steht in einer Buchschrift (Crimson Pro): Techniknamen, Notizen, Kommentare.
   - Japanisch steht in einer Mincho (Noto Serif JP).
5. **Kanji als Zeichen.** Die Kacheln tragen ihr Kanji (技, 稽, 試, 記, 講, 図, 辞) in Rot, die Köpfe ihr Wort
   (稽古, 記録, 辞書 …) klein daneben. Es gehört
   zur Erkennung, nicht zur Übersetzung.
6. **Lesbar zuerst.**
   - Jeder Text erreicht WCAG AA (4,5:1) auf jedem Grund, auf dem er stehen darf. Abschnitt 2 nennt die Werte.
   - Rot steht nie allein für eine Bedeutung: Gewählt ist zugleich gefüllt oder unterstrichen, eine Stufe zugleich die Zahl.

## 2 Farben

Rollen statt Werte: Bausteine und Seiten nennen die Rolle, nie die Hex-Zahl. Die Quelle der Werte ist `tokens.json`.
Der Clickdummy hat für Nebentext `#77716C`; auf `chip` und `selected` verfehlt das AA (4,3 und 4,1). Shinki
nimmt darum das etwas dunklere `#6B655F` (nahe an `--muted` der Clickdummy-Seite, `#6E6863`).

| Rolle | Wert | Wofür | Kontrast auf `paper` |
|---|---|---|---|
| `paper` | `#FFFFFF` | Seitengrund | |
| `paperAlt` | `#FAF9F7` | zweite Fläche: große Kachel, letzte Notiz, rechte Spalte am Tablet | |
| `chip` | `#F3F1EE` | Hinweisfläche, Marke, Knopf unter dem Zeiger | |
| `line` | `#E6E2DD` | feine Linien, Rahmen, Trenner | 1,3 (Linie, kein Text) |
| `ink` | `#1D1B1A` | Text, Symbole, gewähltes Tempo | 17,2 |
| `inkMuted` | `#6B655F` | Nebentext: Untertitel, Achsen, Zeiten | 5,8 (`paperAlt` 5,5, `chip` 5,1, `selected` 4,9) |
| `selected` | `#FBEAEB` | gewählte Listenzeile (9 % `red` in `paper` gemischt) | |
| `red` | `#CE171E` | Akzent: gewählt, Kopfzeile, Hauptknopf, Fortschritt | 5,6 (`chip` 5,0) |
| `onRed` | `#FFFFFF` | Text auf Rot | 5,6 |
| `scrim` | `#140F0A`, Deckkraft 0,38 | Grund hinter einem Blatt (Bottom Sheet) | |
| `video` | `#111111` | Fläche hinter dem Video, Player quer | |

**Stufen** (Einschätzung, Stand je Grad, Kalender, Landkarte). Es ist eine Reihe von Papier zu Rot. Die
Zahl der Stufe steht immer dabei, so trägt die Farbe die Bedeutung nicht allein. Auf der Stufenfarbe steht sie
in `ink`, auf Stufe 4 in `onRed` (`levelText`; 4,6:1 auf Stufe 3, 5,6:1 auf Stufe 4).

| Stufe | Wert | Bedeutung |
|---|---|---|
| 0 | `#E9E6E2` | offen, kein Training |
| 1 | `#F3C7C6` | gesehen |
| 2 | `#E8918F` | mit Hilfe |
| 3 | `#DC5A57` | sicher |
| 4 | `#CE171E` | prüfungsreif |

**Zustände.**
- Fehler stehen in `red` mit Text. Es gibt kein zweites Rot.
- Erfolg steht in `ink` mit Haken. Shinki kennt kein Grün; die Bestätigung ist das Wort.
- Warnungen und wichtige Hinweise stehen auf `paperAlt` mit 1 px Rahmen und 3 px Rot links, wie „Code eingeben“ im Programm (`.novid.buy`).
- **Fokus** (Tastatur) ist ein 2 px Rahmen in `ink`. Dunkel auf Weiß ist überall sichtbar und verwechselt sich nicht mit „gewählt“ (Rot).

**Dunkel.** Shinki ist ein heller Stil, wie die gedruckte Zeitung. Wer dunkel will, nimmt Kante. Nur der
Player hat schon jetzt einen dunklen Grund (`video`), auf dem gilt: Text `#FFFFFF`, Nebentext `#BBBBBB`,
Akzent `red`, Linien weiß mit 30 %.

## 3 Schrift

| Stimme | Familie | Ersatz | Wofür |
|---|---|---|---|
| Bedienung | PT Sans | Segoe UI, sans-serif | Knöpfe, Felder, Listen, Fließtext der Bedienung |
| Kolumne | PT Sans Narrow, fett, Versalien, Sperrung 0,1 em | Arial Narrow | Gruppenköpfe, „Zurück“, Eyebrow über Titeln, Achsentitel |
| Buch | Crimson Pro | Georgia, serif | Techniknamen, Notizen, Kommentare, Titel im Blatt und Player |
| Japanisch | Noto Serif JP | Hiragino Mincho | Kanji und Kana, auch das Logo-Zeichen |

Die Shinki News setzen Myriad und Minion. Mitori nimmt freie Schriften mit ähnlichem Bild. PT Sans und
PT Sans Narrow ersetzen Myriad und Myriad Condensed, Crimson Pro ersetzt Minion. Alle stehen unter der SIL
Open Font License, dürfen also mit der App ausgeliefert werden. Noto Serif JP kommt als Teilmenge: nur die
Zeichen, die die App zeigt: Programmdaten, Glossar, QML und Übersetzungskataloge (die Kachel-Kanji 稽 試 講
記 図 辞 stehen nur im QML). `tools/shinki_fonts.py` erzeugt sie aus den Schriften von google/fonts (die ganze Schrift hat 13 MB); die
Teilmengen liegen im Repo, Crimson Pro nur Latein (ein Drittel der Größe). PT Sans und PT Sans Narrow kommen
unverändert: Ihre OFL reserviert den Namen „PT Sans“, eine Teilmenge dürfte ihn nicht tragen. `tests/test_shinki.py`
prüft, dass jedes Kanji und Kana darin steht: Ein neues Zeichen in den Daten scheitert dort, bis das Werkzeug
wieder läuft. Pfeile (→) haben die Schriften nicht; Qt nimmt sie aus einer Ersatzschrift.

Größen (bei 96 dpi; die App rechnet sie in die Einheit der Plattform um):

| Stufe | Größe / Zeilenhöhe | Schnitt | Beispiel |
|---|---|---|---|
| Seitentitel | 22 / 1,15 | PT Sans fett | „Statistik“ |
| Blatt-Titel | 25 / 1,1 | Crimson Pro halbfett | Techniknamen im Blatt |
| Player-Titel | 21 / 1,15 | Crimson Pro halbfett | |
| Kolumne | 11–12, Sperrung 0,1 em | PT Sans Narrow fett, Versalien | „TACHI-WAZA · MAE-SEME“ |
| Listenzeile | 16 / 1,2 | Crimson Pro halbfett | „Ikkyo“ |
| Lesetext | 15–16 / 1,45 | Crimson Pro | Kommentar, Notiz |
| Bedienung | 14 / 1,35 | PT Sans | Knöpfe, Felder |
| Nebentext | 11–12,5 | PT Sans | Untertitel, Zeiten, Legende |
| Japanisch neben Latein | 0,7–0,8 × der Zeile | Noto Serif JP normal, `inkMuted` | „一教“ hinter „Ikkyo“ |

Zahlen in Tabellen, Zeiten und Zählern stehen in Tabellenziffern.

## 4 Formen und Abstände

- **Ecken.** Flächen sind eckig (Radius 0): Kacheln, Karten, Knöpfe, Felder, Blätter. Rund sind nur der
  Abspielknopf (Kreis, 52 px im Player, 34 px in der Liste), der Punkt im Schieber (14 px), die
  Stufenpunkte (8 px), der Griff des Blatts (2 px) und die Fläche eines Symbolknopfs unter dem Zeiger (`.iconbtn`).
- **Schatten.** Nur das Blatt wirft einen, nach oben (0 −6 px, 24 px weich, 18 % Schwarz): Es liegt über der Seite.
- **Linien.** 1 px in `line` für Rahmen und Trenner. Listenzeilen trennt eine Linie in `paperAlt`.
  Gruppenköpfe tragen unten eine Linie in `line`.
- **Gewählt.**
  - Ein Segment ist gewählt, wenn es ganz rot gefüllt ist und weiß beschriftet.
  - Ein Grad-Chip ist gewählt, wenn er einen roten Rahmen und 3 px Rot innen unten hat.
  - Eine Listenzeile ist gewählt, wenn sie 3 px Rot links hat und `selected` als Fläche.
- **Abstände.** Raster 4 px. Seitenrand 16 px (Kopf 18 px), Abstand zwischen Kacheln 10 px, Innenabstand
  von Kachel und Karte 12–14 px. Zeilenhöhe der Listen mindestens 44 px (Finger).
- **Tuschelavierung.**
  - Drei weiche graue Flecken (radiale Verläufe, 6–10 % Schwarz, leicht unscharf), etwa 300 × 220 px oben
    rechts, zum Teil über den Rand hinaus.
  - Sie erscheint auf Seiten mit Kopf, nicht im Player, nicht in Blättern.
- **Bewegung.**
  - Kurz und gerade: 150 ms für Zustände, 200 ms für Blätter, ohne Federn.
  - Was ohne Ende läuft (die Stand-Leiste, solange sie wartet): gleichmäßig, ein Durchlauf 1200 ms (`sweep`).
  - Die Speicherbestätigung blitzt einmal in 14 % Rot auf und verblasst.
  - Die Systemeinstellung „Bewegung reduzieren“ schaltet die Bewegungen aus.

## 5 Bausteine

Jeder Baustein nennt, was er zeigt, und seine Werte, mit der CSS-Klasse des Clickdummys in Klammern. Was der
Clickdummy nicht zeigt (Schalter, Fokus, Tooltip, Toast), legt diese Bibel fest; das steht dort ohne Klasse.

- **Kopf** (`.hd`)
  - Optional ein Logo-Quadrat: 40 px, `red`, darauf 神氣 in Noto Serif JP, 15 px, weiß.
  - Darüber eine Eyebrow-Kolumne in Rot, etwa „‹ MENÜ“; sie ist zugleich der Zurück-Knopf.
  - Der Seitentitel steht in PT Sans fett, sein Kanji klein in `inkMuted` daneben.
  - Rechts die Aktionen der Seite als Symbolknöpfe, die übrigen in einem Menü (⋮); unten eine Linie.
  - Er ersetzt Kirigamis Leiste (`ShinkiHead`, in der App `LookHead` als Kopf des Fensters).
  - Eine Höhe auf allen Seiten: Die Kolumne behält ihre Zeile, auch ohne Weg zurück. Ändert sich die Höhe während
    des Seitenwechsels, hält Kirigami die abgehende Seite fest (ein Player spielte weiter).
  - Eine Seite mit `headless: true` (der Player quer) hat keinen Kopf.
- **Kachel** (`.tile`)
  - 1 px Rahmen, weiß; das Kanji 22 px rot, Titel 16 px fett, Unterzeile 12,5 px `inkMuted`.
  - Die große Kachel (Programm) geht über die ganze Breite, steht auf `paperAlt` und hat ein Kanji von 34 px.
  - Unter dem Zeiger wird der Rahmen rot.
- **Segmente** (`.seg`): eine Reihe gleich breiter Felder mit 1 px Rahmen, Text 13 px fett `inkMuted`; gewählt rot gefüllt.
- **Grad-Chips** (`.gchip`): Name fett, darunter der Stand („12/30“) in Tabellenziffern; gewählt wie oben.
- **Gruppenkopf** (`.gh`): Kolumne in Rot, das Japanische in `inkMuted` daneben, unten eine Linie.
- **Listenzeile** (`.li`)
  - Techniknamen in Crimson Pro 16 px, Angriff oder Zusatz klein darunter.
  - Ein Kanji davor (Einstellungen: 映 保 色) wie auf der Kachel: 22 px rot, Noto Serif JP.
  - Rechts die vier Stufenpunkte und der Abspielknopf (rot gefüllt); ohne Video bleibt der Platz leer.
- **Blatt** (`.sheet`)
  - Weiß von unten, darauf ein Griff 40 × 4 px in `line`.
  - Oben Eyebrow, Titel 25 px Crimson Pro, Japanisch 16 px darunter.
  - Der Grund dahinter ist `scrim`.
- **Einschätzen** (`.rate`): vier gleich breite Felder mit Zahl (17 px fett) und Wort (11 px); gewählt rot gefüllt.
- **Kennzahl**: die Zahl 28 px fett in Tabellenziffern, `ink`; darunter das Wort als Kolumne (11 px, `inkMuted`).
  Eine Änderung steht klein daneben, mit Pfeil als Form; besser ist `ink`, schlechter `red`.
- **Zahlenfeld**: wie das Feld, die Zahl in Tabellenziffern; − und + als Felder mit 1 px Rahmen links und rechts.
- **Knopf** (`.btn`)
  - Hauptknopf: rot gefüllt, weiß, 15 px fett, volle Breite im Blatt.
  - Zweitknopf: weiß mit 1 px Rahmen, Text `ink`.
  - Symbol 18 px; deaktiviert mit 50 % Deckkraft.
- **Feld** (`.qnote input`): `paperAlt`, 1 px Rahmen, Notizen in Crimson Pro 15 px. Im Fokus wird der Rahmen 2 px `ink`.
- **Schalter**: eckige Bahn 40 × 22 px; aus heißt `line`, an heißt `red`, der Knopf (16 px) ist weiß. An und Aus
  unterscheidet auch die Seite des Knopfes.
- **Einstellungszeile**: Titel 14 px `ink`, darunter der Hinweis 12 px `inkMuted`, rechts das Steuerelement; unten eine
  Linie. Geändert: ein rotes Quadrat am Titel und „Zurücksetzen“ als Link. Ein Abschnitt darüber als Kolumne.
- **Seitentitel** (Kopf): PT Sans fett 22 px, `ink`.
- **Datumsfeld**: das Feld mit einem Kalenderknopf; der Monat auf einer Karte: ‹ Monat Jahr ›, sieben Spalten (36 px),
  der gewählte Tag rot gefüllt, heute in `ink` gerahmt, „Heute“ als Link.
- **Auswahl**: das Feld mit kleinem Pfeil; die Liste auf Papier, die Zeile unter Zeiger oder Tastatur auf `chip` mit
  3 px Rot links, die gewählte fett.
- **Schritte** (Assistent): gleiche Spalten, je ein Balken, ein Quadrat mit Zahl und das Wort. Erledigt: Balken und
  Quadrat in `ink`, ein Haken. Aktuell: Balken 3 px rot, die Zahl weiß auf Rot, das Wort fett. Offen: Balken in
  `line`, das Quadrat hohl.
- **Optionskachel**: die Kachel mit Symbol oder Kanji, Name und Hinweis; gewählt: `selected` als Grund, roter Rahmen
  und 3 px Rot unten.
- **Karte**: `paperAlt` mit 1 px Rahmen in `line`, eckig; Innenabstand 12–14 px.
- **Dialog**: weiß mit 1 px Rahmen, eckig, auf `scrim`; Titel PT Sans fett 16 px, Text 14 px. Unten rechts Abbrechen
  (Zweitknopf) und der Hauptknopf, rot, mit dem, was er tut („Verwerfen“, nicht „OK“). Breiten 432, 648 und 864 px,
  höchstens 90 % des Fensters.
- **Hinweis** (`.novid`, `.sheet .hint`): `chip`-Fläche, Text 12,5 px `inkMuted`, die Aktion rot und fett am Ende.
  Wichtiger Hinweis: `paperAlt` mit 1 px Rahmen und 3 px Rot links.
- **Letzte Notiz** (`.lastnote`): `paperAlt`, darüber Datum und Gerät 11 px, der Text in Crimson Pro.
- **Player** (`.vid`, `.ctrl`, `.speeds`)
  - Video auf `video`. Tempo steht als Chip oben rechts (weiß auf 55 % Schwarz).
  - Der Schieber hat eine Bahn von 4 px in `line`, der Fortschritt ist rot, dazu der Punkt.
  - Der Abspielknopf ist ein roter Kreis.
  - Das gewählte Tempo ist `ink` gefüllt und weiß beschriftet; so liegt es nicht in Konkurrenz zum Rot.
- **Stand-Leiste und Zähler** (Download eines Pakets)
  - Die Leiste füllt sich rot auf `line`; solange der Stand offen ist (wartet auf WLAN), läuft ein rotes Stück
    von einem Viertel der Breite durch. Ohne Bewegung steht es in der Mitte.
  - Der Zähler zeigt die Prozent in PT Sans Narrow fett; jede Ziffer rollt in 150 ms gerade auf ihren Wert, alle
    zugleich.
- **Diagramme**
  - Kalender und gestapelte Balken in den Stufenfarben; eine einzelne Reihe (Durchschnitt im Prüfungsmodus) in
    `inkMuted`, damit ein Balken nie als Stufe gelesen wird (Owner, 03.11.2026). Achsen und Legende in 11 px `inkMuted`.
  - Gitterlinien in `line`. Jede Grafik hat Achsen oder Legende und Tooltips (Projektregel).
- **Tooltip und Toast**: `ink` als Fläche mit 92 %, Text weiß 12 px, eckig. Eine Warnung im Toast hat links 3 px Rot;
  das Wort sagt, was geschah.
- **Diagramm-Beschriftung**: Werte über Balken auf Papier mit 85 % (`chartLabel`), die Grundlinie in `ink`.

## 6 Umsetzung in Qt Quick

Mitori hat vier Stile (Owner, 03.11.2026): **Breeze**, **Material**, **Kante** (dunkel oder hell „Leinen“) und
**Shinki**. Breeze und Material sind die Controls-Stile der Plattform, Kante zeichnet sie in seiner Art „System“.
Kante ist Kantes eigene Art, Shinki dieser Stil. Kante und Shinki bleiben getrennt. Keiner hängt vom anderen
ab, und keiner wird für den anderen geändert. Dazwischen liegt in Mitori eine dünne Schicht **Look**
(`app/qml/Look`). Die Seiten fragen sie, und sie antwortet je nach Stil mit Kante (Breeze, Material, Kante)
oder Shinki.

```
Seiten (app/qml)        Look.levelColor(3), Look.mutedTextColor, LookTile { … }, LookSegmented { … }
   │
Look (app/qml/Look)     wählt je Stil:   Kante ─────────────── Shinki
   │                                     app/qml/Kante          shinki/qml/Shinki
   │                                     (KanteStyle, Kante*)    (ShinkiStyle, Shinki*, Controls-Stil)
Controls (QQC2)         Breeze: org.kde.desktop                Shinki: der Controls-Stil „Shinki“
                        Material: Material (nur Android)
                        Kante, Leinen: Breeze, wo es ihn gibt, sonst Material, mit Kantes Zeichnung
```

- **Wahl.** Der Einrichtungsassistent beim ersten Start fragt nach dem Stil. Er zeigt dazu ein kleines
  Tutorial zu den Funktionen. Später lässt sich der Stil in Einstellungen → Darstellung ändern. Der Wechsel
  gilt sofort, mit Vorschau je Stil: Mitori baut das Fenster neu (`Appearance::rebuild`). Der Controls-Stil
  steht fest, sobald das erste Fenster da ist; darum bietet ein Gerät nur Stile mit demselben Controls-Stil an.
  Breeze gibt es dort, wo es den Stil gibt: in einer Plasma-Sitzung mit qqc2-desktop-style. Den Stil Material gibt
  es nur auf Android (Owner, 06.11.2026), auch nicht im AppImage oder Flatpak; ein gespeichertes Material startet
  anderswo als Leinen. Ohne Breeze zeichnen die Kante-Stile und Shinki auf Qts Material-Controls.
- **`ShinkiStyle`** ist ein Singleton mit den Rollen, Stufen, Schriften und Größen aus `tokens.json`. Es ist
  die einzige Stelle mit Werten; jeder Wert dieser Bibel steht in `tokens.json`. `tools/shinki_style.py`
  erzeugt es, ein Test prüft, dass es aktuell ist. Die Namen: `paper`, `levelColor(3)`, `bookFamily`,
  `listRowSize` (px der Bibel über `unit()`), `pageSpace`, `sheetDuration`, `scrimOpacity`; `onRed` heißt
  `textOnRed` (QML liest „on“ + Großbuchstabe als Signal).
- **Controls-Stil `Shinki`** für die Controls, die Mitori nutzt: Button, ToolButton, TextField, TextArea,
  ComboBox, Switch, CheckBox, RadioButton, Slider, ProgressBar, TabBar/TabButton, Dialog, Menu/MenuItem,
  ToolTip, ScrollBar, Popup, Drawer, ItemDelegate.
- **Eigene Bausteine** für alles, was Kante mit eigener Zeichnung und eigenen Rollen löst, vor allem die
  Stufenfarben, die Kante aus seiner Fokusfarbe ableitet: Kopf (statt `KanteHeading`), Kachel, Segmente,
  Grad-Chip, Gruppenkopf (statt `KanteSectionLabel`), Listenzeile, Stufenpunkte und -wahl, Stand-Leiste,
  Kalender, Raster der Landkarte, Säulen, Legende, Karte, Kennzahl, Hinweis (statt `KanteHintCard`),
  Transportleiste des Players, Toast, Tuschelavierung (`ShinkiInk`), Logo (`ShinkiLogo`).
- **Look** hat für jeden dieser Bausteine einen `Look…`-Baustein mit derselben Schnittstelle unter Kante und
  Shinki: `app/qml/Look/LookTile.qml` ist der Kante-Baustein, `app/qml/Look/+shinki/LookTile.qml` der
  Shinki-Baustein. Welche Datei gilt, entscheidet der QML-Dateiselektor „shinki“, den `Appearance::prepare`
  je Engine setzt; ein Stilwechsel leert den Komponenten-Cache und baut das Fenster neu; kein Loader, keine
  Weiterleitung jeder Eigenschaft eines Bausteins. Die `+shinki`-Dateien stehen in den Ressourcen, nicht als QML-Typen (sonst gälte die letzte
  Datei des qmldir). Dazu kommt das Singleton `Look` mit den Rollen und Schriften, die Seiten heute direkt aus
  `KanteStyle` lesen: Grund, Karte, Bühne, Text, Nebentext, deaktiviert, Akzent, Fokus, positiv, negativ, Linien,
  `levelColor`, die kleine, japanische und Titelschrift. Ein Singleton überlebt den Wechsel: `Look` reicht die Rollen aus `LookRoles` weiter, das unter Shinki
  `+shinki/LookRoles.qml` ist und sie auf `ShinkiStyle` abbildet. Die Vorschau in Darstellung zeichnet jeder
  Stil selbst, in einer eigenen Engine mit eigenem Selektor (`LookPreview`, `LookSample.qml`).
- **Übergang.** Die Seiten ziehen Baustein für Baustein von `Kante…` auf `Look…` um, angefangen bei
  Startmenü, Programm, Blatt und Player. Sobald es `app/qml/Look` gibt, nimmt jede neue oder geänderte Seite
  `Look`. Eine noch nicht umgezogene Seite liest ihre Farben aus `KanteStyle`, einem Singleton, das kein
  Scope erreicht; unter Shinki trüge sie Plattformfarben neben Shinki-Controls. Darum nimmt jede Seite
  `Look`. Die Build-Option `MITORI_SHINKI` (standardmäßig an) lässt Shinki samt Schriften weg.
- **Schriften** liegen in `shinki/fonts` und kommen als Ressource in die App (Android und AppImage haben sie
  sonst nicht). Noto Serif JP ist eine Teilmenge (Abschnitt 3). Ein Test prüft, dass jedes Kanji und Kana
  aus Daten, QML und Katalogen darin steht. Bei einem neuen Zeichen: `python3 tools/shinki_chars.py`,
  dann `python3 tools/shinki_fonts.py <Ordner mit google/fonts>`.
- **Prüfen.**
  - Der Oberflächentest läuft zweimal: `ui` (Kante, Material) und `ui_shinki` (`MITORI_TEST_STYLE=shinki`, Bilder
    in `ui-shots/shinki`). Seine Bilder vergleicht ein Mensch mit dem Clickdummy.
  - Ein Test rechnet die Kontraste aus Abschnitt 2 aus `tokens.json` nach, für jede Paarung aus Text und Grund, die die Bibel erlaubt (`tests/test_shinki.py`).

## 7 Was Shinki nicht ist

- Kein Dunkelmodus (siehe Abschnitt 2).
- Keine zweite Akzentfarbe, kein Grün und kein Blau für Status.
- Keine Fotos oder Pinselgrafiken als Flächen. Die Tusche ist allein die Lavierung.
- Keine Kopie der Zeitung: kein Kolumnentitel, keine Seitenzahl, kein Initial. Das gehört zum Druck.
