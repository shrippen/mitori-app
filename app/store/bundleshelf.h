#pragma once

#include <QByteArray>
#include <QHash>
#include <QJsonObject>
#include <QMap>
#include <QObject>
#include <QString>
#include <QStringList>

#include <optional>

// The video bundles on this device: shelf.json with what belongs to each, and one folder per bundle
// with its decrypted videos. A removed bundle keeps its code and key, so it loads again without the
// code (also when the code was blocked since). The videos may lie elsewhere (videoRoot: an SD card,
// a folder the user chose); codes, keys and contents always stay in the app's own data (root).
//
//   <root>/shelf.json                 {"aikido-kyu": {"code", "key", "version", "videos": {"aikido/k5":
//   <videoRoot>/aikido-kyu/aikido-k5.v2.mkv            {"file", "cropped", "cuts": {"<technique>": [von, bis]}}}}}
//   a video's subtitles ("untertitel": {"en": "aikido-k5.v2.mkv.en.vtt"}) are in its entry beside "file",
//   decrypted WebVTT in the same folder; old shelves without the key load as before.
//   <root>/manifest.json              the manifest as last loaded (Bundles)
//   <root>/shirakawa-1.inhalt.json    a Lernpaket's content (its techniques, tools/paket.py): the bundle
//                                     "has content", that is what makes it a lesson (no extra field in
//                                     shelf.json). Beside the folder, so remove() keeps it: notes and
//                                     ratings of its techniques keep their names.
// Tells the users of the shared shelf that bundles came or went (Videos re-reads its files).
class BundleShelfNotifier : public QObject
{
    Q_OBJECT
signals:
    void changed();
};

class BundleShelf
{
public:
    // The shelf in the app's data folder, one for the app (Bundles and Videos).
    static BundleShelf &shared();
    static BundleShelfNotifier &notifier();

    // Where a technique lies in a video's file, in seconds.
    struct Cut {
        double von = 0;
        double bis = 0;
    };
    using Cuts = QHash<QString, QHash<QString, Cut>>;   // video key → technique id → its place
    using Subtitles = QHash<QString, QMap<QString, QString>>;   // video key → language → file name in the folder

    struct Bundle {
        QString code;               // as the user typed it, normalised
        QByteArray key;             // the content key (from the code)
        int version = 0;            // installed version, 0 when not loaded (or removed)
        QHash<QString, QString> files;      // video key → file name in the bundle's folder
        QStringList cropped;        // the videos whose files are cropped (no black bars)
        Cuts cuts;                  // from the manifest of the loaded version, so they fit its files
        Subtitles subtitles;        // the videos' WebVTT tracks of the loaded version
    };

    // Without a videoRoot the videos lie in root, as before there was a choice.
    explicit BundleShelf(const QString &root, const QString &videoRoot = {});

    QString root() const { return m_root; }
    // Where the bundles' folders lie. A move (Storage) copies them first, then sets the new place.
    QString videoRoot() const { return m_videoRoot; }
    void setVideoRoot(const QString &videoRoot);
    // While the videos move, nothing may load or remove (Bundles asks). The end of a move tells
    // the notifier: what waited (Bundles) goes on.
    bool moving() const { return m_moving; }
    void setMoving(bool moving);
    // The shelf's bundles by id (unlocked ones, loaded or not).
    QHash<QString, Bundle> bundles() const { return m_bundles; }
    Bundle bundle(const QString &id) const { return m_bundles.value(id); }

    // Keeps the code and key of a bundle (unlocked, not loaded yet); false when it cannot be saved
    // or the id is not valid (as for installed and remove).
    bool unlock(const QString &id, const QString &code, const QByteArray &key);
    // A loaded version: its files (in folder(id)), which are cropped, and the techniques' places.
    // `content` (a Lernpaket's) is kept as <id>.inhalt.json; empty keeps what is there. `subtitles`
    // are files in folder(id) too.
    bool installed(const QString &id, int version, const QHash<QString, QString> &files, const QStringList &cropped,
                   const Cuts &cuts, const QJsonObject &content = {}, const Subtitles &subtitles = {});
    // The bundle's files go; code and key stay (and its content).
    bool remove(const QString &id);

    // A bundle's folder; only for a valid id.
    QString folder(const QString &id) const;
    // Whether an id (from the manifest) can name a folder: "aikido-kyu", not "..", "/x" or "a/b".
    static bool validId(const QString &id);
    // The file of a video from a loaded bundle, or "".
    QString path(const QString &video) const;
    bool cropped(const QString &video) const;
    // The subtitle tracks of a loaded video: language → path of the WebVTT file (those that exist).
    QMap<QString, QString> subtitles(const QString &video) const;
    // A technique's place in the file path(video) gives, if the bundle names one.
    std::optional<Cut> cut(const QString &video, const QString &id) const;
    // A Lernpaket's content, also after remove(); empty for a bundle without.
    QJsonObject content(const QString &id) const { return m_content.value(id); }
    // The ids of the bundles that have content (installed or removed).
    QStringList lessonIds() const { return m_content.keys(); }
    // Grows when a lesson's content or installed state changes (not for every save): Lessons reads anew.
    quint64 lessonRevision() const { return m_lessonRevision; }
    // Bytes of all loaded videos.
    qint64 size() const;

    // The default place: "bundles" in the app's data folder.
    static QString defaultRoot();
    // The videos' place the user chose (Storage), or "" for root.
    static QString chosenVideoRoot();
    static void chooseVideoRoot(const QString &videoRoot);

private:
    void load();
    bool save() const;

    QString contentPath(const QString &id) const;
    void restoreContent(const QString &id, const std::optional<QJsonObject> &content);

    QString m_root;
    QString m_videoRoot;
    bool m_moving = false;
    QHash<QString, Bundle> m_bundles;
    QHash<QString, QJsonObject> m_content;
    quint64 m_lessonRevision = 0;
};
