#pragma once

#include <QDateTime>
#include <QHash>
#include <QList>
#include <QString>

#include <optional>

#include "tablemerge.h"

// The practice log in SQLite: every rating of a technique as its own entry with a time stamp
// and the device it came from, so that devices can later be merged entry by entry (sync) and
// the history stays (statistics, "last rated"). Plain C++; QML reaches it through Practice.
class PracticeLog
{
public:
    struct Rating {
        QString uid;
        QString entry;          // programme id, e.g. "aikido/k5/tachi-waza/shomen-uchi/ikkyo"
        int level = 0;          // 1 seen, 2 with help, 3 sure, 4 ready for the exam
        QDateTime at;           // UTC
        QString device;
    };

    // A note on a technique. Changes and deletions keep the uid and set `changed`, so devices can
    // be merged note by note later; a deleted note stays as a mark (`deleted`).
    struct Note {
        QString uid;
        QString entry;
        QString text;
        QDateTime created;      // UTC
        QDateTime changed;      // UTC
        QString device;
        bool deleted = false;
        QString media;          // a photo or voice note: its file in the media folder, or ""
    };

    // A round of the exam mode (mock exam): when, which grade, how many points were asked and
    // the average of their ratings (1..4). The ratings themselves go into `ratings` as usual.
    struct ExamRound {
        QString uid;
        QDateTime at;           // UTC
        QString discipline;     // "aikido", "daitoryu", "shinkitoho"
        QString grade;          // grade id, e.g. "k5"
        int count = 0;
        double average = 0;
        QString device;
    };

    PracticeLog();
    ~PracticeLog();
    PracticeLog(const PracticeLog &) = delete;
    PracticeLog &operator=(const PracticeLog &) = delete;

    // Opens (and creates or migrates) the database file; false with errorString() on failure.
    bool open(const QString &path);
    QString errorString() const { return m_error; }

    // Adds a rating; returns it with its new uid, or an empty uid on failure (errorString()).
    Rating add(const QString &entry, int level, const QDateTime &at, const QString &device);
    // The latest rating of every entry (for lists) and the local day each entry was rated first
    // (its history begins: it was new that day); levels outside 1..4 are skipped. One pass over
    // the log: a second query for the first days took 110 ms of the start with five years.
    struct Summary {
        QHash<QString, Rating> latest;
        QHash<QString, QDate> firstRated;
    };
    Summary summary() const;
    // summary().latest.
    QHash<QString, Rating> latest() const;
    // How many entries were rated on each local day from `from` (UTC) on; an entry rated several
    // times on a day counts once (statistics: practice days).
    // `prefix` keeps a discipline's entries only ("aikido/").
    QHash<QDate, int> practisedPerDay(const QDateTime &from, const QString &prefix = {}, const QDateTime &to = {}) const;
    // The entries rated on each local day from `from` up to `to` (UTC, invalid: no end), as above.
    QHash<QDate, QSet<QString>> practisedOn(const QDateTime &from, const QString &prefix = {}, const QDateTime &to = {}) const;
    // The first rating's time (UTC), or invalid without one.
    QDateTime firstRating() const;
    // Changes when another connection wrote to the log (SQLite's data_version: a sync's or a
    // backup's own PracticeLog); not with this one's writes.
    qint64 dataVersion() const;
    // All ratings of one entry, oldest first.
    QList<Rating> history(const QString &entry) const;

    // Notes: add one (an empty uid on failure), change or delete one by uid (false on failure).
    // Text, a media file (MediaStore), or both.
    Note addNote(const QString &entry, const QString &text, const QDateTime &at, const QString &device,
                 const QString &media = {});
    // The media file of a note (also a deleted one), or "".
    QString noteMedia(const QString &uid) const;
    bool changeNote(const QString &uid, const QString &text, const QDateTime &at);
    bool deleteNote(const QString &uid, const QDateTime &at);
    // The notes of one entry that are not deleted, oldest first.
    QList<Note> notes(const QString &entry) const;
    // Every note that is not deleted, newest first.
    QList<Note> allNotes() const;
    // How many notes there are, and the newest one (the same order as allNotes()): two cheap queries
    // for what only needs these.
    int noteCount() const;
    std::optional<Note> newestNote() const;
    // The newest note of every entry that has one.
    QHash<QString, Note> lastNotes() const;

    // A saved exam round with the ratings it wrote.
    struct SavedRound {
        ExamRound round;        // empty uid on failure (errorString())
        QList<Rating> ratings;
    };

    // Exam rounds: add one with its ratings (entry and level each; time and device from the
    // round) in one transaction, all or nothing; the last `limit` rounds of a discipline,
    // oldest first.
    SavedRound addRound(const ExamRound &round, const QList<Rating> &ratings);
    QList<ExamRound> rounds(const QString &discipline, int limit) const;

    // Every note's `changed` by uid, deleted ones too (the sync's base versions).
    QHash<QString, QDateTime> noteVersions() const;

    // The whole log as one new file (a backup), consistent while the app writes; false when it
    // exists or could not be written.
    bool snapshot(const QString &path);
    // Merges another log (a backup, opened and migrated before): its ratings and exam rounds this
    // one lacks, and its notes that are new or newer (TableMerge).
    bool merge(const QString &otherPath, TableMerge::Mode mode, TableMerge::Result *result,
               const TableMerge::Watch &watch = {});

    // The tables a backup holds and merge() takes.
    static QList<TableMerge::Table> tables();

    static constexpr int schemaVersion = 6;

private:
    bool migrate();
    bool mergeKamae();

    QString m_connection;
    QString m_error;
};
