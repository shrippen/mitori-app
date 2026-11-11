#include "library.h"

#include "bundleshelf.h"
#include "lessons.h"

#include <QCoreApplication>
#include <QEvent>

Library::Library(QObject *parent)
    : Library(Lessons::shared(), BundleShelf::shared(), parent)
{
}

Library::Library(const Lessons &lessons, const BundleShelf &shelf, QObject *parent)
    : QObject(parent)
    , m_lessons(lessons)
    , m_shelf(shelf)
{
    connect(&lessons, &Lessons::changed, this, &Library::changed);
    // The packages' texts follow the language.
    if (auto *app = QCoreApplication::instance()) {
        app->installEventFilter(this);
    }
}

bool Library::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::LanguageChange && watched == QCoreApplication::instance()) {
        emit changed();
    }
    return QObject::eventFilter(watched, event);
}

QVariantList Library::packages() const
{
    return m_lessons.packages();
}

QVariantList Library::rows(const QString &package) const
{
    return m_lessons.rows(package);
}

QVariantList Library::related(const QString &programmeId) const
{
    return m_lessons.related(programmeId);
}

QVariantMap Library::around(const QString &id) const
{
    const QVariantMap entry = m_lessons.entry(id);
    if (entry.isEmpty()) {
        return {{QStringLiteral("playlist"), QVariantList()}, {QStringLiteral("index"), -1}};
    }

    // Playable: its video's file is on the shelf (what Videos::available() asks for a bundle's video).
    const auto playable = [this](const QVariantMap &row) {
        const QString video = row.value(QStringLiteral("video")).toMap().value(QStringLiteral("video")).toString();
        return row.value(QStringLiteral("kind")) == QLatin1String("entry") && !video.isEmpty() && !m_shelf.path(video).isEmpty();
    };
    QVariantList playlist;
    int index = -1;
    for (const QVariant &v : m_lessons.rows(entry.value(QStringLiteral("package")).toString())) {
        const QVariantMap row = v.toMap();
        if (!playable(row)) {
            continue;
        }
        if (row.value(QStringLiteral("id")) == entry.value(QStringLiteral("id"))) {
            index = int(playlist.size());
        }
        playlist << row;
    }
    if (index < 0) {
        return {{QStringLiteral("playlist"), QVariantList{entry}}, {QStringLiteral("index"), 0}};
    }
    return {{QStringLiteral("playlist"), playlist}, {QStringLiteral("index"), index}};
}
