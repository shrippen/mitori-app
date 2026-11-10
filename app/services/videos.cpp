#include "videos.h"

#include "bundleshelf.h"
#include "decoders.h"
#include "lessons.h"

#include <QDir>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QTimer>

namespace {
constexpr auto kFolderKey = "videos/folder";
// The start is over by then (0.5 s on a desktop): the backend does not compete with it.
constexpr int kDecoderPauseMs = 2000;
}

Videos::Videos(QObject *parent)
    : Videos(Catalog::bundled(), parent)
{
}

Videos::Videos(const Catalog &catalog, QObject *parent)
    : QObject(parent)
    , m_catalog(catalog)
    , m_folder(QSettings().value(QLatin1String(kFolderKey), defaultFolder()).toString())
{
    // Videos of a bundle came or went: bindings that ask available() follow (they read folder).
    connect(&BundleShelf::notifier(), &BundleShelfNotifier::changed, this, &Videos::folderChanged);
    connect(&Decoders::shared(), &Decoders::ready, this, &Videos::decodersReadyChanged);
}

bool Videos::decodersReady() const
{
    return Decoders::shared().isReady();
}

void Videos::prepareDecoders()
{
    QTimer::singleShot(kDecoderPauseMs, &Decoders::shared(), &Decoders::prepare);
}

QString Videos::defaultFolder()
{
    const QString fromEnv = qEnvironmentVariable("MITORI_VIDEOS");
    if (!fromEnv.isEmpty()) {
        return fromEnv;
    }
    const QStringList locations = QStandardPaths::standardLocations(QStandardPaths::AppDataLocation);
    for (const QString &location : locations) {
        const QString candidate = QDir(location).filePath(QStringLiteral("videos"));
        if (QFileInfo(candidate).isDir()) {
            return candidate;
        }
    }
#ifdef Q_OS_ANDROID
    // Android lists the external files folder last: there adb can put the videos.
    return locations.isEmpty() ? QString() : QDir(locations.last()).filePath(QStringLiteral("videos"));
#else
    // The first is the user's own (the others are the system's, say /usr/share).
    return locations.isEmpty() ? QString() : QDir(locations.first()).filePath(QStringLiteral("videos"));
#endif
}

void Videos::setFolder(const QString &folder)
{
    if (folder == m_folder) {
        return;
    }
    m_folder = folder;
    QSettings().setValue(QLatin1String(kFolderKey), folder);
    emit folderChanged();
}

// A loaded bundle first, else the folder of the settings.
QString Videos::path(const QString &video) const
{
    const QString bundled = BundleShelf::shared().path(video);
    if (!bundled.isEmpty()) {
        return bundled;
    }
    const QString file = m_catalog.videos().value(video).toMap().value(QStringLiteral("datei")).toString();
    return file.isEmpty() ? QString() : QDir(m_folder).filePath(file);
}

bool Videos::available(const QString &video) const
{
    const QString p = path(video);
    return !p.isEmpty() && QFileInfo::exists(p);
}

QUrl Videos::source(const QString &video) const
{
    return available(video) ? QUrl::fromLocalFile(path(video)) : QUrl();
}

// A bundle's file is cut already: its picture is the whole frame, at the same aspect ratio. A
// video without an area gives an empty map (the player takes 16:9 and the whole frame).
QVariantMap Videos::crop(const QString &video) const
{
    QVariantMap crop = m_catalog.videos().value(video).toMap().value(QStringLiteral("beschnitt")).toMap();
    // A Lernpaket's video is not in the catalog: its picture area comes with its content.
    if (!m_catalog.videos().contains(video)) {
        crop = Lessons::shared().crop(video);
    }
    if (crop.isEmpty() || !BundleShelf::shared().cropped(video) || BundleShelf::shared().path(video).isEmpty()) {
        return crop;
    }
    return {{QStringLiteral("verhaeltnis"), crop.value(QStringLiteral("verhaeltnis"))}};
}

QVariantMap Videos::place(const QString &id, const QVariantMap &place) const
{
    const auto cut = BundleShelf::shared().cut(place.value(QStringLiteral("video")).toString(), id);
    if (!cut) {
        return place;
    }
    QVariantMap moved = place;
    moved[QStringLiteral("von")] = cut->von;
    moved[QStringLiteral("bis")] = cut->bis;
    return moved;
}
