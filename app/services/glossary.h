#pragma once

#include <QList>
#include <QObject>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include "catalog.h"
#include "searchkey.h"

class Speaker;

// The glossary for QML (clickdummy "Glossar & Suche"): Japanese terms with kanji, translation
// (Aiki-Budo lexicon of shinkiryu.de: German, or its English with English on) and their
// pronunciation by speech output.
class Glossary : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Every word, alphabetical: {word, jp, reading, meaning, letter, speech}. `reading` is the kana ("" without), `meaning` is the translation
    // in the app's language ("" without one), `letter` heads its section (A … Z), `speech` is what
    // the speaker button says (the kanji, else the reading in kana, else the word).
    Q_PROPERTY(QVariantList words READ words NOTIFY wordsChanged)
    Q_PROPERTY(QString source READ source NOTIFY wordsChanged)
    Q_PROPERTY(Speech speech READ speech NOTIFY speechChanged)

public:
    enum class Speech {
        Unsupported,    // this build or platform has no speech output (AppImage, Flatpak)
        Starting,
        NoVoice,        // no Japanese voice on the device
        Ready,
    };
    Q_ENUM(Speech)

    explicit Glossary(QObject *parent = nullptr);
    // For tests: another catalog and speech engine ("mock").
    Glossary(const Catalog &catalog, const QString &engine, QObject *parent = nullptr);

    QVariantList words() const { return m_words; }
    QString source() const { return m_source; }
    Speech speech() const;

    // Words whose name, kanji, reading or meaning contain every word of `query` (see
    // SearchText): "Kiriotoshi", "kiri-otoshi" and 切り落とし find the same, "Hüftwurf" finds
    // Koshi-nage ("hip throw" with English on; the meaning shown, not the other language's).
    // Rows as in words, alphabetical.
    Q_INVOKABLE QVariantList search(const QString &query) const;
    // Speaks a word's `speech` with the Japanese voice; nothing without one.
    Q_INVOKABLE void say(const QString &speech);

signals:
    void speechChanged();
    // The words in another language (a LanguageChange).
    void wordsChanged();
    // Each call of say(), with or without a voice (the UI test counts them).
    void sayRequested(const QString &speech);

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void load();

    Catalog m_catalog;
    Catalog::Language m_language;
    QVariantList m_words;
    QList<SearchText> m_texts;      // per word, what search() compares
    QString m_source;
    Speaker *m_speaker = nullptr;
};
