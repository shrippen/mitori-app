#pragma once

#include <QDateTime>
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QtQml/qqmlregistration.h>
#include <memory>

#include "catalog.h"
#include "coursebook.h"
#include "devicecalendar.h"
#include "icsreader.h"
#include "searchkey.h"

class QNetworkAccessManager;
class QNetworkReply;

// Courses for QML (clickdummy "Lehrgänge"): the coming events of the association's public course
// calendar (ICS, kept on the device for offline use) and the user's notebooks, one per course,
// made from an event or by hand (a private training, a guest teacher). `revision` grows with
// every change, so bindings that read notebooks or entries follow.
//
// Also the user's grades (Meine Grade) and the exams planned on courses: the waiting time before
// the next grade comes from the programme data (`wartezeit` of a grade, tools/daten.py).
//
// Days as "YYYY-MM-DD" (a QDate reaches JS as midnight UTC, the day before west of UTC).
//
//   calendar (ICS, cache)  ──►  upcoming      [{uid, title, first, last, place, teacher, …,
//                                              notebook: uid of its notebook or ""}]
//   CourseBook (SQLite)    ──►  notebooks     [{uid, calendarUid, title, first, last, …, entries}]
//                               entries(uid)  [{uid, text, created, changed, media, techniques (ids)}]
//                               linkedEntries(technique)  [{uid, text, media, created, course, title, first, last}]
//                               grades        [{uid, discipline, grade, name, day, place}]
//   + catalog (grade order, waiting times) ──►  nextGrade, waiting, nextExam
class Courses : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(int revision READ revision NOTIFY changed)
    Q_PROPERTY(QVariantList upcoming READ upcoming NOTIFY calendarChanged)
    Q_PROPERTY(QVariantList notebooks READ notebooks NOTIFY changed)
    // Passed grades, the latest day first: {uid, discipline, grade, name, day, place}.
    Q_PROPERTY(QVariantList grades READ grades NOTIFY changed)
    Q_PROPERTY(CalendarState calendarState READ calendarState NOTIFY calendarChanged)
    // When the calendar was last loaded from the network (local time), or invalid.
    Q_PROPERTY(QDateTime calendarLoaded READ calendarLoaded NOTIFY calendarChanged)
    // Why the notebooks could not be opened or the last change not saved; empty when all is well.
    Q_PROPERTY(QString errorString READ errorString NOTIFY errorChanged)
    // The system has a share dialog (platform/sharefile: Android).
    Q_PROPERTY(bool canShare READ canShare CONSTANT)

public:
    enum class CalendarState { Empty, Loading, Ready, Failed };
    Q_ENUM(CalendarState)
    // How a grade's waiting time stands (waiting()):
    //   First      the first grade, no waiting time
    //   FromStart  `years` after the start of training (no day known to the app)
    //   Unknown    `years` after `previous`, which is not entered
    //   Earliest   from `earliest` on (no exam day given)
    //   Fits       the exam day is on or after `earliest`
    //   TooEarly   the exam day is before `earliest`
    enum class Wait { First, FromStart, Unknown, Earliest, Fits, TooEarly };
    Q_ENUM(Wait)

    explicit Courses(QObject *parent = nullptr);
    // For tests: a database file, a calendar source (file:// or http) and a catalog of their own.
    Courses(const QString &path, const QUrl &calendar, const QString &cache, const Catalog &catalog,
            QObject *parent = nullptr);
    ~Courses() override;

    int revision() const { return m_revision; }
    QVariantList upcoming() const;
    QVariantList notebooks() const;
    QVariantList grades() const;
    CalendarState calendarState() const { return m_state; }
    QDateTime calendarLoaded() const { return m_loaded.toLocalTime(); }
    QString errorString() const { return m_error; }

    // Loads the calendar anew; `Older` only when the last load is older than a few hours.
    enum class Reload { Always, Older };
    Q_ENUM(Reload)
    Q_INVOKABLE void reload(Reload when = Reload::Always);

    // Shows the notebooks anew (a backup was merged into them).
    Q_INVOKABLE void refresh();

    // The notebook of a calendar event, made on first use; its uid ("" on failure).
    Q_INVOKABLE QString notebookFor(const QString &eventUid);
    // A notebook without a calendar event, days as "YYYY-MM-DD"; its uid ("" on failure).
    Q_INVOKABLE QString create(const QString &title, const QString &first, const QString &last,
                               const QString &place, const QString &teacher);
    Q_INVOKABLE bool remove(const QString &uid);
    // One notebook as in `notebooks`, or an empty map.
    Q_INVOKABLE QVariantMap notebook(const QString &uid) const;

    // A passed grade, day as "YYYY-MM-DD"; the same grade again corrects day and place.
    Q_INVOKABLE bool addGrade(const QString &discipline, const QString &grade, const QString &day, const QString &place);
    Q_INVOKABLE bool removeGrade(const QString &uid);
    // The grades one can take in a discipline, in order: {id, name, passed}.
    Q_INVOKABLE QVariantList ladder(const QString &discipline) const;
    // The grade after the highest one passed (the first without any), or "" after the last.
    Q_INVOKABLE QString nextGrade(const QString &discipline) const;
    // The waiting time before a grade: {state (Wait), years, previous (name; for a time from the start
    // of training ""), earliest ("YYYY-MM-DD" or "")}; `day` ("YYYY-MM-DD", optional) is the planned exam day it is checked against.
    Q_INVOKABLE QVariantMap waiting(const QString &discipline, const QString &grade, const QString &day = {}) const;
    // When training began in a discipline ("YYYY-MM-DD", "" unknown), and setting it ("" removes);
    // whether a grade's waiting time there counts from it (Shinki Toho Shoden).
    Q_INVOKABLE QString trainingStart(const QString &discipline) const;
    Q_INVOKABLE bool setTrainingStart(const QString &discipline, const QString &day);
    Q_INVOKABLE bool countsFromStart(const QString &discipline) const;

    // Plans an exam on a notebook's course; an empty grade removes it.
    Q_INVOKABLE bool planExam(const QString &uid, const QString &discipline, const QString &grade);
    // The next planned exam whose course has not ended (of a discipline, or of any with ""):
    // {course, title, place, first, discipline, grade, name, days (from today to the first day,
    // 0 while it runs)}, or an empty map.
    Q_INVOKABLE QVariantMap nextExam(const QString &discipline = {}) const;

    Q_INVOKABLE QVariantList entries(const QString &course) const;
    // The entries whose text holds every word of the query (SearchText rules), newest first, at most
    // `limit`: {uid, text, excerpt (the line with the words, shortened), created, course, title, first, last}.
    Q_INVOKABLE QVariantList searchEntries(const QString &query, int limit = 50) const;
    // Every notebook's entries, newest first, and the notebooks' titles by uid (C++ only: AllNotes).
    QList<CourseBook::Entry> allEntries() const;
    QHash<QString, QString> courseTitles() const;
    // Text, a photo or voice note (its name from Media), or both.
    Q_INVOKABLE bool addEntry(const QString &course, const QString &text, const QString &media = {});
    Q_INVOKABLE bool changeEntry(const QString &uid, const QString &text);
    Q_INVOKABLE bool deleteEntry(const QString &uid);

    // Links an entry to a technique, by the user's choice only (Programme.suggest proposes), and
    // back; the entries linked to a technique, the latest course first.
    Q_INVOKABLE bool linkTechnique(const QString &entry, const QString &technique);
    Q_INVOKABLE bool unlinkTechnique(const QString &entry, const QString &technique);
    Q_INVOKABLE QVariantList linkedEntries(const QString &technique) const;

    // The notebook as a ZIP (notizbuch.md, photos, voice notes; store/notebookexport) to a file
    // the user chose (on Android a content:// URL): how many media files were not on the device
    // (left out), or -1 with errorString on failure.
    Q_INVOKABLE int exportNotebook(const QString &uid, const QUrl &target);
    // A file name for it: "Sommerlehrgang 2026-07-01.zip".
    Q_INVOKABLE QString exportName(const QString &uid) const;
    // What the export holds: {title, name, text (notizbuch.md), photos, voices, missing, bytes,
    // size ("1.4 MB")}; empty without the notebook.
    Q_INVOKABLE QVariantMap exportPreview(const QString &uid) const;
    bool canShare() const;
    // The notebook to the share dialog: as exportNotebook, with a copy in the cache.
    Q_INVOKABLE int shareNotebook(const QString &uid);
    // That copy: its path, or "" with errorString. It lies in a folder of its notebook, as two
    // notebooks may have the same file name:
    //
    //   <ShareFile::folder()>/<hash of the uid>/Sommer Mainz 2026-07-04.zip
    //
    // The last one stays until the next, or until its notebook is deleted: the app the user picked
    // may read it long after the dialog (a mail's draft). Tests.
    QString shareCopy(const QString &uid, int *missing = nullptr);

    // The course into the device's calendar app (platform/devicecalendar); false without one.
    Q_INVOKABLE bool addToDeviceCalendar(const QString &uid);
    // The event it hands over (tests).
    DeviceCalendar::Event deviceEvent(const QString &uid) const;

    // The teacher from a description's first line "mit …" ("mit M. D. Nakajima Shihan").
    static QString teacherOf(const QString &description);
    static QString defaultPath();

signals:
    void changed();
    void calendarChanged();
    void errorChanged();

protected:
    // The grades' names follow the data's language (Catalog): a change of it is a change here.
    bool eventFilter(QObject *watched, QEvent *event) override;

private:
    void loadCache();
    void received(QNetworkReply *reply);
    bool saved(bool ok, const QString &what);
    void dropCopy(const QString &uid);
    void dropGoneCopies();
    // A grade of the catalog that one can take, in its discipline's order.
    struct Step {
        QString id;
        QString name;
        int years = 0;          // 0: none
        bool fromStart = false; // years after the start of training, not after the previous grade
    };
    // Read from the catalog at each call: the names in its language of now.
    QList<Step> steps(const QString &discipline) const;
    QString gradeName(const QString &discipline, const QString &grade) const;
    QString disciplineName(const QString &discipline) const;
    QString examName(const QString &discipline, const QString &grade) const;
    QVariantMap courseMap(const CourseBook::Course &c, int entries) const;
    // A notebook's entries with their techniques' names, for the export.
    QList<CourseBook::Entry> namedEntries(const QString &course) const;

    // Every entry with what searchEntries() compares: read once per revision (it asks on every keystroke).
    struct EntryText {
        CourseBook::Entry entry;
        SearchText text;
    };
    const QList<EntryText> &entryTexts() const;

    Catalog m_catalog;
    Catalog::Language m_language;

    std::unique_ptr<CourseBook> m_book;
    QNetworkAccessManager *m_network = nullptr;
    QUrl m_source;
    QString m_cache;
    QList<IcsReader::Event> m_events;
    CalendarState m_state = CalendarState::Empty;
    QDateTime m_loaded;
    QString m_error;
    bool m_open = false;
    int m_revision = 0;
    mutable QList<EntryText> m_entryTexts;
    mutable int m_entryTextsRevision = -1;
};
