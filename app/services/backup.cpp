#include "backup.h"

#include "backuparchive.h"
#include "coursebook.h"
#include "courses.h"
#include "device.h"
#include "practice.h"
#include "practicelog.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>
#include <QStandardPaths>

namespace {

const QString kInspected = QStringLiteral("eingelesen.zip");
const QString kCopyPrefix = QStringLiteral("kopie-");

// {added, changed, edited, removed, holds, lost} of one table for QML.
QVariantMap counts(const TableMerge::Result &r, const QString &table)
{
    return {{QStringLiteral("added"), r.added.value(table)},
            {QStringLiteral("changed"), r.changed.value(table)},
            {QStringLiteral("edited"), r.edited.value(table)},
            {QStringLiteral("removed"), r.removed.value(table)},
            {QStringLiteral("holds"), r.holds.value(table)},
            {QStringLiteral("lost"), r.lost.value(table)}};
}

QSet<QString> nameSet(const QStringList &names)
{
    return QSet<QString>(names.cbegin(), names.cend());
}

} // namespace

Backup::Backup(QObject *parent)
    : Backup(Practice::defaultPath(), Courses::defaultPath(), MediaStore::defaultRoot(),
             QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/sicherung"), parent)
{
}

Backup::Backup(const QString &practice, const QString &courses, const QString &media, const QString &work,
               QObject *parent)
    : QObject(parent)
    , m_practice(practice)
    , m_courses(courses)
    , m_media(media)
    , m_work(work)
{
}

Backup::~Backup()
{
    discard();
}

bool Backup::setError(const QString &error)
{
    if (m_error != error) {
        m_error = error;
        emit errorChanged();
    }
    return error.isEmpty();
}

QString Backup::fileName() const
{
    return QStringLiteral("mitori-sicherung-%1.zip").arg(QDate::currentDate().toString(Qt::ISODate));
}

bool Backup::save(const QUrl &target)
{
    // Consistent copies of both databases first (VACUUM INTO), then the archive.
    QDir().mkpath(m_work);
    const QString practice = QDir(m_work).filePath(kCopyPrefix + BackupArchive::kPractice);
    const QString courses = QDir(m_work).filePath(kCopyPrefix + BackupArchive::kCourses);
    QFile::remove(practice);
    QFile::remove(courses);
    QString why;
    {
        PracticeLog log;
        CourseBook book;
        if (!log.open(m_practice) || !log.snapshot(practice)) {
            why = log.errorString();
        } else if (!book.open(m_courses) || !book.snapshot(courses)) {
            why = book.errorString();
        }
    }

    // A local file, or a content:// URL from Android's file picker (QFile opens both there). The
    // suffix comes from SavePlace, with the dialog that needs it; this is the file to write.
    const QString path = target.isLocalFile() ? target.toLocalFile() : target.toString();
    m_savedTo = target.isLocalFile() ? path : QString();
    QFile file(path);
    bool opened = false;
    if (why.isEmpty()) {
        opened = file.open(QIODevice::WriteOnly | QIODevice::Truncate);
        const BackupArchive::Manifest manifest{BackupArchive::kFormat, QCoreApplication::applicationVersion(),
                                               QDateTime::currentDateTimeUtc(), deviceId()};
        if (!opened || !BackupArchive::write(&file, practice, courses, m_media, manifest, &why) || !file.flush()) {
            why = why.isEmpty() ? file.errorString() : why;
        }
        file.close();
        if (why.isEmpty() && file.error() != QFileDevice::NoError) {
            why = file.errorString();
        }
    }
    QFile::remove(practice);
    QFile::remove(courses);
    if (why.isEmpty()) {
        return setError({});
    }

    // Only a file this backup truncated: no broken archive that looks like a backup.
    if (opened && target.isLocalFile() && QFileInfo(file).isFile()) {
        file.remove();
    }
    return setError(tr("The backup could not be saved: %1").arg(why));
}

QVariantMap Backup::inspect(const QUrl &source)
{
    discard();
    QDir().mkpath(m_work);

    // A copy in the work folder: restore() reads it again, also when the picked file is gone.
    QFile in(source.isLocalFile() ? source.toLocalFile() : source.toString());
    QFile copy(QDir(m_work).filePath(kInspected));
    bool ok = in.open(QIODevice::ReadOnly) && copy.open(QIODevice::WriteOnly | QIODevice::Truncate);
    const QByteArray data = ok ? in.readAll() : QByteArray();
    ok = ok && in.error() == QFileDevice::NoError && copy.write(data) == data.size() && copy.flush();
    const QString why = in.isOpen() ? copy.errorString() : in.errorString();
    copy.close();
    if (!ok) {
        setError(tr("The backup could not be read: %1").arg(why));
        discard();
        return {};
    }

    QVariantMap summary;
    m_inspected = merge(Step::Preview, &summary);
    if (!m_inspected) {
        discard();
        return {};
    }
    return summary;
}

bool Backup::restore()
{
    if (!m_inspected) {
        return false;
    }
    QVariantMap summary;
    const bool ok = merge(Step::Apply, &summary);
    discard();
    if (ok) {
        emit restored();
    }
    return ok;
}

bool Backup::replace()
{
    if (!m_inspected) {
        return false;
    }
    const bool ok = swapIn();
    discard();
    if (ok) {
        emit restored();
    }
    return ok;
}

void Backup::discard()
{
    m_inspected = false;
    if (m_work.isEmpty()) {
        return;
    }
    QDir work(m_work);
    for (const QString &name : {kInspected, kCopyPrefix + BackupArchive::kPractice, kCopyPrefix + BackupArchive::kCourses}) {
        work.remove(name);
    }
}

QString Backup::copyPath(const QString &name) const
{
    return QDir(m_work).filePath(kCopyPrefix + name);
}

// The inspected archive open, its databases as files, migrated to this app's schema.
bool Backup::unpacked(QFile *file, BackupArchive *archive)
{
    file->setFileName(QDir(m_work).filePath(kInspected));
    if (!file->open(QIODevice::ReadOnly) || !archive->open(file)) {
        return setError(tr("The backup could not be read: %1").arg(file->isOpen() ? archive->errorString() : file->errorString()));
    }
    if (!archive->unpack(copyPath(BackupArchive::kPractice), copyPath(BackupArchive::kCourses))) {
        return setError(tr("The backup could not be read: %1").arg(archive->errorString()));
    }
    return true;
}

// All or nothing, in the order that allows it:
//   1  the media files the backup's rows name and this device lacks (a damaged or unwritable one
//      stops here; what came so far goes again)
//   2  all rows of both databases in one transaction (atomic per file under WAL: a crash in the
//      commit may leave one replaced; replacing again mends it)
//   3  the files only the old rows named; after the commit, so a failure never loses one (a file
//      that stays is unused, no harm)
bool Backup::swapIn()
{
    QFile file;
    BackupArchive archive;
    if (!unpacked(&file, &archive)) {
        return false;
    }
    const QString practice = copyPath(BackupArchive::kPractice);
    const QString courses = copyPath(BackupArchive::kCourses);

    // Both stores open and migrated; the preview says what each side's rows name.
    TableMerge::Result fromLog;
    TableMerge::Result fromBook;
    {
        PracticeLog log;
        CourseBook book;
        if (!log.open(m_practice) || !log.merge(practice, TableMerge::Mode::Preview, &fromLog)) {
            return setError(tr("The backup could not be restored: %1").arg(log.errorString()));
        }
        if (!book.open(m_courses) || !book.merge(courses, TableMerge::Mode::Preview, &fromBook)) {
            return setError(tr("The backup could not be restored: %1").arg(book.errorString()));
        }
    }
    const QSet<QString> named = nameSet(fromLog.theirMedia + fromBook.theirMedia);

    QStringList adopted;
    QString why;
    for (const QString &name : archive.media()) {
        if (!named.contains(name) || m_media.has(name)) {
            continue;
        }
        QByteArray data;
        if (!archive.readMedia(name, &data)) {
            why = archive.errorString();
            break;
        }
        if (!m_media.adopt(name, data)) {
            why = tr("%1 could not be saved").arg(name);
            break;
        }
        adopted << name;
    }

    const bool ok = why.isEmpty()
                    && TableMerge::replace({{m_practice, practice, PracticeLog::tables()},
                                            {m_courses, courses, CourseBook::tables()}}, &why);
    if (!ok) {
        for (const QString &name : std::as_const(adopted)) {
            m_media.remove(name);
        }
        return setError(tr("The backup could not be restored: %1").arg(why));
    }

    for (const QString &name : fromLog.mine + fromBook.mine) {
        if (!named.contains(name)) {
            m_media.remove(name);
        }
    }
    return setError({});
}

// Both databases of the archive as files, migrated to this app's schema, then merged into the
// device's (Preview rolls back), then the media files the merged rows name.
bool Backup::merge(Step step, QVariantMap *summary)
{
    QFile file;
    BackupArchive archive;
    if (!unpacked(&file, &archive)) {
        return false;
    }
    const QString practice = copyPath(BackupArchive::kPractice);
    const QString courses = copyPath(BackupArchive::kCourses);

    const TableMerge::Mode mode = step == Step::Apply ? TableMerge::Mode::Apply : TableMerge::Mode::Preview;
    PracticeLog log;
    CourseBook book;
    TableMerge::Result fromLog;
    TableMerge::Result fromBook;
    if (!log.open(m_practice) || !log.merge(practice, mode, &fromLog)) {
        return setError(tr("The backup could not be restored: %1").arg(log.errorString()));
    }
    if (!book.open(m_courses) || !book.merge(courses, mode, &fromBook)) {
        return setError(tr("The backup could not be restored: %1").arg(book.errorString()));
    }

    // The media files the merged rows name and this device lacks; after the rows on Apply (a
    // failed file leaves its note with the hint "not on this device").
    const QStringList named = fromLog.media + fromBook.media;
    const QSet<QString> wanted(named.cbegin(), named.cend());
    int media = 0;
    for (const QString &name : archive.media()) {
        if (!wanted.contains(name) || m_media.has(name)) {
            continue;
        }
        ++media;
        if (step == Step::Preview) {
            continue;
        }
        QByteArray data;
        if (!archive.readMedia(name, &data)) {
            return setError(tr("The backup could not be restored: %1").arg(archive.errorString()));
        }
        if (!m_media.adopt(name, data)) {
            return setError(tr("The backup could not be restored: %1").arg(tr("%1 could not be saved").arg(name)));
        }
    }
    if (step == Step::Apply) {
        for (const QString &name : fromLog.orphans + fromBook.orphans) {
            m_media.remove(name);
        }
    }

    // The files a merge deletes here (Preview; Apply has removed them above).
    int mediaRemoved = 0;
    for (const QString &name : fromLog.orphans + fromBook.orphans) {
        mediaRemoved += m_media.has(name) ? 1 : 0;
    }

    // For replace(): the media the backup's rows name and it holds, and those that would go here.
    const QSet<QString> theirs = nameSet(fromLog.theirMedia + fromBook.theirMedia);
    int mediaHolds = 0;
    for (const QString &name : archive.media()) {
        mediaHolds += theirs.contains(name) ? 1 : 0;
    }
    int mediaLost = 0;
    for (const QString &name : fromLog.mine + fromBook.mine) {
        mediaLost += !theirs.contains(name) && m_media.has(name) ? 1 : 0;
    }

    const BackupArchive::Manifest m = archive.manifest();
    *summary = {{QStringLiteral("created"), m.created},
                {QStringLiteral("device"), m.device},
                {QStringLiteral("thisDevice"), m.device == deviceId()},
                {QStringLiteral("ratings"), counts(fromLog, QStringLiteral("ratings"))},
                {QStringLiteral("notes"), counts(fromLog, QStringLiteral("notes"))},
                {QStringLiteral("rounds"), counts(fromLog, QStringLiteral("exam_rounds"))},
                {QStringLiteral("notebooks"), counts(fromBook, QStringLiteral("courses"))},
                {QStringLiteral("entries"), counts(fromBook, QStringLiteral("entries"))},
                {QStringLiteral("grades"), counts(fromBook, QStringLiteral("grades"))},
                {QStringLiteral("starts"), counts(fromBook, QStringLiteral("starts"))},
                {QStringLiteral("links"), counts(fromBook, QStringLiteral("entry_tags"))},
                {QStringLiteral("media"), media},
                {QStringLiteral("mediaRemoved"), mediaRemoved},
                {QStringLiteral("mediaHolds"), mediaHolds},
                {QStringLiteral("mediaLost"), mediaLost}};
    return setError({});
}
