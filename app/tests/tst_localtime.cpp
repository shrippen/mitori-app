#include <QDateTime>
#include <QElapsedTimer>
#include <QFile>
#include <QTimeZone>
#include <QtTest>

#include <ctime>

#include "localtime.h"

// LocalTime::pin: local times without a file system call each (platform/localtime.h).
class TstLocalTime : public QObject
{
    Q_OBJECT

    static constexpr int kTimes = 20000;
    static constexpr qint64 kDayMs = 24 * 60 * 60 * 1000;

    // The process's CPU time: what the conversions cost, whatever else the machine does.
    static qint64 cpuUs()
    {
        timespec t{};
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t);
        return qint64(t.tv_sec) * 1000000 + t.tv_nsec / 1000;
    }

    // kTimes local days, as the calendars ask for them.
    static qint64 convert()
    {
        const qint64 start = cpuUs();
        qint64 sum = 0;
        for (int i = 0; i < kTimes; ++i) {
            sum += QDateTime::fromMSecsSinceEpoch(i * kDayMs / 7).toLocalTime().date().day();
        }
        const qint64 took = cpuUs() - start;
        // Used, so the loop stays.
        qDebug() << "days summed" << sum;
        return took;
    }

private slots:
    void initTestCase()
    {
#if !defined(Q_OS_LINUX) || defined(Q_OS_ANDROID)
        QSKIP("glibc only");
#endif
        if (!QFile::exists(QStringLiteral("/etc/localtime"))) {
            QSKIP("no /etc/localtime");
        }
    }

    // Same zone and offsets as before, a quarter of the time or less (measured: a sixteenth).
    void pinned()
    {
        qunsetenv("TZ");
        const QByteArray zone = QTimeZone::systemTimeZoneId();
        const QDateTime summer(QDate(2026, 7, 1), QTime(12, 0));
        const int offset = summer.offsetFromUtc();
        const qint64 before = convert();

        LocalTime::pin();

        QCOMPARE(qgetenv("TZ"), QByteArray(":/etc/localtime"));
        QCOMPARE(QTimeZone::systemTimeZoneId(), zone);
        QCOMPARE(QDateTime(QDate(2026, 7, 1), QTime(12, 0)).offsetFromUtc(), offset);
        const qint64 after = convert();
        qInfo() << "local times, us CPU: unpinned" << before << "pinned" << after;
        QVERIFY2(after * 4 <= before, qPrintable(QStringLiteral("%1 us pinned, %2 us not").arg(after).arg(before)));
    }

    // A TZ the user set stays.
    void userZone()
    {
        qputenv("TZ", "Asia/Tokyo");
        LocalTime::pin();
        QCOMPARE(qgetenv("TZ"), QByteArray("Asia/Tokyo"));
    }
};

QTEST_GUILESS_MAIN(TstLocalTime)
#include "tst_localtime.moc"
