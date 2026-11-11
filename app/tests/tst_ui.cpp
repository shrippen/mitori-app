#include <algorithm>
#include <ctime>

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QPointer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLibraryInfo>
#include <QJsonObject>
#include <QUrl>
#include <QVideoFrame>
#include <QVideoSink>
#include <QQmlContext>
#include <QQmlEngine>
#include <QSettings>
#include <QStandardPaths>
#include <QTranslator>
#include <QUrl>
#include <QtQml/QQmlExtensionPlugin>
#include <QtQuickTest>

#include "appearance.h"
#include "courses.h"
#include "bundleshelf.h"
#include "catalog.h"
#include "mediastore.h"
#include "practice.h"
#include "qrimage.h"

Q_IMPORT_QML_PLUGIN(MitoriPlugin)

// The manifest's Lernpaket copy that this version cannot read (tst_ui.qml names it too).
const QString kUnsupportedId = QStringLiteral("test-unsupported");
constexpr int kUnknownContentFormat = 99;

class Setup : public QObject
{
    Q_OBJECT

public:
    // A text from the German catalog ("" without one): how long a page's text is in German, while
    // the run stays English (nothing is installed).
    Q_INVOKABLE QString german(const QString &context, const QString &source)
    {
        if (m_german.isEmpty()) {
            (void)m_german.load(QStringLiteral(":/i18n/mitori_de"));
        }
        return m_german.translate(context.toUtf8().constData(), source.toUtf8().constData());
    }

    // A Lernpaket on the device, as Bundles leaves it (tests/data/bundle/inhalt.json): its first video's
    // file (empty: pages take it for a video, nothing plays) and its content on the shelf. Its first
    // technique is the programme's `same` (a real id of the catalog). The first video has the test
    // subtitle track (English); installLessonTracks() gives it a German one too.
    Q_INVOKABLE bool installLesson(const QString &id, const QString &same)
    {
        return install(id, same, {QStringLiteral("en")});
    }
    Q_INVOKABLE bool installLessonTracks(const QString &id, const QString &same)
    {
        return install(id, same, {QStringLiteral("en"), QStringLiteral("de")});
    }
    Q_INVOKABLE bool removeLesson(const QString &id) { return BundleShelf::shared().remove(id); }
    // The app's language as a code ("de", "en"): Catalog's, which may differ from the system's locale.
    Q_INVOKABLE QString appLanguage() const
    {
        return Catalog::language() == Catalog::Language::German ? QStringLiteral("de") : QStringLiteral("en");
    }

    // The fake camera (services/codescanner): what stands in for the device, and a QR code or an
    // empty picture ("") as a frame of the page's sink.
    Q_INVOKABLE void setCamera(const QString &stand) { qputenv("MITORI_CAMERA", stand.toUtf8()); }
    Q_INVOKABLE void showFrame(QVideoSink *sink, const QString &text)
    {
        if (!sink) {
            return;     // the page is gone
        }
        QImage image(360, 360, QImage::Format_Grayscale8);
        image.fill(128);
        sink->setVideoFrame(QVideoFrame(text.isEmpty() ? image : qrImage(text)));
    }

    // The Flatpak as services/saveplace tells it ("": none).
    Q_INVOKABLE void setFlatpak(const QString &id)
    {
        if (id.isEmpty()) {
            qunsetenv("FLATPAK_ID");
        } else {
            qputenv("FLATPAK_ID", id.toUtf8());
        }
    }

    // Qt's own German catalog is installed (not everywhere: tst_look only checks it then).
    Q_INVOKABLE bool qtCatalogThere() const
    {
        return QFile::exists(QLibraryInfo::path(QLibraryInfo::TranslationsPath) + QStringLiteral("/qt_de.qm"));
    }

    // The windows of the run (tst_look: a change of style leaves one for the app).
    Q_INVOKABLE int windowCount() const { return int(QGuiApplication::allWindows().size()); }

    // The run's zone, hours west of UTC, by the UTC hour it starts at: morning there, so that no
    // run sees midnight (the calendar is written at its start, ratings count per day).
    Q_INVOKABLE int hoursWest(int utcHour) const
    {
        constexpr int kNear = 1, kFar = 12;
        return utcHour >= kNear && utcHour <= kFar ? kNear : kFar;
    }

    // The process's CPU time, every thread: what the app did, whatever else the machine does.
    Q_INVOKABLE qint64 cpuMs() const
    {
        timespec t{};
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &t);
        return qint64(t.tv_sec) * 1000 + t.tv_nsec / 1000000;
    }

    // Objects that must go with a change of style: how many still live.
    Q_INVOKABLE void watch(QObject *object) { m_watched.append(object); }
    Q_INVOKABLE int watchedAlive() const
    {
        return int(std::count_if(m_watched.begin(), m_watched.end(), [](const QPointer<QObject> &o) { return !o.isNull(); }));
    }

    // Whether an item is drawn by Shinki's component ("ShinkiButton" among its QML base types).
    Q_INVOKABLE bool drawnByShinki(QObject *object) const
    {
        for (const QMetaObject *meta = object ? object->metaObject() : nullptr; meta; meta = meta->superClass()) {
            if (QLatin1String(meta->className()).startsWith(QLatin1String("Shinki"))) {
                return true;
            }
        }
        return false;
    }

public slots:
    void applicationAvailable()
    {
        QCoreApplication::setApplicationName(QStringLiteral("mitori-ui-test"));
        QCoreApplication::setOrganizationDomain(QStringLiteral("shrippen.github.io"));   // as main.cpp (Settings)
        // West of UTC: a QDate reaches QML as midnight UTC, the day before here (catches "today"
        // compared that way; NotesPage once did).
        qputenv("TZ", "TST+" + QByteArray::number(hoursWest(QDateTime::currentDateTimeUtc().time().hour())));
        tzset();
        // Data and settings in the build directory, so that runs in different builds (worktrees,
        // reviews) do not share ~/.qttest and delete each other's database.
        qputenv("XDG_DATA_HOME", UI_DATA_DIR "/data");
        qputenv("XDG_CONFIG_HOME", UI_DATA_DIR "/config");
        qputenv("XDG_CACHE_HOME", UI_DATA_DIR "/cache");
        // Every run starts from the defaults (the video folder from MITORI_VIDEOS, not from the
        // setting a test wrote last time).
        QSettings().clear();
        // The first-start wizard has its own case (test_0_welcome); the others start on the menu.
        QSettings().setValue(QStringLiteral("look/welcomed"), true);
        // The shared grade of an older version (test_0a_practice_migrated).
        QSettings().setValue(QStringLiteral("programme/grade/shinkitoho"), QStringLiteral("chuden"));
        // A speech engine without a Japanese voice, the same on every machine (the glossary
        // hides its speaker buttons).
        qputenv("MITORI_SPEECH_ENGINE", "mock");
        QFile::remove(Practice::defaultPath());
        QFile::remove(Courses::defaultPath());
        QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)).remove(QStringLiteral("lehrgaenge.ics"));
        QDir(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + QStringLiteral("/sync")).removeRecursively();
        // The course calendar from a file, dates relative to today: never the network.
        const auto day = [](int offset) { return QDate::currentDate().addDays(offset).toString(QStringLiteral("yyyyMMdd")).toUtf8(); };
        QDir().mkpath(QStringLiteral(UI_DATA_DIR));
        QFile calendar(QStringLiteral(UI_DATA_DIR "/lehrgaenge.ics"));
        if (calendar.open(QIODevice::WriteOnly)) {
            calendar.write("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n"
                           "BEGIN:VEVENT\r\nUID:ui-daito\r\nSUMMARY:Daitoryu Aiki Jujutsu\r\nDTSTART;VALUE=DATE:" + day(12)
                           + "\r\nDTEND;VALUE=DATE:" + day(14) + "\r\nLOCATION:Siebeldingen\r\n"
                           "DESCRIPTION:mit M. D. Nakajima Shihan\\nSamstag\\nAusschreibung: https://example.org/a?b=1\r\nEND:VEVENT\r\n"
                           "BEGIN:VEVENT\r\nUID:ui-aikido\r\nSUMMARY:Aikido-Prüfungsvorbereitung\r\nDTSTART;VALUE=DATE:" + day(40)
                           + "\r\nDTEND;VALUE=DATE:" + day(42) + "\r\nLOCATION:Pforzheim\r\nEND:VEVENT\r\n"
                           "END:VCALENDAR\r\n");
        }
        // Brightness and volume in memory: no test dims the screen (platform/devicelevels).
        qputenv("MITORI_DEVICE_LEVELS", "memory");
        // No test turns a camera on; frames come from showFrame.
        qputenv("MITORI_CAMERA", "frames");
        qputenv("MITORI_COURSES_CALENDAR", QUrl::fromLocalFile(calendar.fileName()).toString().toUtf8());
        // Video bundles from the test data (tools/bundle.py), as a local package folder: never the network.
        QDir(BundleShelf::defaultRoot()).removeRecursively();
        // A voice note on the device for the notes' player (a recorder needs a microphone).
        QDir(MediaStore::defaultRoot()).removeRecursively();
        QDir().mkpath(MediaStore::defaultRoot());
        QFile::copy(QStringLiteral(TEST_MEDIA_DIR "/stimme.m4a"), MediaStore::shared().path(QStringLiteral("test-stimme.m4a")));
        // Two folders for the player, each with a file it really plays (sound only, no picture).
        for (const QString &name : {QStringLiteral("a"), QStringLiteral("b")}) {
            const QString played = QStringLiteral(UI_DATA_DIR "/played-") + name + QStringLiteral("/Aikido/5. Kyu.mkv");
            QDir().mkpath(QFileInfo(played).absolutePath());
            QFile::remove(played);
            QFile::copy(QStringLiteral(TEST_MEDIA_DIR "/stimme.m4a"), played);
        }
        // A long silent clip under the catalog's names: the catalog's chapters really play (tablet).
        const auto clip = [](const QString &file) {
            const QString played = QStringLiteral(UI_DATA_DIR "/played-") + file;
            QDir().mkpath(QFileInfo(played).absolutePath());
            QFile::remove(played);
            QFile::copy(QStringLiteral(TEST_MEDIA_DIR "/stille.m4a"), played);
        };
        for (const QString &name : {QStringLiteral("long"), QStringLiteral("long2")}) {
            clip(name + QStringLiteral("/Aikido/5. Kyu.mkv"));
            clip(name + QStringLiteral("/Aikido/4. Kyu.mkv"));
            clip(name + QStringLiteral("/Shinki Toho/Chuden.mkv"));
        }
        // 4. Kyu plays, 5. Kyu does not: its file is gone, or does not load.
        clip(QStringLiteral("gone/Aikido/4. Kyu.mkv"));
        clip(QStringLiteral("broken/Aikido/4. Kyu.mkv"));
        QFile broken(QStringLiteral(UI_DATA_DIR "/played-broken/Aikido/5. Kyu.mkv"));
        if (!broken.open(QIODevice::WriteOnly)) {
            qFatal("no broken clip: %s", qPrintable(broken.fileName()));
        }
        const QString packages = QStringLiteral(UI_DATA_DIR "/packages");
        const QString video = packages + QStringLiteral("/test-bundle/1/test.mvb");
        QDir().mkpath(QFileInfo(video).absolutePath());
        QFile::remove(video);
        QFile::copy(QStringLiteral(TEST_BUNDLE_DIR "/test.mvb"), video);
        // The exam bundle, the Lernpaket (manifest-lernpaket.json) and a copy of it in a content format
        // this version does not know (State::Unsupported).
        const auto read = [](const QString &file) {
            QFile source(QStringLiteral(TEST_BUNDLE_DIR "/") + file);
            return source.open(QIODevice::ReadOnly) ? QJsonDocument::fromJson(source.readAll()).object() : QJsonObject();
        };
        QJsonObject json = read(QStringLiteral("manifest.json"));
        const QJsonObject lesson = read(QStringLiteral("manifest-lernpaket.json"));
        QJsonArray lessons = lesson.value(QStringLiteral("lernpakete")).toArray();
        QJsonObject newer = lessons.at(0).toObject();
        QJsonObject content = newer.value(QStringLiteral("inhalt")).toObject();
        content.insert(QStringLiteral("format"), kUnknownContentFormat);
        newer.insert(QStringLiteral("id"), kUnsupportedId);
        newer.insert(QStringLiteral("inhalt"), content);
        lessons.append(newer);
        json.insert(QStringLiteral("lernpakete"), lessons);
        QJsonObject codes = json.value(QStringLiteral("codes")).toObject();
        const QJsonObject lessonCodes = lesson.value(QStringLiteral("codes")).toObject();
        for (auto it = lessonCodes.begin(); it != lessonCodes.end(); ++it) {
            codes.insert(it.key(), it.value());
        }
        json.insert(QStringLiteral("codes"), codes);
        QFile manifest(QStringLiteral(UI_DATA_DIR "/manifest.json"));
        if (manifest.open(QIODevice::WriteOnly)) {
            manifest.write(QJsonDocument(json).toJson().replace("file:///unused/test.mvb", QUrl::fromLocalFile(video).toEncoded()));
        }
        qputenv("MITORI_BUNDLES_MANIFEST", QUrl::fromLocalFile(manifest.fileName()).toString().toUtf8());
    }

    void qmlEngineAvailable(QQmlEngine *engine)
    {
        // The app's bundled icons, as on Android (main.cpp).
        QIcon::setThemeSearchPaths({QStringLiteral(":/icons")});
        QIcon::setThemeName(QStringLiteral("breeze-mitori"));
        const bool shinki = qEnvironmentVariable("MITORI_TEST_STYLE") == QLatin1String("shinki");
        const QString shots = QStringLiteral(UI_SHOTS_DIR) + (shinki ? QStringLiteral("/shinki") : QString());
        QDir().mkpath(shots);
        engine->rootContext()->setContextProperty(QStringLiteral("uiDataDir"), QStringLiteral(UI_DATA_DIR));
        engine->rootContext()->setContextProperty(QStringLiteral("uiShotsDir"), shots);
        engine->rootContext()->setContextProperty(QStringLiteral("uiShinki"), shinki);
        engine->rootContext()->setContextProperty(QStringLiteral("uiCatalog"), this);
        // The second run (ctest ui_shinki): the pages through Look as Shinki. The running style
        // belongs to it too: the window's head and the global tool bar follow it (as after a
        // start with Shinki).
        if (shinki) {
            QSettings().setValue(QStringLiteral("look/style"), int(Appearance::Style::Shinki));
            QSettings().setValue(QStringLiteral("look/running"), int(Appearance::Style::Shinki));
            Appearance::prepare(Appearance::Style::Shinki, engine);
        }
        engine->rootContext()->setContextProperty(QStringLiteral("testMediaDir"), QStringLiteral(TEST_MEDIA_DIR));
        // Empty files under the catalog's names: pages take them for videos, nothing plays. The
        // tablet's page can be tested without the videos (the CI has none).
        const QString stand = QStringLiteral(UI_DATA_DIR "/stand-in-videos");
        const QVariantMap videos = Catalog::bundled().videos();
        for (const QVariant &video : videos) {
            const QString file = stand + QLatin1Char('/') + video.toMap().value(QStringLiteral("datei")).toString();
            QDir().mkpath(QFileInfo(file).path());
            QFile standIn(file);
            if (!standIn.open(QIODevice::WriteOnly)) {
                qFatal("no stand-in video: %s", qPrintable(file));
            }
        }
        engine->rootContext()->setContextProperty(QStringLiteral("standInVideos"), stand);
    }

private:
    // The lesson with a WebVTT track per language on its first video ("<video file>.<language>.vtt";
    // the German one says "Hallo" where the test track says "Hello").
    bool install(const QString &id, const QString &same, const QStringList &languages)
    {
        BundleShelf &shelf = BundleShelf::shared();
        QDir().mkpath(shelf.folder(id));
        const QString videoFile = QStringLiteral("v.mkv");
        QFile video(QDir(shelf.folder(id)).filePath(videoFile));
        QFile content(QStringLiteral(TEST_BUNDLE_DIR "/inhalt.json"));
        QFile track(QStringLiteral(TEST_BUNDLE_DIR "/test.en.vtt"));
        if (!video.open(QIODevice::WriteOnly) || !content.open(QIODevice::ReadOnly) || !track.open(QIODevice::ReadOnly)) {
            return false;
        }
        const QByteArray cues = track.readAll();
        QMap<QString, QString> tracks;
        for (const QString &language : languages) {
            const QString name = videoFile + QLatin1Char('.') + language + QStringLiteral(".vtt");
            QFile out(QDir(shelf.folder(id)).filePath(name));
            if (!out.open(QIODevice::WriteOnly)) {
                return false;
            }
            out.write(language == QLatin1String("de") ? QByteArray(cues).replace("Hello", "Hallo") : cues);
            tracks.insert(language, name);
        }

        QJsonObject json = QJsonDocument::fromJson(content.readAll()).object();
        json.insert(QStringLiteral("id"), id);
        QJsonArray sections = json.value(QStringLiteral("abschnitte")).toArray();
        QJsonObject first = sections.at(0).toObject();
        QJsonArray techniques = first.value(QStringLiteral("techniken")).toArray();
        QJsonObject technique = techniques.at(0).toObject();
        technique.insert(QStringLiteral("wie"), QJsonArray{same});
        techniques.replace(0, technique);
        first.insert(QStringLiteral("techniken"), techniques);
        sections.replace(0, first);
        json.insert(QStringLiteral("abschnitte"), sections);
        return shelf.installed(id, 1, {{QStringLiteral("lern-test/v1"), videoFile}},
                               {QStringLiteral("lern-test/v1")}, {}, json, {{QStringLiteral("lern-test/v1"), tracks}});
    }

    QTranslator m_german;
    QList<QPointer<QObject>> m_watched;
};

QUICK_TEST_MAIN_WITH_SETUP(ui, Setup)
#include "tst_ui.moc"
