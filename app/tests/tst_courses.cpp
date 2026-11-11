#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <QTimeZone>

#include "catalog.h"
#include "coursebook.h"
#include "courses.h"
#include "devicecalendar.h"
#include "icsreader.h"

using namespace Qt::StringLiterals;

namespace {

// A calendar with one past and two coming events, dates relative to today.
QByteArray calendar()
{
    const auto day = [](int offset) { return QDate::currentDate().addDays(offset).toString(u"yyyyMMdd"_s).toUtf8(); };
    return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
           "BEGIN:VEVENT\r\nUID:past\r\nSUMMARY:Vorbei\r\nDTSTART;VALUE=DATE:" + day(-20) + "\r\nDTEND;VALUE=DATE:" + day(-18) + "\r\nEND:VEVENT\r\n"
           "BEGIN:VEVENT\r\nUID:later\r\nSUMMARY:Daitoryu\r\nDTSTART;VALUE=DATE:" + day(30) + "\r\nDTEND;VALUE=DATE:" + day(32) + "\r\n"
           "LOCATION:Siebeldingen\r\nDESCRIPTION:mit M. D. Nakajima Shihan\\nSamstag\\nAusschreibung: https://example.org/a?b=1&c=%2F\r\nEND:VEVENT\r\n"
           "BEGIN:VEVENT\r\nUID:soon\r\nSUMMARY:Aikido\r\nDTSTART;VALUE=DATE:" + day(-1) + "\r\nDTEND;VALUE=DATE:" + day(2) + "\r\nEND:VEVENT\r\n"
           "END:VCALENDAR\r\n";
}

} // namespace

class TstCourses : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    Catalog m_catalog;

    QString write(const QString &name, const QByteArray &data)
    {
        QFile file(m_dir.filePath(name));
        if (!file.open(QIODevice::WriteOnly)) {
            return {};
        }
        file.write(data);
        return file.fileName();
    }

    // A service on its own files, the calendar loaded from a local file.
    std::unique_ptr<Courses> made(const QString &name)
    {
        const QUrl source = QUrl::fromLocalFile(write(name + u".ics"_s, calendar()));
        auto c = std::make_unique<Courses>(m_dir.filePath(name + u".sqlite"_s), source, m_dir.filePath(name + u"-cache.ics"_s),
                                           m_catalog);
        QSignalSpy spy(c.get(), &Courses::calendarChanged);
        c->reload();
        while (c->calendarState() == Courses::CalendarState::Loading && spy.wait(5000)) {
        }
        return c;
    }

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        QSettings().clear();
        QVERIFY(m_dir.isValid());
        QVERIFY2(m_catalog.load(QStringLiteral(MITORI_DATEN_JSON)), qPrintable(m_catalog.errorString()));
    }

    // Notebooks and entries stay across a new start; a deletion keeps the others.
    void bookKeepsNotebooks()
    {
        const QString path = m_dir.filePath(u"book.sqlite"_s);
        const QDateTime at = QDateTime::currentDateTimeUtc();
        QString kept;
        {
            CourseBook book;
            QVERIFY2(book.open(path), qPrintable(book.errorString()));
            CourseBook::Course c;
            c.title = u"Training mit Gastlehrer"_s;
            c.first = QDate(2026, 11, 7);
            c.last = QDate(2026, 11, 6);        // before the first day: one day
            const CourseBook::Course made = book.addCourse(c, at, u"dev"_s);
            QVERIFY2(!made.uid.isEmpty(), qPrintable(book.errorString()));
            QCOMPARE(made.last, made.first);
            QVERIFY(book.addCourse({}, at, u"dev"_s).uid.isEmpty());     // no title
            kept = book.addEntry(made.uid, u"  Hüfte zuerst  "_s, at, u"dev"_s).uid;
            const QString gone = book.addEntry(made.uid, u"weg"_s, at.addSecs(1), u"dev"_s).uid;
            QVERIFY(book.addEntry(made.uid, u"   "_s, at, u"dev"_s).uid.isEmpty());
            QVERIFY(book.deleteEntry(gone, at.addSecs(2)));
            QVERIFY(!book.deleteEntry(gone, at.addSecs(3)));            // already deleted
            QVERIFY(book.changeEntry(kept, u"Hüfte früher"_s, at.addSecs(4)));
        }
        CourseBook book;
        QVERIFY(book.open(path));
        const QList<CourseBook::Course> list = book.courses();
        QCOMPARE(list.size(), 1);
        QCOMPARE(list.first().title, u"Training mit Gastlehrer"_s);
        const QList<CourseBook::Entry> entries = book.entries(list.first().uid);
        QCOMPARE(entries.size(), 1);
        QCOMPARE(entries.first().uid, kept);
        QCOMPARE(entries.first().text, u"Hüfte früher"_s);
        QVERIFY(entries.first().changed > entries.first().created);
        QCOMPARE(book.entryCounts().value(list.first().uid), 1);
        QVERIFY(book.deleteCourse(list.first().uid, at.addSecs(5)));
        QVERIFY(book.courses().isEmpty());
        // Its entries go with it, as marks (a later sync must not bring them back).
        QVERIFY(book.entries(list.first().uid).isEmpty());
        QVERIFY(book.entryCounts().isEmpty());
    }

    // A saved entry is written ahead (WAL), not three file syncs of a journal.
    void bookWritesAhead()
    {
        const QString path = m_dir.filePath(u"ahead.sqlite"_s);
        CourseBook book;
        QVERIFY2(book.open(path), qPrintable(book.errorString()));
        CourseBook::Course c;
        c.title = u"Lehrgang"_s;
        c.first = QDate(2026, 11, 7);
        QVERIFY(!book.addCourse(c, QDateTime::currentDateTimeUtc(), u"dev"_s).uid.isEmpty());
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, u"peek"_s);
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(u"PRAGMA journal_mode"_s) && q.next());
            QCOMPARE(q.value(0).toString(), u"wal"_s);
        }
        QSqlDatabase::removeDatabase(u"peek"_s);
    }

    // A newer schema is not opened (it would be changed under a newer Mitori).
    void bookRefusesNewerSchema()
    {
        const QString path = m_dir.filePath(u"newer.sqlite"_s);
        {
            CourseBook book;
            QVERIFY(book.open(path));
        }
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, u"raise"_s);
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery(db).exec(u"PRAGMA user_version = %1"_s.arg(CourseBook::schemaVersion + 1));
            db.close();
        }
        QSqlDatabase::removeDatabase(u"raise"_s);
        CourseBook book;
        QVERIFY(!book.open(path));
        QVERIFY(book.errorString().contains(u"newer"_s));
    }

    // Links: add (twice is one), remove, add again; a deleted entry or notebook takes them.
    void bookLinksTechniques()
    {
        const auto at = [](int hour) { return QDateTime(QDate(2026, 11, 1), QTime(hour, 0), QTimeZone::UTC); };
        const QString tech = u"aikido/t1"_s;
        CourseBook book;
        QVERIFY(book.open(m_dir.filePath(u"links.sqlite"_s)));
        CourseBook::Course c;
        c.title = u"Sommer"_s;
        c.first = c.last = QDate(2026, 7, 4);
        const QString course = book.addCourse(c, at(8), u"dev"_s).uid;
        c.title = u"Herbst"_s;
        c.first = c.last = QDate(2026, 10, 3);
        const QString later = book.addCourse(c, at(8), u"dev"_s).uid;
        const QString one = book.addEntry(course, u"eins"_s, at(9), u"dev"_s).uid;
        const QString two = book.addEntry(course, u"zwei"_s, at(9), u"dev"_s).uid;
        const QString three = book.addEntry(later, u"drei"_s, at(9), u"dev"_s).uid;

        QVERIFY(book.addTag(one, tech, at(10), u"dev"_s));
        QVERIFY(book.addTag(one, tech, at(11), u"dev"_s));
        QVERIFY(book.addTag(one, u"aikido/t2"_s, at(11), u"dev"_s));
        QVERIFY(book.addTag(two, tech, at(10), u"dev"_s));
        QVERIFY(book.addTag(three, tech, at(10), u"dev"_s));
        QCOMPARE(book.courseTags(course).value(one), QStringList({tech, u"aikido/t2"_s}));
        QCOMPARE(book.courseTags(course).value(two), QStringList({tech}));

        // The latest course first, with its title and days; the entries in the order written.
        const QList<CourseBook::Linked> linked = book.linkedEntries(tech);
        QCOMPARE(linked.size(), 3);
        QCOMPARE(linked.at(0).entry.uid, three);
        QCOMPARE(linked.at(0).title, u"Herbst"_s);
        QCOMPARE(linked.at(0).first, QDate(2026, 10, 3));
        QCOMPARE(linked.at(1).entry.uid, one);
        QCOMPARE(linked.at(1).entry.text, u"eins"_s);

        // Not to a technique "", not to an entry that is not there; removing one that is not linked.
        QVERIFY(!book.addTag(one, QString(), at(11), u"dev"_s));
        QVERIFY(!book.addTag(u"nope"_s, tech, at(11), u"dev"_s));
        QVERIFY(!book.removeTag(two, u"aikido/t2"_s, at(11)));

        QVERIFY(book.removeTag(one, tech, at(12)));
        QCOMPARE(book.courseTags(course).value(one), QStringList({u"aikido/t2"_s}));
        QVERIFY(book.addTag(one, tech, at(13), u"dev"_s));
        QCOMPARE(book.linkedEntries(tech).size(), 3);

        QVERIFY(book.deleteEntry(two, at(14)));
        QVERIFY(!book.addTag(two, tech, at(15), u"dev"_s));
        QCOMPARE(book.linkedEntries(tech).size(), 2);
        QVERIFY(!book.courseTags(course).contains(two));

        QVERIFY(book.deleteCourse(course, at(16)));
        QCOMPARE(book.linkedEntries(tech).size(), 1);
        QCOMPARE(book.linkedEntries(tech).first().entry.uid, three);
        QVERIFY(book.linkedEntries(u"aikido/t2"_s).isEmpty());
    }

    // The search finds an entry by its words (accents, case), with its course; a deleted entry or
    // course, and a changed text, follow at once.
    void searchesEntries()
    {
        const auto c = made(u"search-entries"_s);
        const QString uid = c->create(u"Sommer"_s, u"2026-07-04"_s, u"2026-07-05"_s, {}, {});
        QVERIFY(c->addEntry(uid, u"Erste Zeile\nHüftwurf mit Tenkan geübt"_s));
        QVERIFY(c->addEntry(uid, u"Nur Atmung"_s));

        const QVariantList found = c->searchEntries(u"HUFTWURF tenkan"_s);
        QCOMPARE(found.size(), 1);
        const QVariantMap hit = found.first().toMap();
        QCOMPARE(hit.value(u"course"_s).toString(), uid);
        QCOMPARE(hit.value(u"title"_s).toString(), u"Sommer"_s);
        QCOMPARE(hit.value(u"first"_s).toString(), u"2026-07-04"_s);
        QCOMPARE(hit.value(u"excerpt"_s).toString(), u"Hüftwurf mit Tenkan geübt"_s);
        QVERIFY(c->searchEntries(u"hüftwurf zzz"_s).isEmpty());
        QVERIFY(c->searchEntries({}).isEmpty());
        QCOMPARE(c->searchEntries(u"a"_s, 1).size(), 1);

        QVERIFY(c->changeEntry(hit.value(u"uid"_s).toString(), u"Kote-gaeshi"_s));
        QVERIFY(c->searchEntries(u"hüftwurf"_s).isEmpty());
        QCOMPARE(c->searchEntries(u"kote gaeshi"_s).size(), 1);

        QVERIFY(c->deleteEntry(c->searchEntries(u"kote"_s).first().toMap().value(u"uid"_s).toString()));
        QVERIFY(c->searchEntries(u"kote"_s).isEmpty());
        QCOMPARE(c->searchEntries(u"atmung"_s).size(), 1);
        QVERIFY(c->remove(uid));
        QVERIFY(c->searchEntries(u"atmung"_s).isEmpty());
    }

    // The service: entries() names the links; a link is only made when asked (a text naming a
    // technique alone links nothing).
    void linksThroughTheService()
    {
        const auto c = made(u"links-service"_s);
        const QString uid = c->create(u"Sommer"_s, u"2026-07-04"_s, u"2026-07-05"_s, {}, {});
        QVERIFY(c->addEntry(uid, u"Ikkyo aus Katate-dori"_s));
        QVariantMap entry = c->entries(uid).first().toMap();
        QVERIFY(entry.value(u"techniques"_s).toList().isEmpty());

        QSignalSpy changed(c.get(), &Courses::changed);
        QVERIFY(c->linkTechnique(entry.value(u"uid"_s).toString(), u"aikido/t1"_s));
        QCOMPARE(changed.size(), 1);
        entry = c->entries(uid).first().toMap();
        QCOMPARE(entry.value(u"techniques"_s).toList(), QVariantList({u"aikido/t1"_s}));

        const QVariantMap linked = c->linkedEntries(u"aikido/t1"_s).first().toMap();
        QCOMPARE(linked.value(u"text"_s).toString(), u"Ikkyo aus Katate-dori"_s);
        QCOMPARE(linked.value(u"title"_s).toString(), u"Sommer"_s);
        QCOMPARE(linked.value(u"course"_s).toString(), uid);
        QCOMPARE(linked.value(u"first"_s).toString(), u"2026-07-04"_s);
        QCOMPARE(linked.value(u"last"_s).toString(), u"2026-07-05"_s);

        QVERIFY(c->unlinkTechnique(entry.value(u"uid"_s).toString(), u"aikido/t1"_s));
        QVERIFY(c->linkedEntries(u"aikido/t1"_s).isEmpty());

        // A notebook that is gone takes no entry (a page of it still open).
        QVERIFY(c->remove(uid));
        QVERIFY(!c->addEntry(uid, u"zu spät"_s));
        QVERIFY(!c->errorString().isEmpty());
        QVERIFY(c->entries(uid).isEmpty());
        QVERIFY(c->addEntry(c->create(u"Neu"_s, u"2026-07-04"_s, {}, {}, {}), u"geht"_s));

        // A failed link says why.
        QVERIFY(!c->linkTechnique(u"nope"_s, u"aikido/t1"_s));
        QVERIFY(!c->errorString().isEmpty());
    }

    // A file of schema 4 keeps its data and gets the links.
    void bookMigratesSchema4()
    {
        const QString path = m_dir.filePath(u"schema4.sqlite"_s);
        QString entry;
        {
            CourseBook book;
            QVERIFY(book.open(path));
            CourseBook::Course c;
            c.title = u"Alt"_s;
            c.first = c.last = QDate(2026, 5, 1);
            const QString course = book.addCourse(c, QDateTime::currentDateTimeUtc(), u"dev"_s).uid;
            entry = book.addEntry(course, u"Notiz"_s, QDateTime::currentDateTimeUtc(), u"dev"_s).uid;
        }
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, u"schema4"_s);
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(u"DROP TABLE entry_tags"_s));
            QVERIFY(q.exec(u"PRAGMA user_version = 4"_s));
            q.finish();
            db.close();
        }
        QSqlDatabase::removeDatabase(u"schema4"_s);

        CourseBook book;
        QVERIFY2(book.open(path), qPrintable(book.errorString()));
        QCOMPARE(book.allEntries().size(), 1);
        QVERIFY(book.linkedEntries(u"aikido/t1"_s).isEmpty());
        QVERIFY(book.addTag(entry, u"aikido/t1"_s, QDateTime::currentDateTimeUtc(), u"dev"_s));
        QCOMPARE(book.linkedEntries(u"aikido/t1"_s).size(), 1);
    }

    // A notebook file of schema 1 (Mitori 0.x before grades) opens as schema 2: its notebooks and
    // entries stay, the grades table and the exam columns come empty.
    void bookMigratesSchema1()
    {
        const QString path = m_dir.filePath(u"schema1.sqlite"_s);
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, u"schema1"_s);
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            for (const QString &sql : {
                     u"CREATE TABLE courses (uid TEXT PRIMARY KEY, calendar_uid TEXT NOT NULL DEFAULT '',"
                     " title TEXT NOT NULL, first TEXT NOT NULL, last TEXT NOT NULL, place TEXT NOT NULL DEFAULT '',"
                     " teacher TEXT NOT NULL DEFAULT '', info TEXT NOT NULL DEFAULT '',"
                     " announcement TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL, changed INTEGER NOT NULL,"
                     " device TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)"_s,
                     u"CREATE TABLE entries (uid TEXT PRIMARY KEY, course TEXT NOT NULL, text TEXT NOT NULL,"
                     " created INTEGER NOT NULL, changed INTEGER NOT NULL, device TEXT NOT NULL,"
                     " deleted INTEGER NOT NULL DEFAULT 0)"_s,
                     u"CREATE INDEX entries_course ON entries (course)"_s,
                     u"INSERT INTO courses (uid, title, first, last, created, changed, device)"
                     " VALUES ('c1', 'Alt', '2026-05-01', '2026-05-02', 1, 1, 'dev')"_s,
                     u"INSERT INTO entries (uid, course, text, created, changed, device) VALUES ('e1', 'c1', 'Notiz', 1, 1, 'dev')"_s,
                     u"PRAGMA user_version = 1"_s}) {
                QVERIFY2(q.exec(sql), qPrintable(q.lastError().text()));
            }
            db.close();
        }
        QSqlDatabase::removeDatabase(u"schema1"_s);

        CourseBook book;
        QVERIFY2(book.open(path), qPrintable(book.errorString()));
        const QList<CourseBook::Course> list = book.courses();
        QCOMPARE(list.size(), 1);
        QCOMPARE(list.first().title, u"Alt"_s);
        QCOMPARE(list.first().examDiscipline, QString());
        QCOMPARE(book.entries(u"c1"_s).size(), 1);
        QCOMPARE(book.entries(u"c1"_s).first().media, QString());          // schema 3
        QVERIFY(book.grades().isEmpty());
        QVERIFY(book.starts().isEmpty());                                     // schema 4
        QVERIFY(book.setStart(u"shinkitoho"_s, QDate(2024, 9, 1), QDateTime::currentDateTimeUtc(), u"dev"_s));
        QCOMPARE(book.starts().value(u"shinkitoho"_s), QDate(2024, 9, 1));
        QVERIFY(book.planExam(u"c1"_s, u"aikido"_s, u"k4"_s, QDateTime::currentDateTimeUtc()));
        QCOMPARE(book.courses().first().examGrade, u"k4"_s);
    }

    // Passed grades: one per discipline and grade, the latest day first; a planned exam goes
    // with its course and can be taken back.
    void bookKeepsGrades()
    {
        const QString path = m_dir.filePath(u"grades.sqlite"_s);
        const QDateTime at = QDateTime::currentDateTimeUtc();
        {
            CourseBook book;
            QVERIFY(book.open(path));
            QVERIFY(!book.addGrade({u""_s, u"aikido"_s, u"k5"_s, QDate(2024, 3, 2)}, at, u"dev"_s).uid.isEmpty());
            const CourseBook::Grade k4 = book.addGrade({u""_s, u"aikido"_s, u"k4"_s, QDate(2025, 3, 8), u"Mainz"_s}, at, u"dev"_s);
            QVERIFY2(!k4.uid.isEmpty(), qPrintable(book.errorString()));
            QVERIFY(book.addGrade({u""_s, u"aikido"_s, u""_s, QDate(2025, 3, 8)}, at, u"dev"_s).uid.isEmpty());
            QVERIFY(book.addGrade({u""_s, u"aikido"_s, u"k3"_s, QDate()}, at, u"dev"_s).uid.isEmpty());
            // The same grade again: a corrected day, not a second row.
            const CourseBook::Grade again = book.addGrade({u""_s, u"aikido"_s, u"k4"_s, QDate(2025, 3, 9), u"Bonn"_s},
                                                          at.addSecs(1), u"dev"_s);
            QCOMPARE(again.uid, k4.uid);
            QVERIFY(!book.addGrade({u""_s, u"daitoryu"_s, u"k5"_s, QDate(2025, 1, 1)}, at, u"dev"_s).uid.isEmpty());
        }
        CourseBook book;
        QVERIFY(book.open(path));
        QList<CourseBook::Grade> list = book.grades();
        QCOMPARE(list.size(), 3);
        QCOMPARE(list.first().grade, u"k4"_s);
        QCOMPARE(list.first().day, QDate(2025, 3, 9));
        QCOMPARE(list.first().place, u"Bonn"_s);
        QVERIFY(book.deleteGrade(list.first().uid, QDateTime::currentDateTimeUtc()));
        list = book.grades();
        QCOMPARE(list.size(), 2);
        QCOMPARE(list.first().discipline, u"daitoryu"_s);
        // Passed again after a deletion: a new row (the mark stays for sync).
        QVERIFY(!book.addGrade({u""_s, u"aikido"_s, u"k4"_s, QDate(2025, 3, 9)}, QDateTime::currentDateTimeUtc(), u"dev"_s).uid.isEmpty());
        QCOMPARE(book.grades().size(), 3);

        CourseBook::Course c;
        c.title = u"Sommerlehrgang"_s;
        c.first = QDate(2027, 7, 1);
        const QString uid = book.addCourse(c, QDateTime::currentDateTimeUtc(), u"dev"_s).uid;
        QVERIFY(book.planExam(uid, u"aikido"_s, u"k3"_s, QDateTime::currentDateTimeUtc()));
        QCOMPARE(book.courses().first().examDiscipline, u"aikido"_s);
        QVERIFY(book.planExam(uid, u""_s, u""_s, QDateTime::currentDateTimeUtc()));
        QCOMPARE(book.courses().first().examGrade, QString());
        QVERIFY(!book.planExam(u"none"_s, u"aikido"_s, u"k3"_s, QDateTime::currentDateTimeUtc()));
    }

    // Coming events (the one going on counts), by first day; the teacher from "mit …".
    void upcomingFromTheCalendar()
    {
        const auto c = made(u"upcoming"_s);
        QCOMPARE(c->calendarState(), Courses::CalendarState::Ready);
        const QVariantList list = c->upcoming();
        QCOMPARE(list.size(), 2);
        const QVariantMap soon = list.at(0).toMap();
        const QVariantMap later = list.at(1).toMap();
        QCOMPARE(soon.value(u"uid"_s).toString(), u"soon"_s);
        QCOMPARE(later.value(u"teacher"_s).toString(), u"M. D. Nakajima Shihan"_s);
        QCOMPARE(later.value(u"announcement"_s).toString(), u"https://example.org/a?b=1&c=%2F"_s);
        QCOMPARE(later.value(u"last"_s).toString(), QDate::currentDate().addDays(31).toString(Qt::ISODate));
        QVERIFY(later.value(u"notebook"_s).toString().isEmpty());
    }

    // The calendar stays on the device: a new start shows it without network; a failed load
    // keeps it.
    void cacheOffline()
    {
        {
            const auto c = made(u"cache"_s);
            QCOMPARE(c->upcoming().size(), 2);
        }
        Courses offline(m_dir.filePath(u"cache.sqlite"_s), QUrl::fromLocalFile(m_dir.filePath(u"missing.ics"_s)),
                        m_dir.filePath(u"cache-cache.ics"_s), m_catalog);
        QCOMPARE(offline.calendarState(), Courses::CalendarState::Ready);
        QCOMPARE(offline.upcoming().size(), 2);
        QSignalSpy spy(&offline, &Courses::calendarChanged);
        offline.reload();
        QVERIFY(spy.wait(5000) || offline.calendarState() != Courses::CalendarState::Loading);
        while (offline.calendarState() == Courses::CalendarState::Loading) {
            QVERIFY(spy.wait(5000));
        }
        QCOMPARE(offline.calendarState(), Courses::CalendarState::Failed);
        QCOMPARE(offline.upcoming().size(), 2);
        // Fresh: Older does not load again.
        offline.reload(Courses::Reload::Older);
        QVERIFY(offline.calendarState() != Courses::CalendarState::Loading);
    }

    // A notebook made from an event keeps the event's data; asked again, the same notebook.
    void notebookFromAnEvent()
    {
        const auto c = made(u"notebook"_s);
        QSignalSpy changed(c.get(), &Courses::changed);
        const QString uid = c->notebookFor(u"later"_s);
        QVERIFY(!uid.isEmpty());
        QCOMPARE(c->notebookFor(u"later"_s), uid);
        QCOMPARE(changed.count(), 1);
        QVERIFY(c->notebookFor(u"no-such-event"_s).isEmpty());
        const QVariantMap n = c->notebook(uid);
        QCOMPARE(n.value(u"title"_s).toString(), u"Daitoryu"_s);
        QCOMPARE(n.value(u"place"_s).toString(), u"Siebeldingen"_s);
        QCOMPARE(n.value(u"teacher"_s).toString(), u"M. D. Nakajima Shihan"_s);
        QCOMPARE(n.value(u"calendarUid"_s).toString(), u"later"_s);

        QVERIFY(c->addEntry(uid, u"Kote-gaeshi: erst ausweichen"_s));
        QVERIFY(!c->addEntry(uid, u"  "_s));
        QCOMPARE(c->entries(uid).size(), 1);
        QCOMPARE(c->notebook(uid).value(u"entries"_s).toInt(), 1);
        const QVariantMap row = c->upcoming().at(1).toMap();
        QCOMPARE(row.value(u"notebook"_s).toString(), uid);
        QCOMPARE(row.value(u"entries"_s).toInt(), 1);
        const QString entry = c->entries(uid).first().toMap().value(u"uid"_s).toString();
        QVERIFY(c->changeEntry(entry, u"Kote-gaeshi: ausweichen, dann führen"_s));
        QCOMPARE(c->entries(uid).first().toMap().value(u"text"_s).toString(), u"Kote-gaeshi: ausweichen, dann führen"_s);
        QVERIFY(c->deleteEntry(entry));
        QVERIFY(c->entries(uid).isEmpty());
    }

    // A notebook without an event; deleting it leaves the calendar alone.
    void ownNotebook()
    {
        const auto c = made(u"own"_s);
        const QString uid = c->create(u"Training mit Gastlehrer"_s, u"2026-11-07"_s, u"2026-11-08"_s,
                                      u" Dojo Weimar "_s, u"Gast"_s);
        QVERIFY(!uid.isEmpty());
        QCOMPARE(c->notebooks().size(), 1);
        QCOMPARE(c->notebook(uid).value(u"place"_s).toString(), u"Dojo Weimar"_s);
        QVERIFY(c->notebook(uid).value(u"calendarUid"_s).toString().isEmpty());
        QCOMPARE(c->notebook(uid).value(u"last"_s).toString(), u"2026-11-08"_s);
        QVERIFY(c->create(u"Ohne Tag"_s, u"7.11.2026"_s, {}, {}, {}).isEmpty());   // not ISO
        QVERIFY(c->create(u""_s, u"2026-11-07"_s, {}, {}, {}).isEmpty());
        QVERIFY(!c->errorString().isEmpty());
        QVERIFY(c->remove(uid));
        QVERIFY(c->errorString().isEmpty());
        QVERIFY(c->notebooks().isEmpty());
        QCOMPARE(c->upcoming().size(), 2);
    }

    // Meine Grade: the next grade follows the highest passed; its waiting time comes from the
    // programme data (aikido: 1 year after 5. Kyu; Shinki Toho Shoden: 2 years after the start).
    void gradesAndWaiting()
    {
        const auto c = made(u"waiting"_s);
        const auto state = [&](const QString &d, const QString &g, const QString &day = {}) {
            return c->waiting(d, g, day).value(u"state"_s).value<Courses::Wait>();
        };
        QCOMPARE(c->nextGrade(u"aikido"_s), u"k5"_s);
        QCOMPARE(state(u"aikido"_s, u"k5"_s), Courses::Wait::First);
        QCOMPARE(state(u"aikido"_s, u"k4"_s), Courses::Wait::Unknown);
        QCOMPARE(c->waiting(u"aikido"_s, u"k4"_s).value(u"previous"_s).toString(), u"5. Kyu"_s);
        QCOMPARE(c->waiting(u"aikido"_s, u"k4"_s).value(u"years"_s).toInt(), 1);
        QCOMPARE(state(u"shinkitoho"_s, u"shoden"_s), Courses::Wait::FromStart);
        QCOMPARE(c->waiting(u"shinkitoho"_s, u"shoden"_s).value(u"years"_s).toInt(), 2);
        // With the start of training: 2 years after it; removed, unknown again.
        QVERIFY(c->countsFromStart(u"shinkitoho"_s));
        QVERIFY(!c->countsFromStart(u"aikido"_s));
        QVERIFY(!c->setTrainingStart(u"shinkitoho"_s, u"1.9.2024"_s));
        QVERIFY(!c->setTrainingStart(u"karate"_s, u"2024-09-01"_s));
        QVERIFY(c->setTrainingStart(u"shinkitoho"_s, u"2024-09-01"_s));
        QCOMPARE(c->trainingStart(u"shinkitoho"_s), u"2024-09-01"_s);
        QCOMPARE(state(u"shinkitoho"_s, u"shoden"_s), Courses::Wait::Earliest);
        QCOMPARE(c->waiting(u"shinkitoho"_s, u"shoden"_s).value(u"earliest"_s).toString(), u"2026-09-01"_s);
        QCOMPARE(state(u"shinkitoho"_s, u"shoden"_s, u"2026-08-31"_s), Courses::Wait::TooEarly);
        QVERIFY(c->setTrainingStart(u"shinkitoho"_s, u"2024-10-01"_s));     // corrected
        QCOMPARE(c->trainingStart(u"shinkitoho"_s), u"2024-10-01"_s);
        QVERIFY(c->setTrainingStart(u"shinkitoho"_s, {}));
        QCOMPARE(c->trainingStart(u"shinkitoho"_s), QString());
        QCOMPARE(state(u"shinkitoho"_s, u"shoden"_s), Courses::Wait::FromStart);
        QVERIFY(c->waiting(u"aikido"_s, u"x9"_s).isEmpty());
        const QVariantList ladder = c->ladder(u"shinkitoho"_s);
        QCOMPARE(ladder.size(), 6);                                 // no Hôshu
        QCOMPARE(ladder.last().toMap().value(u"id"_s).toString(), u"kaiden"_s);

        QVERIFY(!c->addGrade(u"aikido"_s, u"x9"_s, u"2025-03-08"_s, {}));
        QVERIFY(!c->addGrade(u"aikido"_s, u"k5"_s, u"8.3.2025"_s, {}));
        QVERIFY(c->addGrade(u"aikido"_s, u"k5"_s, u"2025-03-08"_s, u"Mainz"_s));
        QCOMPARE(c->grades().size(), 1);
        const QVariantMap passed = c->grades().first().toMap();
        QCOMPARE(passed.value(u"name"_s).toString(), u"5. Kyu"_s);
        QCOMPARE(passed.value(u"day"_s).toString(), u"2025-03-08"_s);
        QVERIFY(c->ladder(u"aikido"_s).first().toMap().value(u"passed"_s).toBool());
        QCOMPARE(c->nextGrade(u"aikido"_s), u"k4"_s);
        QCOMPARE(state(u"aikido"_s, u"k4"_s), Courses::Wait::Earliest);
        QCOMPARE(c->waiting(u"aikido"_s, u"k4"_s).value(u"earliest"_s).toString(), u"2026-03-08"_s);
        QCOMPARE(state(u"aikido"_s, u"k4"_s, u"2026-03-07"_s), Courses::Wait::TooEarly);
        QCOMPARE(state(u"aikido"_s, u"k4"_s, u"2026-03-08"_s), Courses::Wait::Fits);

        // A later grade entered without the ones before: the next one follows it.
        QVERIFY(c->addGrade(u"aikido"_s, u"k2"_s, u"2027-03-08"_s, {}));
        QCOMPARE(c->nextGrade(u"aikido"_s), u"k1"_s);
        QVERIFY(c->addGrade(u"daitoryu"_s, u"ok"_s, u"2027-03-08"_s, {}));
        QCOMPARE(c->nextGrade(u"daitoryu"_s), QString());           // the last one
        QVERIFY(c->removeGrade(passed.value(u"uid"_s).toString()));
        QCOMPARE(state(u"aikido"_s, u"k4"_s), Courses::Wait::Unknown);
    }

    // An exam planned on a course: the next one whose course has not ended, per discipline.
    void plannedExam()
    {
        const auto c = made(u"exam"_s);
        QVERIFY(c->nextExam().isEmpty());
        const QString later = c->notebookFor(u"later"_s);
        QVERIFY(c->planExam(later, u"daitoryu"_s, u"k4"_s));
        QVERIFY(!c->planExam(later, u"daitoryu"_s, u"x9"_s));
        QCOMPARE(c->notebook(later).value(u"examGrade"_s).toString(), u"k4"_s);
        QCOMPARE(c->notebook(later).value(u"examName"_s).toString(), u"Daitoryu 4. Kyu"_s);
        QVariantMap next = c->nextExam();
        QCOMPARE(next.value(u"course"_s).toString(), later);
        QCOMPARE(next.value(u"days"_s).toInt(), 30);
        QCOMPARE(next.value(u"name"_s).toString(), u"Daitoryu 4. Kyu"_s);
        QCOMPARE(next.value(u"place"_s).toString(), u"Siebeldingen"_s);
        QVERIFY(c->nextExam(u"aikido"_s).isEmpty());

        // A course going on comes first; one that has ended does not count.
        const QString soon = c->notebookFor(u"soon"_s);
        QVERIFY(c->planExam(soon, u"aikido"_s, u"k5"_s));
        QCOMPARE(c->nextExam().value(u"course"_s).toString(), soon);
        QCOMPARE(c->nextExam().value(u"days"_s).toInt(), 0);
        const auto day = [](int offset) { return QDate::currentDate().addDays(offset).toString(Qt::ISODate); };
        const QString past = c->create(u"Vorbei"_s, day(-10), day(-9), {}, {});
        QVERIFY(c->planExam(past, u"daitoryu"_s, u"k3"_s));
        QCOMPARE(c->nextExam(u"daitoryu"_s).value(u"course"_s).toString(), later);

        QVERIFY(c->planExam(later, {}, {}));
        QVERIFY(c->notebook(later).value(u"examGrade"_s).toString().isEmpty());
        QVERIFY(c->nextExam(u"daitoryu"_s).isEmpty());
    }

    // The desktop's calendar gets a whole-day event; folded, escaped, the end exclusive. It
    // reads back as the same event.
    void deviceCalendarIcs()
    {
        const DeviceCalendar::Event e{u"u-1"_s, u"Aikido, Dan; Lehrgang"_s, QDate(2026, 3, 21), QDate(2026, 3, 22),
                                      u"Heidelberg"_s, u"mit der Prüfer-Kommission\nSamstag 09.30 Meditation, "_s + QString(60, QLatin1Char('x'))};
        const QByteArray ics = DeviceCalendar::ics(e);
        QVERIFY(ics.contains("DTSTART;VALUE=DATE:20260321\r\n"));
        QVERIFY(ics.contains("DTEND;VALUE=DATE:20260323\r\n"));
        QVERIFY(ics.contains("SUMMARY:Aikido\\, Dan\\; Lehrgang\r\n"));
        for (const QByteArray &line : ics.split('\n')) {
            QVERIFY2(line.size() <= 76, line.constData());       // 75 octets and the CR
        }
        const QList<IcsReader::Event> back = IcsReader::read(ics);
        QCOMPARE(back.size(), 1);
        QCOMPARE(back.first().title, e.title);
        QCOMPARE(back.first().last, e.last);
        QCOMPARE(back.first().description, e.description);
    }

    // A course of one's own goes to the device's calendar with the notebook's uid (RFC 5545 needs one).
    void ownCourseHasUid()
    {
        const auto c = made(u"uid"_s);
        const QString uid = c->create(u"Training"_s, u"2026-11-07"_s, {}, {}, {});
        QCOMPARE(c->deviceEvent(uid).uid, uid);
        const QString fromEvent = c->notebookFor(u"later"_s);
        QCOMPARE(c->deviceEvent(fromEvent).uid, u"later"_s);
        QVERIFY(DeviceCalendar::ics(c->deviceEvent(uid)).contains("UID:" + uid.toLatin1() + "\r\n"));
    }

    // Grade names follow the data's language; a LanguageChange to another one is a change (the
    // start page's planned exam reads it anew), one that keeps it is none.
    void gradeNamesInLanguage()
    {
        const auto c = made(u"language"_s);
        QVERIFY(c->addGrade(u"aikido"_s, u"k5"_s, u"2025-03-08"_s, {}));
        const QString uid = c->create(u"Training"_s, QDate::currentDate().addDays(10).toString(Qt::ISODate), {}, {}, {});
        QVERIFY(c->planExam(uid, u"aikido"_s, u"k4"_s));
        QSignalSpy spy(c.get(), &Courses::changed);
        const int revision = c->revision();
        QEvent event(QEvent::LanguageChange);

        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);
        QCOMPARE(spy.count(), 0);
        Catalog::setLanguage(Catalog::Language::English);
        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);
        const QString passed = c->grades().first().toMap().value(u"name"_s).toString();
        const QString step = c->ladder(u"aikido"_s).at(1).toMap().value(u"name"_s).toString();
        const QString exam = c->nextExam().value(u"name"_s).toString();
        Catalog::setLanguage(Catalog::Language::German);
        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);

        QCOMPARE(passed, u"5th Kyu"_s);
        QCOMPARE(step, u"4th Kyu"_s);
        QCOMPARE(exam, u"Aikido 4th Kyu"_s);
        QCOMPARE(spy.count(), 2);
        QCOMPARE(c->revision(), revision + 2);
        QCOMPARE(c->grades().first().toMap().value(u"name"_s).toString(), u"5. Kyu"_s);
    }

    void teacher()
    {
        QCOMPARE(Courses::teacherOf(u"mit Petra und Bernd Hubl"_s), u"Petra und Bernd Hubl"_s);
        QCOMPARE(Courses::teacherOf(u"Mit  M. D. Nakajima Shihan\nSamstag"_s), u"M. D. Nakajima Shihan"_s);
        QVERIFY(Courses::teacherOf(u"Samstag\nmit X"_s).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TstCourses)
#include "tst_courses.moc"
