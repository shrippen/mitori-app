#include "glossary.h"

#include <QCoreApplication>
#include <QEvent>

#include "speaker.h"

namespace {

// The section a word stands in: its first letter without accents (Ô-dachi under O).
QString letter(const QString &word)
{
    const QString key = searchKey(word);
    return key.isEmpty() || !key.front().isLetter() ? QStringLiteral("#") : key.left(1).toUpper();
}

// What the speaker says: the kanji, else the reading in kana, else the word itself.
QString speechText(const QString &word, const QString &jp, const QString &kana)
{
    if (!jp.isEmpty()) {
        return jp;
    }
    return kana.isEmpty() ? word : kana;
}

} // namespace

// MITORI_SPEECH_ENGINE picks a speech engine by name (the UI test: "mock"), as MITORI_VIDEOS the videos.
Glossary::Glossary(QObject *parent)
    : Glossary(Catalog::bundled(), qEnvironmentVariable("MITORI_SPEECH_ENGINE"), parent)
{
}

Glossary::Glossary(const Catalog &catalog, const QString &engine, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_language(Catalog::language())
    , m_speaker(new Speaker(engine, this))
{
    load();
    connect(m_speaker, &Speaker::stateChanged, this, &Glossary::speechChanged);
    // A new catalog (Appearance::setLanguage) may bring the data's other language.
    if (auto *app = QCoreApplication::instance()) {
        app->installEventFilter(this);
    }
}

bool Glossary::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::LanguageChange && watched == QCoreApplication::instance()
        && m_language != Catalog::language()) {
        m_language = Catalog::language();
        load();
        emit wordsChanged();
    }
    return QObject::eventFilter(watched, event);
}

// From the catalog's fields (tools/daten.py) to the rows QML shows, in the catalog's language:
// the meaning is `en` with English on (`de` where the lexicon has no English), else `de`.
void Glossary::load()
{
    m_words.clear();
    m_texts.clear();
    m_source = m_catalog.glossarySource();
    const bool english = m_language == Catalog::Language::English;
    for (const QVariant &w : m_catalog.glossary()) {
        const QVariantMap entry = w.toMap();
        const QString word = entry.value(QStringLiteral("wort")).toString();
        const QString jp = entry.value(QStringLiteral("jp")).toString();
        const QString de = entry.value(QStringLiteral("de")).toString();
        const QString en = entry.value(QStringLiteral("en")).toString();
        const QString meaning = english && !en.isEmpty() ? en : de;
        const QString kana = entry.value(QStringLiteral("kana")).toString();
        m_words << QVariantMap{{QStringLiteral("word"), word},
                               {QStringLiteral("jp"), jp},
                               {QStringLiteral("meaning"), meaning},
                               {QStringLiteral("reading"), kana},
                               {QStringLiteral("letter"), letter(word)},
                               {QStringLiteral("speech"), speechText(word, jp, kana)}};
        m_texts << SearchText(QStringList{word, jp, kana, meaning}.join(u' '));
    }
}

Glossary::Speech Glossary::speech() const
{
    switch (m_speaker->state()) {
    case Speaker::State::Unsupported:
        return Speech::Unsupported;
    case Speaker::State::Starting:
        return Speech::Starting;
    case Speaker::State::NoVoice:
        return Speech::NoVoice;
    case Speaker::State::Ready:
        return Speech::Ready;
    }
    return Speech::Unsupported;
}

QVariantList Glossary::search(const QString &query) const
{
    QVariantList result;
    const QStringList words = searchWords(query);
    if (words.isEmpty()) {
        return result;
    }
    for (qsizetype i = 0; i < m_words.size(); ++i) {
        if (m_texts.at(i).matches(words)) {
            result << m_words.at(i);
        }
    }
    return result;
}

void Glossary::say(const QString &speech)
{
    emit sayRequested(speech);
    m_speaker->say(speech);
}
