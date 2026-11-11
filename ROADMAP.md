# Fahrplan

Sechs Schritte bis Mitori 1.0 (aus `entwuerfe/app-konzept.html`, Stand 01.11.2026). Wie jede Ansicht
aussieht und sich verhält, steht im Clickdummy (`entwuerfe/clickdummy/index.html`) und in
`entwuerfe/app-entscheidungen.md`; beides ist die Vorlage, nicht dieser Plan.

| Schritt | Inhalt | Fertig, wenn |
|---|---|---|
| 0 · Daten | Programmdaten als eine Quelle (`daten/*.yaml` → `tools/daten.py`), Kapitel aller Videos den Techniken zuordnen (ffprobe + tesseract, gegenlesen) | jede Technik hat ihre Videostelle |
| 1 · Abspielen | Repo-Gerüst aus Plasmai ✓, Startmenü, Programm, Player mit Zeitlupe und Schleife; Videos vorerst aus einem lokalen Ordner | APK aus der CI spielt jede Technik ab |
| 2 · Üben | Einschätzen (vier Punkte), Notizen mit Fotos und Sprachnotizen, Heute üben, Training als Playliste, Statistik, Suche | eine Woche im Dojo benutzt |
| 3 · Prüfen und Lernen | Prüfungsmodus (Tafel), Technik-Landkarte, Glossar mit Lexikon und Aussprache, Kommentare Shinki Toho | Probeprüfung damit gemacht |
| 4 · Bundles und Termine | `tools/bundle.py` (Beschnitt, Verschlüsselung, Manifest), Code-Eingabe und QR, Download; Lehrgänge aus ICS (je Lehrgang: in den Gerätekalender eintragen, Ausschreibung öffnen), Meine Grade, Wartezeiten, Lehrgangsnotizbuch, Sicherung (Export, Auto Backup, WebDAV-Abgleich) | ein Bundle per Code auf einem fremden Telefon geladen |
| 5 · Release | Demo-Modus mit Studio-Weber-Daten, Update-Check, Screenshots, Landing Page `docs/`, GitHub-Release (APK, AppImage, Flatpak für x86_64 und aarch64) | v1.0.0 auf GitHub und der Landing Page |

## Stand

- Schritt 0: Daten aller drei Sparten in `daten/`, geprüft von `tools/daten.py`; Heft baut (`heft/build.sh`).
  Videostellen aller Videos per `tools/kapitel.py` in `daten/videos.yaml`; offen: die Einträge mit
  `pruefen: true` gegenlesen, Abweichungen Video ↔ Daten in `KORREKTUREN.md` (V-…) klären.
- Schritt 1: Startmenü (Kachel Programm), Programm (Sparte, Grad, Liste), Technik-Blatt, Kommentar,
  Player (Schleife, vier Tempi, Einzelbild, Doppeltipp, Querformat), Videos aus einem lokalen Ordner.
  Wischen hoch/runter links: Helligkeit, rechts: Lautstärke (`platform/devicelevels`: Android Fenster-Helligkeit
  und AudioManager, Linux Helligkeit über Solid, Ton des Players). Offen: Test auf dem Telefon. Tablet quer: Startmenü als
  Raster mit vier Spalten; Programm und Player klein auf einer Seite (Liste links, rechts Player mit Kommentar oder das
  Blatt bei Techniken ohne Video). Offen dort: Player groß mit Titel und Steuerung über/unter dem Video,
  Kommentar als Lesespalte. Tastatur im Programm: Tab geht Zeile für Zeile durch die ganze Liste und hält die
  Zeile im Blick, Ende springt beim ersten Druck ans Ende.
- Schritt 2: Einschätzen 1–4 im Technik-Blatt und im Player (Übungsprotokoll in SQLite, jede Einschätzung ein
  Eintrag mit Zeit und Gerät), Stand als vier Punkte in der Programmliste, Stand je Grad als Leiste mit Legende.
  Heute üben (Wiederholen nach Plan bis zum Übungsgrad, aus „Meine Grade“ oder von Hand, siehe
  `entwuerfe/app-entscheidungen.md`; Abstände je Stufe einstellbar, Kachel im Startmenü) und Training (Playliste der
  fälligen Techniken, Einschätzen schaltet weiter). Notizen je Technik (Text; nach Tagen, lang drücken zum
  Bearbeiten/Löschen, letzte Notiz im Blatt, Eingabe im Player), „Alle Notizen“ (nach Tagen, Filter je Sparte und Lehrgänge, Zeilen in C++; im
  Programm und in den Notizen einer Technik). Suche (Techniken aller Sparten und Grade, eigene Notizen; Groß/klein,
  Akzente, ß, Bindestriche und Okurigana egal; auch Angriffszusatz und Gruppe) über die Lupe im Startmenü. Statistik
  (Kachel im Startmenü): letzte 30 Tage (Übungstage, Techniken geübt), Übungstage als Kalender (halbes Jahr,
  Legende, Tooltip je Tag), Stand je Grad einer Sparte. Fotos und Sprachnotizen an Notizen (mit Schritt 4).
  In der Statistik auch „Meine Grade“ der Sparte (mit „Meine Grade bearbeiten …“) und „Alle Jahre …“ (`YearsPage`:
  ein Kalender je Jahr ab der ersten Einschätzung, alle Sparten oder eine, je Jahr Übungstage, Techniken und Grade).
- Schritt 3: Prüfungsmodus (Kachel 試 im Startmenü, „Probe <Grad>“): Sparte, Grad (nur mit Prüfungsstoff, je
  Anzahl Punkte), Anzahl (alle / 8 / 12 / 15), zufällige Reihenfolge, 2–5 Stichproben aus früheren Graden am
  Anfang (markiert); Einstellungen bleiben. Shinki Toho: Shoden prüft die Kamae-Übung (ein Eintrag) und
  Ô-dachi 1–11, höhere Grade ihre Formen. Runde als Tafel (Gruppe, Angriff, Technik; Shinki
  Toho nur Technik), Weiter mit Leertaste/Enter, Tablet größer. Am Ende jede Technik 1–4 einschätzen; Übernehmen
  setzt den Stand (Übungsprotokoll) und speichert die Runde (SQLite, Schema 4), die Statistik zeigt den Schnitt
  der letzten 8 Runden je Sparte; eine vorgemerkte Prüfung steht oben, ihr Grad ist einen Tipp entfernt.
- Schritt 3: Glossar (Kachel 辞 im Startmenü, auch die Lupe): ohne Eingabe A–Z mit Kanji und Übersetzung, mit
  Eingabe vor Techniken und Notizen (auch deutsche Wörter; gleiche Normalisierung wie die Suche). Daten: Aiki-Budo-
  Lexikon plus die Begriffe aus `daten/begriffe.yaml`, die es nicht hat (Schreibweise in Klammern und oo wie o
  zählen als dasselbe Wort; Begriffe mit offener Kanji-Frage wie A-K-04 und die ungeprüften Daitoryu-Bausteine
  bleiben draußen), je Wort eine Lesung in Hiragana aus der Umschrift (`tools/daten.py`). Aussprache per Qt
  TextToSpeech mit japanischer Stimme (Kanji, sonst die Lesung); ohne Stimme oder Sprachausgabe kein Knopf, ein
  Hinweis. Sprechen kann: Android (Plugin im APK, japanische Stimme der Sprachausgabe nötig), Linux mit qt6-speech
  und einer japanischen Stimme (speech-dispatcher), das AppImage (bringt das speech-dispatcher-Plugin mit). Nicht:
  Flatpak (die KDE-Runtime hat nur das Test-Plugin). Offen: Aussprache auf dem Telefon prüfen, qtspeech für
  Flatpak, A–Z-Sprungleiste, Lesungen ohne lange Vokale (Umschrift ohne ô, „aikido“ → あいきど), in der Suche
  Kommentare und Lehrgänge.
- Schritt 3: Technik-Landkarte (Kachel 図 im Startmenü): Sparte, „bis“ Grad (anfangs der Übungsgrad, Chips nur für die Seite), je Gruppe
  ein Raster Technik × Angriff über alle Grade bis dahin (Gruppen gleichen Titels aus Kyu- und Dan-Graden zusammen),
  jeder Platz in der Farbe seiner besten Stufe, leer, wo die Kombination nicht vorkommt; Shinki Toho als nummerierte
  Ô-dachi-Formen. Tippen öffnet das Technik-Blatt, Überfahren zeigt Technik, Angriff, Grad und Stand; Tab erreicht
  einen Platz je Raster, die Pfeiltasten wandern weiter. Breite Raster scrollen waagerecht, die Technik-Namen bleiben
  stehen. Raster: `KanteHeatGrid` (Kante 1.63, dafür ergänzt; Formenraster füllt die Breite seit Kante 1.64).
- Schritt 4: Lehrgänge (Kachel 講 im Startmenü, nennt den nächsten Termin): die kommenden Termine aus dem öffentlichen
  Lehrgangskalender (ICS, alle sechs Stunden neu geladen, offline vom Gerät), ein Notizbuch je Termin (beim ersten
  Öffnen angelegt, mit einer Kopie des Termins) und eigene Lehrgänge ohne Kalendereintrag. Alle Notizbücher auf eigener
  Seite (Knopf „Meine Notizbücher“ neben „Meine Grade“). Im Notizbuch: Tage, Ort,
  Lehrer (aus „mit …“ der Beschreibung), „In den Kalender“ (Plattform-Schicht `platform/devicecalendar`: Android
  über den Kalender-Intent, sonst als ICS-Datei an die Kalender-App), „Ausschreibung“ (aus der Zeile
  „Ausschreibung: URL“), Einträge nach Tagen (lang drücken: ändern, löschen), Notizbuch löschen. Gespeichert in
  `lehrgaenge.sqlite` (`store/coursebook`, eigenes Schema), jede Zeile mit Zeit und Gerät für den Abgleich.
  Die Einträge stehen auch in „Alle Notizen“ (Filter „Lehrgänge“). „Exportieren“: ein Blatt zeigt, was hinausgeht (`ExportSheet`);
  das Notizbuch als ZIP (`notizbuch.md` nach Tagen, `bilder/`, `audio/`; `store/zipwriter`, `store/notebookexport`) teilen (Android) oder in eine gewählte Datei.
- Schritt 4: Fotos und Sprachnotizen an Notizen einer Technik und an Lehrgangseinträgen: Foto mit der Kamera
  (`CameraPage`) oder aus einer Datei, Sprachnotiz (AAC in MP4) direkt in der Eingabezeile; Anzeige in Notizen,
  Notizbuch und „Alle Notizen“, Sprachnotiz zum Abspielen. Dateien in `medien/` (`store/mediastore`, Fotos höchstens
  2048 px), mit der Notiz gelöscht. Übungsprotokoll Schema 5, Lehrgänge Schema 3 (Spalte `media`). Android fragt nach
  Kamera und Mikrofon beim ersten Mal. Offen: Test auf dem Telefon (Kamera, Mikrofon, Bild aus der Galerie).
- Schritt 4: Meine Grade (in Lehrgänge oben): je Sparte die abgelegten Grade mit Tag und Ort, der nächste Grad mit
  Wartezeit (`wartezeit` aus `abstand` der Programmdaten; Shinki Toho Shoden ab Trainingsbeginn).
  Im Notizbuch eines kommenden Lehrgangs „Prüfung hier ablegen …“ (Sparte, Grad, Wartezeit gegen den ersten Tag);
  Lehrgänge zeigen die geplanten Prüfungen, die Kachel 講, Heute üben und der Prüfungsmodus die nächste.
  `lehrgaenge.sqlite` Schema 2 (Tabelle `grades`, Spalten `exam_*` an `courses`). Trainingsbeginn je Sparte, wo eine
  Wartezeit davon zählt (Shinki Toho Shoden: zwei Jahre), in „Meine Grade“; Schema 4 (Tabelle `starts`, die Sparte
  als uid, mit Sicherung und Abgleich).
- Schritt 4: Sicherung als Datei (Einstellungen → Sicherung): `mitori-sicherung-JJJJ-MM-TT.zip` mit beiden Datenbanken
  (`VACUUM INTO`), `medien/` und `manifest.json` (`store/backuparchive`, `store/zipreader`, `services/backup`).
  Einlesen führt zusammen (`store/tablemerge`): Einschätzungen und Prüfungsrunden als Vereinigung, Notizen,
  Notizbücher, Einträge und Grade per uid, das neuere `changed` gewinnt, Löschmarken eingeschlossen; zwei Notizbücher
  eines Termins werden eins, ein Grad doppelt der neuere. Vorher zeigt ein Dialog, was neu und was geändert ist.
  Oder Ersetzen (Besitzer, 06.11.2026; zweite Rückfrage mit Zahlen): alle Zeilen beider Datenbanken in einer Transaktion
  (`TableMerge::replace`), Medien davor, alles oder nichts (unter WAL je Datei: ein Absturz im Commit kann eine Datei
  ersetzt lassen, erneut ersetzen behebt es; Besitzer, 09.11.2026); schaltet den Abgleich aus, weil dessen Zusammenführen
  zurückholt, was andere Geräte haben, auch ihre neueren Änderungen und Löschungen (eine Weitergabe des Ersetzens an sie gibt es nicht; Einschätzungen und
  Prüfungsrunden haben keine Löschmarken).
  DVD-Codes und Inhaltsschlüssel bleiben draußen. Android Auto Backup sichert die Datenbanken ohne Medien.
  Offen: Die Vorschau zählt Einträge, die das Zusammenführen gleich wieder löscht (Notizbuch woanders gelöscht);
  ein als Dublette gelöschtes Notizbuch kann nach einer späteren Löschung durch den Nutzer wiederkommen (selten).
- Schritt 4: Abgleich über WebDAV / Nextcloud (Einstellungen → Abgleich zwischen Geräten): jedes Gerät legt seine
  Daten ohne Medien als `geraete/<id>.zip` in den Ordner, Fotos und Sprachnotizen einzeln unter `medien/`
  (`store/webdav`, `services/syncjob`, `services/sync`). Abgleichen führt die Archive der anderen Geräte zusammen
  (wie die Sicherung), holt die genannten Medien und legt das eigene Archiv ab; beim Start, einmal am Tag und auf
  Wunsch nach jeder Änderung. Konflikt nur, wenn dieselbe Notiz oder derselbe Eintrag seit dem letzten Abgleich auf
  zwei Geräten geändert wurde: bleibt bis zur Wahl (dieses Gerät, das andere, beide behalten; `ConflictsPage`).
  Konto und Sync-Id in `sync/`, von Android Auto Backup und Geräteumzug ausgenommen; das App-Passwort im Schlüsselbund.
  Offen: Test gegen eine echte Nextcloud; die Konfliktkarte zeigt zum aktuellen Text noch die Zeit des Abgleichs.
- Schritt 4: Video-Bundles (Einstellungen → „Videos und DVD-Codes“, Hinweis im Programm „Code eingeben“): das öffentliche
  Manifest (Gitea-Paket `mitori-manifest`) listet die Bundles; der Code einer DVD (20 Zeichen, Prüfzeichen) schaltet
  eins frei, Mitori lädt, prüft (SHA-256, Blöcke mit Tag) und entschlüsselt seine Videos aufs Gerät
  (`store/bundlecrypto` mit Monocypher, `store/bundleshelf`, `services/bundles`). Nur im WLAN (Schalter, „Jetzt laden“
  einmal ohne), einzeln entfernen (Code bleibt), neue Version als Update mit Hinweis im Startmenü. Videos aus einem
  Bundle sind schon beschnitten. Werkzeug `tools/bundle.py` (build, codes, sperren, pruefen, hochladen), Bundles in
  `tools/bundles.yaml`, Geheimes in `../mitori-bundle-geheim` (mit README zur Handhabung). Alle sechs Bundles sind
  hochgeladen (Version 1, 07.11.2026, mit Zustimmung des Verbands; aus den Originalen kodiert, das Remaster folgt
  später als neue Version). Offen: Freischalten und QR-Scan auf dem Telefon prüfen (Argon2id mit 64 MiB).
- QR-Code der DVD (`platform/qrreader` mit ZXing-C++, `services/codescanner`, `ScanPage`), neben dem Tippen, das der
  Hauptweg bleibt. **Inhalt des QR-Codes: genau der Code in der gruppierten Form, wie ihn `tools/bundle.py codes` in
  die CSV schreibt (erste Spalte), z. B. `7KQ2M-X9HDV-3TAPR-WE6YT`, der Code der Testdaten, kein echter** (23 Zeichen, ASCII, sonst nichts: keine URL, kein
  Präfix). Beim Druck der Einleger genau diesen Text codieren. Ein Scan läuft wie getippt; ein QR-Code ohne gültigen
  Code (Länge, Zeichen, Prüfzeichen) bekommt einen Satz, die Kamera läuft weiter. Der Code wird nie geloggt.
- Lernpakete (Owner, 10.11.2026): Video-Bundles mit eigenen Techniken, ohne Prüfungsbezug, ein Code je Paket. Format
  in mitori-daten `tools/lernpakete.md`; die Pakete liegen in `mitori-bundle-geheim/pakete/` (nicht im öffentlichen
  Repo). App: `catalog/lessons`, `services/library`, Kachel „Lernvideos“, Verweise Programm ↔ Lernvideo. Offen:
  Shirakawa Vol. 1 und 2 (Zeiten `pruefen: true` am Video prüfen), bauen, Codes, hochladen.
- Schritt 5: Demo-Modus (`demo/start.sh`, Emi Hartmanns Übungsstand aus der Studio-Weber-Welt, Abschnitt `dojo`),
  Screenshots (`demo/shots.json`), Landing Page `docs/index.html`, erstes Release 0.1.0 (APK, AppImage, Flatpak x86_64
  und aarch64). Offen: Update-Check, Stores (F-Droid, Flathub).

## Offene Punkte (Stand 03.11.2026)

Kleinigkeiten aus Reviews und Tests, je ein Folge-PR oder beim nächsten Bearbeiten der Datei.

### Wartet auf den Owner
- KORREKTUREN.md: Entscheidungen erst einarbeiten, wenn der Owner fertig ist (03.11.: „noch nicht fertig“).
  Konkrete Antworten bisher: A-X-04 (Futari-/San'nin-gake ohne Zusatz, ändert IDs), A-D-11, D-D-01, D-D-07,
  D-K-02; S-02 und S-12 ohne Antwort; viele „Als Frage an Sensei notieren“.
- Android: „Bildschirm an“ (FLAG_KEEP_SCREEN_ON) nur gebaut, nicht am Telefon geprüft.

### Fehler (Test zuerst)
- CoursePage-Fußleiste gelb in 16b/16c (beide Stile, #57).
- `start.sh` beendete sich beim ersten Lauf am 03.11. nach <10 s mit Exit 0 ohne Meldung (zweiter Lauf normal);
  beobachten.

### Look / Shinki
- LookPageTitle ungenutzt (seit dem Shinki-Kopf): entfernen oder einsetzen.
- Stand im Grad-Chip: Token `chipStandSize` nutzt noch kein Baustein (#52).
- ExamBoard Grundgröße 10 unter Shinki (Größe aus ShinkiStyle); ShinkiSettingRow/KanteSettingRow resetText
  deutsch fest (#55).
- Karten-Innenabstand als Look-Rolle (Shinki cardSpace 12) statt largeSpacing (#57).
- Diagramm-Auslese hell (paper 92 %) gegen Bibel (Tooltip ink 92 %): angleichen (#60).
- qmllint: „not declared as singleton in qmldir“ für Look.qml, +shinki/Look.qml, ShinkiStyle.qml (#50).
- ctest-Lauf ui_shinki zusätzlich unter org.kde.desktop + BreezeDark (Kontrast im Dialog, #56).

### Kante
- KanteChip `checked = !checked` (KanteChip.qml:72) bricht bei ankreuzbaren Chips ohne `choice` die Bindung
  (Grad-Chips seit 1.69 `choice`, behoben) → Kante-PR mit Test.
- KanteHeading horizontalAlignment im Overlay (#117); Screenshots im Kante-Changelog fehlen seit 1.65.
- KanteScope im KanteDialog erreicht ein eigenes contentItem nicht; Binding loop implicitWidth in tst_kante143
  (Fusion, Dialog ohne Inhalt); KanteDialogSkin/SheetSkin Scope als Eigenschaft ohne Fenster (#119).

### Aufräumen
- ExamEndPage.qml:84 `contentHeight` am discardDialog überflüssig seit Kante 1.71 (#63).
- daten.py `korrekturen()`: Tabelle mit ID-Kopf ohne Spalte „Status“ eigens melden (#65).

### Von früher

- **Landkarte**: Varianten eines Platzes (z. B. Ikkyo und Ikkyo ura) sind nur über das erste Blatt erreichbar:
  Frage an den Owner, ob sie einzeln erreichbar sein sollen. Datenfragen A-X-04 und D-D-08 (`KORREKTUREN.md`):
  geklärt, legen sich Spalten bzw. Raster zusammen.
- **Player-Gesten** (Review #35, mit dem Test auf dem Telefon): Android-Helligkeit über 255 (manche Hersteller)
  auf 0..1 begrenzen; Linux: Solid-Aufrufe asynchron, `brightnessMax` einmal je Wisch; beim Verlassen nicht
  zurücksetzen, wenn die Helligkeit inzwischen mit den Tasten geändert wurde.

- **Video-Bundles** (Review #33): `tools/bundle.py hochladen` als Stream (anderes Repo).

## QA gegen den Clickdummy (02.11.2026)

Vergleich jeder Ansicht mit `entwuerfe/clickdummy/` (Bilder beider Seiten, Code geprüft). Behoben: Kiriotoshi-
Kommentar leer, Programmliste über den Grad-Chips, Tippfehler im DVD-Code als „unvollständig“ gemeldet,
Reihenfolge der Kacheln. Offen, nach Gewicht:

- **Training**: Playliste auf dem Tablet links neben dem Player (Telefon: darunter, erledigt).
- **Player**: Knopf ⤢ ins Querformat; Titelzeile mit Kanji (Angriff · Zusatz · Grad · i / n steht hochkant schon,
  quer fehlt sie im Bild); quer die schmale Spalte nach Entwurf B, Zeitleiste im Bild.
- **Lehrgangsnotizbuch**: ⌗ verbindet Einträge mit Techniken (erledigt, #91). Noch offen aus der Vorlage: Angriff und
  Waffe als eigene Verknüpfung und „↗ im Programm“ (der Chip führt bisher zu den Notizen der Technik, nicht ins Programm).
- **Einstellungen** als drei Unterseiten (Videos, Sicherung, Darstellung): erledigt.
- **Startmenü**: Programm-Kachel mit Stand („Aikido · 5. Kyu · 7 von 20 prüfungsreif“ und Leiste, Kurzname);
  Telefon groß + zwei Spalten statt einer; Tablet die große Kachel 2 × 2; Begrüßung; Heute mit Sparte; Bundle-
  Update mit Namen.
- **Programm**: Shinki-Toho-Infokarte (Bedeutung, Inhalt, Mindestabstand); Beschreibung von Suburi und
  Kiriotoshi; Lupe im Kopf; Tablet-Liste schneidet lange Ô-dachi-Zeilen ab.
- **Kommentar**: Fußnoten und Listen setzen; Gruppe und Kanji im Text (Überschriften und ganzer Titel: erledigt).
- **Heute üben**: Kalender 12 Wochen mit Legende; Hinweis „tippen öffnet das Blatt“.
- **Videos**: Code-Seite mit Erklärung
  (Schreibweise egal, was passiert, der Code bleibt auf dem Gerät).
- **Sicherung**: Hinweis auf Android Auto Backup (ohne Medien); Konflikte als Hinweiszeile.
- **Konflikte**: Kopf mit Angriff und Tag.
- **Tablet zweispaltig**: Lehrgänge (Liste + Notizbuch), Einstellungen (Liste + Seite), Heute, Statistik.
- **Kleiner**: Meine Grade Eingabezeile bricht um, Fußtext ohne „Statistik“; Prüfungsende eine Zeile je Technik;
  Alle Jahre am Telefon zu kleine Tage (Dummy scrollt), Grade mit Datum unter dem Jahr; Suche: Programm vor
  Glossar, Trefferzahl je Gruppe; Notizen: Tagesköpfe „· Training/Lehrgang“, Kopf mit Zusatz und Grad; Alle
  Notizen: Uhrzeit bei Lehrgangseinträgen; Lehrgänge: „+ Lehrgang ohne Kalendereintrag“ als Zeile; Prüfung:
  „keine Sprachausgabe“; Statistik-Bild im UI-Test zeigt das Startmenü.

## QA-Runde 05.11.2026

Drei Runden mit sieben Personen (`qa/PERSONAS.md`, `qa/QA.md`), Abgleich mit dem Clickdummy, Performancetest
(`app/tests/perf`). Behoben: Blatt bei 360 px, Assistent, Video unter den Notizen, Vollbild verliert die Stelle,
Training quer (Liste neben dem kleinen Player), Probeprüfung ohne Rückfrage, Zanshin und offene Fragen im Blatt,
Sicherung ohne Endung, konto.ini 600, Alle Notizen und Alle Jahre schneller.

Offen, größer (Vorschläge im Artefakt „Mitori: Nachtschicht“):
- Telefon bei doppelter Anzeigegröße (206 px): Test `test_8o` auf diese Breite ausweiten; Segmente, lange Knöpfe,
  Bewertung und Steuerzeilen des Players brauchen eine schmale Form.
- Tablet nach Vorlage (Programm: Player oder Blatt rechts; Heute, Statistik und Grade in zwei Spalten; Lehrgänge und
  Einstellungen als Liste und Seite: erledigt).
- Programmdaten auf Englisch: erledigt (Daten 2026.11.1, App zeigt sie bei Englisch).
- Kante: Kopf beim ersten Bild hell. Die globale Kopfleiste trägt jetzt Kantes Farben (`KanteWindowScope`, Kante 1.78); ob das erste Bild beim Kaltstart stimmt, am Gerät prüfen.

Offen, klein:
- Treffer in Kommentaren und Lehrgangsnotizen,
  Kommentar mit Gruppe und Kanji.
- Barrierefreiheit: Kontrast der leeren Bewertungskästchen 1,36:1, Fortschrittsspur 1,07:1, Fokusring 2,05:1;
  Fokus nach Dialogen und Zurück, Tastaturweg zum Player (29 Tabs).
- Daten: „Ago: Kin“ (Lexikon, vermutlich „Kinn“), Glossar Kiri-otoshi ohne Übersetzung, „Kote“ ohne Kanji.


Abschlussrunde auf `main` (06.11.2026, ohne Videos): behoben sind Kopf des Trainings unter Kante, Titel und ✕ des Blatts. Offen:
- Kopf der Startseite unter Kante ohne System-Farbschema beim Kaltstart hell (`globalToolBar.colorSet` und späteres Erzeugen des Kopfs wirken nicht).
- Englisch: Bedeutungen und Glossar deutsch: erledigt (Programmdaten auf Englisch).
- Quer am Telefon bleiben im Programm rund 140 px für die Liste.
- „Abbrechen“ im Dialog „Runde verwerfen?“ ist doppeldeutig (Knopf aus dem Standard).
- `ScrollBar.qml:51` meldet Warnungen im Journal (59×); „not placed in the graphics scene“ je Seite.
## Kante-Bedarf

Fehlt in Kante und kommt dort hinzu (GUI-Regel), bevor Mitori es endgültig nutzt:
- Seiten-Scope: Kirigamis ScrollablePage erbt die Kante-Farben nicht (`Theme.inherit: false`); jetzt je Seite
  `KanteScope` plus Seitengrund. Besser eine Option in `KanteScope` (auch für System/Kante Light: View- statt
  Window-Farbe bei Listen). Die globale Kopfleiste des pageStack: erledigt (`KanteWindowScope`, Kante 1.78).

## Querschnitt

- **Stil Shinki** (Shinki News): eigener Stil neben Kante, kein Unterthema (Owner, 02.11.2026); Style-Bibel in
  `shinki/README.md`, Umsetzung als Qt-Quick-Controls-Stil `shinki/qml/Shinki` mit der Schicht `app/qml/Look`.
  Stand: `ShinkiStyle` aus `tokens.json`, Schriften (Japanisch und Crimson Pro als Teilmenge), Kontrasttest;
  `app/qml/Look` (Dateiselektor „shinki“) mit Rollen, Kachel, Hinweis, Knopf, Scope; das Startmenü geht über Look;
  `ctest ui_shinki`. Offen: Controls-Stil, die übrigen Bausteine, alle Seiten umziehen (Kopfzeile: erledigt, #62).
- **Stil wählbar** (Owner, 03.11.2026): Breeze, Material, Kante, Leinen, Shinki; gefragt im
  **Einrichtungsassistenten beim ersten Start** mit kurzem Rundgang, später in Einstellungen → Darstellung
  (`services/appearance`, gilt sofort, mit Vorschau; Material nur auf Android, Owner 06.11.2026). Shinki steht nur mit `-DMITORI_SHINKI=ON` zur Wahl, bis alle
  Seiten über `app/qml/Look` gehen; bis dahin sieht es aus wie Leinen.
- **Videos ausliefern**: beschnitten (Aikido `crop=720:372:0:64`, Daitoryu `crop=720:374:0:50`,
  Shinki Toho ohne), HEVC, als versionierte Bundles: Dateien statisch über Caddy, immer nur die aktuelle Version; das Manifest (Gitea-Paket) nennt ihre Adressen und Schnittpunkte.
- **Übersetzungen** deutsch und englisch von Anfang an.
- **Später**: Stores (F-Droid, Flathub), weitere Statistik-Auswertungen.
