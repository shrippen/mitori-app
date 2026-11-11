Testdaten für tst_bundles (erzeugt mit tools/bundle.py, kleiner Argon2id): Code 7KQ2M-X9HDV-3TAPR-WE6YT, Schlüssel 00 01 … 1f, Klartext klar.bin. Nichts davon ist echt.

Lernpaket: `manifest-lernpaket.json` (Bundle `test-lesson`, Code EVZZG-1NQ2R-HFB8N-BY6Z3, gleicher Schlüssel 00 01 … 1f, `bundle.umhuellt(code, id, key, t=1, m=8)`), Video wieder `test.mvb`, Inhalt `inhalt.mvb` (verschlüsselt, Format 1) mit Klartext `inhalt.json`. Eine Technik mit fremdem Namensraum (`lern/other/…`) ist Absicht: die App lässt sie weg. Nichts davon ist echt.

Untertitel: `test.en.vtt.mvb` (verschlüsselt wie `inhalt.mvb`, gleicher Schlüssel) mit Klartext `test.en.vtt` (WebVTT mit Kopfzeile, NOTE, Cue-Nummer, Einstellungen, Tags, zwei Zeilen, Zeiten mit und ohne Stunden), im Manifest des Lernpakets als `untertitel` am Video. Erzeugt mit `bundle.verschluesselt`. Nichts davon ist echt.
