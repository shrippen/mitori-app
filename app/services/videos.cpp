#include "videos.h"

#include "bundleshelf.h"
#include "decoders.h"
#include "lessons.h"

#include <algorithm>

#include <QDir>
#include <QLocale>
#include <QFileInfo>
#include <QSettings>
#include <QTimer>

namespace {
// The folder setting of 0.3 and before (own DVD files): gone, see videos.h.
constexpr auto kOldFolderKey = "videos/folder";
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
    , m_folder(defaultFolder())
{
    QSettings().remove(QLatin1String(kOldFolderKey));
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
    return qEnvironmentVariable("MITORI_VIDEOS");
}

void Videos::setFolder(const QString &folder)
{
    if (folder == m_folder) {
        return;
    }
    m_folder = folder;
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
    return file.isEmpty() || m_folder.isEmpty() ? QString() : QDir(m_folder).filePath(file);
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

QVariantList Videos::subtitles(const QString &video) const
{
    QVariantList tracks;
    const QMap<QString, QString> found = BundleShelf::shared().subtitles(video);
    for (auto it = found.cbegin(); it != found.cend(); ++it) {
        tracks << QVariantMap{{QStringLiteral("language"), it.key()}, {QStringLiteral("source"), QUrl::fromLocalFile(it.value())}};
    }
    return tracks;
}

QString Videos::subtitleLanguage(const QString &video) const
{
    const QList<QString> languages = BundleShelf::shared().subtitles(video).keys();
    if (!m_subtitlesOn || languages.isEmpty()) {
        return {};
    }
    if (languages.contains(m_subtitleChoice)) {
        return m_subtitleChoice;
    }

    // The app's language: "de" matches "de_CH" as well.
    const auto same = std::find_if(languages.cbegin(), languages.cend(),
                                   [](const QString &code) { return QLocale(code).language() == QLocale().language(); });
    return same != languages.cend() ? *same : languages.first();
}

void Videos::showSubtitles()
{
    chooseSubtitles({});
}

void Videos::chooseSubtitles(const QString &language)
{
    if (m_subtitlesOn && m_subtitleChoice == language) {
        return;
    }
    m_subtitlesOn = true;
    m_subtitleChoice = language;
    emit subtitleChoiceChanged();
}

void Videos::hideSubtitles()
{
    if (!m_subtitlesOn) {
        return;
    }
    m_subtitlesOn = false;
    emit subtitleChoiceChanged();
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
