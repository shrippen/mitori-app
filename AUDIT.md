# Code-Audit mitori-app, 14.11.2026, Stand 7191dbd

## Urteil
Mitori ist gut wartbar. Die Oberfläche erreicht beide Stile, Kante und Shinki, über eine Zwischenschicht, die Speicherschicht ruft nie einen Dienst auf, und fast jeder Dienst hat Tests, die sein Verhalten prüfen. Teuer wird die nächste Änderung dort, wo dasselbe mehrfach steht: kleine Regeln der Oberfläche sind in viele Seiten kopiert und weichen schon voneinander ab, die Bauanleitung der Tests zählt jede Quelldatei von Hand auf, und Datenbanken und Downloads werden an mehreren Stellen einzeln behandelt. Dies ist das erste Audit, einen Vergleich gibt es nicht. Wegen der Größe haben zwei Agenten je einen Teil geprüft (Oberfläche, übriger Code); aus ihren zwölf Funden stehen hier zehn, die übrigen nennt der PR zu diesem Bericht. Eine `ARCHITECTURE.md` fehlt; geprüft wurde gegen das Schichtbild in `agent.md`.

## Kennzahlen
| | letztes Audit | jetzt |
|---|---|---|
| Quelldateien | – | 366 |
| Einträge in der Bestandsliste | – | 58 |
| größte Datei (Zeilen) | – | 9560 (der Oberflächentest); ohne Tests 1715 (der Videospieler) |
| längste Funktion (Zeilen) | – | 254 (ein Testfall); ohne Tests 149 |

## Funde

### 1. Die Bauanleitung der Tests zählt für jedes Testprogramm alle Quelldateien von Hand auf.
**Was es kostet:** Die Bauanleitung (`app/CMakeLists.txt`) legt fest, welche Dateien zu welchem Testprogramm gehören. Dort steht dieselbe Dateiliste rund zwanzigmal, mit kleinen Abweichungen. Die Datei `courses.cpp` zum Beispiel steht in acht dieser Listen. Bekommt ein Dienst eine neue Abhängigkeit, muss man alle Listen finden, in denen er vorkommt. Zwei nachträgliche Sammelkorrekturen zeigen, dass das schon nötig war. Die Bauanleitung wurde in 144 von 718 Commits geändert. Der Oberflächentest bindet dagegen schon heute einfach die fertige Bibliothek der App ein, also das gebündelte Ergebnis aller Quelldateien.

**Vorschlag:** Die Testprogramme binden dieselbe Bibliothek ein wie die App und den Oberflächentest, statt Dateien aufzuzählen.

**Aufwand:** klein bis mittel, ein PR, der vor allem Zeilen löscht.

**Risiko:** gering, weil der Bau selbst jeden Fehler zeigt.

**Beleg:** `app/CMakeLists.txt:483`, `app/CMakeLists.txt:534`, `app/CMakeLists.txt:547`, `app/CMakeLists.txt:589`, `app/CMakeLists.txt:650`, `app/CMakeLists.txt:654`, `app/CMakeLists.txt:739`.

### 2. Die beiden Datenbanken (Übungsprotokoll und Lehrgangshefte) werden an sechs Stellen einzeln geöffnet, kopiert und zusammengeführt.
**Was es kostet:** Die Sicherung und der Abgleich zwischen Geräten machen dasselbe. Beide öffnen jede der zwei Datenbanken, ziehen eine Kopie oder mischen eine fremde Fassung ein und behandeln den Fehler. Das steht in beiden ausgeschrieben, jeweils zweimal hintereinander. Eine dritte Datenbank, etwa eigene Grade, oder eine geänderte Fehlermeldung muss an allen sechs Stellen gleich nachgezogen werden.

**Vorschlag:** In der Speicherschicht ein Baustein „Nutzerdaten“, der beide Datenbanken zusammen kopiert und zusammenführt. Sicherung und Abgleich rufen nur ihn auf.

**Aufwand:** klein.

**Risiko:** gering, `tst_backup` und `tst_sync` decken beide Wege ab.

**Beleg:** `app/services/backup.cpp:84`, `app/services/backup.cpp:231`, `app/services/backup.cpp:291`, `app/services/syncjob.cpp:97`, `app/services/syncjob.cpp:157`, `app/services/syncjob.cpp:168`.

### 3. Das Laden einer Datei aus dem Netz mit Ablage auf dem Gerät ist zweimal gebaut, für den Lehrgangskalender und für die Liste der Videopakete.
**Was es kostet:** Beide Dienste haben dieselben drei Schritte:
- die gespeicherte Fassung lesen,
- nach sechs Stunden neu laden,
- eine gute Antwort speichern, eine schlechte verwerfen.

Dazu gehören dieselben Zustände (leer, lädt, bereit, fehlgeschlagen) und Wartezeiten mit leicht verschiedenen Werten (20 und 30 Sekunden). Eine Änderung am Verhalten, etwa „nur im WLAN“ oder ein Neuversuch, muss zweimal gebaut werden. Zudem liegt der Netzzugriff hier in der Dienstschicht. Der WebDAV-Zugriff für den Abgleich liegt dagegen in der Speicherschicht. WebDAV ist das Protokoll, mit dem die Geräte über einen Online-Ordner abgleichen.

**Vorschlag:** Ein Baustein „gespeicherter Download“ in der Speicherschicht, dem jeder Dienst nur Adresse, Ablageort und Gültigkeitsprüfung gibt.

**Aufwand:** klein.

**Risiko:** gering, `tst_courses` und `tst_bundles` laden beide aus Testdateien.

**Beleg:** `app/services/courses.cpp:120`, `app/services/courses.cpp:131`, `app/services/courses.cpp:160`, `app/services/bundles.cpp:252`, `app/services/bundles.cpp:275`, `app/services/bundles.cpp:292`, `app/services/courses.h:55`, `app/services/bundles.h:57`, `app/services/courses.cpp:38`, `app/services/bundles.cpp:31`.

### 4. Der Name einer Technik wird in acht Seiten von Hand zusammengesetzt, und die Regeln dafür weichen schon voneinander ab

Eine Technik hat einen Titel und oft einen Zusatz, etwa „(Omote)“. Dazu kommen eine Nummer und ein Angriff mit eigenem Zusatz. Wie daraus eine Zeile wird, entscheidet jede Seite selbst. Die meisten lassen den Zusatz weg, wenn die Technik eine Nummer trägt. Die Liste zum Verknüpfen von Techniken mit einem Lehrgang zeigt ihn trotzdem, obwohl ihr Kommentar sagt, sie zeige die Technik „wie die Suche“. Den Angriff setzen drei Seiten als „Angriff (Zusatz)“ und drei andere als „Angriff · Zusatz“. Ändert sich die Schreibweise eines Technik-Namens, muss jemand alle Stellen finden; jede übersehene zeigt dieselbe Technik anders.

Vorschlag: eine Funktion für den Namen und eine für den Angriff, an einer Stelle (eine kleine Hilfsdatei wie die vorhandenen `.js`-Dateien oder im Dienst `Programme`). Alle Seiten rufen sie auf.

Aufwand klein. Risiko gering: Der Oberflächentest lädt jede Seite in beiden Stilen und prüft viele dieser Zeilen.

Beleg: `app/qml/SearchPage.qml:472`, `app/qml/SearchPage.qml:490`, `app/qml/WordDetail.qml:97`, `app/qml/WordDetail.qml:100`, `app/qml/TechniquePickerPage.qml:63`, `app/qml/TechniquePickerPage.qml:72-73`, `app/qml/PlayerView.qml:62`, `app/qml/PlayerView.qml:87-88`, `app/qml/NotesPage.qml:117-118`, `app/qml/PlayerPage.qml:199`, `app/qml/ProgrammePage.qml:488`, `app/qml/TechniqueBody.qml:135`, `app/qml/ExamEndPage.qml:53`.

### 5. Der kleine Spieler auf der Startseite baut das Abspielen eines Kapitels ein zweites Mal

Der kleine Spieler bestimmt die Videodatei, Anfang und Ende der Stelle sowie den Bildausschnitt ohne schwarze Ränder. Das alles schreibt er aus dem großen Spieler ab, und sein Kommentar sagt das selbst („As in PlayerView“). Mit abgeschrieben sind zwei feste Werte: 250 Millisekunden Abstand vom Dateiende und 75 % Deckkraft der Platte unter den Bedienelementen. Wer das Bündel-Format der Videos ändert (Schnittpunkte, Ausschnitt) oder einen Fehler am Kapitelende behebt, muss beide Spieler gleich ändern.

Vorschlag: ein gemeinsamer Baustein „Video-Bühne“ für Datei, Stelle, Schleifenende und Ausschnitt. Beide Spieler benutzen ihn.

Aufwand klein. Risiko gering: Der Oberflächentest prüft beide Spieler.

Beleg: `app/qml/PlayerMini.qml:17-26`, `app/qml/PlayerMini.qml:33`, `app/qml/PlayerMini.qml:95-104`, `app/qml/PlayerView.qml:45`, `app/qml/PlayerView.qml:54`, `app/qml/PlayerView.qml:68-74`, `app/qml/PlayerView.qml:676-683`.

### 6. Die Seite „Alle Notizen“ speichert ihren Filter selbst, an den Diensten vorbei

Alle anderen gemerkten Einstellungen speichert ein Dienst, also eine Programmschicht unter der Oberfläche. So will es auch die Regel des Repos, dass die Oberfläche nie selbst Dateien schreibt. Die Seite „Alle Notizen“ schreibt ihren Filter dagegen selbst in die Einstellungsdatei. Sie prüft auch selbst, ob der gemerkte Filter noch gilt. Dafür kopiert sie zwei Schlüsselwörter („courses“, „lern“) von Hand aus dem Dienst. Der Filter wird damit an drei Stellen gehalten: in der Seite, in der Einstellungsdatei und im Dienst. Mehrere Kommentare umgehen Zeitprobleme, die nur daraus entstehen. Benennt jemand im Dienst einen Filter um, bricht die Seite, ohne dass es beim Bauen auffällt.

Vorschlag: Der Dienst `AllNotes` merkt sich den Filter und verwirft einen ungültigen selbst; die Seite bindet nur noch an ihn.

Aufwand klein. Risiko gering: Für den Dienst gibt es einen eigenen Test, und der Oberflächentest prüft die Seite.

Beleg: `app/qml/AllNotesPage.qml:22-45`, `app/qml/AllNotesPage.qml:49-52`, `app/services/allnotes.h:28`, `app/services/allnotes.h:38`, `app/catalog/lessons.h:31`.

### 7. Die Programmseite hat einen eigenen Schutz gegen das Umspringen bei offener Bildschirmtastatur

Öffnet sich auf dem Tablet die Bildschirmtastatur, wird das Fenster niedriger. Ohne Schutz springt die Seite dann von zwei Spalten auf eine. Dafür gibt es den Baustein `TypingHold`. Vier Seiten nutzen ihn, darunter alle Listen mit Seite daneben. Die Programmseite baut stattdessen eine eigene, einfachere Fassung, die nur auf das Notizfeld des Spielers achtet. Das Drehen des Geräts behandelt sie nicht so, wie `TypingHold` es tut. Ein Fehler beim Tippen auf dem Tablet muss deshalb an zwei Stellen gesucht und behoben werden, und die Programmseite verhält sich beim Tippen anders als die übrigen Seiten.

Vorschlag: Die Programmseite nutzt `TypingHold` wie die anderen Seiten; ihre eigenen Zeilen dazu entfallen.

Aufwand klein. Risiko mittel: Das Verhalten mit Tastatur und Drehen ist nur teilweise im Oberflächentest abgedeckt; vorher einen Fall dafür ergänzen.

Beleg: `app/qml/ProgrammePage.qml:63`, `app/qml/ProgrammePage.qml:68-84`, `app/qml/ProgrammePage.qml:549-557`, `app/qml/TypingHold.qml:15-65`, `app/qml/ListAndPage.qml:37`.

### 8. Der Katalog gibt die Programmdaten roh weiter, und sechs Dienste suchen darin selbst nach Disziplin und Grad.
**Was es kostet:** Der Katalog liest die Programmdaten ein. Er reicht sie als verschachtelte Listen mit den deutschen Feldnamen der Datendatei weiter („grade“, „kurzname“, „pruefbar“, „wartezeit“). Programm, Lehrgänge, Prüfung, Startseite, Notizübersicht und Übungsgrad suchen darin jeweils selbst, welche Disziplin und welcher Grad gemeint ist. Der Name „Aikido 5. Kyu“ wird an zwei Stellen getrennt zusammengesetzt.

Wird ein Feld in `mitori-daten` umbenannt, merkt das der Compiler nicht, also das Programm, das den Code übersetzt. Man muss alle sechs Dienste von Hand finden. Ebenso meldet der Katalog einen Sprachwechsel nicht selbst. Sieben Dienste horchen deshalb jeder für sich auf das Signal der Anwendung, und vier halten eine eigene Kopie der aktuellen Sprache.

**Vorschlag:** Der Katalog bekommt Abfragen wie „Disziplin nach Kennung“, „prüfbare Grade einer Disziplin“ und „Anzeigename eines Grads“ sowie ein eigenes Signal für den Sprachwechsel. Die Dienste benutzen nur diese.

**Aufwand:** mittel, ein PR je zwei bis drei Dienste.

**Risiko:** gering, `tst_catalog`, `tst_programme`, `tst_exam`, `tst_startboard` und `tst_allnotes` gibt es.

**Beleg:** `app/services/courses.cpp:483`, `app/services/courses.cpp:502`, `app/services/courses.cpp:527`, `app/services/allnotes.cpp:100`, `app/services/programme.cpp:163`, `app/services/exam.cpp:139`, `app/services/practicegrade.cpp:100`, `app/services/startboard.cpp:488`, `app/catalog/catalog.h:15`, `app/services/programme.cpp:152`, `app/services/courses.cpp:96`, `app/services/bundles.cpp:188`.

### 9. Das Schichtbild in `agent.md` stimmt nicht mit dem Code überein, und es gibt keine `ARCHITECTURE.md`.
**Was es kostet:** `agent.md` zeichnet die Plattformschicht unter die Speicherschicht. Plattformschicht heißt hier: Bildschirm, Helligkeit, Kalender des Geräts, Teilen. Danach dürften die Dienste sie nur über die Speicherschicht erreichen. Tatsächlich ruft keine Datei der Speicherschicht die Plattform auf. Fünf Dienste rufen sie direkt. Die Plattform steht also neben der Speicherschicht, nicht darunter.

Außerdem liegen unter „store“ (laut Bild „SQLite“) auch Dinge, die nichts speichern: Leser für Kalender und Untertitel, der WebDAV-Zugang, die Entschlüsselung der Pakete und die Suchtext-Aufbereitung. Wer neuen Code einordnen will, findet so keine verlässliche Regel.

**Vorschlag:** Die Hauptsitzung legt nach Skill `architektur` eine `ARCHITECTURE.md` an, die den gelebten Aufbau beschreibt: die Plattform neben der Speicherschicht und den Inhalt von „store“ benannt. `agent.md` verweist dann darauf.

**Aufwand:** klein, nur Text, die erste Fassung bestätigt der Eigentümer.

**Risiko:** keins.

**Beleg:** `agent.md:38`, `agent.md:44`, `app/services/courses.cpp:6`, `app/services/courses.cpp:7`, `app/services/levels.cpp:3`, `app/services/storage.cpp:4`, `app/services/codescanner.cpp:12`, `app/services/appearance.cpp:18`, `app/store/icsreader.h`, `app/store/webdav.h`, `app/store/searchkey.h`.

### 10. Bestandsliste: was sich an einer Naht trennen lässt und was bleiben kann
Die Bestandsliste ist die Datei `structure.baseline`. Sie nennt, was heute über einer Grenze der Strukturprüfung liegt (Länge, Verzweigungen, Verschachtelung).

An einer Naht trennen sich:
- Der Oberflächentest (9560 Zeilen, 285 Fälle): Die Fälle sind schon nach Seiten nummeriert, und der Testlauf führt jede Testdatei im Ordner aus. Je Seite eine Datei, die Hilfsfunktionen in eine gemeinsame Basis.
- Der Videospieler (1715 Zeilen) enthält das Abspielen, neun kleine Bedien-Bausteine und drei vollständige Anordnungen (Telefon hochkant, Telefon quer, Tablet). Er teilt sich in eine Datei je Anordnung und eine für die Bausteine. Aufwand mittel, Risiko gering bis mittel: Der Oberflächentest hat viele Fälle zum Spieler.
- Die Programmseite (954 Zeilen): Auswahl von Fach und Grad, Tastenführung durch die Liste und der rechte Bereich lassen sich als eigene Bausteine herausnehmen.
- Der Abgleich zwischen Geräten (147 Zeilen, 48 Verzweigungen) trennt sich an seinen vier Schritten: Ordner listen, fremde Daten einmischen, Medien tauschen, eigene Daten senden.
- Das Laden der Videopakete (149 Zeilen) trennt sich in drei Teile: fertiges Paket einsetzen, nächste Datei anfordern, Antwort auswerten.
- Der Dienst für Lehrgänge (869 Zeilen) hat vier Aufgaben; die eigenen Grade mit Wartezeiten können ein eigener Dienst werden.

Bleiben können: die beiden Leitern von Schema-Schritten der Datenbanken (je Version ein Schritt), die Zeichentabellen der Suche, die Leser für Kalender und WebDAV, die großen, nach Themen getrennten C++-Tests und das Zellen-Raster von Shinki, das eine Kopie aus Kante ist und nur mit dem Original schrumpft.

Aufwand je Naht klein bis mittel. Risiko gering, wo Tests vorhanden sind. Beleg: `app/tests/qml/tst_ui.qml`, `app/CMakeLists.txt:740`, `app/qml/PlayerView.qml:394`, `app/qml/PlayerView.qml:602`, `app/qml/PlayerView.qml:1160`, `app/qml/PlayerView.qml:1478`, `app/qml/ProgrammePage.qml:176`, `app/qml/ProgrammePage.qml:662`, `app/services/syncjob.cpp:50`, `app/services/bundles.cpp:524`, `app/services/courses.cpp:530`, `app/store/searchkey.h`, `shinki/qml/Shinki/ShinkiHeatGrid.qml:7`.

## Seit dem letzten Audit
Erstes Audit.
