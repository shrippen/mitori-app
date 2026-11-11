#pragma once

#include <QObject>
#include <QUrl>
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

public:
    explicit Videos(QObject *parent = nullptr);
    explicit Videos(const Catalog &catalog, QObject *parent = nullptr);

    QString folder() const { return m_folder; }
    void setFolder(const QString &folder);
    bool decodersReady() const;

    // Whether the file of a video key ("aikido/k5") is on the device.
    Q_INVOKABLE bool available(const QString &video) const;
    Q_INVOKABLE QUrl source(const QString &video) const;
    // Picture area without the black bars: {hoehe, y, h, verhaeltnis} (see tools/kapitel.py).
    Q_INVOKABLE QVariantMap crop(const QString &video) const;
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

private:
    QString path(const QString &video) const;

    const Catalog &m_catalog;
    QString m_folder;
};
