#include "startboard.h"

#include "courses.h"
#include "glossary.h"
#include "practice.h"
#include "practicegrade.h"
#include "programme.h"
#include "schedule.h"

#include <QElapsedTimer>
#include <QQmlEngine>
#include <QRegularExpression>
#include <QtConcurrent/QtConcurrentRun>

#include <algorithm>

using namespace Qt::StringLiterals;

namespace {

constexpr int kSure = 3;
constexpr int kReady = 4;
constexpr int kLevels = 5;              // none, seen, with help, sure, exam-ready
constexpr int kStreakDays = 400;        // how far back a streak counts
constexpr int kNoteWords = 12;          // the notes tile's words of the latest note
constexpr qint64 kNsPerUs = 1000;
constexpr quint32 kExamSeed = 1;    // the worker draws no round: any
constexpr int kNoPlace = -1;            // a map cell with no technique

QString text(const QVariant &map, const QString &key)
{
    return map.toMap().value(key).toString();
}

QStringList idsOf(const QVariantList &rows)
{
    QStringList ids;
    for (const QVariant &r : rows) {
        const QString id = text(r, u"id"_s);
        if (!id.isEmpty()) {
            ids << id;
        }
    }
    return ids;
}

// "k5" → "5K", "d1" → "1D": the ladder's short names; other grades keep theirs.
QString shortGrade(const QString &id, const QString &name)
{
    static const QRegularExpression kyuDan(u"^([kd])(\\d+)$"_s);
    const QRegularExpressionMatch m = kyuDan.match(id);
    return m.hasMatch() ? m.captured(2) + m.captured(1).toUpper() : name;
}

} // namespace

struct StartSnapshot {
    QDate today;
    QString discipline;
    QString disciplineName;
    QString grade;
    QString gradeName;
    QVariantList ladder;
    // Read from the immutable catalog by the worker (Programme and Exam hold no cache these
    // functions touch), so the GUI thread does not build them.
    const Programme *programme = nullptr;
    const Exam *exam = nullptr;
    std::function<void()> hook;         // tests: called in the worker
    QVariantList entries;               // the entries up to the practice grade
    QVariantMap grid;                   // the map's first group
    QHash<QString, PracticeLog::Rating> latest;
    QHash<QString, QDate> first;
    QList<int> intervals;
    QList<QHash<QDate, QSet<QString>>> dayEntries;     // who was rated on each day, per year (copies)
    QHash<QDate, int> perDay;           // techniques practised per day, from dayEntries
    QVariantMap plannedExam;            // Courses::nextExam
    QString examGradeName;              // of the exam mode's grade when none is planned
    QStringList examIds;                // the planned exam's points
    QVariantMap course;                 // the next course
    int courseEntries = -1;
    QVariantList words;
    StartNotes notes;
};

namespace {

int levelOf(const StartSnapshot &s, const QString &id)
{
    return s.latest.value(id).level;
}

int bestOf(const StartSnapshot &s, const QVariant &ids)
{
    int best = 0;
    for (const QVariant &id : ids.toList()) {
        best = std::max(best, levelOf(s, id.toString()));
    }
    return best;
}

QVariantMap programmeTile(const StartSnapshot &s)
{
    QVariantList counts{0, 0, 0, 0, 0};
    int sure = 0;
    for (const QString &id : idsOf(s.entries)) {
        const int level = levelOf(s, id);
        counts[level] = counts[level].toInt() + 1;
        sure += level >= kSure ? 1 : 0;
    }

    // The ladder: what is passed is done, the practice grade the current one.
    QVariantList ladder;
    for (const QVariant &g : s.ladder) {
        const QString id = text(g, u"id"_s);
        const bool passed = g.toMap().value(u"passed"_s).toBool();
        ladder << QVariantMap{{u"name"_s, shortGrade(id, text(g, u"name"_s))},
                              {u"state"_s, id == s.grade ? u"current"_s : passed ? u"done"_s : u"todo"_s}};
    }

    // Where to go on: the technique unsure the longest (lowest level, then the oldest rating),
    // else the first one not yet rated.
    const QVariantMap *next = nullptr;
    QVariantMap nextRow;
    QDateTime nextAt;
    int nextLevel = 0;
    for (const QVariant &v : s.entries) {
        const QVariantMap row = v.toMap();
        const PracticeLog::Rating r = s.latest.value(row.value(u"id"_s).toString());
        if (r.level < 1 || r.level >= kSure) {
            continue;
        }
        if (next && (r.level > nextLevel || (r.level == nextLevel && r.at >= nextAt))) {
            continue;
        }
        nextRow = row;
        next = &nextRow;
        nextLevel = r.level;
        nextAt = r.at;
    }
    if (!next) {
        for (const QVariant &v : s.entries) {
            const QVariantMap row = v.toMap();
            if (levelOf(s, row.value(u"id"_s).toString()) == 0) {
                nextRow = row;
                next = &nextRow;
                break;
            }
        }
    }

    QVariantMap tile{{u"ready"_s, true},
                     {u"discipline"_s, s.disciplineName},
                     {u"gradeName"_s, s.gradeName},
                     {u"ladder"_s, ladder},
                     {u"counts"_s, counts},
                     {u"total"_s, int(s.entries.size())},
                     {u"sure"_s, sure},
                     {u"exam"_s, counts[kReady].toInt()}};
    if (next) {
        tile[u"next"_s] = QVariantMap{{u"id"_s, nextRow.value(u"id"_s)},
                                      {u"title"_s, nextRow.value(u"title"_s)},
                                      {u"attack"_s, nextRow.value(u"attack"_s)}};
    }
    return tile;
}

QVariantMap todayTile(const StartSnapshot &s)
{
    QVariantMap tile{{u"ready"_s, true}, {u"due"_s, 0}, {u"unsure"_s, 0}, {u"fresh"_s, 0}};
    if (s.intervals.size() != 4 || !s.today.isValid()) {
        return tile;
    }

    QList<Schedule::Candidate> candidates;
    for (const QVariant &v : s.entries) {
        const QVariantMap row = v.toMap();
        candidates << Schedule::Candidate{row.value(u"id"_s).toString(), row.value(u"current"_s).toBool()};
    }
    int unsure = 0;
    int fresh = 0;
    const QList<Schedule::Due> due = Schedule::due(candidates, s.latest, s.first, s.today, s.intervals);
    for (const Schedule::Due &d : due) {
        unsure += d.level == 1 || d.level == 2 ? 1 : 0;
        fresh += d.level == 0 ? 1 : 0;
    }
    tile[u"due"_s] = int(due.size());
    tile[u"unsure"_s] = unsure;
    tile[u"fresh"_s] = fresh;
    return tile;
}

QVariantMap examTile(const StartSnapshot &s)
{
    QVariantMap tile{{u"ready"_s, true}, {u"planned"_s, false}, {u"name"_s, s.examGradeName}, {u"mock"_s, s.examGradeName}};
    if (s.plannedExam.value(u"course"_s).toString().isEmpty()) {
        return tile;
    }

    int sure = 0;
    for (const QString &id : s.examIds) {
        sure += levelOf(s, id) >= kSure ? 1 : 0;
    }
    tile[u"planned"_s] = true;
    tile[u"name"_s] = s.plannedExam.value(u"name"_s);
    tile[u"days"_s] = s.plannedExam.value(u"days"_s);
    tile[u"sure"_s] = sure;
    tile[u"total"_s] = int(s.examIds.size());
    tile[u"share"_s] = s.examIds.isEmpty() ? 0.0 : double(sure) / double(s.examIds.size());
    return tile;
}

QVariantMap statsTile(const StartSnapshot &s)
{
    // Days back from today: the calendar's cells (oldest first), the streak.
    QVariantList cells;
    int days = 0;
    int techniques = 0;
    for (int back = StartBoard::kDays - 1; back >= 0; --back) {
        const int n = s.perDay.value(s.today.addDays(-back));
        cells << n;
        days += n > 0 ? 1 : 0;
        techniques += n;
    }

    // A day not practised yet does not break the streak: it counts from yesterday.
    int streak = 0;
    QDate day = s.today;
    if (s.perDay.value(day) == 0) {
        day = day.addDays(-1);
    }
    for (; s.perDay.value(day) > 0 && streak < kStreakDays; day = day.addDays(-1)) {
        ++streak;
    }

    return {{u"ready"_s, true}, {u"days"_s, days}, {u"techniques"_s, techniques}, {u"streak"_s, streak}, {u"cells"_s, cells}};
}

QVariantMap coursesTile(const StartSnapshot &s)
{
    if (s.course.isEmpty()) {
        return {{u"ready"_s, true}, {u"has"_s, false}};
    }

    const QDate first = QDate::fromString(s.course.value(u"first"_s).toString(), Qt::ISODate);
    return {{u"ready"_s, true},
            {u"has"_s, true},
            {u"title"_s, s.course.value(u"title"_s)},
            {u"first"_s, s.course.value(u"first"_s)},
            {u"days"_s, int(std::max<qint64>(0, s.today.daysTo(first)))},
            {u"teacher"_s, s.course.value(u"teacher"_s)},
            {u"place"_s, s.course.value(u"place"_s)},
            {u"entries"_s, s.courseEntries}};
}

// The first group of the technique map as levels, one row each; -1 where no technique answers.
QVariantMap mapTile(const StartSnapshot &s)
{
    QVariantList levels;
    int columns = 0;
    if (s.grid.value(u"kind"_s).toString() == u"matrix"_s) {
        for (const QVariant &r : s.grid.value(u"rows"_s).toList()) {
            QVariantList row;
            for (const QVariant &c : r.toMap().value(u"cells"_s).toList()) {
                const QVariant ids = c.toMap().value(u"ids"_s);
                row << (ids.isValid() ? bestOf(s, ids) : kNoPlace);
            }
            columns = std::max(columns, int(row.size()));
            levels << QVariant(row);
        }
    } else {
        // The forms: one row of them, wrapped by the tile.
        QVariantList row;
        for (const QVariant &c : s.grid.value(u"cells"_s).toList()) {
            row << bestOf(s, c.toMap().value(u"ids"_s));
        }
        columns = int(row.size());
        if (columns > 0) {
            levels << QVariant(row);
        }
    }
    return {{u"ready"_s, true}, {u"title"_s, s.grid.value(u"title"_s)}, {u"columns"_s, columns}, {u"levels"_s, levels}};
}

// A word a day, the same all day: the day's number picks it among those with kanji and translation.
QVariantMap glossaryTile(const StartSnapshot &s)
{
    QVariantList usable;
    for (const QVariant &w : s.words) {
        if (!text(w, u"jp"_s).isEmpty() && !text(w, u"meaning"_s).isEmpty()) {
            usable << w;
        }
    }
    if (usable.isEmpty()) {
        return {{u"ready"_s, true}};
    }

    const QVariantMap word = usable.at(int(s.today.toJulianDay() % usable.size())).toMap();
    return {{u"ready"_s, true},
            {u"word"_s, word.value(u"word"_s)},
            {u"jp"_s, word.value(u"jp"_s)},
            {u"meaning"_s, word.value(u"meaning"_s)}};
}

QVariantMap notesTile(const StartSnapshot &s)
{
    const StartNotes &n = s.notes;
    return {{u"ready"_s, true},
            {u"techniques"_s, n.techniques},
            {u"courses"_s, n.courses},
            {u"text"_s, n.text},
            {u"media"_s, n.media},
            {u"at"_s, n.at}};
}

// What the worker builds from the copies and the immutable catalog.
void derive(StartSnapshot &s)
{
    if (s.hook) {
        s.hook();
    }

    for (const QHash<QDate, QSet<QString>> &year : s.dayEntries) {
        for (auto it = year.cbegin(); it != year.cend(); ++it) {
            s.perDay.insert(it.key(), int(it.value().size()));
        }
    }

    s.entries = s.programme->practiceEntries(s.discipline, s.grade);
    const QVariantList grids = s.programme->techniqueMap(s.discipline, s.grade);
    s.grid = grids.isEmpty() ? QVariantMap() : grids.first().toMap();

    // The exam: the planned one's points, else the exam mode's grade for the hint.
    const QString examDiscipline = text(s.plannedExam, u"discipline"_s);
    if (!examDiscipline.isEmpty()) {
        s.examIds = idsOf(s.exam->material(examDiscipline, text(s.plannedExam, u"grade"_s)));
    }
    const QString mockGrade = s.exam->grade(s.discipline, s.grade);
    for (const QVariant &g : s.exam->grades(s.discipline)) {
        if (text(g, u"id"_s) == mockGrade) {
            s.examGradeName = text(g, u"name"_s);
        }
    }
}

QVariantMap summarise(StartSnapshot s)
{
    derive(s);

    return {{u"programme"_s, programmeTile(s)}, {u"today"_s, todayTile(s)},   {u"exam"_s, examTile(s)},
            {u"stats"_s, statsTile(s)},         {u"courses"_s, coursesTile(s)}, {u"map"_s, mapTile(s)},
            {u"glossary"_s, glossaryTile(s)},   {u"notes"_s, notesTile(s)}};
}

// The first words of a note on one line.
QString firstWords(const QString &note)
{
    const QStringList words = note.simplified().split(u' ', Qt::SkipEmptyParts);
    const QString head = words.mid(0, kNoteWords).join(u' ');
    return words.size() > kNoteWords ? head + u"…"_s : head;
}

} // namespace

StartBoard *StartBoard::create(QQmlEngine *engine, QJSEngine *)
{
    return new StartBoard(Catalog::bundled(),
                          engine->singletonInstance<Programme *>("Mitori", "Programme"),
                          engine->singletonInstance<Practice *>("Mitori", "Practice"),
                          engine->singletonInstance<PracticeGrade *>("Mitori", "PracticeGrade"),
                          engine->singletonInstance<Courses *>("Mitori", "Courses"),
                          engine->singletonInstance<Glossary *>("Mitori", "Glossary"));
}

StartBoard::StartBoard(const Catalog &catalog, Programme *programme, Practice *practice, PracticeGrade *grades,
                       Courses *courses, Glossary *glossary, QObject *parent)
    : QObject(parent)
    , m_programme(programme)
    , m_practice(practice)
    , m_grades(grades)
    , m_courses(courses)
    , m_glossary(glossary)
    , m_workProgramme(catalog)
    , m_workExam(catalog, kExamSeed)
{
    m_pause.setSingleShot(true);
    m_pause.setInterval(kPauseMs);
    connect(&m_pause, &QTimer::timeout, this, &StartBoard::start);
    connect(&m_watcher, &QFutureWatcher<QVariantMap>::finished, this, &StartBoard::done);

    // Everything the summaries read; a burst of them is one run.
    const auto again = [this] { refresh(); };
    const auto notes = [this] {
        m_notesStale = true;
        refresh();
    };
    connect(m_programme, &Programme::textsChanged, this, again);
    connect(m_programme, &Programme::selectionChanged, this, again);
    connect(m_practice, &Practice::changed, this, again);
    connect(m_practice, &Practice::intervalsChanged, this, again);
    connect(m_practice, &Practice::todayChanged, this, again);
    connect(m_practice, &Practice::notesChanged, this, notes);
    connect(m_grades, &PracticeGrade::changed, this, again);
    connect(m_courses, &Courses::changed, this, notes);
    connect(m_courses, &Courses::calendarChanged, this, again);
    connect(m_glossary, &Glossary::wordsChanged, this, again);

    refresh();
}

StartBoard::~StartBoard()
{
    m_watcher.waitForFinished();
}

void StartBoard::refresh()
{
    if (!m_pause.isActive()) {
        m_pause.start();
    }
}

void StartBoard::start()
{
    if (m_watcher.isRunning()) {
        m_again = true;
        return;
    }
    QElapsedTimer timer;
    timer.start();
    StartSnapshot snap = snapshot();
    m_snapshotUs = timer.nsecsElapsed() / kNsPerUs;
    m_watcher.setFuture(QtConcurrent::run([snap = std::move(snap)]() mutable { return summarise(std::move(snap)); }));
}

void StartBoard::done()
{
    m_tiles = m_watcher.result();
    m_ready = true;
    emit tilesChanged();

    if (m_again) {
        m_again = false;
        start();
    }
}

// The notes: how many, and the newest of the notes on techniques and the entries of the notebooks.
// Two small queries each, not every note.
void StartBoard::readNotes()
{
    m_notes = {};
    m_notes.techniques = m_practice->noteCount();
    m_notes.courses = m_courses->entryCount();

    if (const auto n = m_practice->newestNote()) {
        m_notes.at = n->created;
        m_notes.text = firstWords(n->text);
        m_notes.media = !n->media.isEmpty();
    }
    if (const auto e = m_courses->newestEntry(); e && e->created > m_notes.at) {
        m_notes.at = e->created;
        m_notes.text = firstWords(e->text);
        m_notes.media = !e->media.isEmpty();
    }
    m_notes.at = m_notes.at.toLocalTime();
    m_notesStale = false;
}

StartSnapshot StartBoard::snapshot()
{
    StartSnapshot s;
    s.today = m_practice->today();
    s.discipline = m_programme->discipline();

    // The practice grade is worked out from every grade's entries (12 ms): kept until the programme,
    // the discipline or the grade changes.
    const QString gradeKey = QStringLiteral("%1|%2|%3").arg(m_programme->revision()).arg(m_grades->revision()).arg(s.discipline);
    if (gradeKey != m_gradeKey) {
        m_gradeKey = gradeKey;
        m_grade = m_grades->grade(s.discipline);
    }
    s.grade = m_grade;

    for (const QVariant &d : m_programme->disciplines()) {
        if (text(d, u"id"_s) != s.discipline) {
            continue;
        }
        s.disciplineName = text(d, u"kurzname"_s);
        for (const QVariant &g : d.toMap().value(u"grade"_s).toList()) {
            if (text(g, u"id"_s) == s.grade) {
                s.gradeName = text(g, u"name"_s);
            }
        }
    }
    s.ladder = m_courses->ladder(s.discipline);

    s.programme = &m_workProgramme;
    s.exam = &m_workExam;
    s.hook = m_hook;

    s.latest = m_practice->ratings();
    s.first = m_practice->firstDays();
    for (const QVariant &d : m_practice->intervals()) {
        s.intervals << d.toInt();
    }
    // The days of the years the streak can reach: copies sharing their data.
    const int firstYear = m_practice->firstYear();
    for (int year = std::max(firstYear, s.today.addDays(1 - kStreakDays).year()); year <= s.today.year(); ++year) {
        s.dayEntries << m_practice->dayEntries(year);
    }
    s.plannedExam = m_courses->nextExam();

    const QVariantList upcoming = m_courses->upcoming();
    if (!upcoming.isEmpty()) {
        s.course = upcoming.first().toMap();
        const QString notebook = s.course.value(u"notebook"_s).toString();
        s.courseEntries = notebook.isEmpty() ? -1 : m_courses->notebook(notebook).value(u"entries"_s).toInt();
    }

    s.words = m_glossary->words();

    if (m_notesStale) {
        readNotes();
    }
    s.notes = m_notes;
    return s;
}
