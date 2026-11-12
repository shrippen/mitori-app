#include "practice.h"

#include "mediastore.h"

#include "device.h"
#include "searchkey.h"
#include "schedule.h"

#include <algorithm>

#include <QCoreApplication>
#include <QDir>
#include <QEvent>
#include <QSettings>
#include <QStandardPaths>
#include <QUuid>

Practice::Practice(QObject *parent)
    : Practice(defaultPath(), parent)
{
}

Practice::Practice(const QString &path, QObject *parent)
    : QObject(parent)
    , m_log(std::make_unique<PracticeLog>())
{
    load(path);
    // A minute's check for a new day: it also catches the day after a device slept.
    m_dayTimer.setInterval(60 * 1000);
    connect(&m_dayTimer, &QTimer::timeout, this, [this] {
        if (QDate::currentDate() != m_today) {
            m_today = QDate::currentDate();
            emit todayChanged();
        }
    });
    m_dayTimer.start();
    // A new catalog (Appearance::setLanguage): the level names are read anew.
    if (auto *app = QCoreApplication::instance()) {
        app->installEventFilter(this);
    }
}

bool Practice::eventFilter(QObject *watched, QEvent *event)
{
    if (event->type() == QEvent::LanguageChange && watched == QCoreApplication::instance()) {
        emit levelNamesChanged();
    }
    return QObject::eventFilter(watched, event);
}

Practice::~Practice() = default;

void Practice::load(const QString &path)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    if (!m_log->open(path)) {
        m_error = tr("The practice log could not be opened: %1").arg(m_log->errorString());
        qWarning("Practice: %s", qPrintable(m_error));
        return;
    }
    m_open = true;
    PracticeLog::Summary summary = m_log->summary();
    m_latest = std::move(summary.latest);
    m_first = std::move(summary.firstRated);
    m_lastNotes = m_log->lastNotes();
}

void Practice::refresh()
{
    if (!m_open) {
        return;
    }
    PracticeLog::Summary summary = m_log->summary();
    m_latest = std::move(summary.latest);
    m_first = std::move(summary.firstRated);
    m_lastNotes = m_log->lastNotes();
    m_days.clear();
    m_firstRating.reset();
    m_noteTexts.reset();
    ++m_revision;
    ++m_historyRevision;
    emit changed();
    emit historyChanged();
    emit notesChanged();
}

QString Practice::defaultPath()
{
    return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/mitori.sqlite");
}

QString Practice::deviceId()
{
    return ::deviceId();
}

QStringList Practice::levelNames() const
{
    return {tr("not rated"), tr("seen"), tr("with help"), tr("sure"), tr("exam-ready")};
}

bool Practice::rate(const QString &entry, int level)
{
    if (!m_open || entry.isEmpty() || level < 1 || level > 4) {
        return false;
    }
    const PracticeLog::Rating r = m_log->add(entry, level, QDateTime::currentDateTimeUtc(), deviceId());
    if (r.uid.isEmpty()) {
        m_error = tr("The rating could not be saved: %1").arg(m_log->errorString());
        qWarning("Practice: %s", qPrintable(m_error));
        emit errorChanged();
        return false;
    }
    m_latest.insert(entry, r);
    if (!m_first.contains(entry)) {
        m_first.insert(entry, r.at.toLocalTime().date());
    }
    counted(r);
    ++m_revision;
    emit changed();
    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }
    return true;
}

int Practice::level(const QString &entry) const
{
    return m_latest.value(entry).level;
}

int Practice::bestLevel(const QStringList &entries) const
{
    int best = 0;
    for (const QString &e : entries) {
        best = std::max(best, level(e));
    }
    return best;
}

QDateTime Practice::lastRated(const QString &entry) const
{
    const auto it = m_latest.constFind(entry);
    return it == m_latest.constEnd() ? QDateTime() : it->at.toLocalTime();
}

QVariantList Practice::ratingHistory(const QString &entry, int count) const
{
    QVariantList result;
    if (!m_open || count <= 0) {
        return result;
    }

    const QList<PracticeLog::Rating> all = m_log->history(entry);
    for (qsizetype i = std::max<qsizetype>(0, all.size() - count); i < all.size(); ++i) {
        const QDateTime at = all[i].at.toLocalTime();
        result << QVariantMap{{QStringLiteral("day"), at.date().toString(Qt::ISODate)},
                              {QStringLiteral("at"), at},
                              {QStringLiteral("level"), all[i].level}};
    }
    return result;
}

QVariantList Practice::counts(const QStringList &entries) const
{
    QList<int> n(5, 0);
    for (const QString &e : entries) {
        ++n[level(e)];
    }
    return {n[0], n[1], n[2], n[3], n[4]};
}

void Practice::dropStale() const
{
    const qint64 version = m_log->dataVersion();
    if (version == m_logVersion) {
        return;
    }
    m_logVersion = version;
    m_days.clear();
    m_firstRating.reset();
    m_noteTexts.reset();
}

const Practice::DayEntries &Practice::yearDays(int year) const
{
    dropStale();
    const auto it = m_days.constFind(year);
    if (it != m_days.constEnd()) {
        return *it;
    }
    // The whole year from the log (one read), its days in local time.
    const QDate first(year, 1, 1);
    DayEntries &days = m_days[year];
    days = m_log->practisedOn(first.startOfDay().toUTC(), {}, first.addYears(1).startOfDay().toUTC());
    days.removeIf([year](const DayEntries::iterator &it) { return it.key().year() != year; });
    return days;
}

void Practice::counted(const PracticeLog::Rating &r)
{
    const QDate day = r.at.toLocalTime().date();
    const auto year = m_days.find(day.year());
    if (year != m_days.end()) {
        (*year)[day].insert(m_latest.constFind(r.entry).key());
    }
    if (m_firstRating && (!m_firstRating->isValid() || r.at < *m_firstRating)) {
        m_firstRating = r.at;
    }
}

QVariantMap Practice::practisedPerDay(int days) const
{
    QVariantMap result;
    if (!m_open || days <= 0) {
        return result;
    }
    // From the first year with a rating on: a long span reads no empty years.
    const QDate first = m_today.addDays(1 - days);
    for (int year = std::max(first.year(), firstYear()); year <= m_today.year(); ++year) {
        const DayEntries &perDay = yearDays(year);
        for (auto it = perDay.cbegin(); it != perDay.cend(); ++it) {
            if (it.key() >= first && it.key() <= m_today) {
                result.insert(it.key().toString(Qt::ISODate), int(it.value().size()));
            }
        }
    }
    return result;
}

QVariantMap Practice::practisedInYear(int year, const QString &discipline) const
{
    QVariantMap result;
    if (!m_open) {
        return result;
    }
    const QString prefix = discipline.isEmpty() ? QString() : discipline + QLatin1Char('/');
    const DayEntries &perDay = yearDays(year);
    for (auto it = perDay.cbegin(); it != perDay.cend(); ++it) {
        const auto count = prefix.isEmpty() ? it.value().size()
                                            : std::count_if(it.value().cbegin(), it.value().cend(),
                                                            [&](const QString &e) { return e.startsWith(prefix); });
        if (count > 0) {
            result.insert(it.key().toString(Qt::ISODate), int(count));
        }
    }
    return result;
}

int Practice::firstYear() const
{
    if (!m_open) {
        return m_today.year();
    }
    dropStale();
    if (!m_firstRating) {
        m_firstRating = m_log->firstRating();
    }
    return m_firstRating->isValid() ? m_firstRating->toLocalTime().date().year() : m_today.year();
}

bool Practice::ratedToday(const QString &entry) const
{
    const QDateTime last = lastRated(entry);
    return last.isValid() && last.date() == m_today;
}

QVariantList Practice::intervals() const
{
    // Numbers (the settings file gives them back as text after a restart).
    const QVariantList stored = QSettings().value(QStringLiteral("practice/intervals")).toList();
    if (stored.size() == 4) {
        QVariantList days;
        for (const QVariant &v : stored) {
            days << v.toInt();
        }
        return days;
    }
    QVariantList result;
    for (int days : Schedule::defaultIntervals()) {
        result << days;
    }
    return result;
}

void Practice::setIntervals(const QVariantList &intervals)
{
    if (intervals.size() != 4 || intervals == this->intervals()) {
        return;
    }
    QVariantList clean;
    for (const QVariant &v : intervals) {
        clean << qBound(1, v.toInt(), 365);
    }
    QSettings().setValue(QStringLiteral("practice/intervals"), clean);
    emit intervalsChanged();
}

QVariantList Practice::due(const QVariantList &candidates) const
{
    QList<Schedule::Candidate> list;
    QHash<QString, QVariantMap> rows;
    for (const QVariant &c : candidates) {
        const QVariantMap row = c.toMap();
        const QString id = row.value(QStringLiteral("id")).toString();
        list << Schedule::Candidate{id, row.value(QStringLiteral("current")).toBool()};
        rows.insert(id, row);
    }
    QList<int> days;
    for (const QVariant &v : intervals()) {
        days << v.toInt();
    }
    QVariantList result;
    for (const Schedule::Due &d : Schedule::due(list, m_latest, m_first, m_today, days)) {
        QVariantMap row = rows.value(d.id);
        row[QStringLiteral("level")] = d.level;
        row[QStringLiteral("days")] = d.days;
        result << row;
    }
    return result;
}

namespace {

QVariantMap noteMap(const PracticeLog::Note &n)
{
    return {{QStringLiteral("uid"), n.uid},
            {QStringLiteral("text"), n.text},
            {QStringLiteral("created"), n.created.toLocalTime()},
            {QStringLiteral("changed"), n.changed.toLocalTime()},
            {QStringLiteral("media"), n.media}};
}

} // namespace

QVariantList Practice::notes(const QString &entry) const
{
    QVariantList result;
    if (!m_open) {
        return result;
    }
    for (const PracticeLog::Note &n : m_log->notes(entry)) {
        result << noteMap(n);
    }
    return result;
}

QVariantList Practice::notesToday(const QString &entry) const
{
    QVariantList result;
    if (!m_open) {
        return result;
    }
    for (const PracticeLog::Note &n : m_log->notes(entry)) {
        if (n.created.toLocalTime().date() == m_today) {
            result << noteMap(n);
        }
    }
    return result;
}

QVariantList Practice::allNotes() const
{
    QVariantList result;
    if (!m_open) {
        return result;
    }
    for (const PracticeLog::Note &n : m_log->allNotes()) {
        QVariantMap row = noteMap(n);
        row[QStringLiteral("entry")] = n.entry;
        result << row;
    }
    return result;
}

int Practice::noteCount() const
{
    return m_open ? m_log->noteCount() : 0;
}

std::optional<PracticeLog::Note> Practice::newestNote() const
{
    return m_open ? m_log->newestNote() : std::nullopt;
}

QList<PracticeLog::Note> Practice::noteRecords() const
{
    return m_open ? m_log->allNotes() : QList<PracticeLog::Note>();
}

QVariantList Practice::searchNotes(const QString &query, int limit) const
{
    QVariantList result;
    const QStringList words = searchWords(query);
    if (!m_open || words.isEmpty()) {
        return result;
    }
    for (const NoteText &n : noteTexts()) {
        if (n.text.matches(words)) {
            QVariantMap row = noteMap(n.note);
            row[QStringLiteral("entry")] = n.note.entry;
            result << row;
            if (result.size() >= limit) {
                break;
            }
        }
    }
    return result;
}

void Practice::prepareSearch() const
{
    if (m_open) {
        noteTexts();
    }
}

const QList<Practice::NoteText> &Practice::noteTexts() const
{
    dropStale();
    if (!m_noteTexts) {
        QList<NoteText> texts;
        for (const PracticeLog::Note &n : m_log->allNotes()) {
            texts.append({n, SearchText(n.text)});
        }
        m_noteTexts = std::move(texts);
    }
    return *m_noteTexts;
}

QVariantMap Practice::lastNote(const QString &entry) const
{
    const auto it = m_lastNotes.constFind(entry);
    return it == m_lastNotes.constEnd() ? QVariantMap() : noteMap(*it);
}

void Practice::noteSaved(bool ok)
{
    if (!ok) {
        m_error = tr("The note could not be saved: %1").arg(m_log->errorString());
        qWarning("Practice: %s", qPrintable(m_error));
        emit errorChanged();
        return;
    }
    m_noteTexts.reset();
    ++m_notesRevision;
    emit notesChanged();
    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }
}

bool Practice::addNote(const QString &entry, const QString &text, const QString &media)
{
    if (!m_open || entry.isEmpty() || (text.trimmed().isEmpty() && media.isEmpty())) {
        return false;
    }
    const PracticeLog::Note n = m_log->addNote(entry, text, QDateTime::currentDateTimeUtc(), deviceId(), media);
    if (!n.uid.isEmpty()) {
        m_lastNotes.insert(entry, n);
    }
    noteSaved(!n.uid.isEmpty());
    return !n.uid.isEmpty();
}

bool Practice::changeNote(const QString &uid, const QString &text)
{
    if (!m_open || (text.trimmed().isEmpty() && m_log->noteMedia(uid).isEmpty())) {
        return false;
    }
    const bool ok = m_log->changeNote(uid, text, QDateTime::currentDateTimeUtc());
    if (ok) {
        m_lastNotes = m_log->lastNotes();
    }
    noteSaved(ok);
    return ok;
}

bool Practice::deleteNote(const QString &uid)
{
    if (!m_open) {
        return false;
    }
    const bool ok = m_log->deleteNote(uid, QDateTime::currentDateTimeUtc());
    if (ok) {
        MediaStore::shared().remove(m_log->noteMedia(uid));     // the note stays as a mark, its file goes
        m_lastNotes = m_log->lastNotes();
    }
    noteSaved(ok);
    return ok;
}

bool Practice::saveRound(const QString &discipline, const QString &grade, const QVariantList &results)
{
    if (!m_open || results.isEmpty()) {
        return false;
    }
    // Every point rated before anything is written.
    int sum = 0;
    QList<PracticeLog::Rating> ratings;
    for (const QVariant &r : results) {
        const QVariantMap point = r.toMap();
        const int level = point.value(QStringLiteral("level")).toInt();
        if (level < 1 || level > 4) {
            m_error = tr("Not every point of the exam round is rated.");
            emit errorChanged();
            return false;
        }
        sum += level;
        PracticeLog::Rating rating;
        rating.entry = point.value(QStringLiteral("id")).toString();
        rating.level = level;
        ratings << rating;
    }

    // Ratings and round in one transaction: kept whole or not at all.
    PracticeLog::ExamRound round;
    round.at = QDateTime::currentDateTimeUtc();
    round.discipline = discipline;
    round.grade = grade;
    round.count = int(results.size());
    round.average = double(sum) / results.size();
    round.device = deviceId();
    const PracticeLog::SavedRound saved = m_log->addRound(round, ratings);
    if (saved.round.uid.isEmpty()) {
        m_error = tr("The exam round could not be saved: %1").arg(m_log->errorString());
        qWarning("Practice: %s", qPrintable(m_error));
        emit errorChanged();
        return false;
    }

    for (const PracticeLog::Rating &r : saved.ratings) {
        m_latest.insert(r.entry, r);
        if (!m_first.contains(r.entry)) {
            m_first.insert(r.entry, r.at.toLocalTime().date());
        }
        counted(r);
    }
    ++m_revision;
    emit changed();
    if (!m_error.isEmpty()) {
        m_error.clear();
        emit errorChanged();
    }
    return true;
}

QVariantList Practice::rounds(const QString &discipline, int limit) const
{
    QVariantList result;
    if (!m_open || limit <= 0) {
        return result;
    }
    for (const PracticeLog::ExamRound &r : m_log->rounds(discipline, limit)) {
        result << QVariantMap{{QStringLiteral("at"), r.at.toLocalTime()},
                              {QStringLiteral("grade"), r.grade},
                              {QStringLiteral("count"), r.count},
                              {QStringLiteral("average"), r.average}};
    }
    return result;
}
