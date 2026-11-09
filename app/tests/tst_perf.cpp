#include <ctime>

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlContext>
#include <QQmlEngine>
#include <QRandomGenerator>
#include <QSettings>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUuid>
#include <QtQml/QQmlExtensionPlugin>
#include <QtQuickTest>

#include "localtime.h"
#include "practice.h"
#include "practicelog.h"

Q_IMPORT_QML_PLUGIN(MitoriPlugin)

// The pages' times with five years of use (tests/perf/tst_perf.qml): a heavy but real user. Budgets
// there catch what became slow; with `-DCMAKE_BUILD_TYPE=RelWithDebInfo` the numbers are the user's.
namespace {

constexpr int kYears = 5;
constexpr int kRatingsPerDay = 20;
constexpr int kNotes = 3000;
constexpr qint64 kDayMs = 24 * 60 * 60 * 1000;

void collectIds(const QJsonValue &value, QStringList &ids)
{
    if (value.isArray()) {
        for (const QJsonValue &v : value.toArray()) {
            collectIds(v, ids);
        }
        return;
    }
    if (!value.isObject()) {
        return;
    }
    const QJsonObject o = value.toObject();
    const QString id = o.value(QStringLiteral("id")).toString();
    if (id.count(QLatin1Char('-')) >= 2) {
        ids << id;      // a technique's id ("aikido-k5-…"), not a grade's
    }
    for (const QJsonValue &v : o) {
        collectIds(v, ids);
    }
}

// Ratings and notes as the app stores them, spread over the years.
bool seed(const QString &path, const QStringList &ids)
{
    {
        PracticeLog schema;   // the tables, in the app's own version
        if (!schema.open(path)) {
            return false;
        }
    }
    const auto name = QStringLiteral("perf-seed");
    bool ok = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), name);
        db.setDatabaseName(path);
        ok = db.open() && db.transaction();
        QSqlQuery rating(db);
        rating.prepare(QStringLiteral("INSERT INTO ratings (uid, entry, level, at, device) VALUES (?, ?, ?, ?, 'perf')"));
        QSqlQuery note(db);
        note.prepare(QStringLiteral("INSERT INTO notes (uid, entry, text, created, changed, device) VALUES (?, ?, ?, ?, ?, 'perf')"));
        auto *random = QRandomGenerator::system();
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        for (int day = 0; ok && day < kYears * 365; ++day) {
            for (int i = 0; ok && i < kRatingsPerDay; ++i) {
                rating.addBindValue(QUuid::createUuid().toString(QUuid::WithoutBraces));
                rating.addBindValue(ids.at(random->bounded(ids.size())));
                rating.addBindValue(random->bounded(1, 5));
                rating.addBindValue(now - day * kDayMs);
                ok = rating.exec();
            }
        }
        for (int i = 0; ok && i < kNotes; ++i) {
            const qint64 at = now - random->bounded(kYears * 365) * kDayMs;
            note.addBindValue(QUuid::createUuid().toString(QUuid::WithoutBraces));
            note.addBindValue(ids.at(random->bounded(ids.size())));
            note.addBindValue(QStringLiteral("Die Hüfte früher drehen, Uke führen statt ziehen. Notiz %1").arg(i));
            note.addBindValue(at);
            note.addBindValue(at);
            ok = note.exec();
        }
        ok = ok && db.commit();
        if (!ok) {
            qWarning() << "perf seed:" << db.lastError().text();
        }
    }
    QSqlDatabase::removeDatabase(name);
    return ok;
}

}

class Setup : public QObject
{
    Q_OBJECT

public:
    // The process's CPU time, every thread: what the app did, whatever else the machine does.
    Q_INVOKABLE qint64 cpuMs() const
    {
        timespec t{};
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t);
        return qint64(t.tv_sec) * 1000 + t.tv_nsec / 1000000;
    }

    // The practice log opened as at the start (Practice's singleton): five years of ratings read.
    Q_INVOKABLE int loadPractice() const
    {
        const Practice practice(Practice::defaultPath());
        return practice.revision();
    }

    // A debug build's C++ is up to four times slower (Programme.suggest 323 ms, 84 in release):
    // the budgets scale with it.
    Q_INVOKABLE bool debugBuild() const
    {
#ifdef NDEBUG
        return false;
#else
        return true;
#endif
    }

public slots:
    void applicationAvailable()
    {
        QCoreApplication::setApplicationName(QStringLiteral("mitori-perf"));
        QCoreApplication::setOrganizationDomain(QStringLiteral("shrippen.github.io"));
        qputenv("XDG_DATA_HOME", PERF_DATA_DIR "/data");
        qputenv("XDG_CONFIG_HOME", PERF_DATA_DIR "/config");
        qputenv("XDG_CACHE_HOME", PERF_DATA_DIR "/cache");
        LocalTime::pin();   // as main() does
        qputenv("MITORI_SPEECH_ENGINE", "mock");
        qputenv("MITORI_DEVICE_LEVELS", "memory");
        qputenv("MITORI_COURSES_CALENDAR", "file:///nonexistent.ics");
        qputenv("MITORI_BUNDLES_MANIFEST", "file:///nonexistent.json");
        QSettings().clear();
        QSettings().setValue(QStringLiteral("look/welcomed"), true);

        QFile::remove(Practice::defaultPath());
        QDir().mkpath(QFileInfo(Practice::defaultPath()).absolutePath());
        QFile data(QStringLiteral(MITORI_DATEN_JSON));
        QStringList ids;
        if (data.open(QIODevice::ReadOnly)) {
            collectIds(QJsonDocument::fromJson(data.readAll()).object().value(QStringLiteral("disziplinen")), ids);
        }
        if (ids.isEmpty() || !seed(Practice::defaultPath(), ids)) {
            qFatal("perf: no seed data");
        }
    }

    void qmlEngineAvailable(QQmlEngine *engine)
    {
        engine->rootContext()->setContextProperty(QStringLiteral("perfClock"), this);
        QIcon::setThemeSearchPaths({QStringLiteral(":/icons")});
        QIcon::setThemeName(QStringLiteral("breeze-mitori"));
    }
};

QUICK_TEST_MAIN_WITH_SETUP(perf, Setup)
#include "tst_perf.moc"
