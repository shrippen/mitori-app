#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>

#include "bundleshelf.h"
#include "catalog.h"
#include "lessons.h"
#include "library.h"
#include "videos.h"

using namespace Qt::StringLiterals;

// The Lernpakete's techniques (Lessons), their list for the player (Library) and the picture area
// of their videos (Videos), from the content of tests/data/bundle/inhalt.json on the app's shelf.
class TstLessons : public QObject
{
    Q_OBJECT

    const QString m_id = u"test-lesson"_s;
    const QString m_video = u"lern-test/v1"_s;

    // The package as Bundles leaves it: the first video's file in the folder, the content next to it.
    void install(const QStringList &cropped = {u"lern-test/v1"_s}, const QString &id = u"test-lesson"_s,
                 const QString &contentId = u"test-lesson"_s)
    {
        BundleShelf &shelf = BundleShelf::shared();
        QVERIFY(QDir().mkpath(shelf.folder(id)));
        QFile video(QDir(shelf.folder(id)).filePath(u"v.mkv"_s));
        QVERIFY(video.open(QIODevice::WriteOnly));
        video.close();

        QFile file(QStringLiteral(TEST_BUNDLE_DIR "/inhalt.json"));
        QVERIFY(file.open(QIODevice::ReadOnly));
        QJsonObject content = QJsonDocument::fromJson(file.readAll()).object();
        content.insert(u"id"_s, contentId);
        QVERIFY(shelf.installed(id, 1, {{m_video, u"v.mkv"_s}}, cropped, {}, content));
    }

    static QVariantMap entry(const QVariantList &rows, const QString &id)
    {
        for (const QVariant &r : rows) {
            if (r.toMap().value(u"id"_s) == id) {
                return r.toMap();
            }
        }
        return {};
    }

private slots:
    void initTestCase()
    {
        QStandardPaths::setTestModeEnabled(true);
        QDir(BundleShelf::defaultRoot()).removeRecursively();
    }

    void cleanupTestCase()
    {
        QDir(BundleShelf::defaultRoot()).removeRecursively();
    }

    void cleanup()
    {
        Catalog::setLanguage(Catalog::Language::German);
        BundleShelf::shared().remove(m_id);
    }

    // An installed package with its rows in order; ids from another package's namespace are left out.
    void packagesAndRows()
    {
        install();
        const Lessons &lessons = Lessons::shared();
        const QVariantList packages = lessons.packages();
        QCOMPARE(packages.size(), 1);
        const QVariantMap p = packages.first().toMap();
        QCOMPARE(p.value(u"id"_s).toString(), m_id);
        QCOMPARE(p.value(u"title"_s).toString(), u"Lernpaket"_s);
        QCOMPARE(p.value(u"text"_s).toString(), u"Kurz"_s);
        QCOMPARE(p.value(u"count"_s).toInt(), 4);
        QCOMPARE(p.value(u"videos"_s).toList().size(), 2);

        const QVariantList rows = lessons.rows(m_id);
        QCOMPARE(rows.size(), 6);
        QCOMPARE(rows.at(0).toMap().value(u"kind"_s).toString(), u"group"_s);
        QCOMPARE(rows.at(0).toMap().value(u"title"_s).toString(), u"Grundtechniken"_s);
        QCOMPARE(rows.at(3).toMap().value(u"title"_s).toString(), u"Mehr"_s);

        const QVariantMap irimi = rows.at(1).toMap();
        QCOMPARE(irimi.value(u"kind"_s).toString(), u"entry"_s);
        QCOMPARE(irimi.value(u"id"_s).toString(), u"lern/test-lesson/irimi"_s);
        QCOMPARE(irimi.value(u"title"_s).toString(), u"Irimi-nage"_s);
        QCOMPARE(irimi.value(u"extra"_s).toString(), u"Variante"_s);
        QCOMPARE(irimi.value(u"jp"_s).toString(), u"入身投げ"_s);
        QCOMPARE(irimi.value(u"attack"_s).toString(), u"Shomen-uchi"_s);
        QCOMPARE(irimi.value(u"attackJp"_s).toString(), u"正面打ち"_s);
        QCOMPARE(irimi.value(u"wie"_s).toStringList(), QStringList{u"aikido/k5/irimi-nage-2"_s});
        QCOMPARE(irimi.value(u"discipline"_s).toString(), u"lern"_s);
        QCOMPARE(irimi.value(u"package"_s).toString(), m_id);
        QCOMPARE(irimi.value(u"disciplineName"_s).toString(), u"Lernpaket"_s);
        QCOMPARE(irimi.value(u"gradeName"_s).toString(), QString());
        QCOMPARE(irimi.value(u"groupName"_s).toString(), u"Grundtechniken"_s);
        const QVariantMap video = irimi.value(u"video"_s).toMap();
        QCOMPARE(video.value(u"video"_s).toString(), m_video);
        QCOMPARE(video.value(u"von"_s).toDouble(), 1.5);
        QCOMPARE(video.value(u"bis"_s).toDouble(), 2.5);

        QVERIFY(!entry(rows, u"lern/test-lesson/ohne"_s).value(u"video"_s).isValid());
        QVERIFY(lessons.entry(u"lern/other/fremd"_s).isEmpty());
        QVERIFY(lessons.rows(u"unknown"_s).isEmpty());
    }

    // English takes x_en where there is one, as the catalog does.
    void english()
    {
        install();
        Catalog::setLanguage(Catalog::Language::English);
        const Lessons &lessons = Lessons::shared();
        QCOMPARE(lessons.packages().first().toMap().value(u"title"_s).toString(), u"Lesson pack"_s);
        QCOMPARE(lessons.packages().first().toMap().value(u"text"_s).toString(), u"Short"_s);
        const QVariantList rows = lessons.rows(m_id);
        QCOMPARE(rows.at(0).toMap().value(u"title"_s).toString(), u"Basic techniques"_s);
        const QVariantMap irimi = lessons.entry(u"lern/test-lesson/irimi"_s);
        QCOMPARE(irimi.value(u"extra"_s).toString(), u"variant"_s);
        QCOMPARE(irimi.value(u"text"_s).toString(), u"Shows the entry"_s);
        QCOMPARE(irimi.value(u"disciplineName"_s).toString(), u"Lesson pack"_s);
        // No English: the German stays.
        QCOMPARE(rows.at(3).toMap().value(u"title"_s).toString(), u"Mehr"_s);

        Catalog::setLanguage(Catalog::Language::German);
        QCOMPARE(lessons.entry(u"lern/test-lesson/irimi"_s).value(u"extra"_s).toString(), u"Variante"_s);
    }

    // A removed package leaves the list but keeps its techniques' names; the services hear of both.
    void entrySurvivesRemove()
    {
        const Lessons &lessons = Lessons::shared();
        QSignalSpy changed(&Lessons::shared(), &Lessons::changed);
        install();
        QCOMPARE(changed.count(), 1);
        QCOMPARE(lessons.packages().size(), 1);

        QVERIFY(BundleShelf::shared().remove(m_id));
        QCOMPARE(changed.count(), 2);
        QVERIFY(lessons.packages().isEmpty());
        QVERIFY(lessons.rows(m_id).isEmpty());
        QCOMPARE(lessons.entry(u"lern/test-lesson/irimi"_s).value(u"title"_s).toString(), u"Irimi-nage"_s);

        // The shelf on disk has it too (a restart).
        const BundleShelf again(BundleShelf::shared().root());
        QCOMPARE(again.content(m_id).value(u"id"_s).toString(), m_id);
        QCOMPARE(again.bundle(m_id).version, 0);

        install();
        QCOMPARE(lessons.packages().size(), 1);
    }

    // The reverse of `wie`: installed packages' entries by the programme id; follows remove and language.
    void related()
    {
        const QString same = u"aikido/k5/irimi-nage-2"_s;
        const Library library;
        QVERIFY(library.related(same).isEmpty());

        install();
        QVariantList rows = library.related(same);
        QCOMPARE(rows.size(), 1);
        QCOMPARE(rows.first().toMap().value(u"id"_s).toString(), u"lern/test-lesson/irimi"_s);
        QCOMPARE(rows.first().toMap().value(u"disciplineName"_s).toString(), u"Lernpaket"_s);
        QCOMPARE(rows.first().toMap().value(u"extra"_s).toString(), u"Variante"_s);
        QVERIFY(library.related(u"aikido/k5/other"_s).isEmpty());
        QVERIFY(library.related(u"lern/test-lesson/irimi"_s).isEmpty());

        Catalog::setLanguage(Catalog::Language::English);
        rows = library.related(same);
        QCOMPARE(rows.first().toMap().value(u"disciplineName"_s).toString(), u"Lesson pack"_s);
        QCOMPARE(rows.first().toMap().value(u"extra"_s).toString(), u"variant"_s);
        Catalog::setLanguage(Catalog::Language::German);

        QVERIFY(BundleShelf::shared().remove(m_id));
        QVERIFY(library.related(same).isEmpty());
    }

    // The content of another package under this name is not used.
    void contentOfAnotherPackage()
    {
        install({}, m_id, u"other-lesson"_s);
        QVERIFY(Lessons::shared().packages().isEmpty());
        QVERIFY(Lessons::shared().entry(u"lern/test-lesson/irimi"_s).isEmpty());
    }

    // The player's list: the package's entries with a video on the device, around the one asked for.
    void libraryAround()
    {
        install();
        const Library library;
        QCOMPARE(library.packages().size(), 1);
        QCOMPARE(library.rows(m_id).size(), 6);

        QVariantMap around = library.around(u"lern/test-lesson/tenkan"_s);
        QCOMPARE(around.value(u"playlist"_s).toList().size(), 2);        // irimi, tenkan: v2 is not on the device
        QCOMPARE(around.value(u"index"_s).toInt(), 1);
        QCOMPARE(around.value(u"playlist"_s).toList().at(0).toMap().value(u"id"_s).toString(), u"lern/test-lesson/irimi"_s);
        QCOMPARE(library.around(u"lern/test-lesson/irimi"_s).value(u"index"_s).toInt(), 0);

        // Without a video on the device: a list of its own.
        around = library.around(u"lern/test-lesson/zwei"_s);
        QCOMPARE(around.value(u"playlist"_s).toList().size(), 1);
        QCOMPARE(around.value(u"index"_s).toInt(), 0);
        around = library.around(u"lern/test-lesson/ohne"_s);
        QCOMPARE(around.value(u"playlist"_s).toList().size(), 1);

        around = library.around(u"lern/nobody/nothing"_s);
        QVERIFY(around.value(u"playlist"_s).toList().isEmpty());
        QCOMPARE(around.value(u"index"_s).toInt(), -1);

        QSignalSpy changed(&library, &Library::changed);
        QVERIFY(BundleShelf::shared().remove(m_id));
        QCOMPARE(changed.count(), 1);
        QVERIFY(library.packages().isEmpty());
    }

    // The picture area of a lesson video: the content's, whole frame when the file is cropped, none
    // (the player takes 16:9) where the content names none.
    void videosCrop()
    {
        const Catalog catalog;
        const Videos videos(catalog);
        install();
        QVERIFY(videos.available(m_video));
        QVERIFY(!videos.available(u"lern-test/v2"_s));

        const QVariantMap whole = videos.crop(m_video);
        QCOMPARE(whole.size(), 1);
        QCOMPARE(whole.value(u"verhaeltnis"_s).toDouble(), 1.7778);
        QVERIFY(videos.crop(u"lern-test/v2"_s).isEmpty());
        QVERIFY(videos.crop(u"nobody/v"_s).isEmpty());

        // A file that is not cropped keeps the content's area.
        install({});
        const QVariantMap area = videos.crop(m_video);
        QCOMPARE(area.value(u"hoehe"_s).toInt(), 1080);
        QCOMPARE(area.value(u"h"_s).toInt(), 1000);
    }
};

QTEST_GUILESS_MAIN(TstLessons)
#include "tst_lessons.moc"
