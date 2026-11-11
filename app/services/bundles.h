#pragma once

#include <QCryptographicHash>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QObject>
#include <QPointer>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>

#include "bundlecrypto.h"
#include "bundleshelf.h"
#include "catalog.h"

class QNetworkAccessManager;
class QNetworkReply;

// The video bundles for QML (clickdummy "Videos", "Code"): the public manifest lists them; a
// DVD's code unlocks one; it loads, checks and decrypts its videos onto the device (BundleShelf).
// A new version in the manifest shows as an update. No secret is in the app: the code is the
// only one (store/bundlecrypto, tools/bundle.py).
//
// A Lernpaket (manifest key "lernpakete") is a bundle that brings its own techniques: beside the
// videos it loads `inhalt` (encrypted JSON, kept by the shelf); Lessons reads it.
//
//   manifest (network, cache) ──► bundles [{id, title, kind, version, installed, videos, size, state,
//                                           progress, hint, code}]
//   unlock(code) ─Argon2id, a moment─► unlocked(id) / failed(reason)
//   load(id) ──► Downloading … progress … Installed (or Failed, the old version stays)
class Bundles : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // Enums only as Bundles.State.Failed (two of them have Failed).
    Q_CLASSINFO("RegisterEnumClassesUnscoped", "false")
    Q_PROPERTY(QVariantList bundles READ bundles NOTIFY changed)
    Q_PROPERTY(ManifestState manifestState READ manifestState NOTIFY changed)
    Q_PROPERTY(bool unlocking READ unlocking NOTIFY changed)
    // Download only over Wi-Fi (or a cable): a setting, on by default.
    Q_PROPERTY(bool wifiOnly READ wifiOnly WRITE setWifiOnly NOTIFY changed)
    // Bytes of the loaded videos.
    Q_PROPERTY(qint64 size READ size NOTIFY changed)
    // Free on the disk that holds the videos (the storage bar), in bytes.
    Q_PROPERTY(qint64 freeSpace READ freeSpace NOTIFY changed)
    // Bundles with a newer version than the one loaded (the start menu's hint).
    Q_PROPERTY(int updates READ updates NOTIFY changed)
    Q_PROPERTY(QString errorString READ errorString NOTIFY changed)

public:
    enum class ManifestState { Empty, Loading, Ready, Failed };
    Q_ENUM(ManifestState)
    // Unsupported: a Lernpaket in a content format this version does not know (update Mitori).
    enum class State { Locked, Unlocked, Waiting, Downloading, Installed, Update, Failed, Unsupported };
    Q_ENUM(State)
    // Exam: a bundle with the videos of the programme; Lesson: a Lernpaket.
    enum class Kind { Exam, Lesson };
    Q_ENUM(Kind)
    enum class UnlockError { Invalid, Unknown, Wrong, NoManifest, Typo };
    Q_ENUM(UnlockError)
    enum class Network { WifiOnly, Any };
    Q_ENUM(Network)
    enum class Reload { Always, Older };
    Q_ENUM(Reload)

    explicit Bundles(QObject *parent = nullptr);
    // For tests: a manifest URL and a shelf folder of their own.
    Bundles(const QUrl &manifest, const QString &root, QObject *parent = nullptr);
    ~Bundles() override;

    bool eventFilter(QObject *watched, QEvent *event) override;

    QVariantList bundles() const;
    ManifestState manifestState() const { return m_manifestState; }
    bool unlocking() const { return m_unlocking; }
    bool wifiOnly() const;
    void setWifiOnly(bool on);
    qint64 size() const { return m_shelf->size(); }
    qint64 freeSpace() const;
    int updates() const;
    QString errorString() const { return m_error; }

    Q_INVOKABLE void reload(Reload when = Reload::Always);
    // Checks the code (length, check character) at once, then opens its bundle's key (Argon2id,
    // in the background): unlocked(id) or unlockFailed(reason).
    Q_INVOKABLE void unlock(const QString &code);
    // Whether a code as typed is complete and its check fits (the field's hint).
    Q_INVOKABLE bool codeValid(const QString &code) const;
    Q_INVOKABLE QString grouped(const QString &code) const;
    // Loads the newest version of an unlocked bundle; with WifiOnly and no Wi-Fi it waits (State::Waiting).
    Q_INVOKABLE void load(const QString &id, Network network = Network::WifiOnly);
    Q_INVOKABLE void cancel(const QString &id);
    // Removes a bundle's videos; its code stays, so it loads again without it.
    Q_INVOKABLE bool remove(const QString &id);

    // Whether the network now is one to load over with WifiOnly (Wi-Fi, cable, or unknown).
    static bool onWifi();

signals:
    void changed();
    void unlocked(const QString &id);
    void unlockFailed(Bundles::UnlockError reason);
    // A bundle's videos are on the device (Videos re-reads its files).
    void installed(const QString &id);

private slots:
    // The network changed: what waits for Wi-Fi loads if it is one now.
    void networkChanged();

private:
    struct Job {
        QString id;
        int version = 0;
        QJsonArray videos;          // still to load, first one now (a Lernpaket's `inhalt` first, marked)
        QJsonObject content;        // a Lernpaket's content, once loaded and checked
        QHash<QString, QString> files;
        QStringList cropped;
        BundleShelf::Cuts cuts;
        qint64 done = 0;            // bytes of the bundle's files already loaded
        qint64 total = 0;
        QPointer<QNetworkReply> reply;
        std::unique_ptr<QFile> part;
        std::unique_ptr<BundleCrypto::Decryptor> decryptor;
        QCryptographicHash sha{QCryptographicHash::Sha256};
        qint64 received = 0;
        QElapsedTimer shown;        // since the last progress report
    };

    void watchLanguage();
    void watchNetwork();
    void cleanOld(const QString &id);
    void loadCache();
    void received(QNetworkReply *reply);
    // The manifest's entry of a bundle or Lernpaket (`kind` tells which list); empty for an unknown id.
    QJsonObject manifestBundle(const QString &id, Kind *kind = nullptr) const;
    void next(Job &job);
    QString readContent(Job &job);
    void fail(const QString &id, const QString &why);
    QNetworkAccessManager *network();

    std::unique_ptr<BundleShelf> m_ownShelf;     // tests: a folder of their own
    BundleShelf *m_shelf = nullptr;             // else the shared one (Videos reads it too)
    QNetworkAccessManager *m_network = nullptr;
    QUrl m_source;
    QJsonObject m_manifest;
    QDateTime m_loaded;
    ManifestState m_manifestState = ManifestState::Empty;
    Catalog::Language m_language;               // the titles' language, as last shown
    QHash<QString, std::shared_ptr<Job>> m_jobs;
    QHash<QString, State> m_failed;     // Failed or Waiting, until the next load
    bool m_unlocking = false;
    QString m_error;
};
