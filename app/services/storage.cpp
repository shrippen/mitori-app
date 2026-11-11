#include "storage.h"

#include "bundleshelf.h"
#include "storageplaces.h"
#include "videomove.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QStorageInfo>

namespace {
// The folder the videos get on a card: beside what else the app may keep there one day.
const QString kCardFolder = QStringLiteral("bundles");
// The folder the videos get in a folder the user picks: the app's own, nothing else in it is touched.
const QString kPickedFolder = QStringLiteral("Mitori");
// Space kept free beyond the videos: a full card fails late and slowly.
constexpr qint64 kReserve = 200LL * 1024 * 1024;

// The nearest folder of a path that exists (a new place may not exist yet).
QString existing(const QString &path)
{
    QString p = QDir::cleanPath(path);
    while (!QFileInfo::exists(p) && QFileInfo(p).absolutePath() != p) {
        p = QFileInfo(p).absolutePath();
    }
    return p;
}

qint64 freeAt(const QString &path)
{
    return QStorageInfo(existing(path)).bytesAvailable();
}
}

Storage::Storage(QObject *parent)
    : Storage(BundleShelf::shared(), parent)
{
}

Storage::Storage(BundleShelf &shelf, QObject *parent)
    : QObject(parent)
    , m_shelf(shelf)
{
    // A bundle loaded or removed changes the free space.
    connect(&BundleShelf::notifier(), &BundleShelfNotifier::changed, this, &Storage::changed);
}

Storage::~Storage()
{
    // Leaving during a move: it stops between two pieces, the old place stays.
    m_cancel = true;
    if (m_thread) {
        m_thread->wait();
    }
}

QVariantList Storage::places() const
{
    const QString now = QDir::cleanPath(m_shelf.videoRoot());
    const auto place = [&now](const QString &path, const QString &name, Kind kind) {
        return QVariantMap{{QStringLiteral("path"), path},
                           {QStringLiteral("name"), name},
                           {QStringLiteral("kind"), QVariant::fromValue(kind)},
                           {QStringLiteral("free"), freeAt(path)},
                           {QStringLiteral("current"), QDir::cleanPath(path) == now}};
    };

    QVariantList list{place(m_shelf.root(), tr("On this device"), Kind::App)};
    bool listed = QDir::cleanPath(m_shelf.root()) == now;
    for (const StoragePlaces::Place &card : StoragePlaces::cards()) {
        const QString path = QDir(card.path).filePath(kCardFolder);
        list << place(path, card.label.isEmpty() ? tr("SD card") : card.label, Kind::Card);
        listed = listed || QDir::cleanPath(path) == now;
    }
    // A folder of one's own, or a card that is out: the place now, by its path.
    if (!listed) {
        list << place(m_shelf.videoRoot(), QDir::toNativeSeparators(m_shelf.videoRoot()), Kind::Folder);
    }
    return list;
}

QString Storage::path() const
{
    return m_shelf.videoRoot();
}

bool Storage::reachable() const
{
    // The app's own folder comes with the first bundle; any other place must be there.
    return m_shelf.videoRoot() == m_shelf.root() || QFileInfo(m_shelf.videoRoot()).isDir();
}

bool Storage::picksFolder() const
{
#ifdef Q_OS_ANDROID
    return false;
#else
    return true;
#endif
}

void Storage::moveTo(const QString &path)
{
    if (m_state == State::Moving || path.isEmpty()) {
        return;
    }
    const QString from = m_shelf.videoRoot();
    if (QDir::cleanPath(path) == QDir::cleanPath(from)) {
        return;
    }
    if (downloading()) {
        fail(tr("Videos are loading. Move them once the download is done."));
        return;
    }
    if (!reachable()) {
        abandon(path);
        return;
    }

    // The loaded bundles' folders; the others hold nothing to take along.
    QStringList folders;
    const auto bundles = m_shelf.bundles();
    for (auto it = bundles.cbegin(); it != bundles.cend(); ++it) {
        if (it->version > 0 && QFileInfo(m_shelf.folder(it.key())).isDir()) {
            folders << it.key();
        }
    }

    auto move = std::make_shared<VideoMove>(from, path, folders);
    m_total = move->total();
    if (freeAt(path) < m_total + kReserve && QStorageInfo(existing(path)).device() != QStorageInfo(existing(from)).device()) {
        fail(tr("Not enough space there: the videos need %1 MB.").arg(m_total / (1000 * 1000)));
        return;
    }

    m_state = State::Moving;
    m_error.clear();
    m_progress = 0;
    m_cancel = false;
    m_shelf.setMoving(true);
    emit changed();
    emit progressChanged();

    // The copy in a thread of its own; its progress and end come back to this one.
    m_thread.reset(QThread::create([this, move, path] {
        const VideoMove::Result result = move->run([this](qint64 done) {
            QMetaObject::invokeMethod(this, [this, done] { report(done); }, Qt::QueuedConnection);
        }, m_cancel);
        const QString why = move->errorString();
        QMetaObject::invokeMethod(this, [this, result, path, why] { finish(int(result), path, why); }, Qt::QueuedConnection);
    }));
    m_thread->start();
}

void Storage::cancel()
{
    m_cancel = true;
}

void Storage::report(qint64 done)
{
    const qreal now = m_total > 0 ? qreal(done) / qreal(m_total) : 1;
    // Each hundredth: a card copies 4 MB pieces faster than a page can draw.
    if (now - m_progress < 0.01 && now < 1) {
        return;
    }
    m_progress = now;
    emit progressChanged();
}

void Storage::finish(int result, const QString &to, const QString &why)
{
    if (m_thread) {
        m_thread->wait();
        m_thread.reset();
    }

    const auto r = VideoMove::Result(result);
    if (r == VideoMove::Result::Failed) {
        m_shelf.setMoving(false);
        fail(tr("The videos could not be moved: %1").arg(why));
        return;
    }
    m_state = State::Idle;
    if (r == VideoMove::Result::Done) {
        // The app's own folder is the default: no setting for it. Only the app's shelf is remembered.
        if (&m_shelf == &BundleShelf::shared()) {
            BundleShelf::chooseVideoRoot(QDir::cleanPath(to) == QDir::cleanPath(m_shelf.root()) ? QString() : to);
        }
        m_shelf.setVideoRoot(to);
    }
    // After the new place is set: a bundle that waited for Wi-Fi loads into it.
    m_shelf.setMoving(false);
    if (r == VideoMove::Result::Done) {
        emit moved();
    }
    emit changed();
}

void Storage::fail(const QString &why)
{
    m_state = State::Failed;
    m_error = why;
    emit changed();
}

// A download writes into <id>.part beside its bundle's folder (only the shelf's ids: a picked
// folder may hold others).
bool Storage::downloading() const
{
    const auto bundles = m_shelf.bundles();
    for (auto it = bundles.cbegin(); it != bundles.cend(); ++it) {
        if (QFileInfo(m_shelf.folder(it.key()) + QStringLiteral(".part")).isDir()) {
            return true;
        }
    }
    return false;
}

// The place is gone for good (a lost card): the new one starts empty. The bundles count as
// removed; codes and keys stay, so they load again there.
void Storage::abandon(const QString &to)
{
    // A new card's folder does not exist yet; without it the place would still count as missing.
    if (!QDir().mkpath(to)) {
        fail(tr("The videos could not be moved: %1").arg(QStringLiteral("cannot create %1").arg(to)));
        return;
    }
    const auto bundles = m_shelf.bundles();
    for (auto it = bundles.cbegin(); it != bundles.cend(); ++it) {
        if (it->version > 0) {
            m_shelf.remove(it.key());
        }
    }
    finish(int(VideoMove::Result::Done), to, {});
}

QString Storage::folderPath(const QUrl &folder) const
{
    return QDir(folder.toLocalFile()).filePath(kPickedFolder);
}
