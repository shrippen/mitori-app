#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include "catalog.h"

// The videos on this device: those of the loaded bundles (BundleShelf). Only for development and
// the UI test also a folder with the layout of "Mitori Videos" (Aikido/5. Kyu.mkv …), from
// MITORI_VIDEOS: one's own files rarely fit the bundles' cut points, so users get no such folder.
class Videos : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // MITORI_VIDEOS, or "" (tests set another). Bindings that ask available() read it: its signal
    // also says that a bundle's videos came or went.
    Q_PROPERTY(QString folder READ folder WRITE setFolder NOTIFY folderChanged)
    // The video decoders are tried (prepareDecoders()).
    Q_PROPERTY(bool decodersReady READ decodersReady NOTIFY decodersReadyChanged)
    // The user's subtitle choice for the rest of the run, over all videos: on or off, and a language
    // ("" = none chosen: subtitleLanguage() decides). Not saved.
    Q_PROPERTY(bool subtitlesOn READ subtitlesOn NOTIFY subtitleChoiceChanged)
    Q_PROPERTY(QString subtitleChoice READ subtitleChoice NOTIFY subtitleChoiceChanged)
    // The subtitles' size, saved (Settings → Videos), and its factor on the size the player gives
    // them from the picture's height.
    Q_PROPERTY(SubtitleSize subtitleSize READ subtitleSize WRITE setSubtitleSize NOTIFY subtitleSizeChanged)
    Q_PROPERTY(qreal subtitleScale READ subtitleScale NOTIFY subtitleSizeChanged)

public:
    enum class SubtitleSize { Small, Normal, Large, Huge };
    Q_ENUM(SubtitleSize)

    explicit Videos(QObject *parent = nullptr);
    explicit Videos(const Catalog &catalog, QObject *parent = nullptr);

    QString folder() const { return m_folder; }
    void setFolder(const QString &folder);
    bool decodersReady() const;
    bool subtitlesOn() const { return m_subtitlesOn; }
    QString subtitleChoice() const { return m_subtitleChoice; }
    SubtitleSize subtitleSize() const;
    void setSubtitleSize(SubtitleSize size);
    qreal subtitleScale() const;

    // Whether the file of a video key ("aikido/k5") is on the device.
    Q_INVOKABLE bool available(const QString &video) const;
    Q_INVOKABLE QUrl source(const QString &video) const;
    // Picture area without the black bars: {hoehe, y, h, verhaeltnis} (see tools/kapitel.py).
    Q_INVOKABLE QVariantMap crop(const QString &video) const;
    // The subtitle tracks of a loaded bundle's video: [{language, name, source}], `name` the
    // language's own name without a region ("English"), `source` a file URL for SubtitleTrack;
    // empty without a loaded bundle or tracks.
    Q_INVOKABLE QVariantList subtitles(const QString &video) const;
    // The language of the track a video shows: the chosen one if the video has it, else the app's
    // language if it has, else the first track. "" when subtitles are off or the video has none.
    Q_INVOKABLE QString subtitleLanguage(const QString &video) const;
    // On, with the default track.
    Q_INVOKABLE void showSubtitles();
    // On, with this language (a video without it falls back to the default track).
    Q_INVOKABLE void chooseSubtitles(const QString &language);
    Q_INVOKABLE void hideSubtitles();
    // Where technique `id` lies in the file: a loaded bundle's cut point (it fits that file), else
    // `place` as is, the row's {video, von, bis} from the catalog.
    Q_INVOKABLE QVariantMap place(const QString &id, const QVariantMap &place) const;

    Q_INVOKABLE static QString defaultFolder();

    // After the start: the video decoders are tried in the background (Decoders), not when the
    // first video opens (a second with some GPUs).
    Q_INVOKABLE void prepareDecoders();

signals:
    void folderChanged();
    void decodersReadyChanged();
    void subtitleChoiceChanged();
    void subtitleSizeChanged();

private:
    QString path(const QString &video) const;

    const Catalog &m_catalog;
    QString m_folder;
    bool m_subtitlesOn = true;
    QString m_subtitleChoice;
};
