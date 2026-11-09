#include <QDir>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlEngine>
#include <QQuickStyle>
#include <QtQml/QQmlExtensionPlugin>

#include "appearance.h"
#include "localtime.h"
#ifdef MITORI_DEMO
#include "demo/demo.h"
#endif

Q_IMPORT_QML_PLUGIN(MitoriPlugin)

int main(int argc, char *argv[])
{
    LocalTime::pin();
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("Mitori"));
    QGuiApplication::setOrganizationDomain(QStringLiteral("shrippen.github.io"));
    QGuiApplication::setDesktopFileName(QStringLiteral("io.github.shrippen.Mitori"));
    QGuiApplication::setApplicationVersion(QStringLiteral(MITORI_VERSION));
    // The bundled Breeze subset (scripts/sync-icons.sh): the theme where there is none
    // (Android, AppImage), else the fallback behind the system theme.
    QIcon::setThemeSearchPaths(QIcon::themeSearchPaths() << QStringLiteral(":/icons"));
    QIcon::setFallbackThemeName(QStringLiteral("breeze-mitori"));
    if (QIcon::themeName().isEmpty() || QIcon::themeName() == QLatin1String("hicolor")) {
        QIcon::setThemeName(QStringLiteral("breeze-mitori"));
    }

#ifdef MITORI_DEMO
    // Settings, data and course calendar of the demo world, before the language is read.
    Demo::prepare();
#endif

    // The language chosen in Appearance, else the first of the user's languages with a catalog
    // (de, en); otherwise the English of the code. Dates follow the chosen language too.
    Appearance::startLanguage();

#ifdef MITORI_DEMO
    // scripts/check-no-demo.sh looks for this mark in the binary: a release that carries it fails.
    // Split here, so shipped sources (Flatpak debug info) do not carry it.
    qInfo("MITORI-DEMO" "-BUILD");
#endif

    // A plain engine: a change of style replaces the window (Appearance::rebuild), which
    // QQmlApplicationEngine's list of root objects does not allow for.
    QQmlEngine engine;
    QObject::connect(&engine, &QQmlEngine::quit, &app, &QCoreApplication::quit);
    QObject::connect(&engine, &QQmlEngine::exit, &app, &QCoreApplication::exit);
    // The controls style of the chosen style (Appearance), before the first window.
    const Appearance::Style style = Appearance::startStyle(engine.importPathList());
    Appearance::prepare(style, &engine);
    if (qEnvironmentVariableIsEmpty("QT_QUICK_CONTROLS_STYLE")) {
        QQuickStyle::setStyle(Appearance::controlsStyle(style, engine.importPathList()));
    }
    if (!Appearance::openWindow(&engine)) {
        return 1;
    }
#ifdef MITORI_DEMO
    Demo::shoot(engine.singletonInstance<Appearance *>("Mitori", "Appearance")->window());
#endif
    const int code = app.exec();

    // Before the engine: the pages' last words need it (NoteRow saves a draft).
    delete engine.singletonInstance<Appearance *>("Mitori", "Appearance")->window();
    return code;
}
