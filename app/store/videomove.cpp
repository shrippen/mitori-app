#include "videomove.h"

#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QStorageInfo>

namespace {
constexpr qint64 kPiece = 4 * 1024 * 1024;

// The nearest folder of a path that exists (a new place may not exist yet).
QString existing(const QString &path)
{
    QString p = QDir::cleanPath(path);
    while (!QFileInfo::exists(p) && QFileInfo(p).absolutePath() != p) {
        p = QFileInfo(p).absolutePath();
    }
    return p;
}
}

VideoMove::VideoMove(const QString &from, const QString &to, const QStringList &folders, Way way)
    : m_from(from)
    , m_to(to)
    , m_folders(folders)
    , m_way(way)
{
}

qint64 VideoMove::total() const
{
    qint64 bytes = 0;
    for (const QString &name : m_folders) {
        QDirIterator it(QDir(m_from).filePath(name), QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            bytes += it.nextFileInfo().size();
        }
    }
    return bytes;
}

VideoMove::Result VideoMove::run(const std::function<void(qint64)> &progress, const std::atomic_bool &cancel)
{
    if (!QDir().mkpath(m_to)) {
        m_error = QStringLiteral("cannot create %1").arg(m_to);
        return Result::Failed;
    }

    // A folder of the same name in the new place would mix two versions.
    for (const QString &name : m_folders) {
        const QDir target(QDir(m_to).filePath(name));
        if (target.exists() && !target.isEmpty()) {
            m_error = QStringLiteral("%1 exists already").arg(target.path());
            return Result::Failed;
        }
    }

    return m_way == Way::Auto && sameDisk() ? rename() : copy(progress, cancel);
}

bool VideoMove::sameDisk() const
{
    return QStorageInfo(existing(m_from)).device() == QStorageInfo(existing(m_to)).device();
}

// The same disk: a rename each, at once. One that fails puts the others back.
VideoMove::Result VideoMove::rename()
{
    QStringList moved;
    for (const QString &name : m_folders) {
        const QString target = QDir(m_to).filePath(name);
        QDir(target).removeRecursively();      // empty, see run()
        if (!QDir().rename(QDir(m_from).filePath(name), target)) {
            for (const QString &back : moved) {
                QDir().rename(QDir(m_to).filePath(back), QDir(m_from).filePath(back));
            }
            m_error = QStringLiteral("cannot move %1").arg(name);
            return Result::Failed;
        }
        moved << name;
    }
    return Result::Done;
}

// Another disk: every file, then the old folders.
VideoMove::Result VideoMove::copy(const std::function<void(qint64)> &progress, const std::atomic_bool &cancel)
{
    qint64 done = 0;
    for (const QString &name : m_folders) {
        const QDir source(QDir(m_from).filePath(name));
        QDirIterator it(source.path(), QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString file = it.next();
            const QString target = QDir(QDir(m_to).filePath(name)).filePath(source.relativeFilePath(file));
            if (!copyFile(file, target, done, progress, cancel)) {
                undo();
                return m_cancelled ? Result::Cancelled : Result::Failed;
            }
        }
    }

    for (const QString &name : m_folders) {
        QDir(QDir(m_from).filePath(name)).removeRecursively();
    }
    return Result::Done;
}

bool VideoMove::copyFile(const QString &source, const QString &target, qint64 &done,
                         const std::function<void(qint64)> &progress, const std::atomic_bool &cancel)
{
    QDir().mkpath(QFileInfo(target).absolutePath());
    QFile in(source);
    QFile out(target);
    if (!in.open(QIODevice::ReadOnly)) {
        m_error = in.errorString();
        return false;
    }
    if (!out.open(QIODevice::WriteOnly)) {
        m_error = out.errorString();
        return false;
    }

    while (!in.atEnd()) {
        if (cancel) {
            m_cancelled = true;
            return false;
        }
        const QByteArray piece = in.read(kPiece);
        if (piece.isEmpty() && in.error() != QFileDevice::NoError) {
            m_error = in.errorString();
            return false;
        }
        if (out.write(piece) != piece.size()) {
            m_error = out.errorString();
            return false;
        }
        done += piece.size();
        progress(done);
    }

    // On a card a full disk often shows only here.
    if (!out.flush()) {
        m_error = out.errorString();
        return false;
    }
    out.close();
    if (out.error() != QFileDevice::NoError) {
        m_error = out.errorString();
        return false;
    }
    return true;
}

// What was copied goes; the old place stays as it was.
void VideoMove::undo()
{
    for (const QString &name : m_folders) {
        QDir(QDir(m_to).filePath(name)).removeRecursively();
    }
}
