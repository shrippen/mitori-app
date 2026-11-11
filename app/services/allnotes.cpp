#include "allnotes.h"

#include "courses.h"
#include "lessons.h"
#include "practice.h"
#include "programme.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QEvent>

namespace {

const QString kTechnique = QStringLiteral("technique");
const QString kCourse = QStringLiteral("course");

} // namespace

void AllNotes::setPractice(Practice *practice)
{
    if (m_practice == practice) {
        return;
    }
    if (m_practice) {
        disconnect(m_practice, nullptr, this, nullptr);
    }
    m_practice = practice;
    if (m_practice) {
        connect(m_practice, &Practice::notesChanged, this, &AllNotes::rebuild);
    }
    emit sourcesChanged();
    rebuild();
}

AllNotes::AllNotes(QObject *parent)
    : KeyedListModel(parent)
{
    // A new catalog (Appearance::setLanguage): a row's texts are read anew.
    if (auto *app = QCoreApplication::instance()) {
        app->installEventFilter(this);
    }
    // A Lernpaket came or went: its notes' titles are read anew.
    connect(&Lessons::shared(), &Lessons::changed, this, [this] {
        m_techniques.clear();
        rebuild();
    });
}

bool AllNotes::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::LanguageChange && watched == QCoreApplication::instance()) {
        m_techniques.clear();
        readGradeNames();
        rebuild();
    }
    return KeyedListModel::eventFilter(watched, event);
}

void AllNotes::setCourses(Courses *courses)
{
    if (m_courses == courses) {
        return;
    }
    if (m_courses) {
        disconnect(m_courses, nullptr, this, nullptr);
    }
    m_courses = courses;
    if (m_courses) {
        connect(m_courses, &Courses::changed, this, &AllNotes::rebuild);
    }
    emit sourcesChanged();
    rebuild();
}

void AllNotes::setProgramme(Programme *programme)
{
    if (m_programme == programme) {
        return;
    }
    m_programme = programme;
    m_techniques.clear();
    readGradeNames();
    emit sourcesChanged();
    rebuild();
}

// The grades' names in the programme's language of now (a LanguageChange reads them anew).
void AllNotes::readGradeNames()
{
    m_gradeNames.clear();
    if (!m_programme) {
        return;
    }
    for (const QVariant &dv : m_programme->disciplines()) {
        const QVariantMap d = dv.toMap();
        const QString id = d.value(QStringLiteral("id")).toString();
        for (const QVariant &gv : m_programme->grades(id)) {
            const QVariantMap g = gv.toMap();
            m_gradeNames.insert(id + QLatin1Char('/') + g.value(QStringLiteral("id")).toString(),
                                d.value(QStringLiteral("kurzname")).toString() + QLatin1Char(' ')
                                    + g.value(QStringLiteral("name")).toString());
        }
    }
}

void AllNotes::setFilter(const QString &filter)
{
    if (m_filter == filter) {
        return;
    }
    m_filter = filter;
    emit filterChanged();
    show();
}

void AllNotes::rebuild()
{
    collect();
    show();
}

// "Aikido 5. Kyu · 3 · Shiho-nage · Katate-dori"; a note whose technique left the programme
// says so.
QString AllNotes::techniqueTitle(const QVariantMap &e) const
{
    const QString title = e.value(QStringLiteral("title")).toString();
    if (title.isEmpty()) {
        return tr("Technique no longer in the programme");
    }
    const QString nr = e.value(QStringLiteral("nr")).toString();
    // A Lernpaket's technique has no grade: its package stands there.
    QString gradeName = m_gradeNames.value(e.value(QStringLiteral("discipline")).toString() + QLatin1Char('/')
                                           + e.value(QStringLiteral("grade")).toString());
    if (gradeName.isEmpty() && !e.value(QStringLiteral("package")).toString().isEmpty()) {
        gradeName = e.value(QStringLiteral("disciplineName")).toString();
    }
    QStringList parts{gradeName,
                      (nr.isEmpty() ? QString() : nr + QStringLiteral(" · ")) + title,
                      e.value(QStringLiteral("attack")).toString()};
    parts.removeAll(QString());
    return parts.join(QStringLiteral(" · "));
}

// A technique's title and discipline, read from the programme once (an entry is a large map,
// and many notes share a technique).
const AllNotes::Technique &AllNotes::technique(const QString &entry)
{
    auto it = m_techniques.find(entry);
    if (it == m_techniques.end()) {
        const QVariantMap e = m_programme->entry(entry);
        it = m_techniques.insert(entry, {techniqueTitle(e), e.value(QStringLiteral("discipline")).toString()});
    }
    return *it;
}

// The local day of a time (UTC), converted only when it leaves the day of the one before: the
// notes come newest first, so a day costs one conversion, not each note (toLocalTime is slow).
class DayOf
{
public:
    QString operator()(const QDateTime &utc)
    {
        const qint64 ms = utc.toMSecsSinceEpoch();
        if (ms < m_from || ms >= m_to) {
            const QDate day = utc.toLocalTime().date();
            m_from = QDateTime(day, QTime(0, 0)).toMSecsSinceEpoch();
            m_to = QDateTime(day.addDays(1), QTime(0, 0)).toMSecsSinceEpoch();
            m_text = day.toString(Qt::ISODate);
        }
        return m_text;
    }

private:
    qint64 m_from = 0;
    qint64 m_to = 0;
    QString m_text;
};

// Both kinds in one list, newest first: the two lists come sorted, so they are merged.
void AllNotes::collect()
{
    m_all.clear();
    m_lessonNotes = 0;
    const QList<PracticeLog::Note> notes = m_practice && m_programme ? m_practice->noteRecords() : QList<PracticeLog::Note>();
    const QList<CourseBook::Entry> entries = m_courses ? m_courses->allEntries() : QList<CourseBook::Entry>();
    const QHash<QString, QString> titles = m_courses ? m_courses->courseTitles() : QHash<QString, QString>();
    m_all.reserve(notes.size() + entries.size());

    DayOf dayOf;
    qsizetype i = 0;
    qsizetype j = 0;
    while (i < notes.size() || j < entries.size()) {
        const bool note = j >= entries.size() || (i < notes.size() && notes.at(i).created >= entries.at(j).created);
        if (note) {
            const PracticeLog::Note &n = notes.at(i++);
            const Technique &t = technique(n.entry);
            m_lessonNotes += t.discipline == QLatin1String(Lessons::kDiscipline);
            m_all << QVariantMap{{QStringLiteral("uid"), n.uid}, {QStringLiteral("kind"), kTechnique},
                                 {QStringLiteral("text"), n.text}, {QStringLiteral("created"), n.created},
                                 {QStringLiteral("changed"), n.changed}, {QStringLiteral("day"), dayOf(n.created)},
                                 {QStringLiteral("title"), t.title}, {QStringLiteral("discipline"), t.discipline},
                                 {QStringLiteral("entry"), n.entry}, {QStringLiteral("media"), n.media}};
            continue;
        }
        const CourseBook::Entry &e = entries.at(j++);
        m_all << QVariantMap{{QStringLiteral("uid"), e.uid}, {QStringLiteral("kind"), kCourse},
                             {QStringLiteral("text"), e.text}, {QStringLiteral("created"), e.created},
                             {QStringLiteral("changed"), e.changed}, {QStringLiteral("day"), dayOf(e.created)},
                             {QStringLiteral("title"), titles.value(e.course)}, {QStringLiteral("discipline"), QString()},
                             {QStringLiteral("course"), e.course}, {QStringLiteral("media"), e.media}};
    }
}

void AllNotes::show()
{
    if (m_filter.isEmpty()) {
        setRows(m_all);
        return;
    }
    const bool courses = m_filter == QLatin1String(kCourses);
    QVariantList shown;
    for (const QVariant &v : std::as_const(m_all)) {
        const QVariantMap n = v.toMap();
        const bool match = courses ? n.value(QStringLiteral("kind")) == kCourse
                                   : n.value(QStringLiteral("discipline")) == m_filter;
        if (match) {
            shown << v;
        }
    }
    setRows(shown);
}
