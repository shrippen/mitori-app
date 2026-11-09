#pragma once

#include <QObject>
#include <QUrl>
#include <QVariantMap>
#include <QtQml/qqmlregistration.h>

#include "mediastore.h"

class BackupArchive;
class QFile;

// The backup for QML (Einstellungen → Sicherung): everything the user wrote as one ZIP
// (store/backuparchive), and such a file read back, in one of two ways. Merging (TableMerge): new
// rows come in, newer ones replace older, a newer deletion deletes here too, what the backup lacks
// stays, except what CourseBook's clean-up joins or takes (an entry in a notebook the backup deleted
// later, two notebooks of one course, a grade twice). Replacing: the device's
// ratings, notes, exam rounds, notebooks, entries, grades, starts of training, photos and voice
// notes go, the backup's take their place; all or nothing (per file under WAL: a crash in the
// commit may leave one replaced; replacing again mends it), and it cannot be undone.
//
//   save(url)       ──► mitori-sicherung-2026-11-02.zip
//   inspect(url)    ──► {created, device, ratings: {added, changed, edited, removed, holds, lost}, …, starts,
//                        media, mediaRemoved, mediaHolds, mediaLost}
//   restore()       merges what inspect() read, then restored() (Practice and Courses reload)
//   replace()       puts what inspect() read in place of the device's data, then restored()
//                   (the sync would bring back what other devices hold: Sync::dataReplaced)
class Backup : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(QString errorString READ errorString NOTIFY errorChanged)

public:
    explicit Backup(QObject *parent = nullptr);
    // For tests: files and folders of their own.
    Backup(const QString &practice, const QString &courses, const QString &media, const QString &work,
           QObject *parent = nullptr);
    ~Backup() override;

    QString errorString() const { return m_error; }
    // Where the last save went, for the message: a path; "" from Android's file picker.
    Q_INVOKABLE QString savedTo() const { return m_savedTo; }

    // "mitori-sicherung-2026-11-02.zip"
    Q_INVOKABLE QString fileName() const;
    Q_INVOKABLE bool save(const QUrl &target);
    // Reads a backup and says what restore() would change, what it holds and what replace() would
    // delete or set back; {} on failure (errorString).
    Q_INVOKABLE QVariantMap inspect(const QUrl &source);
    Q_INVOKABLE bool restore();
    Q_INVOKABLE bool replace();
    // Forgets the inspected backup (its copy in the work folder).
    Q_INVOKABLE void discard();

signals:
    void errorChanged();
    void restored();

private:
    enum class Step { Preview, Apply };
    bool merge(Step step, QVariantMap *summary);
    bool swapIn();
    bool unpacked(QFile *file, BackupArchive *archive);
    QString copyPath(const QString &name) const;
    bool setError(const QString &error);

    QString m_practice;
    QString m_courses;
    MediaStore m_media;
    QString m_work;
    QString m_error;
    QString m_savedTo;
    bool m_inspected = false;
};
