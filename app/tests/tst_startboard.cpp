#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTest>

#include "bundleshelf.h"
#include "catalog.h"
#include "courses.h"
#include "exam.h"
#include "glossary.h"
#include "practice.h"
#include "practicegrade.h"
#include "programme.h"
#include "startboard.h"

using namespace Qt::StringLiterals;

namespace {

// A calendar with one course running and one in 30 days, dates relative to today.
QByteArray calendar()
{
    const auto day = [](int offset) { return QDate::currentDate().addDays(offset).toString(u"yyyyMMdd"_s).toUtf8(); };
    return "BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
           "BEGIN:VEVENT\r\nUID:later\r\nSUMMARY:Daitoryu\r\nDTSTART;VALUE=DATE:" + day(30) + "\r\nDTEND;VALUE=DATE:" + day(32) + "\r\n"
           "LOCATION:Siebeldingen\r\nDESCRIPTION:mit M. D. Nakajima Shihan\r\nEND:VEVENT\r\n"
           "END:VCALENDAR\r\n";
}

QStringList entryIds(const QVariantList &rows)
{
    QStringList ids;
    for (const QVariant &r : rows) {
        if (r.toMap().value(u"kind"_s) == u"entry"_s) {
            ids << r.toMap().value(u"id"_s).toString();
        }
    }
    return ids;
}

} // namespace

// The start menu's tiles: their values for a known store, and that they arrive off the GUI thread
// and follow a change.
class TstStartBoard : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    Catalog m_catalog;

    struct Services {
        std::unique_ptr<Practice> practice;
        std::unique_ptr<Courses> courses;
        std::unique_ptr<Programme> programme;
        std::unique_ptr<PracticeGrade> grades;
        std::unique_ptr<Exam> exam;
        std::unique_ptr<Glossary> glossary;
        QStringList ids;        // Aikido 5. Kyu, in programme order

        std::unique_ptr<StartBoard> board()
        {
            return std::make_unique<StartBoard>(programme.get(), practice.get(), grades.get(), courses.get(), exam.get(), glossary.get());
        }
    };

    Services made(const QString &name)
    {
        QSettings().clear();
        QFile file(m_dir.filePath(name + u".ics"_s));
        (void)file.open(QIODevice::WriteOnly);
        file.write(calendar());
        file.close();

        Services s;
        s.practice = std::make_unique<Practice>(m_dir.filePath(name + u"-practice.sqlite"_s));
        s.courses = std::make_unique<Courses>(m_dir.filePath(name + u"-courses.sqlite"_s), QUrl::fromLocalFile(file.fileName()),
                                              m_dir.filePath(name + u"-cache.ics"_s), m_catalog);
        QSignalSpy loaded(s.courses.get(), &Courses::calendarChanged);
        s.courses->reload();
        while (s.courses->calendarState() == Courses::CalendarState::Loading && loaded.wait(5000)) {
        }
        s.programme = std::make_unique<Programme>(m_catalog);
        s.programme->setDiscipline(u"aikido"_s);
        s.grades = std::make_unique<PracticeGrade>(s.programme.get(), s.courses.get());
        s.exam = std::make_unique<Exam>(m_catalog, 1);
        s.glossary = std::make_unique<Glossary>(m_catalog, u"mock"_s);
        s.ids = entryIds(s.programme->entries(u"aikido"_s, u"k5"_s));
        return s;
    }

    // The first tile values after the board's first run.
    static QVariantMap tiles(StartBoard &board)
    {
        QSignalSpy spy(&board, &StartBoard::tilesChanged);
        if (!board.ready()) {
            spy.wait(5000);
        }
        return board.tiles();
    }

    static QVariantMap tile(StartBoard &board, const QString &name)
    {
        return board.tiles().value(name).toMap();
    }

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        QVERIFY(m_dir.isValid());
        QDir(BundleShelf::defaultRoot()).removeRecursively();
        QVERIFY2(m_catalog.load(QStringLiteral(MITORI_DATEN_JSON)), qPrintable(m_catalog.errorString()));
    }

    void cleanupTestCase()
    {
        QDir(BundleShelf::defaultRoot()).removeRecursively();
    }

    // The board is made at once and empty; the tiles come with a signal, from another thread.
    void arrivesAsynchronously()
    {
        Services s = made(u"async"_s);
        const auto board = s.board();
        QVERIFY(!board->ready());
        QVERIFY(board->tiles().isEmpty());

        QSignalSpy spy(board.get(), &StartBoard::tilesChanged);
        QVERIFY(spy.wait(5000));
        QVERIFY(board->ready());
        for (const QString &name : {u"programme"_s, u"today"_s, u"exam"_s, u"stats"_s, u"courses"_s, u"map"_s, u"glossary"_s, u"notes"_s}) {
            QVERIFY2(tile(*board, name).value(u"ready"_s).toBool(), qPrintable(name));
        }
    }

    void programmeTile()
    {
        Services s = made(u"programme"_s);
        QVERIFY(s.ids.size() > 6);
        QVERIFY(s.practice->rate(s.ids[0], 4));
        QVERIFY(s.practice->rate(s.ids[1], 3));
        QVERIFY(s.practice->rate(s.ids[2], 3));
        QVERIFY(s.practice->rate(s.ids[3], 2));
        QVERIFY(s.practice->rate(s.ids[4], 1));

        const auto board = s.board();
        tiles(*board);
        const QVariantMap t = tile(*board, u"programme"_s);
        QCOMPARE(t.value(u"discipline"_s).toString(), u"Aikido"_s);
        QCOMPARE(t.value(u"gradeName"_s).toString(), u"5. Kyu"_s);
        QCOMPARE(t.value(u"total"_s).toInt(), int(s.ids.size()));
        QCOMPARE(t.value(u"counts"_s).toList(), s.practice->counts(s.ids));
        QCOMPARE(t.value(u"sure"_s).toInt(), 3);
        QCOMPARE(t.value(u"exam"_s).toInt(), 1);

        // The ladder: the practice grade is the current one, short names.
        const QVariantList ladder = t.value(u"ladder"_s).toList();
        QVERIFY(ladder.size() > 3);
        QCOMPARE(ladder.first().toMap().value(u"name"_s).toString(), u"5K"_s);
        QCOMPARE(ladder.first().toMap().value(u"state"_s).toString(), u"current"_s);
        QCOMPARE(ladder.last().toMap().value(u"state"_s).toString(), u"todo"_s);

        // The one unsure the longest: the lowest level.
        const QVariantMap next = t.value(u"next"_s).toMap();
        QCOMPARE(next.value(u"id"_s).toString(), s.ids[4]);
        QVERIFY(!next.value(u"title"_s).toString().isEmpty());
    }

    // Nothing unsure: the first technique not yet rated.
    void continuesWithNew()
    {
        Services s = made(u"new"_s);
        QVERIFY(s.practice->rate(s.ids[0], 4));
        const auto board = s.board();
        tiles(*board);
        QCOMPARE(tile(*board, u"programme"_s).value(u"next"_s).toMap().value(u"id"_s).toString(), s.ids[1]);
    }

    void todayTile()
    {
        Services s = made(u"today"_s);
        QVERIFY(s.practice->rate(s.ids[0], 1));
        QVERIFY(s.practice->rate(s.ids[1], 2));

        const auto board = s.board();
        tiles(*board);
        const QVariantList due = s.practice->due(s.programme->practiceEntries(u"aikido"_s, u"k5"_s));
        const QVariantMap t = tile(*board, u"today"_s);
        QCOMPARE(t.value(u"due"_s).toInt(), int(due.size()));
        const auto count = [&due](int level) {
            return int(std::count_if(due.cbegin(), due.cend(), [level](const QVariant &r) { return r.toMap().value(u"level"_s).toInt() == level; }));
        };
        QCOMPARE(t.value(u"unsure"_s).toInt(), count(1) + count(2));
        QCOMPARE(t.value(u"fresh"_s).toInt(), count(0));
    }

    void statsTile()
    {
        Services s = made(u"stats"_s);
        QVERIFY(s.practice->rate(s.ids[0], 2));
        QVERIFY(s.practice->rate(s.ids[1], 2));
        QVERIFY(s.practice->rate(s.ids[2], 3));

        const auto board = s.board();
        tiles(*board);
        const QVariantMap t = tile(*board, u"stats"_s);
        QCOMPARE(t.value(u"days"_s).toInt(), 1);
        QCOMPARE(t.value(u"techniques"_s).toInt(), 3);
        QCOMPARE(t.value(u"streak"_s).toInt(), 1);
        const QVariantList cells = t.value(u"cells"_s).toList();
        QCOMPARE(cells.size(), StartBoard::kDays);
        QCOMPARE(cells.last().toInt(), 3);
        QCOMPARE(cells.first().toInt(), 0);
    }

    void coursesAndNotes()
    {
        Services s = made(u"courses"_s);
        const auto board = s.board();
        tiles(*board);
        QVERIFY(tile(*board, u"courses"_s).value(u"has"_s).toBool());
        QCOMPARE(tile(*board, u"courses"_s).value(u"title"_s).toString(), u"Daitoryu"_s);
        QCOMPARE(tile(*board, u"courses"_s).value(u"days"_s).toInt(), 30);
        QCOMPARE(tile(*board, u"courses"_s).value(u"teacher"_s).toString(), u"M. D. Nakajima Shihan"_s);
        QCOMPARE(tile(*board, u"courses"_s).value(u"entries"_s).toInt(), -1);
        QCOMPARE(tile(*board, u"notes"_s).value(u"techniques"_s).toInt(), 0);
        QVERIFY(tile(*board, u"notes"_s).value(u"text"_s).toString().isEmpty());

        // A notebook with an entry, and a note on a technique after it: the newest leads.
        const QString notebook = s.courses->notebookFor(u"later"_s);
        QVERIFY(s.courses->addEntry(notebook, u"Hüfte zuerst"_s));
        QSignalSpy spy(board.get(), &StartBoard::tilesChanged);
        QVERIFY(spy.wait(5000));
        QCOMPARE(tile(*board, u"courses"_s).value(u"entries"_s).toInt(), 1);
        QCOMPARE(tile(*board, u"notes"_s).value(u"courses"_s).toInt(), 1);
        QCOMPARE(tile(*board, u"notes"_s).value(u"text"_s).toString(), u"Hüfte zuerst"_s);

        QTest::qWait(5);
        QVERIFY(s.practice->addNote(s.ids[0], u"Eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf dreizehn"_s));
        QVERIFY(spy.wait(5000));
        const QVariantMap notes = tile(*board, u"notes"_s);
        QCOMPARE(notes.value(u"techniques"_s).toInt(), 1);
        QCOMPARE(notes.value(u"text"_s).toString(), u"Eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf…"_s);
    }

    void examTile()
    {
        Services s = made(u"exam"_s);
        const auto board = s.board();
        tiles(*board);
        QVERIFY(!tile(*board, u"exam"_s).value(u"planned"_s).toBool());
        QCOMPARE(tile(*board, u"exam"_s).value(u"name"_s).toString(), u"5. Kyu"_s);

        // An exam planned on the course: the share of its points at "sure" or better.
        const QString notebook = s.courses->notebookFor(u"later"_s);
        QVERIFY(s.courses->planExam(notebook, u"aikido"_s, u"k5"_s));
        const QVariantList material = s.exam->material(u"aikido"_s, u"k5"_s);
        QVERIFY(material.size() > 4);
        QVERIFY(s.practice->rate(material[0].toMap().value(u"id"_s).toString(), 3));
        QVERIFY(s.practice->rate(material[1].toMap().value(u"id"_s).toString(), 4));
        QVERIFY(s.practice->rate(material[2].toMap().value(u"id"_s).toString(), 2));

        QSignalSpy spy(board.get(), &StartBoard::tilesChanged);
        QVERIFY(spy.wait(5000));
        QTRY_VERIFY_WITH_TIMEOUT(tile(*board, u"exam"_s).value(u"sure"_s).toInt() == 2, 5000);
        const QVariantMap t = tile(*board, u"exam"_s);
        QVERIFY(t.value(u"planned"_s).toBool());
        QCOMPARE(t.value(u"days"_s).toInt(), 30);
        QCOMPARE(t.value(u"total"_s).toInt(), int(material.size()));
        QCOMPARE(t.value(u"share"_s).toDouble(), 2.0 / double(material.size()));
    }

    void mapAndGlossary()
    {
        Services s = made(u"map"_s);
        for (const QString &id : s.ids) {
            QVERIFY(s.practice->rate(id, 3));
        }
        const auto board = s.board();
        tiles(*board);

        const QVariantMap map = tile(*board, u"map"_s);
        QVERIFY(!map.value(u"title"_s).toString().isEmpty());
        const QVariantList levels = map.value(u"levels"_s).toList();
        QVERIFY(levels.size() > 1);
        QVERIFY(map.value(u"columns"_s).toInt() > 1);
        int rated = 0;
        for (const QVariant &row : levels) {
            for (const QVariant &level : row.toList()) {
                rated += level.toInt() == 3 ? 1 : 0;
                QVERIFY(level.toInt() >= -1 && level.toInt() <= 4);
            }
        }
        QVERIFY(rated >= 1);

        // The word of the day is the same on every run, and has kanji and a translation.
        const QVariantMap word = tile(*board, u"glossary"_s);
        QVERIFY(!word.value(u"jp"_s).toString().isEmpty());
        QVERIFY(!word.value(u"meaning"_s).toString().isEmpty());
        const auto again = s.board();
        tiles(*again);
        QCOMPARE(tile(*again, u"glossary"_s).value(u"word"_s), word.value(u"word"_s));
    }

    // The GUI thread only copies: a snapshot takes little, however much the programme holds. The
    // programme's rows and the days are the worker's.
    void snapshotIsCheap()
    {
        constexpr qint64 kBudgetUs = 5000;
        Services s = made(u"cheap"_s);
        for (const QString &id : s.ids) {
            QVERIFY(s.practice->rate(id, 2));
        }
        QVERIFY(s.practice->addNote(s.ids[0], u"Notiz"_s));
        const auto board = s.board();
        tiles(*board);

        // The next run: the notes are read, the rest is copies.
        QSignalSpy spy(board.get(), &StartBoard::tilesChanged);
        QVERIFY(s.practice->rate(s.ids[0], 3));
        QVERIFY(spy.wait(5000));
        qInfo() << "snapshot on the GUI thread:" << board->snapshotUs() << "us";
        QVERIFY2(board->snapshotUs() < kBudgetUs, qPrintable(QString::number(board->snapshotUs())));
    }

    // A burst of ratings is a run or two, and the tiles show the last state.
    void followsBurst()
    {
        Services s = made(u"burst"_s);
        const auto board = s.board();
        tiles(*board);
        QSignalSpy spy(board.get(), &StartBoard::tilesChanged);

        for (int i = 0; i < 6; ++i) {
            QVERIFY(s.practice->rate(s.ids[i], 3));
        }
        QVERIFY(spy.wait(5000));
        QTRY_COMPARE_WITH_TIMEOUT(tile(*board, u"programme"_s).value(u"sure"_s).toInt(), 6, 5000);
        QVERIFY2(spy.size() <= 2, qPrintable(QString::number(spy.size())));
    }
};

QTEST_MAIN(TstStartBoard)
#include "tst_startboard.moc"
