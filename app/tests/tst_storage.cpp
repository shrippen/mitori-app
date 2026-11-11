#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>

#include "bundleshelf.h"
#include "storage.h"
#include "videomove.h"

using namespace Qt::StringLiterals;

// Where the videos lie: VideoMove takes the bundles' folders to another place, Storage runs it for
// the page. Codes and keys stay in the app's data.
class TstStorage : public QObject
{
    Q_OBJECT

    QTemporaryDir m_dir;
    const QString m_id = u"aikido-kyu"_s;
    const QByteArray m_video = QByteArray(9 * 1024 * 1024, 'v');    // more than two pieces

    // A shelf with one loaded bundle: one video file in its folder.
    QString shelfWithBundle(const QString &name)
    {
        const QString root = m_dir.filePath(name);
        BundleShelf shelf(root);
        shelf.unlock(m_id, u"CODE"_s, "key");
        QDir().mkpath(shelf.folder(m_id));
        QFile f(QDir(shelf.folder(m_id)).filePath(u"k5.mkv"_s));
        if (!f.open(QIODevice::WriteOnly)) {
            return {};
        }
        f.write(m_video);
        f.close();
        shelf.installed(m_id, 1, {{u"aikido/k5"_s, u"k5.mkv"_s}}, {}, {});
        return root;
    }

    static QByteArray contents(const QString &path)
    {
        QFile f(path);
        return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray();
    }

private slots:
    void initTestCase()
    {
        QVERIFY(m_dir.isValid());
    }

    // A copy takes every file along and only then removes the old folder.
    void copyMoves()
    {
        const QString root = shelfWithBundle(u"copy"_s);
        const QString to = m_dir.filePath(u"copy-card"_s);
        VideoMove move(root, to, {m_id}, VideoMove::Way::Copy);
        QCOMPARE(move.total(), qint64(m_video.size()));

        QList<qint64> seen;
        const std::atomic_bool cancel = false;
        QCOMPARE(move.run([&seen](qint64 done) { seen << done; }, cancel), VideoMove::Result::Done);
        QCOMPARE(contents(to + u"/aikido-kyu/k5.mkv"_s), m_video);
        QVERIFY(!QFileInfo::exists(root + u"/aikido-kyu"_s));
        QVERIFY(seen.size() >= 3);
        QCOMPARE(seen.last(), qint64(m_video.size()));
        // shelf.json stays where it was.
        QVERIFY(QFileInfo::exists(root + u"/shelf.json"_s));
    }

    // A cancel leaves the old place whole and nothing at the new one.
    void cancelKeepsOld()
    {
        const QString root = shelfWithBundle(u"cancel"_s);
        const QString to = m_dir.filePath(u"cancel-card"_s);
        VideoMove move(root, to, {m_id}, VideoMove::Way::Copy);
        std::atomic_bool cancel = false;
        QCOMPARE(move.run([&cancel](qint64) { cancel = true; }, cancel), VideoMove::Result::Cancelled);
        QCOMPARE(contents(root + u"/aikido-kyu/k5.mkv"_s), m_video);
        QVERIFY(!QFileInfo::exists(to + u"/aikido-kyu"_s));
    }

    // A folder of the same name at the new place is not overwritten.
    void refusesFullTarget()
    {
        const QString root = shelfWithBundle(u"taken"_s);
        const QString to = m_dir.filePath(u"taken-card"_s);
        QDir().mkpath(to + u"/aikido-kyu"_s);
        QFile other(to + u"/aikido-kyu/other.mkv"_s);
        QVERIFY(other.open(QIODevice::WriteOnly));
        other.close();
        VideoMove move(root, to, {m_id});
        const std::atomic_bool cancel = false;
        QCOMPARE(move.run([](qint64) {}, cancel), VideoMove::Result::Failed);
        QVERIFY(!move.errorString().isEmpty());
        QVERIFY(QFileInfo::exists(to + u"/aikido-kyu/other.mkv"_s));
        QCOMPARE(contents(root + u"/aikido-kyu/k5.mkv"_s), m_video);
    }

    // Storage moves the videos, the shelf finds them at the new place, and back again.
    void storageMovesAndBack()
    {
        const QString root = shelfWithBundle(u"storage"_s);
        BundleShelf shelf(root);
        Storage storage(shelf);
        QCOMPARE(storage.path(), root);
        QVERIFY(storage.reachable());
        QCOMPARE(storage.places().first().toMap().value(u"current"_s).toBool(), true);

        const QString to = m_dir.filePath(u"storage-elsewhere"_s);
        QSignalSpy moved(&storage, &Storage::moved);
        storage.moveTo(to);
        QCOMPARE(storage.state(), Storage::State::Moving);
        QVERIFY(shelf.moving());
        QVERIFY(moved.wait(10000));
        QCOMPARE(storage.state(), Storage::State::Idle);
        QVERIFY(!shelf.moving());
        QCOMPARE(shelf.videoRoot(), to);
        QCOMPARE(shelf.path(u"aikido/k5"_s), to + u"/aikido-kyu/k5.mkv"_s);
        // The place now is a folder of one's own, listed by its path.
        const QVariantMap last = storage.places().last().toMap();
        QCOMPARE(last.value(u"kind"_s).value<Storage::Kind>(), Storage::Kind::Folder);
        QVERIFY(last.value(u"current"_s).toBool());

        storage.moveTo(root);
        QVERIFY(moved.wait(10000));
        QCOMPARE(shelf.path(u"aikido/k5"_s), root + u"/aikido-kyu/k5.mkv"_s);
        QCOMPARE(storage.places().size(), 1);
    }

    // While a download runs (its .part folder), nothing moves.
    void storageWaitsForDownload()
    {
        const QString root = shelfWithBundle(u"busy"_s);
        BundleShelf shelf(root);
        QDir().mkpath(root + u"/other.part"_s);
        Storage storage(shelf);
        storage.moveTo(m_dir.filePath(u"busy-elsewhere"_s));
        QCOMPARE(storage.state(), Storage::State::Failed);
        QVERIFY(!storage.errorString().isEmpty());
        QCOMPARE(shelf.videoRoot(), root);
        QVERIFY(QFileInfo::exists(root + u"/aikido-kyu/k5.mkv"_s));
    }

    // A place that is gone (a card taken out) says so.
    void storageMissingPlace()
    {
        const QString root = shelfWithBundle(u"gone"_s);
        BundleShelf shelf(root, m_dir.filePath(u"gone-card"_s));
        Storage storage(shelf);
        QVERIFY(!storage.reachable());
        QVERIFY(shelf.path(u"aikido/k5"_s).isEmpty());
    }
};

QTEST_GUILESS_MAIN(TstStorage)
#include "tst_storage.moc"
