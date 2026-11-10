#pragma once

#include <QString>
#include <QVariant>
#include <QVariantList>

class QLocale;

// The programme data of all disciplines (mitori-daten.json, built by tools/daten.py from daten/).
// Read by services only, never by QML (agent.md, layers).
//
// The data's texts in two languages: beside a field x the data carry x_en where the English
// differs ("zusatz": "2 Arten", "zusatz_en": "2 variants"). In English every x reads as its x_en;
// ids and keys stay German. The language is the app's (Appearance sets it with its catalogs), the
// same for every Catalog; services read the texts anew on QEvent::LanguageChange.
class Catalog
{
public:
    static constexpr int kFormat = 1;  // FORMAT in tools/daten.py
    static constexpr auto kResource = ":/daten/mitori-daten.json";

    enum class Language { German, English };
    // German until Appearance sets the app's language (tests that do not).
    static Language language();
    static void setLanguage(Language language);
    // The language of a locale's texts, as the app's catalogs choose: the first of its languages
    // that has one (de, en), English (the code's) without.
    static Language languageOf(const QLocale &locale);

    // A value of other data (a Lernpaket's content) with every x replaced by its x_en, in nested
    // maps and lists too: the rule above, for the data that do not come with the catalog.
    static QVariant inEnglish(const QVariant &value);

    // The catalog in the app's resources, loaded once and shared by the services.
    static const Catalog &bundled();

    bool load(const QString &path);
    QVariantList disciplines() const;
    // Per video key ("aikido/k5"): datei (path in the video folder), beschnitt {hoehe, y, h, verhaeltnis}.
    QVariantMap videos() const { return m_videos; }
    // The glossary, alphabetical: per word wort, jp (or null), de (or ""), en (beside a de), kana
    // (its reading).
    QVariantList glossary() const;
    // Where the glossary's translations come from (the lexicon of shinkiryu.de and its date).
    QString glossarySource() const;
    // The data's release (STAND in mitori-daten), shown under "About Mitori" and on the booklet's title.
    QString dataVersion() const { return m_dataVersion; }
    QString errorString() const { return m_error; }

private:
    bool fail(const QString &error);

    // Per language (index: Language): German as the data have it, English with x_en in place of x.
    QVariantList m_disciplines[2];
    QVariantMap m_videos;
    QVariantList m_glossary[2];
    QString m_glossarySource[2];
    QString m_dataVersion;
    QString m_error;
};
