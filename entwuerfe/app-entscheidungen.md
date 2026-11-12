# Mitori: Entscheidungen

Ergänzt `app-konzept.html` (Stand 2). Stand 01.11.2026.

## Aufbau

- Startmenü: **Bento (Variante C)** (Owner, 12.11.2026, gewählt auf dem Design-Canvas; löst Variante 1 ab):
  Kacheln unterschiedlicher Größe, die Programm-Kachel immer 2 × 2 (auf jeder Breite), Heute 2 × 1, die
  übrigen 1 × 1; jede Kachel zeigt ihren Inhalt (Programm: Gradleiter, Stand, „Weiter mit“; Heute: fällige
  Techniken mit Start; Prüfung: Countdown und Anteil sicherer Techniken, ersetzt den Hinweis über den Kacheln;
  Statistik, Lehrgänge, Landkarte, Glossar, Notizen). Die Werte werden asynchron geladen (`StartBoard`):
  die Kacheln stehen sofort, die Werte kommen nach. Der Clickdummy zeigt Variante 1 und ist hier überholt.
- Jede Einzelansicht wird als Clickdummy durchgespielt (`clickdummy/index.html`, nur Theme Shinki),
  Fragen und Antworten je Ansicht stehen dort rechts neben dem Telefon.

## Lehrgangsmodus

- Ansätze 1–3 aus dem Konzept übernommen (Notizbuch je Lehrgang, Struktur wo leicht, Foto und Sprachnotiz).
- Lehrgänge lassen sich auch **ohne Kalendereintrag** anlegen (private Trainings, Gastlehrer).
- **Fotos und Sprachnotizen: ja.**
- Notizen bleiben **privat**; weitergeben nur über den Export.
- Export möglichst einfach (Markdown/Text); für die Shinki News wird ohnehin umgebaut.
- Lehrgangsnotizen erscheinen **nicht** in „Wiederholen nach Plan“.
- **„Meine Notizbücher“** (Owner, 06.11.2026): Knopf neben „Meine Grade“ oben auf „Lehrgänge“, eigene Seite mit allen
  Notizbüchern; ein Termin öffnet weiter sein Notizbuch und legt es beim ersten Mal an. Ersetzt den Abschnitt im Clickdummy.

## Video-Bundles

- Manifest-Verfahren mit Code je DVD wie im Konzept.
- Die **Videodateien** liegen statisch auf dem Server (Caddy), immer nur die aktuelle Version. Das **Manifest** liegt als generisches Gitea-Paket (git.arianw.de) und nennt je Datei Adresse und Schnittpunkte (Owner, 06.11.2026).
- Öffentlich abrufbar dürfen die Dateien nur verschlüsselt sein; Schlüssel und Codes bleiben geheim (Owner, 06.11.2026).
- Videos dürfen **entschlüsselt auf dem Gerät** liegen (kein eigenes AES-QIODevice).
- Bundles sind **versioniert**; eine neue Bundle-Version bekommt einen eigenen Update-Hinweis in der App
  (getrennt vom App-Update-Check).
- Neukodieren und Remastern macht der Owner von Hand (`bundle.py build --fertig`, Owner, 06.11.2026).
- Zustimmung des Verbands holt der Nutzer selbst ein.

## Sicherung

Alle drei Wege: **Export/Import** als Datei, **Android Auto Backup**, **WebDAV/Nextcloud**.
Syncthing entfällt als eigener Weg (geht über den Export-Ordner).

## Programm (Clickdummy-Runde 1)

- Ein Grad zeigt nur seinen eigenen Stoff, kein Umschalter „alles bis hier“. Der Prüfungsmodus würfelt
  2–3 Techniken aus früheren Graden dazu.
- Zeile antippen öffnet zuerst das Technik-Blatt (einschätzen, letzte Notiz, Video, Notizen).
- Stand als vier Punkte.
- Shinki Toho: die Kamae-Übung ist eine Technik mit eigenem Stand und Video (Id `shinkitoho/kamae`; Owner
  02.11.2026: 26 Positionen in einem Fluss, ein Punkt), die Positionen stehen als Beschreibung im Blatt. Ebenso
  Suburi und Kiriotoshi mit eigenem Stand und Video.
- Grade ohne Video normal zeigen; nur ▶ ausblenden und darauf hinweisen.
- Shinki Toho: im Blatt der Knopf „Kommentar“ mit den Texten von shinkiryu.de (Odachi Kommentare,
  Kamae Kommentare, Suburi). `tools/kommentare.py` liest die PDFs nach `daten/shinki-toho-kommentare.yaml`,
  `tools/daten.py` hängt sie an die Einträge in `mitori-daten.json`.

## Player (Runde 2)

- Schleife ist Standard. Einschätzen und Notiz direkt im Player. Vier Tempi (0,25 / 0,5 / 0,75 / 1) reichen.
- Jede neue Technik startet mit 1× (Eigentümer, 06.11.2026), auch nach einem Neustart; die Schleife und der
  Wechsel zwischen klein und groß behalten das Tempo.
- Gesten aufs Video: Doppeltipp links/rechts = 2 s zurück/vor; Wischen hoch/runter in der linken Hälfte =
  Helligkeit des Geräts, in der rechten = Lautstärke.
- Querformat: Entwurf B, schmale Spalte rechts (Hochformat, Einzelbild, Pause, Tempo, Schleife), Bild bleibt frei,
  Zeitleiste unten im Bild, Technikname dauerhaft oben links. Keine vorige/nächste Technik im Querformat.
- Zurück aus dem Player zeigt die Programmliste an der vorherigen Stelle; die zuletzt angesehene Technik wird
  kurz markiert (auch wenn im Player weitergeschaltet wurde).
- **Videos werden für die Auslieferung beschnitten**: Schwarz oben und unten mit den eingebrannten Titeln fällt
  weg, die App zeigt Angriff und Technik selbst. Gemessen über den Zeilen-Median (Bildbereich):
  Aikido (alle Kyu/Dan, 720×478) Zeilen 63–437 → `crop=720:372:0:64`;
  Daitoryu (720×464) Zeilen 49–424 → `crop=720:374:0:50`; Shinki Toho (720×576, 16:9) ohne Balken.
  Pixel-Seitenverhältnis 16:15 bleibt, Aikido/Daitoryu danach ≈ 2,06 : 1. Beschneiden heißt neu kodieren;
  `tools/bundle.py` macht das mit hoher Qualität (HEVC), nicht kleiner.
- Fehlen Videos, weist die App auf die DVD beim Verband hin, mit Link
  https://www.shinkiryu.de/shinkiryu/de/DVD.php und „Code eingeben“.

## Kommentar (Shinki Toho)

- Texte werden mit der App ausgeliefert (offline).
- Kumidachi-Einleitung (Rollen U/S, Waffenkombinationen, Rei-ho, Ansage) als eigener Eintrag über den Ô-dachi.

## Tablet quer (Mattenrand)

- Die App bekommt insgesamt einen Querformat-Modus für ein dauerhaft quer aufgestelltes Tablet.
- Player: „groß“ (wie Telefon quer) und „klein“ (Video mit Steuerung links, rechts Einschätzen, Notiz,
  Kommentar und weitere Inhalte).
- Startmenü als 4-spaltiges Kachelraster.
- **Programm und Player klein sind eine Seite**: Liste links, rechts Video, Steuerung, Einschätzen, Notiz und
  Kommentar der gewählten Technik; Tippen auf eine Zeile spielt sie. Ohne Video steht rechts das Blatt.
  Beim Öffnen steht das Video still am Kapitelanfang (Eigentümer, 06.11.2026); das erste Tippen startet es, danach
  spielt jede gewählte Technik sofort. Sonst behält das Video seinen Zustand (Review, 06.11.2026): Drehen, Fenstergröße,
  Infokarte, anderer Grad, Regal speichern starten kein stehendes Video; nur das Wählen einer Technik startet.
  Beim Verlassen des Vollbilds folgt der Zustand dem Vollbild: dort pausiert bleibt pausiert, dort spielend spielt weiter.
- **Blatt neben der Liste** (Eigentümer, 06.11.2026: „Tablet nach Vorlage“): Der rechte Bereich zeigt den Player oder das
  Blatt, das Blatt liegt nicht mehr als Dialog darüber. Eine Zeile ohne Video zeigt ihr Blatt, der Player wartet darunter
  still an seiner Stelle; ihre Zeile holt ihn zurück, ein anderer Grad lässt ihn stehen. Hochkant gilt das Layout des
  Telefons; ein offenes Blatt geht beim Drehen mit, und eine Technik mit Video steht danach im Player, ohne zu starten.
- **Liste und Seite** (Eigentümer, 06.11.2026: „Tablet nach Vorlage“): Lehrgänge und Einstellungen zeigen quer neben der
  Liste die gewählte Seite. Beim Lehrgang steht zuerst ein Notizbuch, ohne Notizbuch ein Hinweis. Hochkant öffnet eine Zeile
  ihre Seite; beim Drehen bleibt die Seite dieselbe (Felder, Dialoge, Kamera, Scan, Aufnahme laufen weiter), hochkant füllt die gewählte oder benutzte Seite das Fenster, Zurück führt zur Liste. Ein begonnener Eintrag wird beim Wechsel der Zeile gespeichert; eine laufende Aufnahme wird dabei beendet und als Eintrag behalten.
- **Player groß**: bleibt über und unter dem Video genug Platz (ab 120 px, z. B. Tablet 16:10 mit
  Aikido/Daitoryu), stehen Titel oben und Steuerung unten im freien Raum; sonst die Spalte rechts
  (Telefon quer, Shinki Toho 16:9 auf dem Tablet).
- Kein eigener Mattenmodus.
- Kommentar als Lesespalte.

## Restliche Ansichten (Runde 3)

- **Heute üben**: Umschalter, welche Sparten die heutige Einheit enthält (mehrere möglich), jede bis zu ihrem Grad.
- **Prüfungsmodus**: Ergebnisse setzen auch den Stand der Techniken. Standard ist die Reihenfolge der
  Prüfungsordnung, zufällig als Option. Am Anfang Ja/Nein, ob 2–3 Techniken aus früheren Graden dazukommen
  (geordnet am Ende, zufällig eingestreut). Für die Rundenanzeige vier Gestaltungsvorschläge (A–D), Wahl offen.
- **Lehrgänge**: abgelegte Grade eintragen („Meine Grade“); auf einem kommenden Lehrgang eine Prüfung vormerken
  (Sparte + Grad). Grundlage für Wartezeiten, Hinweise (Menü, Heute üben, Prüfungsmodus) und Statistik.
- **Abgleich**: echter Abgleich zwischen Geräten über WebDAV/Nextcloud; Einträge mit Zeitstempel werden
  zusammengeführt, Konflikt nur bei gleichem Eintrag (Notiz: eine oder beide behalten; Einschätzung: eine gilt).
- **Videos**: Bundles einzeln entfernbar, ohne Code neu ladbar (Code bleibt gespeichert); Download
  standardmäßig nur im WLAN.
- **Statistik**: große Heatmap über alle Jahre, Filter je Sparte.

## Runde 4

- **Prüfungsmodus**: Gestaltung D (Tafel). Techniken aus früheren Graden (Ja/Nein) kommen immer am Anfang,
  2–5 Stichproben. Kein Zeitdruck. Shinki Toho zeigt nur die Technik; Shoden prüft Kamae (als ein Punkt) und
  Ô-dachi 1–11, höhere Grade ihre Formen.
- **Heute üben**: eine Sparte je Einheit (keine Mehrfachauswahl), keine Minutenangabe, Abstände je Stufe
  einstellbar, keine Erinnerung.
- **Übungsgrad** (Owner, 06.11.2026: „Übungsgrad kommt aus meine Grade oder manuell, nicht aus dem Programm.“,
  „Übungsgrad getrennt vom Blättern“): je Sparte ein eigener Wert für Startmenü, Heute üben und Prüfungsmodus. Er ist
  der Grad nach dem höchsten abgelegten aus „Meine Grade“ (ohne Stoff, etwa Hon-Menkyo: der letzte mit Stoff davor;
  nichts eingetragen: der erste), bis man ihn in Heute üben oder im Prüfungsmodus von Hand wählt. Eine Wahl gilt, bis
  ein später abgelegter Grad den Vorschlag über sie hinaus schiebt; ist sie schon weiter, bleibt sie. Den Vorschlag
  selbst wählen hebt die Wahl auf. Programm und Technik-Landkarte blättern für sich: sie beginnen beim Übungsgrad,
  ihre Chips ändern nur die Seite und werden nicht gemerkt.
- **Mindestabstände** (in `daten/aikido.yaml`, `daten/daitoryu.yaml` als `abstand` am Grad): Kyu je 1 Jahr;
  2. Dan 2 Jahre nach dem 1. Dan, 3. Dan 3 Jahre nach dem 2., 4. Dan bzw. Okugi 4 Jahre nach dem 3. Dan.
  1. Dan 1 Jahr nach dem 1. Kyu; Daitoryu-Okugi 4 Jahre nach dem 3. Dan (bestätigt).
- **Startmenü**: Reihenfolge und Auswahl so; Einstellungen als Zahnrad; Programm-Kachel zeigt die zuletzt
  gewählte Sparte.
- **Lehrgänge**: nur kommende Termine und vorhandene Notizbücher. Je Termin aus dem Kalender „In den
  Kalender“ (Gerätekalender) und, wenn die ICS-Beschreibung eine Zeile „Ausschreibung: URL“ enthält,
  „Ausschreibung“ (öffnet die offizielle Ausschreibung); im Clickdummy im Kopf des Notizbuchs.
- **Landkarte**: Gruppen getrennt.
- **Glossar**: Übersetzungen aus dem Aiki-Budo-Lexikon von shinkiryu.de (`tools/lexikon.py` →
  `daten/lexikon.yaml`, 219 Wörter); Aussprache zunächst per Sprachsynthese.

## Später (Todo)

- Statistik: weitere Auswertungen (z. B. Stand je Gruppe, Entwicklung über die Zeit).

## Runde 5

- Prüfungsrunde: Stichproben bleiben markiert.
- **Notizen**: Bearbeiten/Löschen per langem Drücken; Fotos und Sprachnotizen auch bei Technik-Notizen (Format wie
  im Lehrgang); Übersicht „Alle Notizen“ (Filter je Sparte oder Lehrgänge), erreichbar über das Programm.
- **Training**: „Training starten“ erzeugt eine Playliste nur aus den heutigen Techniken. Einschätzen schaltet zur
  nächsten offenen Technik; vorige/nächste und das Querformat bleiben in der Playliste (vorher landete man nach
  „Video ansehen“ im Querformat in der Programmübersicht und kam nicht zu Technik 2).
- **Lehrgang-Export**: kleines ZIP-Archiv mit Markdown, Fotos und Sprachnotizen.
- **Übungstage**: die große Jahresübersicht reicht vorerst.
- **Code**: auch per QR-Code scanbar (Aufkleber auf der DVD).
