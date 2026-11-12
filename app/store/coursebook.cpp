#include "coursebook.h"

#include <QCoreApplication>
#include <QHash>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QTimeZone>
#include <QUuid>
#include <QVariant>

#include "writeahead.h"

namespace {

const QString kDateFormat = QStringLiteral("yyyy-MM-dd");
const QString kCourseColumns = QStringLiteral("uid, calendar_uid, title, first, last, place, teacher, info, announcement,"
                                              " created, changed, device, deleted, exam_discipline, exam_grade");
const QString kGradeColumns = QStringLiteral("uid, discipline, grade, day, place, created, changed, device, deleted");
const QString kEntryColumns = QStringLiteral("e.uid, e.course, e.text, e.created, e.changed, e.device, e.deleted, e.media");
// entry_tags.deleted of a link that went with its entry (see the header); 1 is unlinked by the user.
constexpr int kWithEntry = 2;

QDateTime utc(const QVariant &ms)
{
    return QDateTime::fromMSecsSinceEpoch(ms.toLongLong(), QTimeZone::UTC);
}

CourseBook::Course course(const QSqlQuery &q)
{
    CourseBook::Course c;
    c.uid = q.value(0).toString();
    c.calendarUid = q.value(1).toString();
    c.title = q.value(2).toString();
    c.first = QDate::fromString(q.value(3).toString(), kDateFormat);
    c.last = QDate::fromString(q.value(4).toString(), kDateFormat);
    c.place = q.value(5).toString();
    c.teacher = q.value(6).toString();
    c.info = q.value(7).toString();
    c.announcement = q.value(8).toString();
    c.created = utc(q.value(9));
    c.changed = utc(q.value(10));
    c.device = q.value(11).toString();
    c.deleted = q.value(12).toBool();
    c.examDiscipline = q.value(13).toString();
    c.examGrade = q.value(14).toString();
    return c;
}

CourseBook::Grade grade(const QSqlQuery &q)
{
    CourseBook::Grade g;
    g.uid = q.value(0).toString();
    g.discipline = q.value(1).toString();
    g.grade = q.value(2).toString();
    g.day = QDate::fromString(q.value(3).toString(), kDateFormat);
    g.place = q.value(4).toString();
    g.created = utc(q.value(5));
    g.changed = utc(q.value(6));
    g.device = q.value(7).toString();
    g.deleted = q.value(8).toBool();
    return g;
}

CourseBook::Entry entry(const QSqlQuery &q)
{
    CourseBook::Entry e;
    e.uid = q.value(0).toString();
    e.course = q.value(1).toString();
    e.text = q.value(2).toString();
    e.created = utc(q.value(3));
    e.changed = utc(q.value(4));
    e.device = q.value(5).toString();
    e.deleted = q.value(6).toBool();
    e.media = q.value(7).toString();
    return e;
}

// A null QString binds as NULL; the columns hold "" for nothing.
QVariant bound(const QString &s)
{
    return s.isNull() ? QVariant(QString(QLatin1String(""))) : QVariant(s);
}

// Whether a table has a column (a step that adds one runs again on a file set back by hand or a
// test, as the steps with IF NOT EXISTS do).
bool hasColumn(QSqlQuery &q, const QString &table, const QString &column)
{
    q.exec(QStringLiteral("PRAGMA table_info(%1)").arg(table));
    while (q.next()) {
        if (q.value(1).toString() == column) {
            return true;
        }
    }
    return false;
}

QString newUid()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

// A link's uid is the pair: the same link made on two devices is one row.
QString tagUid(const QString &entry, const QString &technique)
{
    return entry + QLatin1Char('/') + technique;
}

} // namespace

CourseBook::CourseBook()
    : m_connection(QStringLiteral("coursebook-") + newUid())
{
}

CourseBook::~CourseBook()
{
    if (QSqlDatabase::contains(m_connection)) {
        QSqlDatabase::database(m_connection).close();
        QSqlDatabase::removeDatabase(m_connection);
    }
}

bool CourseBook::open(const QString &path)
{
    QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), m_connection);
    db.setDatabaseName(path);
    if (!db.open()) {
        m_error = db.lastError().text();
        return false;
    }
    WriteAhead::enable(db);
    return migrate();
}

// user_version holds the schema; each step brings it one version further.
bool CourseBook::migrate()
{
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA user_version"));
    const int version = q.next() ? q.value(0).toInt() : 0;
    if (version > schemaVersion) {
        m_error = QCoreApplication::translate("CourseBook", "it comes from a newer Mitori (schema %1); update Mitori").arg(version);
        return false;
    }
    if (version < 1) {
        const bool ok = db.transaction()
            && q.exec(QStringLiteral("CREATE TABLE courses (uid TEXT PRIMARY KEY, calendar_uid TEXT NOT NULL DEFAULT '',"
                                     " title TEXT NOT NULL, first TEXT NOT NULL, last TEXT NOT NULL, place TEXT NOT NULL DEFAULT '',"
                                     " teacher TEXT NOT NULL DEFAULT '', info TEXT NOT NULL DEFAULT '',"
                                     " announcement TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL, changed INTEGER NOT NULL,"
                                     " device TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)"))
            && q.exec(QStringLiteral("CREATE TABLE entries (uid TEXT PRIMARY KEY, course TEXT NOT NULL, text TEXT NOT NULL,"
                                     " created INTEGER NOT NULL, changed INTEGER NOT NULL, device TEXT NOT NULL,"
                                     " deleted INTEGER NOT NULL DEFAULT 0)"))
            && q.exec(QStringLiteral("CREATE INDEX entries_course ON entries (course)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 1"))
            && db.commit();
        if (!ok) {
            m_error = q.lastError().text();
            db.rollback();
            return false;
        }
    }

    // 2: the user's grades and an exam planned on a course.
    if (version < 2) {
        const bool ok = db.transaction()
            && q.exec(QStringLiteral("ALTER TABLE courses ADD COLUMN exam_discipline TEXT NOT NULL DEFAULT ''"))
            && q.exec(QStringLiteral("ALTER TABLE courses ADD COLUMN exam_grade TEXT NOT NULL DEFAULT ''"))
            && q.exec(QStringLiteral("CREATE TABLE grades (uid TEXT PRIMARY KEY, discipline TEXT NOT NULL, grade TEXT NOT NULL,"
                                     " day TEXT NOT NULL, place TEXT NOT NULL DEFAULT '', created INTEGER NOT NULL,"
                                     " changed INTEGER NOT NULL, device TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 2"))
            && db.commit();
        if (!ok) {
            m_error = q.lastError().text();
            db.rollback();
            return false;
        }
    }

    // 3: a photo or voice note on an entry (the file's name in the media folder, "" for none).
    if (version < 3) {
        const bool ok = (hasColumn(q, QStringLiteral("entries"), QStringLiteral("media"))
                         || q.exec(QStringLiteral("ALTER TABLE entries ADD COLUMN media TEXT NOT NULL DEFAULT ''")))
            && q.exec(QStringLiteral("PRAGMA user_version = 3"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }

    // 4: when the user began training in a discipline (a grade's waiting time may count from it);
    // the discipline is the uid, so two devices merge into one row.
    if (version < 4) {
        const bool ok = q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS starts (uid TEXT PRIMARY KEY, day TEXT NOT NULL,"
                                              " created INTEGER NOT NULL, changed INTEGER NOT NULL, device TEXT NOT NULL,"
                                              " deleted INTEGER NOT NULL DEFAULT 0)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 4"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }

    // 5: the techniques an entry is linked to.
    if (version < 5) {
        const bool ok = q.exec(QStringLiteral("CREATE TABLE IF NOT EXISTS entry_tags (uid TEXT PRIMARY KEY, entry TEXT NOT NULL,"
                                              " technique TEXT NOT NULL, created INTEGER NOT NULL, changed INTEGER NOT NULL,"
                                              " device TEXT NOT NULL, deleted INTEGER NOT NULL DEFAULT 0)"))
            && q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS entry_tags_entry ON entry_tags (entry)"))
            && q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS entry_tags_technique ON entry_tags (technique)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 5"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }
    return true;
}

QHash<QString, QDate> CourseBook::starts() const
{
    QHash<QString, QDate> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT uid, day FROM starts WHERE deleted = 0"));
    while (q.next()) {
        result.insert(q.value(0).toString(), QDate::fromString(q.value(1).toString(), kDateFormat));
    }
    return result;
}

bool CourseBook::setStart(const QString &discipline, const QDate &day, const QDateTime &at, const QString &device)
{
    m_error.clear();
    QSqlQuery q(QSqlDatabase::database(m_connection));
    const qint64 now = at.toUTC().toMSecsSinceEpoch();
    if (!day.isValid()) {
        q.prepare(QStringLiteral("UPDATE starts SET deleted = 1, changed = ?, device = ? WHERE uid = ?"));
        q.addBindValue(now);
        q.addBindValue(device);
        q.addBindValue(discipline);
    } else {
        q.prepare(QStringLiteral("INSERT INTO starts (uid, day, created, changed, device, deleted) VALUES (?, ?, ?, ?, ?, 0)"
                                 " ON CONFLICT(uid) DO UPDATE SET day = excluded.day, changed = excluded.changed,"
                                 " device = excluded.device, deleted = 0"));
        for (const QVariant &v : {QVariant(discipline), QVariant(day.toString(kDateFormat)), QVariant(now), QVariant(now),
                                  QVariant(device)}) {
            q.addBindValue(v);
        }
    }
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return true;
}

CourseBook::Course CourseBook::addCourse(Course c, const QDateTime &at, const QString &device)
{
    m_error.clear();
    if (c.title.trimmed().isEmpty() || !c.first.isValid()) {
        m_error = QCoreApplication::translate("CourseBook", "a course needs a title and a first day");
        return {};
    }
    c.uid = newUid();
    c.created = at.toUTC();
    c.changed = c.created;
    c.device = device;
    c.deleted = false;
    if (!c.last.isValid() || c.last < c.first) {
        c.last = c.first;
    }

    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("INSERT INTO courses (%1) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)").arg(kCourseColumns));
    for (const QVariant &v : {QVariant(c.uid), bound(c.calendarUid), QVariant(c.title.trimmed()),
                              QVariant(c.first.toString(kDateFormat)), QVariant(c.last.toString(kDateFormat)),
                              bound(c.place), bound(c.teacher), bound(c.info), bound(c.announcement),
                              QVariant(c.created.toMSecsSinceEpoch()), QVariant(c.changed.toMSecsSinceEpoch()),
                              bound(device), bound(c.examDiscipline), bound(c.examGrade)}) {
        q.addBindValue(v);
    }
    if (!q.exec()) {
        m_error = q.lastError().text();
        return {};
    }
    c.title = c.title.trimmed();
    return c;
}

QList<CourseBook::Course> CourseBook::courses() const
{
    QList<Course> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT %1 FROM courses WHERE deleted = 0 ORDER BY first DESC, created DESC").arg(kCourseColumns));
    while (q.next()) {
        result << course(q);
    }
    return result;
}

CourseBook::Course CourseBook::courseForEvent(const QString &calendarUid) const
{
    if (calendarUid.isEmpty()) {
        return {};
    }
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT %1 FROM courses WHERE calendar_uid = ? AND deleted = 0 ORDER BY created LIMIT 1").arg(kCourseColumns));
    q.addBindValue(calendarUid);
    return q.exec() && q.next() ? course(q) : Course();
}

// The notebook and its entries, in one step: the entries go as marks too (sync).
bool CourseBook::deleteCourse(const QString &uid, const QDateTime &at)
{
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    if (!db.transaction()) {
        m_error = db.lastError().text();
        return false;
    }
    QSqlQuery q(db);
    q.prepare(QStringLiteral("UPDATE entry_tags SET deleted = %1, changed = ? WHERE deleted = 0"
                             " AND entry IN (SELECT uid FROM entries WHERE course = ?)").arg(kWithEntry));
    q.addBindValue(at.toUTC().toMSecsSinceEpoch());
    q.addBindValue(uid);
    if (!q.exec()) {
        m_error = q.lastError().text();
        db.rollback();
        return false;
    }
    q.prepare(QStringLiteral("UPDATE entries SET deleted = 1, changed = ? WHERE course = ? AND deleted = 0"));
    q.addBindValue(at.toUTC().toMSecsSinceEpoch());
    q.addBindValue(uid);
    if (!q.exec() || !mark(QStringLiteral("courses"), uid, at)) {
        if (m_error.isEmpty()) {
            m_error = q.lastError().text();
        }
        db.rollback();
        return false;
    }
    return db.commit();
}

bool CourseBook::planExam(const QString &uid, const QString &discipline, const QString &grade, const QDateTime &at)
{
    m_error.clear();
    const bool none = discipline.isEmpty() || grade.isEmpty();
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("UPDATE courses SET exam_discipline = ?, exam_grade = ?, changed = ? WHERE uid = ? AND deleted = 0"));
    q.addBindValue(none ? QString(QLatin1String("")) : discipline);
    q.addBindValue(none ? QString(QLatin1String("")) : grade);
    q.addBindValue(at.toUTC().toMSecsSinceEpoch());
    q.addBindValue(uid);
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return q.numRowsAffected() == 1;
}

// A grade passed again (a corrected day or place) keeps its row: one per discipline and grade.
CourseBook::Grade CourseBook::addGrade(Grade g, const QDateTime &at, const QString &device)
{
    m_error.clear();
    if (g.discipline.isEmpty() || g.grade.isEmpty() || !g.day.isValid()) {
        m_error = QCoreApplication::translate("CourseBook", "a grade needs a discipline, a grade and a day");
        return {};
    }
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    QSqlQuery q(db);
    q.prepare(QStringLiteral("SELECT %1 FROM grades WHERE discipline = ? AND grade = ? AND deleted = 0").arg(kGradeColumns));
    q.addBindValue(g.discipline);
    q.addBindValue(g.grade);
    const bool known = q.exec() && q.next();
    const Grade old = known ? grade(q) : Grade();
    q.finish();

    g.uid = known ? old.uid : newUid();
    g.created = known ? old.created : at.toUTC();
    g.changed = at.toUTC();
    g.device = device;
    g.deleted = false;
    g.place = g.place.trimmed();
    if (known) {
        q.prepare(QStringLiteral("UPDATE grades SET day = ?, place = ?, changed = ?, device = ? WHERE uid = ?"));
        for (const QVariant &v : {QVariant(g.day.toString(kDateFormat)), bound(g.place), QVariant(g.changed.toMSecsSinceEpoch()),
                                  bound(device), QVariant(g.uid)}) {
            q.addBindValue(v);
        }
    } else {
        q.prepare(QStringLiteral("INSERT INTO grades (%1) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)").arg(kGradeColumns));
        for (const QVariant &v : {QVariant(g.uid), QVariant(g.discipline), QVariant(g.grade), QVariant(g.day.toString(kDateFormat)),
                                  bound(g.place), QVariant(g.created.toMSecsSinceEpoch()), QVariant(g.changed.toMSecsSinceEpoch()),
                                  bound(device)}) {
            q.addBindValue(v);
        }
    }
    if (!q.exec()) {
        m_error = q.lastError().text();
        return {};
    }
    return g;
}

bool CourseBook::deleteGrade(const QString &uid, const QDateTime &at)
{
    return mark(QStringLiteral("grades"), uid, at);
}

QList<CourseBook::Grade> CourseBook::grades() const
{
    QList<Grade> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT %1 FROM grades WHERE deleted = 0 ORDER BY day DESC, created DESC").arg(kGradeColumns));
    while (q.next()) {
        result << grade(q);
    }
    return result;
}

CourseBook::Entry CourseBook::addEntry(const QString &courseUid, const QString &text, const QDateTime &at, const QString &device,
                                      const QString &media)
{
    m_error.clear();
    Entry e{newUid(), courseUid, text.trimmed(), at.toUTC(), at.toUTC(), device, false, media};
    if ((e.text.isEmpty() && media.isEmpty()) || courseUid.isEmpty()) {
        m_error = QCoreApplication::translate("CourseBook", "an entry needs a text and a course");
        return {};
    }
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("INSERT INTO entries (uid, course, text, created, changed, device, deleted, media)"
                             " VALUES (?, ?, ?, ?, ?, ?, 0, ?)"));
    for (const QVariant &v : {QVariant(e.uid), QVariant(e.course), bound(e.text), QVariant(e.created.toMSecsSinceEpoch()),
                              QVariant(e.changed.toMSecsSinceEpoch()), bound(device), bound(media)}) {
        q.addBindValue(v);
    }
    if (!q.exec()) {
        m_error = q.lastError().text();
        return {};
    }
    return e;
}

// An entry with a photo or voice note may lose its text, one without may not.
bool CourseBook::changeEntry(const QString &uid, const QString &text, const QDateTime &at)
{
    m_error.clear();
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("UPDATE entries SET text = ?, changed = ? WHERE uid = ? AND deleted = 0 AND (? <> '' OR media <> '')"));
    q.addBindValue(text.trimmed());
    q.addBindValue(at.toUTC().toMSecsSinceEpoch());
    q.addBindValue(uid);
    q.addBindValue(text.trimmed());
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return q.numRowsAffected() == 1;
}

QString CourseBook::entryMedia(const QString &uid) const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT media FROM entries WHERE uid = ?"));
    q.addBindValue(uid);
    return q.exec() && q.next() ? q.value(0).toString() : QString();
}

QStringList CourseBook::courseMedia(const QString &course) const
{
    QStringList result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT media FROM entries WHERE course = ? AND media <> ''"));
    q.addBindValue(course);
    q.exec();
    while (q.next()) {
        result << q.value(0).toString();
    }
    return result;
}

// The entry and its links, in one step.
bool CourseBook::deleteEntry(const QString &uid, const QDateTime &at)
{
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    if (!db.transaction()) {
        m_error = db.lastError().text();
        return false;
    }
    QSqlQuery q(db);
    q.prepare(QStringLiteral("UPDATE entry_tags SET deleted = %1, changed = ? WHERE entry = ? AND deleted = 0").arg(kWithEntry));
    q.addBindValue(at.toUTC().toMSecsSinceEpoch());
    q.addBindValue(uid);
    if (!q.exec()) {
        m_error = q.lastError().text();
        db.rollback();
        return false;
    }
    if (!mark(QStringLiteral("entries"), uid, at)) {
        db.rollback();
        return false;
    }
    return db.commit();
}

bool CourseBook::addTag(const QString &entryUid, const QString &technique, const QDateTime &at, const QString &device)
{
    m_error.clear();
    if (technique.isEmpty()) {
        m_error = QCoreApplication::translate("CourseBook", "a link needs a technique");
        return false;
    }
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT 1 FROM entries WHERE uid = ? AND deleted = 0"));
    q.addBindValue(entryUid);
    if (!q.exec() || !q.next()) {
        m_error = q.lastError().isValid() ? q.lastError().text() : QCoreApplication::translate("CourseBook", "the entry is gone");
        return false;
    }
    q.finish();

    // A link removed before comes back on its row; one that stands keeps its time.
    const qint64 now = at.toUTC().toMSecsSinceEpoch();
    q.prepare(QStringLiteral("INSERT INTO entry_tags (uid, entry, technique, created, changed, device, deleted)"
                             " VALUES (?, ?, ?, ?, ?, ?, 0) ON CONFLICT(uid) DO UPDATE SET changed = excluded.changed,"
                             " device = excluded.device, deleted = 0 WHERE deleted <> 0"));
    for (const QVariant &v : {QVariant(tagUid(entryUid, technique)), QVariant(entryUid), QVariant(technique), QVariant(now),
                              QVariant(now), bound(device)}) {
        q.addBindValue(v);
    }
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return true;
}

bool CourseBook::removeTag(const QString &entry, const QString &technique, const QDateTime &at)
{
    return mark(QStringLiteral("entry_tags"), tagUid(entry, technique), at);
}

QHash<QString, QStringList> CourseBook::courseTags(const QString &course) const
{
    QHash<QString, QStringList> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT t.entry, t.technique FROM entry_tags t JOIN entries e ON e.uid = t.entry"
                             " WHERE e.course = ? AND t.deleted = 0 AND e.deleted = 0 ORDER BY t.created, t.rowid"));
    q.addBindValue(course);
    q.exec();
    while (q.next()) {
        result[q.value(0).toString()] << q.value(1).toString();
    }
    return result;
}

QList<CourseBook::Linked> CourseBook::linkedEntries(const QString &technique) const
{
    QList<Linked> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT %1, c.title, c.first, c.last FROM entry_tags t JOIN entries e ON e.uid = t.entry"
                             " JOIN courses c ON c.uid = e.course"
                             " WHERE t.technique = ? AND t.deleted = 0 AND e.deleted = 0 AND c.deleted = 0"
                             " ORDER BY c.first DESC, c.created DESC, e.created, e.rowid").arg(kEntryColumns));
    q.addBindValue(technique);
    q.exec();
    while (q.next()) {
        result << Linked{entry(q), q.value(8).toString(), QDate::fromString(q.value(9).toString(), kDateFormat),
                         QDate::fromString(q.value(10).toString(), kDateFormat)};
    }
    return result;
}

// A deletion stays as a mark with its time (sync).
bool CourseBook::mark(const QString &table, const QString &uid, const QDateTime &at)
{
    m_error.clear();
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("UPDATE %1 SET deleted = 1, changed = ? WHERE uid = ? AND deleted = 0").arg(table));
    q.addBindValue(at.toUTC().toMSecsSinceEpoch());
    q.addBindValue(uid);
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return q.numRowsAffected() == 1;
}

QList<CourseBook::Entry> CourseBook::entries(const QString &courseUid) const
{
    QList<Entry> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT uid, course, text, created, changed, device, deleted, media FROM entries"
                             " WHERE course = ? AND deleted = 0 ORDER BY created, rowid"));
    q.addBindValue(courseUid);
    q.exec();
    while (q.next()) {
        result << entry(q);
    }
    return result;
}

QList<CourseBook::Entry> CourseBook::allEntries() const
{
    QList<Entry> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT e.uid, e.course, e.text, e.created, e.changed, e.device, e.deleted, e.media FROM entries e"
                          " JOIN courses c ON c.uid = e.course WHERE e.deleted = 0 AND c.deleted = 0"
                          " ORDER BY e.created DESC, e.rowid DESC"));
    while (q.next()) {
        result << entry(q);
    }
    return result;
}

int CourseBook::entryCount() const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT COUNT(*) FROM entries e JOIN courses c ON c.uid = e.course"
                          " WHERE e.deleted = 0 AND c.deleted = 0"));
    return q.next() ? q.value(0).toInt() : 0;
}

std::optional<CourseBook::Entry> CourseBook::newestEntry() const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT e.uid, e.course, e.text, e.created, e.changed, e.device, e.deleted, e.media FROM entries e"
                          " JOIN courses c ON c.uid = e.course WHERE e.deleted = 0 AND c.deleted = 0"
                          " ORDER BY e.created DESC, e.rowid DESC LIMIT 1"));
    return q.next() ? std::optional<Entry>(entry(q)) : std::nullopt;
}

QHash<QString, int> CourseBook::entryCounts() const
{
    QHash<QString, int> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT course, COUNT(*) FROM entries WHERE deleted = 0 GROUP BY course"));
    while (q.next()) {
        result.insert(q.value(0).toString(), q.value(1).toInt());
    }
    return result;
}

QHash<QString, QDateTime> CourseBook::entryVersions() const
{
    QHash<QString, QDateTime> versions;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT uid, changed FROM entries"));
    while (q.next()) {
        versions.insert(q.value(0).toString(), QDateTime::fromMSecsSinceEpoch(q.value(1).toLongLong(), QTimeZone::UTC));
    }
    return versions;
}

bool CourseBook::snapshot(const QString &path)
{
    m_error.clear();
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("VACUUM INTO ?"));
    q.addBindValue(path);
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return true;
}

namespace {

// After a merge: one notebook per calendar event and one row per passed grade, as the app keeps
// them. The losers become deletion marks (now), so a later merge carries that on.
bool joinDoubles(QSqlDatabase &db, QString *error)
{
    const QString now = QStringLiteral("CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER)");
    const QStringList steps = {
        // Notebooks of one event: the oldest stays, the others' entries and planned exam move to it.
        QStringLiteral("DROP TABLE IF EXISTS temp.doubles"),
        QStringLiteral("CREATE TEMP TABLE doubles AS SELECT c.uid AS loser,"
                       " (SELECT w.uid FROM courses w WHERE w.deleted = 0 AND w.calendar_uid = c.calendar_uid"
                       "  ORDER BY w.created, w.uid LIMIT 1) AS winner"
                       " FROM courses c WHERE c.deleted = 0 AND c.calendar_uid <> ''"),
        QStringLiteral("DELETE FROM temp.doubles WHERE loser = winner"),
        QStringLiteral("UPDATE entries SET course = (SELECT winner FROM temp.doubles WHERE loser = entries.course),"
                       " changed = %1 WHERE course IN (SELECT loser FROM temp.doubles)").arg(now),
        QStringLiteral("UPDATE courses SET (exam_discipline, exam_grade) = (SELECT l.exam_discipline, l.exam_grade"
                       "  FROM temp.doubles d JOIN courses l ON l.uid = d.loser"
                       "  WHERE d.winner = courses.uid AND l.exam_discipline <> '' LIMIT 1), changed = %1"
                       " WHERE exam_discipline = '' AND uid IN (SELECT d.winner FROM temp.doubles d"
                       "  JOIN courses l ON l.uid = d.loser WHERE l.exam_discipline <> '')").arg(now),
        QStringLiteral("UPDATE courses SET deleted = 1, changed = %1 WHERE uid IN (SELECT loser FROM temp.doubles)").arg(now),
        QStringLiteral("DROP TABLE temp.doubles"),
        // Entries written on another device into a notebook joined here earlier: to the one left.
        // (Deleting a notebook deletes its entries, so a live entry there came from a merge.)
        QStringLiteral("UPDATE entries SET course = (SELECT w.uid FROM courses l JOIN courses w"
                       "  ON w.calendar_uid = l.calendar_uid AND w.deleted = 0"
                       "  WHERE l.uid = entries.course ORDER BY w.created, w.uid LIMIT 1), changed = %1"
                       " WHERE deleted = 0 AND course IN (SELECT l.uid FROM courses l WHERE l.deleted = 1"
                       "  AND l.calendar_uid <> '' AND EXISTS (SELECT 1 FROM courses w"
                       "  WHERE w.deleted = 0 AND w.calendar_uid = l.calendar_uid))").arg(now),
        // Any other live entry of a deleted notebook: newer than the deletion, it brings the
        // notebook back (written after it, on another device); older, it goes with it.
        QStringLiteral("UPDATE courses SET deleted = 0, changed = %1 WHERE deleted = 1 AND EXISTS (SELECT 1 FROM entries e"
                       " WHERE e.course = courses.uid AND e.deleted = 0 AND e.changed > courses.changed)").arg(now),
        QStringLiteral("UPDATE entries SET deleted = 1, changed = %1 WHERE deleted = 0"
                       " AND course IN (SELECT uid FROM courses WHERE deleted = 1)").arg(now),
        // Links follow their entry as it stands now: gone with a deleted one (made elsewhere after
        // the deletion), back with one that returned (changed elsewhere after the deletion).
        QStringLiteral("UPDATE entry_tags SET deleted = %1, changed = %2 WHERE deleted = 0"
                       " AND entry IN (SELECT uid FROM entries WHERE deleted = 1)").arg(kWithEntry).arg(now),
        QStringLiteral("UPDATE entry_tags SET deleted = 0, changed = %1 WHERE deleted = %2"
                       " AND entry IN (SELECT uid FROM entries WHERE deleted = 0)").arg(now).arg(kWithEntry),
        // One passed grade twice: the newer row stays.
        QStringLiteral("UPDATE grades SET deleted = 1, changed = %1 WHERE deleted = 0 AND EXISTS (SELECT 1 FROM grades g"
                       " WHERE g.deleted = 0 AND g.discipline = grades.discipline AND g.grade = grades.grade"
                       " AND (g.changed > grades.changed OR (g.changed = grades.changed AND g.uid > grades.uid)))").arg(now),
    };
    QSqlQuery q(db);
    for (const QString &step : steps) {
        if (!q.exec(step)) {
            *error = q.lastError().text();
            return false;
        }
    }
    return true;
}

} // namespace

QList<TableMerge::Table> CourseBook::tables()
{
    using namespace Qt::StringLiterals;
    using TableMerge::Kind;
    return {
        {QStringLiteral("courses"),
         {u"uid"_s, u"calendar_uid"_s, u"title"_s, u"first"_s, u"last"_s, u"place"_s, u"teacher"_s, u"info"_s,
          u"announcement"_s, u"created"_s, u"changed"_s, u"device"_s, u"deleted"_s, u"exam_discipline"_s,
          u"exam_grade"_s},
         Kind::Editable, {}},
        {QStringLiteral("entries"),
         {u"uid"_s, u"course"_s, u"text"_s, u"created"_s, u"changed"_s, u"device"_s, u"deleted"_s, u"media"_s},
         Kind::Editable, u"media"_s, u"text"_s, u"course"_s},
        {QStringLiteral("grades"),
         {u"uid"_s, u"discipline"_s, u"grade"_s, u"day"_s, u"place"_s, u"created"_s, u"changed"_s, u"device"_s,
          u"deleted"_s},
         Kind::Editable, {}},
        {QStringLiteral("starts"), {u"uid"_s, u"day"_s, u"created"_s, u"changed"_s, u"device"_s, u"deleted"_s},
         Kind::Editable, {}},
        {QStringLiteral("entry_tags"),
         {u"uid"_s, u"entry"_s, u"technique"_s, u"created"_s, u"changed"_s, u"device"_s, u"deleted"_s},
         Kind::Editable, {}},
    };
}

bool CourseBook::merge(const QString &otherPath, TableMerge::Mode mode, TableMerge::Result *result,
                   const TableMerge::Watch &watch)
{
    m_error.clear();
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    return TableMerge::run(db, otherPath, tables(), mode, result, &m_error, joinDoubles, watch);
}
