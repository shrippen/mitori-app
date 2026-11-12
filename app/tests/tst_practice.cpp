#include <ctime>

#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QSqlDatabase>
#include <QScopeGuard>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>
#include <QTimeZone>

#include "practice.h"
#include "practicelog.h"

class TstPractice : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        QSettings().clear();
    }

    void logKeepsEveryRating()
    {
        QTemporaryDir dir;
        PracticeLog log;
        QVERIFY2(log.open(dir.filePath(QStringLiteral("log.sqlite"))), qPrintable(log.errorString()));
        const QDateTime t = QDateTime(QDate(2026, 11, 1), QTime(18, 30), QTimeZone::UTC);
        QVERIFY(!log.add(QStringLiteral("a"), 2, t, QStringLiteral("phone")).uid.isEmpty());
        QVERIFY(!log.add(QStringLiteral("a"), 3, t.addDays(1), QStringLiteral("tablet")).uid.isEmpty());
        QVERIFY(!log.add(QStringLiteral("b"), 1, t, QStringLiteral("phone")).uid.isEmpty());
        QVERIFY(log.add(QStringLiteral("b"), 5, t, QStringLiteral("phone")).uid.isEmpty());
        QVERIFY(log.add(QStringLiteral("b"), 0, t, QStringLiteral("phone")).uid.isEmpty());

        const auto latest = log.latest();
        QCOMPARE(latest.size(), 2);
        QCOMPARE(latest.value(QStringLiteral("a")).level, 3);
        QCOMPARE(latest.value(QStringLiteral("a")).device, QStringLiteral("tablet"));
        QCOMPARE(latest.value(QStringLiteral("a")).at, t.addDays(1));
        const auto history = log.history(QStringLiteral("a"));
        QCOMPARE(history.size(), 2);
        QCOMPARE(history.first().level, 2);
    }

    // A rating is a tap: written ahead (WAL), not three file syncs of a journal (30 ms on an SSD).
    void logWritesAhead()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        PracticeLog log;
        QVERIFY(log.open(path));
        QVERIFY(!log.add(QStringLiteral("a"), 2, QDateTime::currentDateTimeUtc(), QStringLiteral("phone")).uid.isEmpty());
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("peek"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(QStringLiteral("PRAGMA journal_mode")) && q.next());
            QCOMPARE(q.value(0).toString(), QStringLiteral("wal"));
            QVERIFY(q.exec(QStringLiteral("SELECT COUNT(*) FROM ratings")) && q.next());
            QCOMPARE(q.value(0).toInt(), 1);
        }
        QSqlDatabase::removeDatabase(QStringLiteral("peek"));
    }

    // How many techniques were practised (rated) on each local day: each technique once a day.
    void practisedPerDay()
    {
        QTemporaryDir dir;
        PracticeLog log;
        QVERIFY(log.open(dir.filePath(QStringLiteral("log.sqlite"))));
        const QDateTime t = QDateTime(QDate(2026, 11, 1), QTime(12, 0), QTimeZone::UTC);
        log.add(QStringLiteral("a"), 2, t, QStringLiteral("phone"));
        log.add(QStringLiteral("a"), 3, t.addSecs(60), QStringLiteral("phone"));    // the same technique again
        log.add(QStringLiteral("b"), 1, t.addSecs(120), QStringLiteral("phone"));
        log.add(QStringLiteral("a"), 4, t.addDays(3), QStringLiteral("phone"));
        log.add(QStringLiteral("c"), 4, t.addDays(-40), QStringLiteral("phone"));   // before the range
        const QHash<QDate, int> days = log.practisedPerDay(t.addDays(-30));
        QCOMPARE(days.size(), 2);
        QCOMPARE(days.value(t.toLocalTime().date()), 2);
        QCOMPARE(days.value(t.addDays(3).toLocalTime().date()), 1);

        // The service: {"YYYY-MM-DD": count} for the last days up to today.
        Practice practice(dir.filePath(QStringLiteral("mitori.sqlite")));
        practice.rate(QStringLiteral("a"), 2);
        practice.rate(QStringLiteral("b"), 2);
        practice.rate(QStringLiteral("b"), 3);
        const QVariantMap map = practice.practisedPerDay(30);
        QCOMPARE(map.size(), 1);
        QCOMPARE(map.value(QDate::currentDate().toString(Qt::ISODate)).toInt(), 2);

        // A discipline's entries only ("aikido/"), and a calendar year (All years).
        QCOMPARE(log.practisedPerDay(t.addDays(-30), QStringLiteral("a")).value(t.toLocalTime().date()), 1);
        // Up to a day: what came later is not read at all (All years asks per year).
        QCOMPARE(log.practisedPerDay(t.addDays(-30), {}, t.addDays(1)).size(), 1);
        QCOMPARE(log.firstRating(), t.addDays(-40));
        practice.rate(QStringLiteral("aikido/k5/x"), 3);
        const int year = QDate::currentDate().year();
        QCOMPARE(practice.practisedInYear(year, QStringLiteral("aikido")).size(), 1);
        QCOMPARE(practice.practisedInYear(year, QStringLiteral("aikido")).first().toInt(), 1);
        QCOMPARE(practice.practisedInYear(year, {}).first().toInt(), 3);
        QVERIFY(practice.practisedInYear(year - 1, {}).isEmpty());
        QCOMPARE(practice.firstYear(), year);
    }

    // Days end at local midnight, also on the day summer time ends (25 h): the log walks the
    // ratings in time order and finds each day's end once.
    void practisedPerDayAtMidnight()
    {
        const QByteArray zone = qgetenv("TZ");
        qputenv("TZ", "CET-1CEST,M3.5.0,M10.5.0/3");    // Central Europe, no tzdata needed
        tzset();
        // Back to the zone before, also when a check fails.
        const auto restore = qScopeGuard([zone] {
            if (zone.isNull()) {
                qunsetenv("TZ");
            } else {
                qputenv("TZ", zone);
            }
            tzset();
        });
        QTemporaryDir dir;
        PracticeLog log;
        QVERIFY(log.open(dir.filePath(QStringLiteral("log.sqlite"))));
        const auto at = [](int day, int hour, int minute) {
            return QDateTime(QDate(2026, 10, day), QTime(hour, minute));
        };
        log.add(QStringLiteral("a"), 2, at(24, 23, 30), QStringLiteral("phone"));
        log.add(QStringLiteral("a"), 2, at(25, 0, 30), QStringLiteral("phone"));
        log.add(QStringLiteral("b"), 2, at(25, 23, 59), QStringLiteral("phone"));
        log.add(QStringLiteral("a"), 2, at(26, 0, 0), QStringLiteral("phone"));
        log.add(QStringLiteral("b"), 2, at(26, 0, 1), QStringLiteral("phone"));
        log.add(QStringLiteral("b"), 3, at(26, 9, 0), QStringLiteral("phone"));    // b again that day
        const QHash<QDate, int> days = log.practisedPerDay(at(20, 0, 0));
        QCOMPARE(days.size(), 3);
        QCOMPARE(days.value(QDate(2026, 10, 24)), 1);
        QCOMPARE(days.value(QDate(2026, 10, 25)), 2);
        QCOMPARE(days.value(QDate(2026, 10, 26)), 2);
    }

    // The calendars after ratings now, an exam round and a merged log: the same as a fresh read of
    // the log (Practice keeps the years it read and adds to them). Ratings of past years stay.
    void calendarsFollowRatings()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("mitori.sqlite"));
        const QDateTime now = QDateTime::currentDateTimeUtc();
        const QStringList ids{QStringLiteral("aikido/k5/a"), QStringLiteral("aikido/k5/b"),
                              QStringLiteral("daitoryu/k5/a"), QStringLiteral("shinkitoho/k5/a")};
        {
            PracticeLog log;
            QVERIFY(log.open(path));
            for (int day = 0; day < 800; day += 3) {
                for (int i = 0; i <= day % 4; ++i) {
                    log.add(ids.at((day + i) % ids.size()), 1 + i, now.addDays(-day).addSecs(-60 * i), QStringLiteral("d"));
                }
            }
        }
        Practice practice(path);
        const int year = QDate::currentDate().year();
        const QStringList disciplines{{}, QStringLiteral("aikido"), QStringLiteral("daitoryu")};
        // Every calendar the pages show: Today (84 days), statistics (182), all years.
        const auto calendars = [&](const Practice &p) {
            QVariantList all{p.practisedPerDay(84), p.practisedPerDay(182), p.practisedPerDay(1000), p.firstYear()};
            for (int y = year - 3; y <= year; ++y) {
                for (const QString &d : disciplines) {
                    all << p.practisedInYear(y, d);
                }
            }
            return all;
        };
        QCOMPARE(calendars(practice), calendars(Practice(path)));

        // A rating now: today changes, past days not.
        QSignalSpy history(&practice, &Practice::historyChanged);
        QVERIFY(practice.rate(ids.at(0), 3));
        QVERIFY(practice.rate(ids.at(0), 4));       // the same technique again: counts once
        QVERIFY(practice.rate(QStringLiteral("aikido/k4/new"), 2));
        const QVariantList round{QVariantMap{{QStringLiteral("id"), ids.at(2)}, {QStringLiteral("level"), 3}},
                                 QVariantMap{{QStringLiteral("id"), QStringLiteral("daitoryu/k4/new")}, {QStringLiteral("level"), 1}}};
        QVERIFY(practice.saveRound(QStringLiteral("daitoryu"), QStringLiteral("k5"), round));
        QCOMPARE(history.count(), 0);
        QCOMPARE(calendars(practice), calendars(Practice(path)));

        // A merged log (a backup, sync): read anew, past days included.
        {
            PracticeLog other;
            QVERIFY(other.open(path));
            other.add(QStringLiteral("shinkitoho/k5/b"), 2, now.addYears(-3), QStringLiteral("other"));
            other.add(QStringLiteral("aikido/k5/c"), 2, now.addDays(-1), QStringLiteral("other"));
        }
        practice.refresh();
        QCOMPARE(history.count(), 1);
        QCOMPARE(calendars(practice), calendars(Practice(path)));
        QCOMPARE(practice.firstYear(), now.addYears(-3).toLocalTime().date().year());
    }

    // The same time stamp twice: the later insert wins (two taps within a millisecond).
    void sameTimeLaterWins()
    {
        QTemporaryDir dir;
        PracticeLog log;
        QVERIFY(log.open(dir.filePath(QStringLiteral("log.sqlite"))));
        const QDateTime t = QDateTime::currentDateTimeUtc();
        log.add(QStringLiteral("a"), 2, t, QStringLiteral("d"));
        log.add(QStringLiteral("a"), 4, t, QStringLiteral("d"));
        QCOMPARE(log.latest().value(QStringLiteral("a")).level, 4);
    }

    void reopenKeepsData()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        {
            PracticeLog log;
            QVERIFY(log.open(path));
            log.add(QStringLiteral("a"), 3, QDateTime::currentDateTimeUtc(), QStringLiteral("d"));
        }
        PracticeLog again;
        QVERIFY(again.open(path));
        QCOMPARE(again.latest().value(QStringLiteral("a")).level, 3);
    }

    // A log written by a newer Mitori is not touched.
    void newerSchemaRefused()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("newer"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery(db).exec(QStringLiteral("PRAGMA user_version = 99"));
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("newer"));
        PracticeLog log;
        QVERIFY(!log.open(path));
        QVERIFY(log.errorString().contains(QStringLiteral("99")));
    }

    // A merged or edited log may carry other levels: they do not count (and cannot overrun counts()).
    void levelsOutsideOneToFourIgnored()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        {
            PracticeLog log;
            QVERIFY(log.open(path));
            log.add(QStringLiteral("a"), 2, QDateTime::currentDateTimeUtc().addSecs(-60), QStringLiteral("d"));
        }
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("edit"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(QStringLiteral("INSERT INTO ratings VALUES ('x', 'a', 5, %1, 'd'), ('y', 'b', -1, %1, 'd')")
                               .arg(QDateTime::currentMSecsSinceEpoch())));
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("edit"));
        Practice practice(path);
        QCOMPARE(practice.level(QStringLiteral("a")), 2);
        QCOMPARE(practice.level(QStringLiteral("b")), 0);
        QCOMPARE(practice.counts({QStringLiteral("a"), QStringLiteral("b")}), (QVariantList{1, 0, 1, 0, 0}));
    }

    // A log that cannot be opened, or a rating that cannot be saved, says so.
    void errorsAreReported()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        {
            Practice practice(path);
            QSignalSpy errors(&practice, &Practice::errorChanged);
            QVERIFY(practice.rate(QStringLiteral("a"), 1));
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("break"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QVERIFY(QSqlQuery(db).exec(QStringLiteral("DROP TABLE ratings")));
            db.close();
            QSqlDatabase::removeDatabase(QStringLiteral("break"));
            QVERIFY(!practice.rate(QStringLiteral("a"), 2));
            QCOMPARE(errors.count(), 1);
            QVERIFY(!practice.errorString().isEmpty());
            QCOMPARE(practice.level(QStringLiteral("a")), 1);
        }
        QFile::remove(path);
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("newer2"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery(db).exec(QStringLiteral("PRAGMA user_version = 99"));
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("newer2"));
        Practice newer(path);
        QVERIFY(newer.errorString().contains(QStringLiteral("99")));
        QVERIFY(!newer.rate(QStringLiteral("a"), 1));
    }

    void serviceRatesAndCounts()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("mitori.sqlite"));
        {
            Practice practice(path);
            QCOMPARE(practice.errorString(), QString());
            QSignalSpy spy(&practice, &Practice::changed);
            QCOMPARE(practice.level(QStringLiteral("a")), 0);
            QVERIFY(!practice.lastRated(QStringLiteral("a")).isValid());
            practice.rate(QStringLiteral("a"), 3);
            practice.rate(QStringLiteral("b"), 1);
            practice.rate(QStringLiteral("b"), 1);
            QVERIFY(!practice.rate(QStringLiteral("c"), 9));
            QCOMPARE(spy.count(), 3);
            QCOMPARE(practice.revision(), 3);
            QCOMPARE(practice.level(QStringLiteral("a")), 3);
            QVERIFY(practice.lastRated(QStringLiteral("a")).secsTo(QDateTime::currentDateTime()) < 5);
            const QVariantList n = practice.counts({QStringLiteral("a"), QStringLiteral("b"), QStringLiteral("c"), QStringLiteral("d")});
            QCOMPARE(n, (QVariantList{2, 1, 0, 1, 0}));
            // A place on the technique map: the best of its entries.
            QCOMPARE(practice.bestLevel({QStringLiteral("b"), QStringLiteral("a"), QStringLiteral("c")}), 3);
            QCOMPARE(practice.bestLevel({QStringLiteral("c")}), 0);
            QCOMPARE(practice.levelNames().size(), 5);
        }
        Practice again(path);
        QCOMPARE(again.level(QStringLiteral("b")), 1);
    }

    void ratingHistoryKeepsTheLastRatings()
    {
        QTemporaryDir dir;
        Practice practice(dir.filePath(QStringLiteral("mitori.sqlite")));
        const QString a = QStringLiteral("a");

        QVERIFY(practice.ratingHistory(a, 8).isEmpty());

        for (const int level : {1, 2, 2, 3, 4}) {
            practice.rate(a, level);
        }
        practice.rate(QStringLiteral("b"), 1);

        // Oldest first, the last `count` only, other entries left out.
        const QVariantList all = practice.ratingHistory(a, 8);
        QCOMPARE(all.size(), 5);
        QCOMPARE(all.first().toMap().value(QStringLiteral("level")).toInt(), 1);
        QCOMPARE(all.last().toMap().value(QStringLiteral("level")).toInt(), 4);

        const QVariantList last = practice.ratingHistory(a, 2);
        QCOMPARE(last.size(), 2);
        QCOMPARE(last.first().toMap().value(QStringLiteral("level")).toInt(), 3);
        QCOMPARE(last.last().toMap().value(QStringLiteral("level")).toInt(), 4);

        // The day is the local one, as a date string.
        const QVariantMap row = last.last().toMap();
        QCOMPARE(row.value(QStringLiteral("day")).toString(), QDate::currentDate().toString(Qt::ISODate));
        QVERIFY(row.value(QStringLiteral("at")).toDateTime().isValid());
    }

    void dueAndIntervals()
    {
        QTemporaryDir dir;
        Practice practice(dir.filePath(QStringLiteral("mitori.sqlite")));
        QSignalSpy spy(&practice, &Practice::intervalsChanged);
        QCOMPARE(practice.intervals(), (QVariantList{2, 4, 14, 35}));
        practice.setIntervals({1, 0, 500, 7});
        QCOMPARE(spy.count(), 1);
        QCOMPARE(practice.intervals(), (QVariantList{1, 1, 365, 7}));
        practice.setIntervals({1, 2});
        QCOMPARE(spy.count(), 1);

        // Rated today: practised, not due; two new ones of the current grade.
        practice.rate(QStringLiteral("a"), 1);
        QVERIFY(practice.ratedToday(QStringLiteral("a")));
        QVERIFY(!practice.ratedToday(QStringLiteral("b")));
        const QVariantList candidates{
            QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("current"), true}},
            QVariantMap{{QStringLiteral("id"), QStringLiteral("b")}, {QStringLiteral("current"), true}, {QStringLiteral("title"), QStringLiteral("B")}},
            QVariantMap{{QStringLiteral("id"), QStringLiteral("c")}, {QStringLiteral("current"), false}},
            QVariantMap{{QStringLiteral("id"), QStringLiteral("d")}, {QStringLiteral("current"), true}}};
        // "a" was new and is practised today: one of the day's two new places is taken.
        const QVariantList due = practice.due(candidates);
        QCOMPARE(due.size(), 1);
        QCOMPARE(due.first().toMap().value(QStringLiteral("id")).toString(), QStringLiteral("b"));
        QCOMPARE(due.first().toMap().value(QStringLiteral("title")).toString(), QStringLiteral("B"));
        QCOMPARE(due.first().toMap().value(QStringLiteral("level")).toInt(), 0);
        practice.setIntervals({2, 4, 14, 35});
    }

    // After a restart the log still knows what was new today (firstRated from the database).
    void newTodayAfterRestart()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("mitori.sqlite"));
        const QVariantList candidates{
            QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("current"), true}},
            QVariantMap{{QStringLiteral("id"), QStringLiteral("b")}, {QStringLiteral("current"), true}},
            QVariantMap{{QStringLiteral("id"), QStringLiteral("c")}, {QStringLiteral("current"), true}}};
        {
            Practice practice(path);
            practice.rate(QStringLiteral("a"), 1);
            practice.rate(QStringLiteral("b"), 2);
        }
        Practice again(path);
        QVERIFY(again.due(candidates).isEmpty());
    }

    void notesKeepTheirHistory()
    {
        QTemporaryDir dir;
        PracticeLog log;
        QVERIFY(log.open(dir.filePath(QStringLiteral("log.sqlite"))));
        const QDateTime t = QDateTime(QDate(2026, 11, 2), QTime(18, 0), QTimeZone::UTC);
        QCOMPARE(log.noteCount(), 0);
        QVERIFY(!log.newestNote());
        const auto a = log.addNote(QStringLiteral("e"), QStringLiteral("  Hüfte früher drehen  "), t, QStringLiteral("phone"));
        QVERIFY(!a.uid.isEmpty());
        QCOMPARE(a.text, QStringLiteral("Hüfte früher drehen"));
        QVERIFY(log.addNote(QStringLiteral("e"), QStringLiteral("   "), t, QStringLiteral("phone")).uid.isEmpty());
        const auto b = log.addNote(QStringLiteral("e"), QStringLiteral("Blick beim Partner"), t.addSecs(60), QStringLiteral("phone"));
        QVERIFY(log.changeNote(a.uid, QStringLiteral("Hüfte früher"), t.addSecs(120)));
        QVERIFY(!log.changeNote(a.uid, QStringLiteral(" "), t.addSecs(130)));
        QCOMPARE(log.notes(QStringLiteral("e")).size(), 2);
        QCOMPARE(log.notes(QStringLiteral("e")).first().text, QStringLiteral("Hüfte früher"));
        QCOMPARE(log.notes(QStringLiteral("e")).first().changed, t.addSecs(120));
        QCOMPARE(log.lastNotes().value(QStringLiteral("e")).uid, b.uid);
        QCOMPARE(log.noteCount(), 2);
        QCOMPARE(log.newestNote()->uid, b.uid);
        QVERIFY(log.deleteNote(b.uid, t.addSecs(180)));
        QVERIFY(!log.deleteNote(b.uid, t.addSecs(190)));
        QVERIFY(!log.changeNote(b.uid, QStringLiteral("again"), t.addSecs(200)));
        QCOMPARE(log.notes(QStringLiteral("e")).size(), 1);
        QCOMPARE(log.lastNotes().value(QStringLiteral("e")).uid, a.uid);
        QCOMPARE(log.noteCount(), 1);
        QCOMPARE(log.newestNote()->uid, a.uid);
    }

    // A log of schema 1 (ratings only) gets the notes table and keeps its ratings.
    void migratesFromSchemaOne()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("v1"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(QStringLiteral("CREATE TABLE ratings (uid TEXT PRIMARY KEY, entry TEXT NOT NULL,"
                                          " level INTEGER NOT NULL, at INTEGER NOT NULL, device TEXT NOT NULL)")));
            QVERIFY(q.exec(QStringLiteral("INSERT INTO ratings VALUES ('x', 'e', 3, %1, 'd')").arg(QDateTime::currentMSecsSinceEpoch())));
            QVERIFY(q.exec(QStringLiteral("PRAGMA user_version = 1")));
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("v1"));
        Practice practice(path);
        QCOMPARE(practice.errorString(), QString());
        QCOMPARE(practice.level(QStringLiteral("e")), 3);
        QSignalSpy spy(&practice, &Practice::notesChanged);
        QVERIFY(practice.addNote(QStringLiteral("e"), QStringLiteral("Kreis größer")));
        QCOMPARE(spy.count(), 1);
        QCOMPARE(practice.lastNote(QStringLiteral("e")).value(QStringLiteral("text")).toString(), QStringLiteral("Kreis größer"));
        QCOMPARE(practice.notesToday(QStringLiteral("e")).size(), 1);
        QVERIFY(practice.notesToday(QStringLiteral("other")).isEmpty());
        const QString uid = practice.notes(QStringLiteral("e")).first().toMap().value(QStringLiteral("uid")).toString();
        QVERIFY(practice.changeNote(uid, QStringLiteral("Kreis viel größer")));
        QCOMPARE(practice.lastNote(QStringLiteral("e")).value(QStringLiteral("text")).toString(), QStringLiteral("Kreis viel größer"));
        QVERIFY(practice.deleteNote(uid));
        QVERIFY(practice.lastNote(QStringLiteral("e")).isEmpty());
        QCOMPARE(spy.count(), 3);
    }

    // A log of schema 2 with the 26 Kamae entries of before: one entry now, the weakest rating
    // of each day (the newest on a tie) and every note on it; other entries stay as they were.
    void migratesKamaeToOneEntry()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        const QDateTime day1 = QDateTime(QDate(2026, 10, 30), QTime(12, 0), QTimeZone::UTC);
        const QDateTime day2 = day1.addDays(1);
        {
            PracticeLog log;
            QVERIFY(log.open(path));
            log.add(QStringLiteral("shinkitoho/kamae/3"), 1, day1, QStringLiteral("phone"));
            log.add(QStringLiteral("shinkitoho/kamae/1"), 2, day1.addSecs(60), QStringLiteral("phone"));
            log.add(QStringLiteral("shinkitoho/kamae/2"), 3, day1.addSecs(120), QStringLiteral("phone"));
            log.add(QStringLiteral("shinkitoho/kamae/12"), 1, day2, QStringLiteral("phone"));
            log.add(QStringLiteral("shinkitoho/kamae/26"), 1, day2.addSecs(60), QStringLiteral("tablet"));
            log.add(QStringLiteral("shinkitoho/kiriotoshi"), 4, day2, QStringLiteral("phone"));
            log.addNote(QStringLiteral("shinkitoho/kamae/5"), QStringLiteral("In: Spitze höher"), day1, QStringLiteral("phone"));
            log.addNote(QStringLiteral("shinkitoho/kamae/17"), QStringLiteral("Hongaku ruhig"), day2, QStringLiteral("phone"));
        }
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("v2"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QVERIFY(QSqlQuery(db).exec(QStringLiteral("PRAGMA user_version = 2")));
            // A level outside 1..4 (written by hand or a broken sync) never wins the day.
            QVERIFY(QSqlQuery(db).exec(QStringLiteral("INSERT INTO ratings VALUES ('bad', 'shinkitoho/kamae/4', 0, %1, 'phone')")
                                           .arg(day1.addSecs(180).toMSecsSinceEpoch())));
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("v2"));

        PracticeLog log;
        QVERIFY2(log.open(path), qPrintable(log.errorString()));
        const QString kamae = QStringLiteral("shinkitoho/kamae");
        const auto history = log.history(kamae);
        QCOMPARE(history.size(), 2);
        QCOMPARE(history.at(0).level, 1);
        QCOMPARE(history.at(0).at, day1);
        QCOMPARE(history.at(1).level, 1);
        QCOMPARE(history.at(1).device, QStringLiteral("tablet"));
        QCOMPARE(log.latest().size(), 2);
        QCOMPARE(log.latest().value(QStringLiteral("shinkitoho/kiriotoshi")).level, 4);
        QCOMPARE(log.notes(kamae).size(), 2);
        QCOMPARE(log.notes(kamae).last().text, QStringLiteral("Hongaku ruhig"));
        QVERIFY(log.notes(QStringLiteral("shinkitoho/kamae/5")).isEmpty());
    }

    void searchNotes()
    {
        QTemporaryDir dir;
        Practice practice(dir.filePath(QStringLiteral("mitori.sqlite")));
        practice.addNote(QStringLiteral("a"), QStringLiteral("Hüfte früher drehen"));
        practice.addNote(QStringLiteral("b"), QStringLiteral("Blick beim Partner, Hüfte tief"));
        practice.addNote(QStringLiteral("c"), QStringLiteral("Kreis größer"));
        QCOMPARE(practice.searchNotes(QStringLiteral("hufte")).size(), 2);       // without the umlaut
        const QVariantList both = practice.searchNotes(QStringLiteral("HÜFTE blick"));
        QCOMPARE(both.size(), 1);
        QCOMPARE(both.first().toMap().value(QStringLiteral("entry")).toString(), QStringLiteral("b"));
        QCOMPARE(practice.searchNotes(QStringLiteral("hüfte")).first().toMap().value(QStringLiteral("entry")).toString(),
                 QStringLiteral("b"));                                         // newest first
        const QString uid = practice.notes(QStringLiteral("c")).first().toMap().value(QStringLiteral("uid")).toString();
        practice.deleteNote(uid);
        QVERIFY(practice.searchNotes(QStringLiteral("kreis")).isEmpty());
        practice.addNote(QStringLiteral("d"), QStringLiteral("Fuß nach außen"));
        QCOMPARE(practice.searchNotes(QStringLiteral("fuss aussen")).size(), 1);   // ß as ss
        practice.addNote(QStringLiteral("e"), QStringLiteral("Shiho-nage: Arm über den Kopf"));
        QCOMPARE(practice.searchNotes(QStringLiteral("shihonage")).size(), 1);    // the hyphen does not matter
        // Joined across a space only from the start of a word: "rein" is not in "nur ein".
        practice.addNote(QStringLiteral("f"), QStringLiteral("Fuß nur ein wenig drehen"));
        QVERIFY(practice.searchNotes(QStringLiteral("rein")).isEmpty());
        QCOMPARE(practice.searchNotes(QStringLiteral("nurein")).size(), 1);
        // Across a space, the match also ends where a word ends: "mitte" is not in "mit Tenkan".
        practice.addNote(QStringLiteral("g"), QStringLiteral("Erst mit Tenkan ausweichen"));
        QVERIFY(practice.searchNotes(QStringLiteral("mitte")).isEmpty());
        QCOMPARE(practice.searchNotes(QStringLiteral("mittenkan")).size(), 1);
        // Punctuation separates words: a word after "(" or before "," still starts or ends there.
        practice.addNote(QStringLiteral("h"), QStringLiteral("Wie im Kurs (Shiho-nage) gezeigt. Irimi nage, dann „Kote gaeshi“."));
        QCOMPARE(practice.searchNotes(QStringLiteral("shihonage")).size(), 2);   // with "e"
        QCOMPARE(practice.searchNotes(QStringLiteral("iriminage")).size(), 1);
        QCOMPARE(practice.searchNotes(QStringLiteral("kotegaeshi")).size(), 1);
        // An emoji ends a word like any symbol, also outside the BMP.
        practice.addNote(QStringLiteral("j"), QStringLiteral("Sumi otoshi👍🏽 endlich"));
        QCOMPARE(practice.searchNotes(QStringLiteral("sumiotoshi")).size(), 1);
        // A soft hyphen is invisible.
        practice.addNote(QStringLiteral("i"), QStringLiteral("Mit\u00ADte halten"));
        QCOMPARE(practice.searchNotes(QStringLiteral("mitte")).size(), 1);
        // Capital ẞ as ß.
        QCOMPARE(practice.searchNotes(QStringLiteral("NUR EIN FUẞ")).size(), 1);
        QVERIFY(practice.searchNotes(QStringLiteral(" ")).isEmpty());

        // A changed note is found by its new text, also one written by another connection (a
        // sync's conflict resolved), without refresh().
        const QString fuss = practice.notes(QStringLiteral("d")).first().toMap().value(QStringLiteral("uid")).toString();
        QVERIFY(practice.changeNote(fuss, QStringLiteral("Fuß nach innen")));
        QVERIFY(practice.searchNotes(QStringLiteral("aussen")).isEmpty());
        QCOMPARE(practice.searchNotes(QStringLiteral("innen")).size(), 1);
        {
            PracticeLog other;
            QVERIFY(other.open(dir.filePath(QStringLiteral("mitori.sqlite"))));
            other.addNote(QStringLiteral("k"), QStringLiteral("Tegatana gerade"), QDateTime::currentDateTimeUtc(), QStringLiteral("other"));
        }
        QCOMPARE(practice.searchNotes(QStringLiteral("tegatana")).size(), 1);
    }

    // All notes, newest first, each with its technique; deleted ones left out.
    void allNotes()
    {
        QTemporaryDir dir;
        Practice practice(dir.filePath(QStringLiteral("mitori.sqlite")));
        QVERIFY(practice.allNotes().isEmpty());
        practice.addNote(QStringLiteral("a"), QStringLiteral("erste"));
        QTest::qWait(5);
        practice.addNote(QStringLiteral("b"), QStringLiteral("zweite"));
        QTest::qWait(5);
        practice.addNote(QStringLiteral("a"), QStringLiteral("dritte"));
        QVariantList all = practice.allNotes();
        QCOMPARE(all.size(), 3);
        QCOMPARE(all.first().toMap().value(QStringLiteral("text")).toString(), QStringLiteral("dritte"));
        QCOMPARE(all.first().toMap().value(QStringLiteral("entry")).toString(), QStringLiteral("a"));
        QCOMPARE(all.last().toMap().value(QStringLiteral("text")).toString(), QStringLiteral("erste"));
        practice.deleteNote(all.at(1).toMap().value(QStringLiteral("uid")).toString());
        all = practice.allNotes();
        QCOMPARE(all.size(), 2);
        QVERIFY(all.first().toMap().value(QStringLiteral("created")).toDateTime().isValid());
    }

    // An exam round: every point's rating goes into the log, the round is kept with its average;
    // a round with a point unrated is refused whole.
    void examRoundSaved()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("mitori.sqlite"));
        {
            Practice practice(path);
            const QVariantList unrated{QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("level"), 3}},
                                       QVariantMap{{QStringLiteral("id"), QStringLiteral("b")}, {QStringLiteral("level"), 0}}};
            QVERIFY(!practice.saveRound(QStringLiteral("aikido"), QStringLiteral("k5"), unrated));
            QCOMPARE(practice.level(QStringLiteral("a")), 0);
            QVERIFY(practice.rounds(QStringLiteral("aikido"), 8).isEmpty());

            const QVariantList results{QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("level"), 3}},
                                       QVariantMap{{QStringLiteral("id"), QStringLiteral("k")}, {QStringLiteral("level"), 2}}};
            QSignalSpy spy(&practice, &Practice::changed);
            QVERIFY(practice.saveRound(QStringLiteral("aikido"), QStringLiteral("k5"), results));
            QVERIFY(spy.count() >= 1);
            QCOMPARE(practice.level(QStringLiteral("a")), 3);
            QCOMPARE(practice.level(QStringLiteral("k")), 2);
            QVERIFY(practice.saveRound(QStringLiteral("daitoryu"), QStringLiteral("k5"), results));
        }
        // Kept across starts, per discipline.
        Practice practice(path);
        const QVariantList rounds = practice.rounds(QStringLiteral("aikido"), 8);
        QCOMPARE(rounds.size(), 1);
        const QVariantMap round = rounds.first().toMap();
        QCOMPARE(round.value(QStringLiteral("grade")).toString(), QStringLiteral("k5"));
        QCOMPARE(round.value(QStringLiteral("count")).toInt(), 2);
        QCOMPARE(round.value(QStringLiteral("average")).toDouble(), 2.5);
        QCOMPARE(round.value(QStringLiteral("at")).toDateTime().date(), QDate::currentDate());

        // The newest `limit`, oldest first.
        PracticeLog log;
        QVERIFY(log.open(dir.filePath(QStringLiteral("log.sqlite"))));
        const QDateTime t = QDateTime(QDate(2026, 11, 1), QTime(12, 0), QTimeZone::UTC);
        for (int i = 0; i < 10; ++i) {
            const PracticeLog::ExamRound r{QString(), t.addDays(i), QStringLiteral("aikido"), QStringLiteral("k5"), i + 1, 2.0, QStringLiteral("d")};
            QVERIFY(!log.addRound(r, {}).round.uid.isEmpty());
        }
        const QList<PracticeLog::ExamRound> last = log.rounds(QStringLiteral("aikido"), 8);
        QCOMPARE(last.size(), 8);
        QCOMPARE(last.first().count, 3);
        QCOMPARE(last.last().count, 10);
        QCOMPARE(last.last().at, t.addDays(9));
        QVERIFY(log.rounds(QStringLiteral("daitoryu"), 8).isEmpty());
    }

    // A round is kept whole or not at all: a rating that cannot be saved (an empty entry) leaves
    // neither the other ratings nor the round behind.
    void examRoundAtomic()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("mitori.sqlite"));
        {
            Practice practice(path);
            const QVariantList results{QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("level"), 3}},
                                       QVariantMap{{QStringLiteral("id"), QString()}, {QStringLiteral("level"), 2}}};
            QSignalSpy spy(&practice, &Practice::changed);
            QVERIFY(!practice.saveRound(QStringLiteral("aikido"), QStringLiteral("k5"), results));
            QCOMPARE(practice.level(QStringLiteral("a")), 0);
            QCOMPARE(spy.count(), 0);
            QVERIFY(practice.rounds(QStringLiteral("aikido"), 8).isEmpty());
            // The failed round is rolled back: the next one is saved.
            const QVariantList next{QVariantMap{{QStringLiteral("id"), QStringLiteral("b")}, {QStringLiteral("level"), 4}}};
            QVERIFY2(practice.saveRound(QStringLiteral("aikido"), QStringLiteral("k5"), next), qPrintable(practice.errorString()));
        }
        Practice again(path);
        QCOMPARE(again.level(QStringLiteral("a")), 0);
        QCOMPARE(again.level(QStringLiteral("b")), 4);
        QCOMPARE(again.rounds(QStringLiteral("aikido"), 8).size(), 1);
    }

    // The error names the last failure, not an earlier one.
    void examRoundErrorIsFresh()
    {
        QTemporaryDir dir;
        PracticeLog log;
        QVERIFY(log.open(dir.filePath(QStringLiteral("log.sqlite"))));
        QVERIFY(log.addRound(PracticeLog::ExamRound{}, {}).round.uid.isEmpty());
        QVERIFY(log.errorString().contains(QStringLiteral("incomplete")));
        const PracticeLog::ExamRound round{QString(), QDateTime::currentDateTimeUtc(), QStringLiteral("aikido"), QStringLiteral("k5"), 1, 2.0, QStringLiteral("d")};
        PracticeLog::Rating empty;
        empty.level = 2;
        QVERIFY(log.addRound(round, {empty}).round.uid.isEmpty());
        QVERIFY2(log.errorString().contains(QStringLiteral("invalid")), qPrintable(log.errorString()));
    }

    // A point without a rating: nothing is written, and the error says why.
    void examRoundUnrated()
    {
        QTemporaryDir dir;
        Practice practice(dir.filePath(QStringLiteral("mitori.sqlite")));
        const QVariantList results{QVariantMap{{QStringLiteral("id"), QStringLiteral("a")}, {QStringLiteral("level"), 3}},
                                   QVariantMap{{QStringLiteral("id"), QStringLiteral("b")}}};
        QVERIFY(!practice.saveRound(QStringLiteral("aikido"), QStringLiteral("k5"), results));
        QCOMPARE(practice.errorString(), QStringLiteral("Not every point of the exam round is rated."));
        QCOMPARE(practice.level(QStringLiteral("a")), 0);
        QVERIFY(practice.rounds(QStringLiteral("aikido"), 8).isEmpty());
    }

    // A log of schema 3 (ratings, notes, the Kamae as one entry) gets the table of exam rounds.
    void migratesFromSchemaThree()
    {
        QTemporaryDir dir;
        const QString path = dir.filePath(QStringLiteral("log.sqlite"));
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("v3"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(QStringLiteral("CREATE TABLE ratings (uid TEXT PRIMARY KEY, entry TEXT NOT NULL,"
                                          " level INTEGER NOT NULL, at INTEGER NOT NULL, device TEXT NOT NULL)")));
            QVERIFY(q.exec(QStringLiteral("CREATE TABLE notes (uid TEXT PRIMARY KEY, entry TEXT NOT NULL, text TEXT NOT NULL,"
                                          " created INTEGER NOT NULL, changed INTEGER NOT NULL, device TEXT NOT NULL,"
                                          " deleted INTEGER NOT NULL DEFAULT 0)")));
            QVERIFY(q.exec(QStringLiteral("INSERT INTO ratings VALUES ('x', 'e', 3, %1, 'd')").arg(QDateTime::currentMSecsSinceEpoch())));
            QVERIFY(q.exec(QStringLiteral("INSERT INTO notes VALUES ('n', 'e', 'Hüfte', %1, %1, 'd', 0)").arg(QDateTime::currentMSecsSinceEpoch())));
            QVERIFY(q.exec(QStringLiteral("PRAGMA user_version = 3")));
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("v3"));
        {
            Practice practice(path);
            QCOMPARE(practice.errorString(), QString());
            QCOMPARE(practice.level(QStringLiteral("e")), 3);
            QCOMPARE(practice.notes(QStringLiteral("e")).size(), 1);
            const QVariantList results{QVariantMap{{QStringLiteral("id"), QStringLiteral("e")}, {QStringLiteral("level"), 4}}};
            QVERIFY(practice.saveRound(QStringLiteral("aikido"), QStringLiteral("k5"), results));
            QCOMPARE(practice.rounds(QStringLiteral("aikido"), 8).size(), 1);
        }
        // Opened again: schema 4 stays, nothing is migrated twice, everything is there.
        Practice again(path);
        QCOMPARE(again.errorString(), QString());
        QCOMPARE(again.level(QStringLiteral("e")), 4);
        QCOMPARE(again.lastNote(QStringLiteral("e")).value(QStringLiteral("text")).toString(), QStringLiteral("Hüfte"));
        QCOMPARE(again.lastNote(QStringLiteral("e")).value(QStringLiteral("media")).toString(), QString());   // schema 5
        QCOMPARE(again.rounds(QStringLiteral("aikido"), 8).size(), 1);
        {
            QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), QStringLiteral("v4"));
            db.setDatabaseName(path);
            QVERIFY(db.open());
            QSqlQuery q(db);
            QVERIFY(q.exec(QStringLiteral("PRAGMA user_version")) && q.next());
            QCOMPARE(q.value(0).toInt(), PracticeLog::schemaVersion);
            db.close();
        }
        QSqlDatabase::removeDatabase(QStringLiteral("v4"));
    }

    void deviceIdStays()
    {
        const QString id = Practice::deviceId();
        QVERIFY(!id.isEmpty());
        QCOMPARE(Practice::deviceId(), id);
    }
};

int main(int argc, char *argv[])
{
    // Settings and data in the build directory (not ~/.qttest, which every build and review
    // running at the same time would share and overwrite).
    qputenv("XDG_CONFIG_HOME", TEST_DATA_DIR "/config");
    qputenv("XDG_DATA_HOME", TEST_DATA_DIR "/data");
    QCoreApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("mitori-practice-test"));
    TstPractice test;
    return QTest::qExec(&test, argc, argv);
}
#include "tst_practice.moc"
