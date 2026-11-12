#pragma once

#include <QDate>
#include <QObject>
#include <QSet>
#include <QTimer>
#include <QStringList>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>
#include <optional>

#include "practicelog.h"
#include "searchkey.h"

// How well each technique sits, for QML: rate an entry 1..4, read its latest level and when it
// was rated, count levels for a grade. Backed by the practice log (SQLite in the app's data
// folder). `revision` grows with every change, so bindings that read levels follow.
class Practice : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    // Grows with every new, changed or deleted note.
    Q_PROPERTY(int notesRevision READ notesRevision NOTIFY notesChanged)
    // Grows when ratings of past days change (the log read anew); a rating now changes only today,
    // so the calendars of past years keep what they show.
    Q_PROPERTY(int historyRevision READ historyRevision NOTIFY historyChanged)
    // Why the log could not be opened or the last rating not saved; empty when all is well.
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorChanged)
    // Days until a technique of level 1..4 is due again (settings, "Heute üben").
    Q_PROPERTY(QVariantList intervals READ intervals WRITE setIntervals NOTIFY intervalsChanged)
    // Today's date; changes at midnight, so due lists and "rated today" follow a new day.
    Q_PROPERTY(QDate today READ today NOTIFY todayChanged)
    // Words per level: [none, seen, with help, sure, ready for the exam] (translated).
    Q_PROPERTY(QStringList levelNames READ levelNames NOTIFY levelNamesChanged)

public:
    explicit Practice(QObject *parent = nullptr);
    // For tests: a database file of its own.
    explicit Practice(const QString &path, QObject *parent = nullptr);
    ~Practice() override;

    int revision() const { return m_revision; }
    int notesRevision() const { return m_notesRevision; }
    int historyRevision() const { return m_historyRevision; }
    QString errorString() const { return m_error; }
    QStringList levelNames() const;

    // A new rating of an entry now (1..4); a rating of the same level again counts as practice.
    // False (and errorString set) when it could not be saved.
    Q_INVOKABLE bool rate(const QString &entry, int level);
    // The latest level of an entry, 0 if never rated.
    Q_INVOKABLE int level(const QString &entry) const;
    // The highest level among entries (a place on the technique map with variants), 0 if none rated.
    Q_INVOKABLE int bestLevel(const QStringList &entries) const;
    // When the entry was rated last (local time), or an invalid date.
    Q_INVOKABLE QDateTime lastRated(const QString &entry) const;
    // How many of the entries stand at each level: [none, 1, 2, 3, 4].
    Q_INVOKABLE QVariantList counts(const QStringList &entries) const;
    // How many techniques were practised on each of the last `days` days up to today:
    // {"YYYY-MM-DD": count}, days without practice left out.
    Q_INVOKABLE QVariantMap practisedPerDay(int days) const;
    // The same for a calendar year, of one discipline ("" all): {"2025-03-08": 7, …}.
    Q_INVOKABLE QVariantMap practisedInYear(int year, const QString &discipline) const;
    // The year of the first rating (this year without one): where "all years" begin.
    Q_INVOKABLE int firstYear() const;
    // Whether the entry was rated today (practised).
    Q_INVOKABLE bool ratedToday(const QString &entry) const;
    // Today's practice from candidate rows (Programme.practiceEntries: id, current, …): the due
    // ones in order (Schedule::due), each row with `level` and `days` added.
    Q_INVOKABLE QVariantList due(const QVariantList &candidates) const;

    // The latest rating of every entry and the day each was rated first, as copies (C++ only: StartBoard
    // hands them to a worker thread; the hashes share their data until this one writes).
    QHash<QString, PracticeLog::Rating> ratings() const { return m_latest; }
    QHash<QString, QDate> firstDays() const { return m_first; }
    // Who was rated on each local day of a year (levels 1..4), a copy that shares its data.
    QHash<QDate, QSet<QString>> dayEntries(int year) const { return m_open ? yearDays(year) : DayEntries(); }

    // Notes on a technique: {uid, text, created, changed} with local dates, oldest first.
    Q_INVOKABLE QVariantList notes(const QString &entry) const;
    // The entry's notes written today (the player's "Noted today"), oldest first.
    Q_INVOKABLE QVariantList notesToday(const QString &entry) const;
    // The newest note of an entry ({uid, text, created, changed}), or an empty map.
    Q_INVOKABLE QVariantMap lastNote(const QString &entry) const;
    // Every note ({uid, entry, text, created, changed}), newest first.
    Q_INVOKABLE QVariantList allNotes() const;
    // The same as records, newest first (C++ only: AllNotes builds its rows without maps).
    QList<PracticeLog::Note> noteRecords() const;
    // Notes containing every word of `query` (case and accents do not matter), newest first:
    // {uid, entry, text, created, changed}.
    Q_INVOKABLE QVariantList searchNotes(const QString &query, int limit = 50) const;
    // Reads what searchNotes() compares (30 ms with 3000 notes), when the search opens, not on
    // the first letter.
    Q_INVOKABLE void prepareSearch() const;
    // Add, change or delete a note; false (and errorString set) when it could not be saved.
    // Text, a photo or voice note (its name from Media), or both.
    Q_INVOKABLE bool addNote(const QString &entry, const QString &text, const QString &media = {});
    Q_INVOKABLE bool changeNote(const QString &uid, const QString &text);
    Q_INVOKABLE bool deleteNote(const QString &uid);

    // The end of an exam round: every point's rating ([{id, level: 1..4}]) goes into the log
    // like any rating, and the round (date, discipline, grade, number of points, average) is
    // kept for the statistics. False (and errorString set) when a level is missing or it could not be saved.
    Q_INVOKABLE bool saveRound(const QString &discipline, const QString &grade, const QVariantList &results);
    // The last `limit` exam rounds of a discipline, oldest first: {at (local), grade, count, average}.
    Q_INVOKABLE QVariantList rounds(const QString &discipline, int limit) const;

    QDate today() const { return m_today; }
    QVariantList intervals() const;
    void setIntervals(const QVariantList &intervals);

    // Reads the log anew (a backup was merged into it).
    Q_INVOKABLE void refresh();

    static QString defaultPath();
    // This device's id for the log (made once, kept in the settings).
    static QString deviceId();

signals:
    void levelNamesChanged();
    void changed();
    void errorChanged();
    void intervalsChanged();
    void todayChanged();
    void notesChanged();
    void historyChanged();

protected:
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void load(const QString &path);
    void noteSaved(bool ok);
    // Who was rated on each local day of a year (levels 1..4): read from the log once, then kept
    // up to date by counted(). The calendars ask on every change, which touches only today.
    using DayEntries = QHash<QDate, QSet<QString>>;
    const DayEntries &yearDays(int year) const;
    void counted(const PracticeLog::Rating &r);
    // Every note with what searchNotes() compares, newest first: read once, until a note changes
    // (the search asks on every keystroke, 3000 notes in five years).
    struct NoteText {
        PracticeLog::Note note;
        SearchText text;
    };
    const QList<NoteText> &noteTexts() const;
    // The caches above go when another connection wrote to the log (a sync's conflict resolved
    // with its own PracticeLog); refresh() drops them too.
    void dropStale() const;

    std::unique_ptr<PracticeLog> m_log;
    QHash<QString, PracticeLog::Rating> m_latest;
    QHash<QString, QDate> m_first;
    QHash<QString, PracticeLog::Note> m_lastNotes;
    mutable QHash<int, DayEntries> m_days;       // by year, filled by yearDays()
    mutable std::optional<QDateTime> m_firstRating;     // firstYear(): unset until read, invalid: none
    mutable std::optional<QList<NoteText>> m_noteTexts;  // unset until read
    mutable qint64 m_logVersion = -1;                    // the log's dataVersion() they were read at
    QDate m_today = QDate::currentDate();
    QTimer m_dayTimer;
    QString m_error;
    bool m_open = false;
    int m_revision = 0;
    int m_notesRevision = 0;
    int m_historyRevision = 0;
};
