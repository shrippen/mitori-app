# Changelog

## [Unreleased]

## [0.1.1] — 2026-11-08

### English

A fix for Android: the app reaches the internet again, so the DVD code loads the exam videos. With it come a faster Practise today and a few fixes.

#### Improved
- Practise today opens faster: the page shows at once, the due techniques follow a moment later. After years of use it took noticeably long before.

#### Fixed
- Android: the app could not open any secure (HTTPS) connection, because a library for it was missing from the APK. The video list stayed empty, a DVD code could not be unlocked and the course calendar did not load. All three work now.
- Glossary: after a tap on a letter the list now stays there; it sometimes jumped back to the top, for example after turning the phone.
- Closing the window during a voice recording no longer loses it: it is kept with the note's text.

#### Note
- About Mitori now also lists the licences of OpenSSL and the OpenMP runtime, which the APK contains.

All changes: https://github.com/shrippen/mitori-app/compare/v0.1.0...v0.1.1

### Deutsch

Eine Korrektur für Android: Die App kommt wieder ins Internet, der Code der DVD lädt die Prüfungsvideos. Dazu kommen ein schnelleres „Heute üben“ und ein paar Korrekturen.

#### Verbessert
- „Heute üben“ öffnet schneller: Die Seite steht sofort, die fälligen Techniken folgen einen Augenblick später. Nach Jahren der Nutzung dauerte es vorher spürbar.

#### Behoben
- Android: Die App konnte keine sichere Verbindung (HTTPS) aufbauen, weil eine Bibliothek dafür im APK fehlte. Die Videoliste blieb leer, der Code einer DVD ließ sich nicht freischalten, und der Lehrgangskalender lud nicht. Alle drei gehen jetzt.
- Glossar: Nach dem Tippen auf einen Buchstaben bleibt die Liste dort; vorher sprang sie manchmal nach oben zurück, etwa nach dem Drehen des Telefons.
- Wer das Fenster während einer Sprachaufnahme schließt, verliert sie nicht mehr: Sie bleibt mit dem Text der Notiz erhalten.

#### Hinweis
- „Über Mitori“ nennt jetzt auch die Lizenzen von OpenSSL und der OpenMP-Laufzeit, die das APK enthält.

## [0.1.0] — 2026-11-07

### English

The first release: Mitori puts the exam programmes of Aikido Shinki Rengo, Daitoryu and Itto-den Shinki Toho on your phone, tablet or desktop, so you can look up every technique, practise it, rate how well you know it and prepare for your next exam.

#### New
- The programmes of all three disciplines, grade by grade, with Japanese names and kanji, the attacks and groups as in the exam rules, and the comments on Shinki Toho; in German or English.
- Tap a technique and its place in the exam video plays: slow motion in three speeds, loop, frame by frame, full screen; swipe for brightness and volume.
- Rate each technique from 1 (seen) to 4 (ready for the exam); the programme and the grade chips show where you stand.
- Practise today: what is due by a review plan up to your practice grade, as a training playlist where rating moves on to the next technique.
- Notes on every technique, with photos and voice notes; all notes in one list, filtered by discipline and courses; search across techniques and your notes.
- Exam mode: a mock exam as a board, all or 8, 12 or 15 techniques of a grade, in order or shuffled, with a few from earlier grades; at the end you rate each one and the round goes into your statistics.
- Technique map: attack × technique for all grades up to yours, each place in the colour of how well you know it.
- Glossary with the Aiki-Budo lexicon, kanji, translation and pronunciation (where the device has a Japanese voice).
- Statistics: practice days as a calendar, techniques practised, the state of each grade and the average of your mock exams; all years at a glance.
- Courses from the association's course calendar, one notebook per course (with photos, voice notes and linked techniques, export as ZIP), add a course to your device calendar; your own courses too.
- My grades: the grades you passed, the next one with its waiting time, an exam planned on a course; the start menu, Practise today and the exam mode show it.
- Exam videos from the DVDs: the DVD's code (typed or scanned as QR code) loads its videos onto the device, checked and decrypted there.
- Backup to a file (merge or replace when reading it back) and sync between your devices over WebDAV or Nextcloud, with a choice when the same note was changed on two devices.
- Two styles of its own, Kante and Shinki (after the club's newspaper), next to Breeze and Material; style and language change without a restart.
- Phone, tablet (list and page side by side) and desktop: an APK for Android, an AppImage and Flatpaks for Linux and Plasma Mobile.

#### Note
- The videos are not part of the app: they come from the DVDs of the Shinkiryu association, and each DVD's code unlocks its own. Without a code the app shows the programme, notes and everything else, only no video.
- Videos load over Wi-Fi only unless you allow otherwise; they need space on the device.
- Not yet tested on a real phone: scanning the QR code, the camera and microphone for notes, keeping the screen on while practising. Sync is not yet tested against a real Nextcloud. Please report what fails.
- The APK needs Android 9 or newer on a 64-bit ARM phone. The AppImage is for x86_64; the Flatpaks are for x86_64 and aarch64 (Plasma Mobile). The Flatpak has no pronunciation in the glossary yet.
- App stores (F-Droid, Flathub) come later; until then updates come as new files on the release page.

All changes: https://github.com/shrippen/mitori-app/commits/v0.1.0

### Deutsch

Das erste Release: Mitori bringt die Prüfungsprogramme von Aikido Shinki Rengo, Daitoryu und Itto-den Shinki Toho auf Telefon, Tablet oder Desktop, damit du jede Technik nachschlagen, üben, einschätzen und dich auf deine nächste Prüfung vorbereiten kannst.

#### Neu
- Die Programme aller drei Sparten, Grad für Grad, mit japanischen Namen und Kanji, Angriffen und Gruppen wie in der Prüfungsordnung und den Kommentaren zu Shinki Toho; auf Deutsch oder Englisch.
- Technik antippen, ihre Stelle im Prüfungsvideo läuft: Zeitlupe in drei Stufen, Schleife, Einzelbild, Vollbild; Wischen für Helligkeit und Lautstärke.
- Jede Technik einschätzen von 1 (gesehen) bis 4 (prüfungsreif); Programm und Grad-Chips zeigen deinen Stand.
- Heute üben: was nach Plan fällig ist, bis zu deinem Übungsgrad, als Training in einer Playliste, in der Einschätzen zur nächsten Technik weiterschaltet.
- Notizen zu jeder Technik, mit Fotos und Sprachnotizen; alle Notizen in einer Liste, gefiltert nach Sparte und Lehrgängen; Suche über Techniken und deine Notizen.
- Prüfungsmodus: eine Probeprüfung als Tafel, alle oder 8, 12 oder 15 Techniken eines Grades, in Reihenfolge oder gemischt, mit Stichproben aus früheren Graden; am Ende schätzt du jede ein, die Runde geht in die Statistik.
- Technik-Landkarte: Angriff × Technik über alle Grade bis zu deinem, jeder Platz in der Farbe deines Stands.
- Glossar mit dem Aiki-Budo-Lexikon, Kanji, Übersetzung und Aussprache (wo das Gerät eine japanische Stimme hat).
- Statistik: Übungstage als Kalender, geübte Techniken, Stand je Grad und der Schnitt deiner Probeprüfungen; alle Jahre auf einen Blick.
- Lehrgänge aus dem Lehrgangskalender des Verbands, je Lehrgang ein Notizbuch (mit Fotos, Sprachnotizen und verknüpften Techniken, Export als ZIP), Lehrgang in den Gerätekalender eintragen; auch eigene Lehrgänge.
- Meine Grade: abgelegte Grade, der nächste mit Wartezeit, eine auf einem Lehrgang vorgemerkte Prüfung; Startmenü, Heute üben und Prüfungsmodus zeigen sie.
- Prüfungsvideos der DVDs: der Code der DVD (getippt oder als QR-Code gescannt) lädt ihre Videos aufs Gerät, dort geprüft und entschlüsselt.
- Sicherung als Datei (beim Einlesen zusammenführen oder ersetzen) und Abgleich zwischen deinen Geräten über WebDAV oder Nextcloud, mit einer Wahl, wenn dieselbe Notiz auf zwei Geräten geändert wurde.
- Zwei eigene Stile, Kante und Shinki (nach der Vereinszeitung), neben Breeze und Material; Stil und Sprache wechseln ohne Neustart.
- Telefon, Tablet (Liste und Seite nebeneinander) und Desktop: eine APK für Android, ein AppImage und Flatpaks für Linux und Plasma Mobile.

#### Hinweis
- Die Videos gehören nicht zur App: sie kommen von den DVDs des Shinkiryu-Verbands, und der Code jeder DVD schaltet ihre frei. Ohne Code zeigt die App Programm, Notizen und alles andere, nur kein Video.
- Videos laden nur im WLAN, wenn du es nicht anders erlaubst; sie brauchen Platz auf dem Gerät.
- Noch nicht auf einem echten Telefon getestet: QR-Code scannen, Kamera und Mikrofon für Notizen, Bildschirm an beim Üben. Der Abgleich ist noch nicht gegen eine echte Nextcloud getestet. Bitte melde, was nicht geht.
- Die APK braucht Android 9 oder neuer auf einem Telefon mit 64-Bit-ARM. Das AppImage ist für x86_64, die Flatpaks für x86_64 und aarch64 (Plasma Mobile). Im Flatpak fehlt die Aussprache im Glossar noch.
- App-Stores (F-Droid, Flathub) kommen später; bis dahin kommen Updates als neue Dateien auf der Release-Seite.

[Alle Änderungen](https://github.com/shrippen/mitori-app/commits/v0.1.0)
