#include "catalog.h"

#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocale>

namespace {

constexpr QLatin1StringView kEnglishSuffix("_en");
constexpr QLatin1StringView kGerman("de");
constexpr QLatin1StringView kEnglish("en");

Catalog::Language g_language = Catalog::Language::German;

int at(Catalog::Language language) { return int(language); }

// A value with every field x replaced by its x_en, in nested maps and lists too:
//   {"name": "5. Kyu", "name_en": "5th Kyu"}  →  {"name": "5th Kyu", "name_en": "5th Kyu"}
QVariant english(const QVariant &value)
{
    if (value.typeId() == QMetaType::QVariantList) {
        QVariantList list = value.toList();
        for (QVariant &item : list) {
            item = english(item);
        }
        return list;
    }
    if (value.typeId() != QMetaType::QVariantMap) {
        return value;
    }

    QVariantMap map = value.toMap();
    for (auto it = map.begin(); it != map.end(); ++it) {
        it.value() = english(it.value());
    }
    const QStringList keys = map.keys();
    for (const QString &key : keys) {
        if (key.endsWith(kEnglishSuffix)) {
            map.insert(key.chopped(kEnglishSuffix.size()), map.value(key));
        }
    }
    return map;
}

} // namespace

Catalog::Language Catalog::language()
{
    return g_language;
}

void Catalog::setLanguage(Language language)
{
    g_language = language;
}

Catalog::Language Catalog::languageOf(const QLocale &locale)
{
    // As QTranslator::load(locale, …) looks for mitori_de and mitori_en: "de-CH" finds mitori_de.
    for (const QString &name : locale.uiLanguages()) {
        if (name.startsWith(kGerman)) {
            return Language::German;
        }
        if (name.startsWith(kEnglish)) {
            return Language::English;
        }
    }
    return Language::English;
}

QVariant Catalog::inEnglish(const QVariant &value)
{
    return english(value);
}

const Catalog &Catalog::bundled()
{
    static const Catalog catalog = [] {
        Catalog c;
        c.load(QString::fromLatin1(kResource));
        return c;
    }();
    return catalog;
}

QVariantList Catalog::disciplines() const
{
    return m_disciplines[at(g_language)];
}

QVariantList Catalog::glossary() const
{
    return m_glossary[at(g_language)];
}

QString Catalog::glossarySource() const
{
    return m_glossarySource[at(g_language)];
}

bool Catalog::load(const QString &path)
{
    for (const Language language : {Language::German, Language::English}) {
        m_disciplines[at(language)].clear();
        m_glossary[at(language)].clear();
        m_glossarySource[at(language)].clear();
    }
    m_videos.clear();
    m_dataVersion.clear();
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return fail(QStringLiteral("%1: %2").arg(path, file.errorString()));
    }
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (doc.isNull()) {
        return fail(QStringLiteral("%1: %2").arg(path, parseError.errorString()));
    }
    const QJsonObject root = doc.object();
    const int format = root.value(QLatin1String("format")).toInt();
    if (format != kFormat) {
        return fail(QStringLiteral("%1: format %2, expected %3").arg(path).arg(format).arg(kFormat));
    }
    const QJsonArray disciplines = root.value(QLatin1String("disziplinen")).toArray();
    if (disciplines.isEmpty()) {
        return fail(QStringLiteral("%1: no disciplines").arg(path));
    }
    const QString dataVersion = root.value(QLatin1String("stand")).toString();
    if (dataVersion.isEmpty()) {
        return fail(QStringLiteral("%1: no data version").arg(path));
    }
    m_dataVersion = dataVersion;
    m_videos = root.value(QLatin1String("videos")).toObject().toVariantMap();

    // Both languages at once: a change of language is a lookup, not a walk through the data.
    const QVariantMap glossary = root.value(QLatin1String("glossar")).toObject().toVariantMap();
    const QVariantMap glossaryEnglish = english(glossary).toMap();
    const QString words = QStringLiteral("woerter");
    const QString source = QStringLiteral("quelle");
    m_disciplines[at(Language::German)] = disciplines.toVariantList();
    m_disciplines[at(Language::English)] = english(m_disciplines[at(Language::German)]).toList();
    m_glossary[at(Language::German)] = glossary.value(words).toList();
    m_glossary[at(Language::English)] = glossaryEnglish.value(words).toList();
    m_glossarySource[at(Language::German)] = glossary.value(source).toString();
    m_glossarySource[at(Language::English)] = glossaryEnglish.value(source).toString();
    m_error.clear();
    return true;
}

bool Catalog::fail(const QString &error)
{
    m_error = error;
    return false;
}
