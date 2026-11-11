#pragma once

#include <QObject>
#include <QThread>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>

#include <atomic>
#include <memory>

class BundleShelf;

// Where the loaded videos lie, for QML (the videos page): the app's own data folder, a card
// (Android), or a folder "Mitori" in a folder the user picks (Linux). A new place takes the videos along (VideoMove,
// in a thread of its own); while they move nothing loads. Codes, keys and contents stay in the
// app's data (BundleShelf).
//
//   moveTo(path) ── no download running, room enough ──► Moving … progress … Idle at the new place
//                                                    └─► Failed (errorString), the old place stays
//                └─ the old place is gone ──► Idle at the new place, the bundles removed (codes stay)
class Storage : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    // [{path, name, kind, free, current}]: the app's folder, the cards, and a folder chosen before.
    Q_PROPERTY(QVariantList places READ places NOTIFY changed)
    // The videos' place now, and whether it is there (a card may be out).
    Q_PROPERTY(QString path READ path NOTIFY changed)
    Q_PROPERTY(bool reachable READ reachable NOTIFY changed)
    // A folder of one's own over the system's folder dialog (Linux); on Android only the places.
    Q_PROPERTY(bool picksFolder READ picksFolder CONSTANT)
    Q_PROPERTY(State state READ state NOTIFY changed)
    Q_PROPERTY(qreal progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString errorString READ errorString NOTIFY changed)

public:
    enum class Kind { App, Card, Folder };
    Q_ENUM(Kind)
    enum class State { Idle, Moving, Failed };
    Q_ENUM(State)

    explicit Storage(QObject *parent = nullptr);
    // For tests: a shelf of their own.
    explicit Storage(BundleShelf &shelf, QObject *parent = nullptr);
    ~Storage() override;

    QVariantList places() const;
    QString path() const;
    bool reachable() const;
    bool picksFolder() const;
    State state() const { return m_state; }
    qreal progress() const { return m_progress; }
    QString errorString() const { return m_error; }

    // Moves the videos to `path` (one of places, or a folder the user picked).
    Q_INVOKABLE void moveTo(const QString &path);
    // Where the videos go in the folder the dialog answered: a folder "Mitori" in it.
    Q_INVOKABLE QString folderPath(const QUrl &folder) const;
    Q_INVOKABLE void cancel();

signals:
    void changed();
    void progressChanged();
    // The videos lie at the new place.
    void moved();

private:
    void fail(const QString &why);
    void finish(int result, const QString &to, const QString &why);
    void report(qint64 done);
    void abandon(const QString &to);
    bool downloading() const;

    BundleShelf &m_shelf;
    std::unique_ptr<QThread> m_thread;
    std::atomic_bool m_cancel = false;
    qint64 m_total = 0;
    State m_state = State::Idle;
    qreal m_progress = 0;
    QString m_error;
};
