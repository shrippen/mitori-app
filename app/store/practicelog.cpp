#include "practicelog.h"

#include <limits>

#include <QCoreApplication>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QSet>
#include <QTimeZone>
#include <QUuid>
#include <QVariant>

#include "writeahead.h"

namespace {

PracticeLog::Rating rating(const QSqlQuery &q)
{
    PracticeLog::Rating r;
    r.uid = q.value(0).toString();
    r.entry = q.value(1).toString();
    r.level = q.value(2).toInt();
    r.at = QDateTime::fromMSecsSinceEpoch(q.value(3).toLongLong(), QTimeZone::UTC);
    r.device = q.value(4).toString();
    return r;
}

PracticeLog::Note note(const QSqlQuery &q)
{
    PracticeLog::Note n;
    n.uid = q.value(0).toString();
    n.entry = q.value(1).toString();
    n.text = q.value(2).toString();
    n.created = QDateTime::fromMSecsSinceEpoch(q.value(3).toLongLong(), QTimeZone::UTC);
    n.changed = QDateTime::fromMSecsSinceEpoch(q.value(4).toLongLong(), QTimeZone::UTC);
    n.device = q.value(5).toString();
    n.deleted = q.value(6).toBool();
    n.media = q.value(7).toString();
    return n;
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

} // namespace

PracticeLog::PracticeLog()
    : m_connection(QStringLiteral("practicelog-") + QUuid::createUuid().toString(QUuid::WithoutBraces))
{
}

PracticeLog::~PracticeLog()
{
    if (QSqlDatabase::contains(m_connection)) {
        QSqlDatabase::database(m_connection).close();
        QSqlDatabase::removeDatabase(m_connection);
    }
}

bool PracticeLog::open(const QString &path)
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
bool PracticeLog::migrate()
{
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    QSqlQuery q(db);
    q.exec(QStringLiteral("PRAGMA user_version"));
    const int version = q.next() ? q.value(0).toInt() : 0;
    if (version > schemaVersion) {
        m_error = QCoreApplication::translate("PracticeLog", "it comes from a newer Mitori (schema %1); update Mitori").arg(version);
        return false;
    }
    if (version < 1) {
        const bool ok = q.exec(QStringLiteral(
                            "CREATE TABLE IF NOT EXISTS ratings ("
                            " uid TEXT PRIMARY KEY, entry TEXT NOT NULL, level INTEGER NOT NULL,"
                            " at INTEGER NOT NULL, device TEXT NOT NULL)"))
            && q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS ratings_entry ON ratings (entry, at)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 1"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }
    if (version < 2) {
        const bool ok = q.exec(QStringLiteral(
                            "CREATE TABLE IF NOT EXISTS notes ("
                            " uid TEXT PRIMARY KEY, entry TEXT NOT NULL, text TEXT NOT NULL,"
                            " created INTEGER NOT NULL, changed INTEGER NOT NULL, device TEXT NOT NULL,"
                            " deleted INTEGER NOT NULL DEFAULT 0)"))
            && q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS notes_entry ON notes (entry, created)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 2"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }
    if (version < 3 && !mergeKamae()) {
        return false;
    }
    if (version < 4) {
        const bool ok = q.exec(QStringLiteral(
                            "CREATE TABLE IF NOT EXISTS exam_rounds ("
                            " uid TEXT PRIMARY KEY, at INTEGER NOT NULL, discipline TEXT NOT NULL,"
                            " grade TEXT NOT NULL, count INTEGER NOT NULL, average REAL NOT NULL,"
                            " device TEXT NOT NULL)"))
            && q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS exam_rounds_discipline ON exam_rounds (discipline, at)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 4"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }
    // 5: a photo or voice note on a note (the file's name in the media folder, "" for none).
    if (version < 5) {
        const bool ok = (hasColumn(q, QStringLiteral("notes"), QStringLiteral("media"))
                         || q.exec(QStringLiteral("ALTER TABLE notes ADD COLUMN media TEXT NOT NULL DEFAULT ''")))
            && q.exec(QStringLiteral("PRAGMA user_version = 5"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }
    // 6: the ratings by time (the calendars ask for a year of them; 100000 ratings are a real user).
    if (version < 6) {
        const bool ok = q.exec(QStringLiteral("CREATE INDEX IF NOT EXISTS ratings_at ON ratings (at)"))
            && q.exec(QStringLiteral("PRAGMA user_version = 6"));
        if (!ok) {
            m_error = q.lastError().text();
            return false;
        }
    }
    return true;
}

// Schema 3: the Kamae exercise of Shinki Toho was 26 entries (shinkitoho/kamae/1 … /26) and is
// one now (shinkitoho/kamae), practised in one flow. Of its old ratings the weakest of each
// local day stays (the newest on a tie; a level outside 1..4 never wins): a weak position makes
// the whole exercise due again sooner. The history keeps one rating a day; the notes move along.
bool PracticeLog::mergeKamae()
{
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    QSqlQuery q(db);
    if (!db.transaction()) {
        m_error = db.lastError().text();
        return false;
    }
    const bool ok = q.exec(QStringLiteral(
                        "DELETE FROM ratings WHERE entry GLOB 'shinkitoho/kamae/*' AND rowid NOT IN ("
                        " SELECT rowid FROM (SELECT rowid, ROW_NUMBER() OVER ("
                        "  PARTITION BY date(at / 1000, 'unixepoch', 'localtime') ORDER BY (level BETWEEN 1 AND 4) DESC, level ASC, at DESC) AS n"
                        "  FROM ratings WHERE entry GLOB 'shinkitoho/kamae/*') WHERE n = 1)"))
        && q.exec(QStringLiteral("UPDATE ratings SET entry = 'shinkitoho/kamae' WHERE entry GLOB 'shinkitoho/kamae/*'"))
        && q.exec(QStringLiteral("UPDATE notes SET entry = 'shinkitoho/kamae' WHERE entry GLOB 'shinkitoho/kamae/*'"))
        && q.exec(QStringLiteral("PRAGMA user_version = 3"));
    if (!ok) {
        m_error = q.lastError().text();
        db.rollback();
        return false;
    }
    if (!db.commit()) {
        m_error = db.lastError().text();
        db.rollback();
        return false;
    }
    return true;
}

PracticeLog::Rating PracticeLog::add(const QString &entry, int level, const QDateTime &at, const QString &device)
{
    Rating r;
    if (entry.isEmpty() || level < 1 || level > 4) {
        return r;
    }
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("INSERT INTO ratings (uid, entry, level, at, device) VALUES (?, ?, ?, ?, ?)"));
    const QString uid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    q.addBindValue(uid);
    q.addBindValue(entry);
    q.addBindValue(level);
    q.addBindValue(at.toMSecsSinceEpoch());
    q.addBindValue(device);
    if (!q.exec()) {
        m_error = q.lastError().text();
        return r;
    }
    r = {uid, entry, level, at.toUTC(), device};
    return r;
}

PracticeLog::Summary PracticeLog::summary() const
{
    Summary result;
    // Each entry's newest and oldest by (at, rowid): a later rowid wins a tie, as in the log's order.
    QHash<QString, std::pair<qint64, qint64>> newest;
    QHash<QString, std::pair<qint64, qint64>> oldest;

    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.setForwardOnly(true);
    // In the table's order: sorted by time through the index, each row was a lookup (3 times slower).
    q.exec(QStringLiteral("SELECT uid, entry, level, at, device, rowid FROM ratings WHERE level BETWEEN 1 AND 4"));
    while (q.next()) {
        const QString entry = q.value(1).toString();
        const std::pair<qint64, qint64> key{q.value(3).toLongLong(), q.value(5).toLongLong()};
        auto first = oldest.find(entry);
        if (first == oldest.end() || key < *first) {
            oldest.insert(entry, key);
        }
        auto last = newest.find(entry);
        if (last == newest.end() || *last < key) {
            newest.insert(entry, key);
            result.latest.insert(entry, rating(q));
        }
    }

    for (auto it = oldest.cbegin(); it != oldest.cend(); ++it) {
        result.firstRated.insert(it.key(), QDateTime::fromMSecsSinceEpoch(it.value().first, QTimeZone::UTC).toLocalTime().date());
    }
    return result;
}

QHash<QString, PracticeLog::Rating> PracticeLog::latest() const
{
    return summary().latest;
}

QHash<QDate, int> PracticeLog::practisedPerDay(const QDateTime &from, const QString &prefix, const QDateTime &to) const
{
    const QHash<QDate, QSet<QString>> entries = practisedOn(from, prefix, to);
    QHash<QDate, int> result;
    for (auto it = entries.cbegin(); it != entries.cend(); ++it) {
        result.insert(it.key(), int(it.value().size()));
    }
    return result;
}

QHash<QDate, QSet<QString>> PracticeLog::practisedOn(const QDateTime &from, const QString &prefix, const QDateTime &to) const
{
    QHash<QDate, QSet<QString>> entries;
    QSet<QString> ids;      // one copy of each id's text for all days
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.setForwardOnly(true);
    q.prepare(QStringLiteral("SELECT entry, at FROM ratings WHERE level BETWEEN 1 AND 4 AND at >= ? AND at < ? AND substr(entry, 1, ?) = ? ORDER BY at"));
    q.addBindValue(from.toMSecsSinceEpoch());
    q.addBindValue(to.isValid() ? to.toMSecsSinceEpoch() : std::numeric_limits<qint64>::max());
    q.addBindValue(prefix.size());
    q.addBindValue(prefix.isNull() ? QStringLiteral("") : prefix);     // a null string binds NULL
    q.exec();

    // In time order, a local day's end found once per day, not a time zone conversion per rating
    // (a year of 20 ratings a day: 20 ms).
    QSet<QString> *today = nullptr;
    qint64 dayEnd = std::numeric_limits<qint64>::min();
    while (q.next()) {
        const qint64 at = q.value(1).toLongLong();
        if (at >= dayEnd) {
            const QDate day = QDateTime::fromMSecsSinceEpoch(at, QTimeZone::UTC).toLocalTime().date();
            today = &entries[day];
            dayEnd = day.addDays(1).startOfDay().toMSecsSinceEpoch();
        }
        today->insert(*ids.insert(q.value(0).toString()));
    }
    return entries;
}

qint64 PracticeLog::dataVersion() const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    return q.exec(QStringLiteral("PRAGMA data_version")) && q.next() ? q.value(0).toLongLong() : -1;
}

QDateTime PracticeLog::firstRating() const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    if (!q.exec(QStringLiteral("SELECT MIN(at) FROM ratings")) || !q.next() || q.value(0).isNull()) {
        return {};
    }
    return QDateTime::fromMSecsSinceEpoch(q.value(0).toLongLong(), QTimeZone::UTC);
}

QList<PracticeLog::Rating> PracticeLog::history(const QString &entry) const
{
    QList<Rating> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT uid, entry, level, at, device FROM ratings WHERE entry = ? ORDER BY at, rowid"));
    q.addBindValue(entry);
    q.exec();
    while (q.next()) {
        const Rating r = rating(q);
        if (r.level >= 1 && r.level <= 4) {
            result << r;
        }
    }
    return result;
}

PracticeLog::Note PracticeLog::addNote(const QString &entry, const QString &text, const QDateTime &at, const QString &device,
                                       const QString &media)
{
    Note n;
    if (entry.isEmpty() || (text.trimmed().isEmpty() && media.isEmpty())) {
        return n;
    }
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("INSERT INTO notes (uid, entry, text, created, changed, device, media) VALUES (?, ?, ?, ?, ?, ?, ?)"));
    const QString uid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    q.addBindValue(uid);
    q.addBindValue(entry);
    q.addBindValue(text.trimmed().isNull() ? QString(QLatin1String("")) : text.trimmed());
    q.addBindValue(at.toMSecsSinceEpoch());
    q.addBindValue(at.toMSecsSinceEpoch());
    q.addBindValue(device);
    q.addBindValue(media.isNull() ? QString(QLatin1String("")) : media);
    if (!q.exec()) {
        m_error = q.lastError().text();
        return n;
    }
    n = {uid, entry, text.trimmed(), at.toUTC(), at.toUTC(), device, false, media};
    return n;
}

// A note with a photo or voice note may lose its text, one without may not.
bool PracticeLog::changeNote(const QString &uid, const QString &text, const QDateTime &at)
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("UPDATE notes SET text = ?, changed = ? WHERE uid = ? AND deleted = 0 AND (? <> '' OR media <> '')"));
    q.addBindValue(text.trimmed());
    q.addBindValue(at.toMSecsSinceEpoch());
    q.addBindValue(uid);
    q.addBindValue(text.trimmed());
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return q.numRowsAffected() == 1;
}

QString PracticeLog::noteMedia(const QString &uid) const
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT media FROM notes WHERE uid = ?"));
    q.addBindValue(uid);
    return q.exec() && q.next() ? q.value(0).toString() : QString();
}

bool PracticeLog::deleteNote(const QString &uid, const QDateTime &at)
{
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("UPDATE notes SET deleted = 1, changed = ? WHERE uid = ? AND deleted = 0"));
    q.addBindValue(at.toMSecsSinceEpoch());
    q.addBindValue(uid);
    if (!q.exec()) {
        m_error = q.lastError().text();
        return false;
    }
    return q.numRowsAffected() == 1;
}

QList<PracticeLog::Note> PracticeLog::notes(const QString &entry) const
{
    QList<Note> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.prepare(QStringLiteral("SELECT uid, entry, text, created, changed, device, deleted, media FROM notes"
                             " WHERE entry = ? AND deleted = 0 ORDER BY created, rowid"));
    q.addBindValue(entry);
    q.exec();
    while (q.next()) {
        result << note(q);
    }
    return result;
}

QList<PracticeLog::Note> PracticeLog::allNotes() const
{
    QList<Note> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT uid, entry, text, created, changed, device, deleted, media FROM notes"
                          " WHERE deleted = 0 ORDER BY created DESC, rowid DESC"));
    while (q.next()) {
        result << note(q);
    }
    return result;
}

QHash<QString, PracticeLog::Note> PracticeLog::lastNotes() const
{
    QHash<QString, Note> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT uid, entry, text, created, changed, device, deleted, media FROM notes"
                          " WHERE deleted = 0 ORDER BY created, rowid"));
    while (q.next()) {
        const Note n = note(q);
        result.insert(n.entry, n);
    }
    return result;
}

PracticeLog::SavedRound PracticeLog::addRound(const ExamRound &round, const QList<Rating> &ratings)
{
    m_error.clear();
    if (round.discipline.isEmpty() || round.grade.isEmpty() || round.count <= 0) {
        m_error = QCoreApplication::translate("PracticeLog", "the round is incomplete");
        return {};
    }
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    if (!db.transaction()) {
        m_error = db.lastError().text();
        return {};
    }

    // The ratings first; any that fails takes the whole round back.
    SavedRound result;
    for (const Rating &r : ratings) {
        const Rating saved = add(r.entry, r.level, round.at, round.device);
        if (saved.uid.isEmpty()) {
            if (m_error.isEmpty()) {
                m_error = QCoreApplication::translate("PracticeLog", "a rating is invalid (\"%1\")").arg(r.entry);
            }
            db.rollback();
            return {};
        }
        result.ratings << saved;
    }

    QSqlQuery q(db);
    q.prepare(QStringLiteral("INSERT INTO exam_rounds (uid, at, discipline, grade, count, average, device)"
                             " VALUES (?, ?, ?, ?, ?, ?, ?)"));
    ExamRound saved = round;
    saved.uid = QUuid::createUuid().toString(QUuid::WithoutBraces);
    saved.at = round.at.toUTC();
    q.addBindValue(saved.uid);
    q.addBindValue(saved.at.toMSecsSinceEpoch());
    q.addBindValue(saved.discipline);
    q.addBindValue(saved.grade);
    q.addBindValue(saved.count);
    q.addBindValue(saved.average);
    q.addBindValue(saved.device);
    if (!q.exec()) {
        m_error = q.lastError().text();
        db.rollback();
        return {};
    }
    if (!db.commit()) {
        m_error = db.lastError().text();
        db.rollback();
        return {};
    }
    result.round = saved;
    return result;
}

QList<PracticeLog::ExamRound> PracticeLog::rounds(const QString &discipline, int limit) const
{
    QList<ExamRound> result;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    // The newest `limit`, then turned to oldest first.
    q.prepare(QStringLiteral("SELECT uid, at, discipline, grade, count, average, device FROM exam_rounds"
                             " WHERE discipline = ? ORDER BY at DESC, rowid DESC LIMIT ?"));
    q.addBindValue(discipline);
    q.addBindValue(limit);
    q.exec();
    while (q.next()) {
        ExamRound r;
        r.uid = q.value(0).toString();
        r.at = QDateTime::fromMSecsSinceEpoch(q.value(1).toLongLong(), QTimeZone::UTC);
        r.discipline = q.value(2).toString();
        r.grade = q.value(3).toString();
        r.count = q.value(4).toInt();
        r.average = q.value(5).toDouble();
        r.device = q.value(6).toString();
        result.prepend(r);
    }
    return result;
}

QHash<QString, QDateTime> PracticeLog::noteVersions() const
{
    QHash<QString, QDateTime> versions;
    QSqlQuery q(QSqlDatabase::database(m_connection));
    q.exec(QStringLiteral("SELECT uid, changed FROM notes"));
    while (q.next()) {
        versions.insert(q.value(0).toString(), QDateTime::fromMSecsSinceEpoch(q.value(1).toLongLong(), QTimeZone::UTC));
    }
    return versions;
}

bool PracticeLog::snapshot(const QString &path)
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

QList<TableMerge::Table> PracticeLog::tables()
{
    using namespace Qt::StringLiterals;
    using TableMerge::Kind;
    return {
        {QStringLiteral("ratings"), {u"uid"_s, u"entry"_s, u"level"_s, u"at"_s, u"device"_s}, Kind::Log, {}},
        {QStringLiteral("notes"),
         {u"uid"_s, u"entry"_s, u"text"_s, u"created"_s, u"changed"_s, u"device"_s, u"deleted"_s, u"media"_s},
         Kind::Editable, u"media"_s, u"text"_s, u"entry"_s},
        {QStringLiteral("exam_rounds"),
         {u"uid"_s, u"at"_s, u"discipline"_s, u"grade"_s, u"count"_s, u"average"_s, u"device"_s}, Kind::Log, {}},
    };
}

bool PracticeLog::merge(const QString &otherPath, TableMerge::Mode mode, TableMerge::Result *result,
                   const TableMerge::Watch &watch)
{
    m_error.clear();
    QSqlDatabase db = QSqlDatabase::database(m_connection);
    return TableMerge::run(db, otherPath, tables(), mode, result, &m_error, nullptr, watch);
}
