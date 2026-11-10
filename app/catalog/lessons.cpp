#include "lessons.h"

#include "bundleshelf.h"

#include <QJsonObject>
#include <algorithm>

namespace {

QString text(const QVariantMap &map, const char *key)
{
    return map.value(QLatin1String(key)).toString();
}

// The attack: {"name", "jp"}, or only its name.
QVariantMap attackOf(const QVariant &value)
{
    if (value.typeId() == QMetaType::QString) {
        return {{QStringLiteral("name"), value}};
    }
    return value.toMap();
}

QVariantMap rowOf(const QVariantMap &t, const QString &package, const QString &packageTitle, const QString &section)
{
    const QVariantMap attack = attackOf(t.value(QStringLiteral("angriff")));
    QVariant video;
    if (!text(t, "video").isEmpty()) {
        video = QVariantMap{{QStringLiteral("video"), text(t, "video")},
                            {QStringLiteral("von"), t.value(QStringLiteral("von")).toDouble()},
                            {QStringLiteral("bis"), t.value(QStringLiteral("bis")).toDouble()}};
    }
    return {{QStringLiteral("kind"), QStringLiteral("entry")},
            {QStringLiteral("id"), text(t, "id")},
            {QStringLiteral("title"), text(t, "name")},
            {QStringLiteral("extra"), text(t, "zusatz")},
            {QStringLiteral("jp"), text(t, "jp")},
            {QStringLiteral("attack"), text(attack, "name")},
            {QStringLiteral("attackJp"), text(attack, "jp")},
            {QStringLiteral("text"), text(t, "text")},
            {QStringLiteral("wie"), t.value(QStringLiteral("wie")).toList()},
            {QStringLiteral("video"), video},
            {QStringLiteral("discipline"), QString::fromLatin1(Lessons::kDiscipline)},
            {QStringLiteral("package"), package},
            {QStringLiteral("disciplineName"), packageTitle},
            {QStringLiteral("gradeName"), QString()},
            {QStringLiteral("groupName"), section},
            {QStringLiteral("steps"), QVariantList()},
            {QStringLiteral("open"), false}};
}

} // namespace

Lessons &Lessons::shared()
{
    static Lessons lessons(BundleShelf::shared());
    return lessons;
}

Lessons::Lessons(const BundleShelf &shelf, QObject *parent)
    : QObject(parent)
    , m_shelf(shelf)
    , m_signalled(shelf.lessonRevision())
{
    // Any shelf saves through the one notifier: only a change of the lessons is passed on.
    connect(&BundleShelf::notifier(), &BundleShelfNotifier::changed, this, [this] {
        if (m_signalled == m_shelf.lessonRevision()) {
            return;
        }
        m_signalled = m_shelf.lessonRevision();
        emit changed();
    });
}

quint64 Lessons::revision() const
{
    return m_shelf.lessonRevision();
}

// All packages with content, installed or not: a removed package's techniques keep their labels.
void Lessons::refresh() const
{
    const Catalog::Language language = Catalog::language();
    if (m_built && m_revision == m_shelf.lessonRevision() && m_language == language) {
        return;
    }
    m_built = true;
    m_revision = m_shelf.lessonRevision();
    m_language = language;
    m_packages.clear();
    m_entries.clear();
    m_crops.clear();

    const QStringList ids = m_shelf.lessonIds();
    for (const QString &id : ids) {
        QVariantMap content = m_shelf.content(id).toVariantMap();
        if (language == Catalog::Language::English) {
            content = Catalog::inEnglish(content).toMap();
        }
        // The content of another package under this name is none of ours.
        if (text(content, "id") != id) {
            continue;
        }

        const bool installed = m_shelf.bundle(id).version > 0;
        const QString title = text(content, "titel");
        // Ids from the content must lie in the package's own namespace: no technique replaces another.
        const QString prefix = QString::fromLatin1(kPrefix) + id + QLatin1Char('/');

        Package package;
        int count = 0;
        for (const QVariant &s : content.value(QStringLiteral("abschnitte")).toList()) {
            const QVariantMap section = s.toMap();
            package.rows << QVariantMap{{QStringLiteral("kind"), QStringLiteral("group")},
                                        {QStringLiteral("title"), text(section, "titel")},
                                        {QStringLiteral("jp"), QString()},
                                        {QStringLiteral("text"), text(section, "text")}};
            for (const QVariant &v : section.value(QStringLiteral("techniken")).toList()) {
                const QVariantMap row = rowOf(v.toMap(), id, title, text(section, "titel"));
                const QString techniqueId = text(row, "id");
                if (!techniqueId.startsWith(prefix) || m_entries.contains(techniqueId)) {
                    continue;
                }
                m_entries.insert(techniqueId, row);
                package.rows << row;
                ++count;
            }
        }

        QVariantList videos;
        for (const QVariant &v : content.value(QStringLiteral("videos")).toList()) {
            const QVariantMap video = v.toMap();
            videos << QVariantMap{{QStringLiteral("video"), text(video, "id")}, {QStringLiteral("title"), text(video, "titel")}};
            const QVariantMap crop = video.value(QStringLiteral("beschnitt")).toMap();
            if (!crop.isEmpty()) {
                m_crops.insert(text(video, "id"), crop);
            }
        }

        if (!installed) {
            continue;
        }
        package.info = {{QStringLiteral("id"), id},
                        {QStringLiteral("title"), title},
                        {QStringLiteral("text"), text(content, "text")},
                        {QStringLiteral("sparte"), text(content, "sparte")},
                        {QStringLiteral("count"), count},
                        {QStringLiteral("videos"), videos}};
        m_packages << package;
    }

    std::stable_sort(m_packages.begin(), m_packages.end(), [](const Package &a, const Package &b) {
        return QString::localeAwareCompare(text(a.info, "title"), text(b.info, "title")) < 0;
    });
}

QVariantList Lessons::packages() const
{
    refresh();
    QVariantList result;
    for (const Package &p : std::as_const(m_packages)) {
        result << p.info;
    }
    return result;
}

QVariantList Lessons::rows(const QString &package) const
{
    refresh();
    for (const Package &p : std::as_const(m_packages)) {
        if (text(p.info, "id") == package) {
            return p.rows;
        }
    }
    return {};
}

QVariantMap Lessons::entry(const QString &id) const
{
    refresh();
    return m_entries.value(id);
}

QVariantMap Lessons::crop(const QString &video) const
{
    refresh();
    return m_crops.value(video);
}
