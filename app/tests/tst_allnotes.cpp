#include <algorithm>
#include <ctime>
#include <QJsonArray>
#include <QJsonObject>
#include <QSettings>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

#include "allnotes.h"
#include "bundleshelf.h"
#include "catalog.h"
#include "courses.h"
#include "practice.h"
#include "programme.h"

using namespace Qt::StringLiterals;

// All notes against services on files of their own: technique notes and course entries in one
// list, the filter, rows changed in place, and the time a change takes with many notes.
class TstAllNotes : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    Catalog m_catalog;

    struct Sources {
        std::unique_ptr<Practice> practice;
        std::unique_ptr<Courses> courses;
        std::unique_ptr<Programme> programme;
        std::unique_ptr<AllNotes> notes;
    };

    Sources made(const QString &name)
    {
        Sources s;
        s.practice = std::make_unique<Practice>(m_dir.filePath(name + u"-practice.sqlite"_s));
        s.courses = std::make_unique<Courses>(m_dir.filePath(name + u"-courses.sqlite"_s), QUrl::fromLocalFile(m_dir.filePath(u"none.ics"_s)),
                                              m_dir.filePath(name + u"-cache.ics"_s), m_catalog);
        s.programme = std::make_unique<Programme>(m_catalog);
        s.notes = std::make_unique<AllNotes>();
        s.notes->setPractice(s.practice.get());
        s.notes->setCourses(s.courses.get());
        s.notes->setProgramme(s.programme.get());
        return s;
    }

    static QVariantMap row(const AllNotes &n, int i)
    {
        return n.data(n.index(i), KeyedListModel::RowRole).toMap();
    }

    // The first technique of a discipline's first grade.
    QString firstEntry(const Programme &p, const QString &discipline) const
    {
        const QString grade = p.grades(discipline).first().toMap().value(u"id"_s).toString();
        for (const QVariant &v : p.entries(discipline, grade)) {
            if (v.toMap().value(u"kind"_s) == u"entry"_s) {
                return v.toMap().value(u"id"_s).toString();
            }
        }
        return {};
    }

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        QSettings().clear();
        QVERIFY(m_dir.isValid());
        QDir(BundleShelf::defaultRoot()).removeRecursively();
        QVERIFY2(m_catalog.load(QStringLiteral(MITORI_DATEN_JSON)), qPrintable(m_catalog.errorString()));
    }

    void cleanupTestCase()
    {
        QDir(BundleShelf::defaultRoot()).removeRecursively();
    }

    // Both kinds, newest first, each with its title; the filter by discipline and by courses.
    void bothKinds()
    {
        auto s = made(u"both"_s);
        const QString aikido = firstEntry(*s.programme, u"aikido"_s);
        QVERIFY(s.practice->addNote(aikido, u"Hüfte"_s));
        QTest::qWait(5);
        QVERIFY(s.practice->addNote(u"not-in-the-programme"_s, u"verwaist"_s));
        QTest::qWait(5);
        const QString course = s.courses->create(u"Sommerlehrgang"_s, u"2026-07-01"_s, {}, {}, {});
        QVERIFY(s.courses->addEntry(course, u"Kote-gaeshi"_s));

        QCOMPARE(s.notes->count(), 3);
        QCOMPARE(s.notes->total(), 3);
        QCOMPARE(row(*s.notes, 0).value(u"kind"_s).toString(), u"course"_s);
        QCOMPARE(row(*s.notes, 0).value(u"title"_s).toString(), u"Sommerlehrgang"_s);
        QCOMPARE(row(*s.notes, 0).value(u"course"_s).toString(), course);
        QCOMPARE(row(*s.notes, 1).value(u"title"_s).toString(), u"Technique no longer in the programme"_s);
        QCOMPARE(row(*s.notes, 2).value(u"discipline"_s).toString(), u"aikido"_s);
        QVERIFY(row(*s.notes, 2).value(u"title"_s).toString().startsWith(u"Aikido 5. Kyu · "_s));
        QCOMPARE(row(*s.notes, 2).value(u"day"_s).toString(), QDate::currentDate().toString(Qt::ISODate));

        s.notes->setFilter(QString::fromLatin1(AllNotes::kCourses));
        QCOMPARE(s.notes->count(), 1);
        QCOMPARE(s.notes->total(), 3);
        s.notes->setFilter(u"aikido"_s);
        QCOMPARE(s.notes->count(), 1);
        QCOMPARE(row(*s.notes, 0).value(u"text"_s).toString(), u"Hüfte"_s);
        s.notes->setFilter(u"daitoryu"_s);
        QCOMPARE(s.notes->count(), 0);

        // A deleted notebook takes its entries out of the list.
        s.notes->setFilter({});
        QVERIFY(s.courses->remove(course));
        QCOMPARE(s.notes->count(), 2);
    }

    // A note on a Lernpaket's technique: titled with its package, in the "lern" discipline, never "no
    // longer in the programme"; the title follows the package coming and going (its name stays).
    void lessonNotes()
    {
        auto s = made(u"lesson"_s);
        const QString id = u"lern/note-lesson/irimi"_s;
        QVERIFY(s.practice->addNote(id, u"Eintritt"_s));
        QCOMPARE(row(*s.notes, 0).value(u"title"_s).toString(), u"Technique no longer in the programme"_s);

        const QJsonObject technique{{u"id"_s, id}, {u"name"_s, u"Irimi-nage"_s}, {u"angriff"_s, QJsonObject{{u"name"_s, u"Shomen-uchi"_s}}}};
        const QJsonObject content{{u"id"_s, u"note-lesson"_s}, {u"titel"_s, u"Lernpaket"_s},
                                  {u"abschnitte"_s, QJsonArray{QJsonObject{{u"titel"_s, u"Grund"_s}, {u"techniken"_s, QJsonArray{technique}}}}}};
        QVERIFY(BundleShelf::shared().installed(u"note-lesson"_s, 1, {}, {}, {}, content));
        QCOMPARE(row(*s.notes, 0).value(u"title"_s).toString(), u"Lernpaket · Irimi-nage · Shomen-uchi"_s);
        QCOMPARE(row(*s.notes, 0).value(u"discipline"_s).toString(), u"lern"_s);

        QVERIFY(BundleShelf::shared().remove(u"note-lesson"_s));
        QCOMPARE(row(*s.notes, 0).value(u"title"_s).toString(), u"Lernpaket · Irimi-nage · Shomen-uchi"_s);
        QCOMPARE(row(*s.notes, 0).value(u"discipline"_s).toString(), u"lern"_s);
    }

    // A technique's title names its grade in the data's language of now: a LanguageChange reads
    // the names anew (they were read once, with the programme).
    void titlesFollowLanguage()
    {
        auto s = made(u"language"_s);
        QVERIFY(s.practice->addNote(firstEntry(*s.programme, u"aikido"_s), u"Hüfte"_s));
        QEvent event(QEvent::LanguageChange);
        const auto title = [&s] { return row(*s.notes, 0).value(u"title"_s).toString(); };
        QVERIFY(title().startsWith(u"Aikido 5. Kyu · "_s));

        Catalog::setLanguage(Catalog::Language::English);
        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);
        const QString english = title();
        Catalog::setLanguage(Catalog::Language::German);
        QCoreApplication::sendEvent(QCoreApplication::instance(), &event);

        QVERIFY2(english.startsWith(u"Aikido 5th Kyu · "_s), qPrintable(english));
        QVERIFY(title().startsWith(u"Aikido 5. Kyu · "_s));
    }

    // A change keeps the other rows (no reset, nothing inserted or removed).
    void changeInPlace()
    {
        auto s = made(u"place"_s);
        const QString aikido = firstEntry(*s.programme, u"aikido"_s);
        for (int i = 0; i < 5; ++i) {
            QVERIFY(s.practice->addNote(aikido, u"Übung %1"_s.arg(i)));
        }
        QSignalSpy reset(s.notes.get(), &QAbstractItemModel::modelReset);
        QSignalSpy inserted(s.notes.get(), &QAbstractItemModel::rowsInserted);
        QSignalSpy removed(s.notes.get(), &QAbstractItemModel::rowsRemoved);
        QSignalSpy changed(s.notes.get(), &QAbstractItemModel::dataChanged);
        QVERIFY(s.practice->changeNote(row(*s.notes, 2).value(u"uid"_s).toString(), u"geändert"_s));
        QCOMPARE(row(*s.notes, 2).value(u"text"_s).toString(), u"geändert"_s);
        QCOMPARE(reset.count() + inserted.count() + removed.count(), 0);
        QCOMPARE(changed.count(), 1);
    }

    // 2000 technique notes and 200 course entries: a change is rebuilt in a few milliseconds
    // (JavaScript took 64–120 ms, a dropped frame on every note).
    void manyNotesFast()
    {
        auto s = made(u"many"_s);
        const QString aikido = firstEntry(*s.programme, u"aikido"_s);
        const QString daito = firstEntry(*s.programme, u"daitoryu"_s);
        s.notes->setPractice(nullptr);          // not rebuilt for every note added
        s.notes->setCourses(nullptr);
        for (int i = 0; i < 2000; ++i) {
            QVERIFY(s.practice->addNote(i % 2 ? aikido : daito, u"Übung %1"_s.arg(i)));
        }
        const QString course = s.courses->create(u"Lehrgang"_s, u"2026-07-01"_s, {}, {}, {});
        for (int i = 0; i < 200; ++i) {
            QVERIFY(s.courses->addEntry(course, u"Eintrag %1"_s.arg(i)));
        }
        s.notes->setPractice(s.practice.get());
        s.notes->setCourses(s.courses.get());
        QCOMPARE(s.notes->count(), 2200);

        QList<qint64> times;
        // Rows 0–199 are the course entries (added last): change technique notes below them.
        // The fastest: a run that another process interrupts or slows says nothing about the code.
        for (int i = 0; i < kRuns; ++i) {
            const qint64 start = cpuMs();
            QVERIFY(s.practice->changeNote(row(*s.notes, 300 + i).value(u"uid"_s).toString(), u"neu %1"_s.arg(i)));
            times << cpuMs() - start;
        }
        const qint64 fastest = *std::min_element(times.begin(), times.end());
        qInfo("a change with 2200 notes: %lld ms CPU (fastest of %d)", fastest, kRuns);
        QVERIFY2(fastest < kMaxMs, qPrintable(u"%1 ms"_s.arg(fastest)));
    }

private:
    // The CPU time of this thread (ms): other work on the machine (a parallel build) does not
    // count, as it does in wall time (152 ms under load, 32 ms alone).
    static qint64 cpuMs()
    {
        timespec t{};
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &t);
        return qint64(t.tv_sec) * 1000 + t.tv_nsec / 1000000;
    }

    static constexpr int kRuns = 9;

    // Twice what a release build measures alone (9–10 ms): a busy process on the other half of the
    // core alone makes that 14–16, so a frame at 60 Hz (16) failed without any change to the code. A
    // debug build is about three times slower (31 ms), with room for a slower CI machine.
#ifdef NDEBUG
    static constexpr qint64 kMaxMs = 20;
#else
    static constexpr qint64 kMaxMs = 60;
#endif
};

QTEST_GUILESS_MAIN(TstAllNotes)
#include "tst_allnotes.moc"
