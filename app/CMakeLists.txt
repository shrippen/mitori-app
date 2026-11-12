cmake_minimum_required(VERSION 3.21)
project(mitori VERSION 0.3.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

# 6.9: DelegateChooser in QtQml.Models (ProgrammePage); before it lived in Qt.labs.qmlmodels.
set(MITORI_QT_MIN 6.9)
find_package(Qt6 ${MITORI_QT_MIN} REQUIRED COMPONENTS Core Gui Quick QuickControls2 Multimedia Sql Network Concurrent LinguistTools)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
find_package(KF6 REQUIRED COMPONENTS Kirigami)
find_package(Python3 REQUIRED COMPONENTS Interpreter)
# The app password in the system's key store (store/secretstore).
find_package(Qt6Keychain REQUIRED)
# Pronunciation in the glossary; without the module the speaker buttons stay hidden.
find_package(Qt6 ${MITORI_QT_MIN} QUIET COMPONENTS TextToSpeech)
# The screen's brightness over Solid (platform/devicelevels) on Linux.
if(NOT ANDROID)
    find_package(Qt6 ${MITORI_QT_MIN} REQUIRED COMPONENTS DBus)
endif()

qt_standard_project_setup(REQUIRES ${MITORI_QT_MIN})
# Module output in <build>/qml: scripts/qmllint.sh finds the Mitori module there.
set(QT_QML_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/qml)

# Programme data: tools/daten.py (mitori-daten, Submodul) checks daten/*.yaml and writes
# mitori-daten.json into the build. Override with -DMITORI_DATA_DIR=/path/to/mitori-daten
# when the submodul lives elsewhere or you want a different data revision.
# Default: ../third_party/mitori-daten (relative to the app/CMakeLists.txt).
set(MITORI_DATA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../third_party/mitori-daten"
    CACHE PATH "Pfad zum mitori-daten-Repo (Submodul oder Checkout)")
get_filename_component(MITORI_DATA_DIR "${MITORI_DATA_DIR}" ABSOLUTE)
if(NOT EXISTS "${MITORI_DATA_DIR}/tools/daten.py")
    message(FATAL_ERROR "mitori-daten nicht unter ${MITORI_DATA_DIR} (oder tools/daten.py fehlt); git submodule update --init laufen lassen")
endif()
set(MITORI_DATEN_DIR ${CMAKE_CURRENT_BINARY_DIR}/daten)
set(MITORI_DATEN_JSON ${MITORI_DATEN_DIR}/mitori-daten.json)
file(GLOB MITORI_DATEN_YAML CONFIGURE_DEPENDS ${MITORI_DATA_DIR}/daten/*.yaml)
add_custom_command(
    OUTPUT ${MITORI_DATEN_JSON}
    COMMAND Python3::Interpreter ${MITORI_DATA_DIR}/tools/daten.py --ausgabe ${MITORI_DATEN_DIR}
    DEPENDS ${MITORI_DATA_DIR}/tools/daten.py ${MITORI_DATA_DIR}/STAND ${MITORI_DATA_DIR}/KORREKTUREN.md ${MITORI_DATEN_YAML}
    COMMENT "Checking programme data (mitori-daten/tools/daten.py)"
    VERBATIM
)

# Shinki (shinki/README.md): always offered in the style choice, the pages now reach it through
# app/qml/Look. The build still ships without it (MITORI_SHINKI=OFF) for a stripped-down binary.
option(MITORI_SHINKI "Offer the Shinki style (default; OFF strips it out)" ON)
option(MITORI_BUILD_TESTS "Build the C++ unit tests" OFF)

# The app's QML module, services and resources as a static library: the app and the UI test
# (tests/tst_ui.cpp) link the same.
# The version for "About Mitori" (services/appearance) and the application.
add_compile_definitions(MITORI_VERSION="${PROJECT_VERSION}")

qt_add_library(mitori_app STATIC)
set_source_files_properties(qml/Look/Look.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
set_source_files_properties(qml/Tablet.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(mitori_app
    URI Mitori
    QML_FILES
        qml/Main.qml
        qml/StartPage.qml
        qml/ProgrammePage.qml
        qml/TechniqueSheet.qml
        qml/TechniqueBody.qml
        qml/StepList.qml
        qml/Tablet.qml
        qml/TwoColumns.qml
        qml/TypingHold.qml
        qml/ListAndPage.qml
        qml/CommentPage.qml
        qml/PlayerPage.qml
        qml/PlayerView.qml
        qml/PlayerRatings.qml
        qml/PlayerHistory.qml
        qml/PlayerTrainingList.qml
        qml/SettingsPage.qml
        qml/RatingRow.qml
        qml/GradeStand.qml
        qml/TodayPage.qml
        qml/TrainingEndPage.qml
        qml/NotesPage.qml
        qml/NoteEditor.qml
        qml/LeaveDialog.qml
        qml/NoteRow.qml
        qml/AllNotesPage.qml
        qml/SearchPage.qml
        qml/StatsPage.qml
        qml/ExamPage.qml
        qml/ExamRoundPage.qml
        qml/ExamBoard.qml
        qml/ExamEndPage.qml
        qml/TechniqueMapPage.qml
        qml/TechniquePickerPage.qml
        qml/CoursesPage.qml
        qml/NotebooksPage.qml
        qml/CourseRow.qml
        qml/CoursePage.qml
        qml/ExportSheet.qml
        qml/SaveFileDialog.qml
        qml/CourseNewPage.qml
        qml/coursedays.js
        qml/playlists.js
        qml/comment.js
        qml/VideosPage.qml
        qml/LessonsPage.qml
        qml/LessonPackagePage.qml
        qml/BackupPage.qml
        qml/GradesPage.qml
        qml/grades.js
        qml/MediaView.qml
        qml/MediaVoice.qml
        qml/MediaCompose.qml
        qml/CameraPage.qml
        qml/ScanPage.qml
        qml/ConflictsPage.qml
        qml/YearsPage.qml
        qml/StyleChoice.qml
        qml/LanguageChoice.qml
        qml/ChoiceTile.qml
        qml/LookSample.qml
        qml/AppearancePage.qml
        qml/WelcomePage.qml
        qml/Look/Look.qml
        qml/Look/LookRoles.qml
        qml/Look/LookTile.qml
        qml/Look/LookHint.qml
        qml/Look/LookButton.qml
        qml/Look/LookScope.qml
        qml/Look/LookWindowScope.qml
        qml/Look/LookSegmented.qml
        qml/Look/LookChip.qml
        qml/Look/LookListRow.qml
        qml/Look/LookLevelDots.qml
        qml/Look/LookToolButton.qml
        qml/Look/LookLevelPicker.qml
        qml/Look/LookProgressBar.qml
        qml/Look/LookOdometer.qml
        qml/Look/LookLegend.qml
        qml/Look/LookHeading.qml
        qml/Look/LookSectionLabel.qml
        qml/Look/LookTextField.qml
        qml/Look/LookSliderSkin.qml
        qml/Look/LookTransportBar.qml
        qml/Look/LookFocusFollow.qml
        qml/Look/LookPlayButton.qml
        qml/Look/LookGroupHead.qml
        qml/Look/LookKpi.qml
        qml/Look/LookSpinBox.qml
        qml/Look/LookSwitch.qml
        qml/Look/LookSettingRow.qml
        qml/Look/LookDialog.qml
        qml/Look/LookCard.qml
        qml/Look/LookDateField.qml
        qml/Look/LookComboBox.qml
        qml/Look/LookSteps.qml
        qml/Look/LookOptionTile.qml
        qml/Look/LookToast.qml
        qml/Look/LookCalendarHeatmap.qml
        qml/Look/LookBarChart.qml
        qml/Look/LookHead.qml
        qml/Look/LookHeatGrid.qml
        qml/Look/LookLabel.qml
        qml/Look/LookKicker.qml
        qml/Look/LookToggle.qml
        qml/Look/LookFormRow.qml
        qml/Look/LookEmptyState.qml
        qml/Look/LookTextArea.qml
        qml/Look/LookMenu.qml
        qml/Look/LookMenuItem.qml
        qml/Look/LookScrollView.qml
        qml/Look/LookToolBar.qml
    SOURCES
        catalog/catalog.h
        catalog/catalog.cpp
        catalog/lessons.h
        catalog/lessons.cpp
        services/programme.h
        services/programme.cpp
        services/practicegrade.h
        services/practicegrade.cpp
        services/glossary.h
        services/glossary.cpp
        player/speaker.h
        player/speaker.cpp
        player/decoders.h
        player/decoders.cpp
        services/videos.h
        services/videos.cpp
        services/practice.h
        services/practice.cpp
        services/exam.h
        services/exam.cpp
        store/practicelog.h
        store/practicelog.cpp
        store/schedule.h
        store/schedule.cpp
        store/searchkey.h
        store/icsreader.h
        store/icsreader.cpp
        store/coursebook.h
        store/coursebook.cpp
        store/writeahead.h
        store/device.h
        services/courses.h
        services/courses.cpp
        services/saveplace.h
        services/saveplace.cpp
        platform/devicecalendar.h
        platform/devicecalendar.cpp
        platform/sharefile.h
        platform/sharefile.cpp
        platform/typedpath.h
        platform/typedpath.cpp
        platform/localtime.h
        platform/localtime.cpp
        platform/devicelevels.h
        platform/devicelevels.cpp
        services/levels.h
        services/levels.cpp
        services/appearance.h
        services/appearance.cpp
        services/lookpreview.h
        services/lookpreview.cpp
        platform/systembars.h
        platform/systembars.cpp
        store/bundlecrypto.h
        store/bundlecrypto.cpp
        store/bundleshelf.h
        store/bundleshelf.cpp
        store/webvtt.h
        store/webvtt.cpp
        services/subtitletrack.h
        services/subtitletrack.cpp
        store/videomove.h
        store/videomove.cpp
        platform/storageplaces.h
        platform/storageplaces.cpp
        services/storage.h
        services/storage.cpp
        services/bundles.h
        services/bundles.cpp
        services/library.h
        services/library.cpp
        platform/qrreader.h
        platform/qrreader.cpp
        services/codescanner.h
        services/codescanner.cpp
        services/keyedlistmodel.h
        services/keyedlistmodel.cpp
        services/allnotes.h
        services/allnotes.cpp
        store/mediastore.h
        store/mediastore.cpp
        store/zipwriter.h
        store/zipwriter.cpp
        store/notebookexport.h
        store/notebookexport.cpp
        store/zipreader.h
        store/zipreader.cpp
        store/tablemerge.h
        store/tablemerge.cpp
        store/backuparchive.h
        store/backuparchive.cpp
        services/backup.h
        services/backup.cpp
        store/webdav.h
        store/webdav.cpp
        store/secretstore.h
        store/secretstore.cpp
        store/syncaccount.h
        store/syncaccount.cpp
        services/syncjob.h
        services/syncjob.cpp
        services/sync.h
        services/sync.cpp
        services/media.h
        services/media.cpp
)

# Texts: English in the code, German in i18n/mitori_de.ts (update: cmake --build <dir> --target
# update_translations). The .qm files go into the resources under :/i18n. mitori_en.ts holds only
# the English plural forms; it also makes English win where it comes before German in the
# user's languages. The catalogues hold no source locations (-locations none): line numbers
# would change with every edit and make parallel pull requests conflict there.
qt_add_translations(mitori_app
    TS_FILES i18n/mitori_de.ts
    PLURALS_TS_FILE i18n/mitori_en.ts
    RESOURCE_PREFIX /i18n
    LUPDATE_OPTIONS -no-obsolete -locations none
)

qt_add_resources(mitori_app "daten"
    PREFIX "/daten"
    BASE ${MITORI_DATEN_DIR}
    FILES ${MITORI_DATEN_JSON}
)

# Icons for platforms without an icon theme (scripts/sync-icons.sh).
file(GLOB_RECURSE ICON_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS icons/*)
qt_add_resources(mitori_app "icons"
    PREFIX "/icons"
    BASE icons
    FILES ${ICON_FILES}
)

# Kante (scripts/sync-kante.sh) as the QML module "Kante" in the resources.
file(GLOB_RECURSE KANTE_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS qml/Kante/*)
qt_add_resources(mitori_app "kante"
    PREFIX "/qt/qml/Kante"
    BASE qml/Kante
    FILES ${KANTE_FILES}
)

# Shinki (shinki/, the club newspaper's style) as a separate QML module "Shinki" with
# its fonts, and the Look layer's Shinki files (app/qml/Look/+shinki, chosen by the file selector
# "shinki", Appearance::prepare). Only where Shinki can be chosen or is tested: its fonts are
# 1.3 MB. `app/qml/Look/+shinki/*.qml`
# imports "Shinki", which the import scanner finds in the separate module target.
if(MITORI_SHINKI OR MITORI_BUILD_TESTS)
    get_filename_component(MITORI_SHINKI_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../shinki" ABSOLUTE)
    qt_add_library(mitori_shinki STATIC)
    file(GLOB SHINKI_QML_FILES CONFIGURE_DEPENDS
        ${MITORI_SHINKI_DIR}/qml/Shinki/*.qml)
    # qt_add_qml_module needs each file as a relative path or with QT_RESOURCE_ALIAS set; the
    # files live outside app/, so each gets its basename as alias. ShinkiStyle is a
    # singleton in shinki/qml/Shinki/qmldir; mark it so Qt generates the qmldir accordingly.
    foreach(file ${SHINKI_QML_FILES})
        get_filename_component(_alias "${file}" NAME)
        set_source_files_properties(${file}
            PROPERTIES QT_RESOURCE_ALIAS "${_alias}")
    endforeach()
    set_source_files_properties(${MITORI_SHINKI_DIR}/qml/Shinki/ShinkiStyle.qml
        PROPERTIES QT_RESOURCE_ALIAS "ShinkiStyle.qml"
        QT_QML_SINGLETON_TYPE TRUE)
    qt_add_qml_module(mitori_shinki
        URI Shinki
        VERSION 1.0
        QML_FILES ${SHINKI_QML_FILES}
    )
    file(GLOB SHINKI_FONTS ${MITORI_SHINKI_DIR}/fonts/*.ttf)
    foreach(font ${SHINKI_FONTS})
        get_filename_component(_font_alias "${font}" NAME)
        set_source_files_properties(${font}
            PROPERTIES QT_RESOURCE_ALIAS "${_font_alias}")
    endforeach()
    qt_add_resources(mitori_shinki "shinki_fonts"
        PREFIX "/shinki/fonts"
        BASE ${MITORI_SHINKI_DIR}/fonts
        FILES ${SHINKI_FONTS}
    )
    file(GLOB LOOK_SHINKI RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS qml/Look/+shinki/*.qml)
    qt_add_resources(mitori_app "look_shinki"
        PREFIX "/qt/qml/Mitori"
        FILES ${LOOK_SHINKI}
    )
    target_link_libraries(mitori_app PRIVATE mitori_shinki)
    target_compile_definitions(mitori_app PRIVATE MITORI_SHINKI_FILES)
endif()

# Monocypher (app/third_party, BSD-2-Clause / CC0): Argon2id, BLAKE2b and XChaCha20-Poly1305 for the
# video bundles (store/bundlecrypto).
add_library(monocypher STATIC third_party/monocypher/monocypher.c third_party/monocypher/monocypher.h)
target_include_directories(monocypher PUBLIC third_party/monocypher)
set_target_properties(monocypher PROPERTIES POSITION_INDEPENDENT_CODE ON)
# ZXing-C++ (app/third_party, Apache-2.0): the DVD's QR code (platform/qrreader).
add_subdirectory(third_party/zxing-cpp)
# The licences of what is linked ask that binaries carry them: shown in "About Mitori"
# (services/appearance).
qt_add_resources(mitori_app "licences"
    PREFIX "/licences"
    BASE third_party
    FILES third_party/zxing-cpp/ATTRIBUTION.txt third_party/zxing-cpp/LICENSE third_party/qtkeychain/COPYING
        third_party/monocypher/LICENCE.md
        third_party/openssl/ATTRIBUTION.txt third_party/openssl/LICENSE.txt
        third_party/libomp/ATTRIBUTION.txt third_party/libomp/LICENSE.TXT
)

# The generated type registration includes the headers by name.
target_include_directories(mitori_app PUBLIC catalog services store player platform)
target_link_libraries(mitori_app PUBLIC Qt6::Quick Qt6::QuickControls2 Qt6::Multimedia Qt6::Sql Qt6::Network Qt6::Concurrent KF6::Kirigami monocypher ZXing)
target_link_libraries(mitori_app PRIVATE Qt6Keychain::Qt6Keychain)
# The video decoders tried in the background (player/decoders.cpp) need Qt's private headers;
# without them the first player tries them. Only QFactoryLoader and the media plugin's create() are
# used, both there since Qt 6.2 (symbol version Qt_6_PRIVATE_API, not tied to a patch release).
set(QT_NO_PRIVATE_MODULE_WARNING ON)
find_package(Qt6 QUIET COMPONENTS CorePrivate MultimediaPrivate)
if(TARGET Qt6::MultimediaPrivate AND TARGET Qt6::CorePrivate)
    target_link_libraries(mitori_app PRIVATE Qt6::CorePrivate Qt6::MultimediaPrivate)
    target_compile_definitions(mitori_app PRIVATE MITORI_MULTIMEDIA_PRIVATE)
endif()
if(NOT ANDROID)
    target_link_libraries(mitori_app PUBLIC Qt6::DBus)
endif()
if(TARGET Qt6::TextToSpeech)
    target_link_libraries(mitori_app PUBLIC Qt6::TextToSpeech)
    target_compile_definitions(mitori_app PRIVATE MITORI_SPEECH)
else()
    message(STATUS "Qt6 TextToSpeech not found: the glossary has no pronunciation")
endif()

qt_add_executable(mitori main.cpp)
target_link_libraries(mitori PRIVATE mitori_app mitori_appplugin)
target_include_directories(mitori PRIVATE services)
# The QML import scan links static plugins; a shared Qt needs none, and Kirigami's plugin
# targets are not exported (one warning per plugin). Android keeps it for androiddeployqt.
if(NOT ANDROID)
    set_target_properties(mitori PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
endif()

if(MITORI_SHINKI)
    target_compile_definitions(mitori_app PRIVATE MITORI_SHINKI)
endif()

# Internal demo (Studio Weber data, screenshots only). Never in published builds.
option(MITORI_DEMO "Include the internal demo mode (development only)" OFF)
if(MITORI_DEMO)
    target_compile_definitions(mitori PRIVATE MITORI_DEMO)
    target_sources(mitori PRIVATE demo/demo.cpp demo/demo.h)
endif()

if(ANDROID)
    set_property(TARGET mitori APPEND PROPERTY
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android")
    set_target_properties(mitori PROPERTIES
        QT_ANDROID_PACKAGE_NAME "io.github.shrippen.Mitori"
        QT_ANDROID_VERSION_NAME "0.3.0"
        QT_ANDROID_VERSION_CODE "300"
        QT_ANDROID_MIN_SDK_VERSION "28"
        QT_ANDROID_TARGET_SDK_VERSION "34"
        QT_ANDROID_COMPILE_SDK_VERSION "36"
        QT_ANDROID_SDK_BUILD_TOOLS_REVISION "36.0.0"
    )
    # Kirigami's QML plugin needs libomp.so from the NDK.
    file(GLOB LIBOMP_CANDIDATES "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/lib/clang/*/lib/linux/aarch64/libomp.so")
    if(LIBOMP_CANDIDATES)
        list(GET LIBOMP_CANDIDATES 0 LIBOMP_PATH)
    else()
        message(FATAL_ERROR "libomp.so not found in the NDK (${ANDROID_NDK}); Kirigami cannot load without it")
    endif()
    # Qt's TLS plugin loads OpenSSL at runtime: without it no HTTPS (bundles, manifest, calendar).
    set(MITORI_ANDROID_OPENSSL "" CACHE PATH "libssl_3.so and libcrypto_3.so (scripts/build-kf6-android.sh)")
    set(MITORI_OPENSSL_LIBS "${MITORI_ANDROID_OPENSSL}/libssl_3.so" "${MITORI_ANDROID_OPENSSL}/libcrypto_3.so")
    foreach(lib IN LISTS MITORI_OPENSSL_LIBS)
        if(NOT EXISTS "${lib}")
            message(FATAL_ERROR "${lib} missing (MITORI_ANDROID_OPENSSL, scripts/build-kf6-android.sh)")
        endif()
    endforeach()
    set_target_properties(mitori PROPERTIES QT_ANDROID_EXTRA_LIBS "${LIBOMP_PATH};${MITORI_OPENSSL_LIBS}")
    # Kirigami's QML plugins: <prefix>/lib/cmake/KF6Kirigami -> <prefix>/lib/qml.
    get_filename_component(KF6_QML_DIR "${KF6Kirigami_DIR}/../../qml" ABSOLUTE)
    if(IS_DIRECTORY "${KF6_QML_DIR}")
        set_property(TARGET mitori APPEND PROPERTY QT_QML_IMPORT_PATH "${KF6_QML_DIR}")
    endif()
endif()

if(MITORI_BUILD_TESTS AND NOT ANDROID)
    enable_testing()
    # The fake camera (services/codescanner): in test builds only.
    target_compile_definitions(mitori_app PRIVATE MITORI_TEST_CAMERA)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(tst_catalog tests/tst_catalog.cpp catalog/catalog.cpp catalog/catalog.h)
    target_include_directories(tst_catalog PRIVATE catalog)
    target_compile_definitions(tst_catalog PRIVATE MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")
    target_link_libraries(tst_catalog PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    add_dependencies(tst_catalog mitori)
    set_target_properties(tst_catalog PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME catalog COMMAND tst_catalog)

    qt_add_executable(tst_programme tests/tst_programme.cpp services/programme.cpp services/programme.h
        services/practicegrade.cpp services/practicegrade.h
        services/courses.cpp services/courses.h
        store/coursebook.cpp store/coursebook.h store/tablemerge.cpp store/tablemerge.h store/icsreader.cpp store/icsreader.h store/device.h
        platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h store/mediastore.cpp store/mediastore.h store/zipwriter.cpp store/zipwriter.h store/notebookexport.cpp store/notebookexport.h
        catalog/catalog.cpp catalog/catalog.h)
    target_include_directories(tst_programme PRIVATE catalog services store platform)
    target_compile_definitions(tst_programme PRIVATE MITORI_DATEN_JSON="${MITORI_DATEN_JSON}"
        TEST_BUNDLE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/bundle"
        TEST_DATA_DIR="${CMAKE_BINARY_DIR}/test-data/programme")
    target_link_libraries(tst_programme PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Test)
    set_target_properties(tst_programme PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_dependencies(tst_programme mitori)
    add_test(NAME programme COMMAND tst_programme)

    qt_add_executable(tst_exam tests/tst_exam.cpp services/exam.cpp services/exam.h
        services/programme.cpp services/programme.h catalog/catalog.cpp catalog/catalog.h)
    target_include_directories(tst_exam PRIVATE catalog services store)
    target_compile_definitions(tst_exam PRIVATE MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")
    target_link_libraries(tst_exam PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    set_target_properties(tst_exam PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_dependencies(tst_exam mitori)
    add_test(NAME exam COMMAND tst_exam)

    qt_add_executable(tst_glossary tests/tst_glossary.cpp services/glossary.cpp services/glossary.h
        player/speaker.cpp player/speaker.h catalog/catalog.cpp catalog/catalog.h)
    target_include_directories(tst_glossary PRIVATE catalog services store player)
    target_compile_definitions(tst_glossary PRIVATE MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")
    target_link_libraries(tst_glossary PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    if(TARGET Qt6::TextToSpeech)
        target_link_libraries(tst_glossary PRIVATE Qt6::TextToSpeech)
        target_compile_definitions(tst_glossary PRIVATE MITORI_SPEECH)
    endif()
    set_target_properties(tst_glossary PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_dependencies(tst_glossary mitori)
    add_test(NAME glossary COMMAND tst_glossary)

    qt_add_executable(tst_practice tests/tst_practice.cpp services/practice.cpp services/practice.h
        store/practicelog.cpp store/practicelog.h store/tablemerge.cpp store/tablemerge.h store/schedule.cpp store/schedule.h store/mediastore.cpp store/mediastore.h)
    target_include_directories(tst_practice PRIVATE services store)
    target_compile_definitions(tst_practice PRIVATE TEST_DATA_DIR="${CMAKE_BINARY_DIR}/test-data/practice")
    target_link_libraries(tst_practice PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Test)
    set_target_properties(tst_practice PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME practice COMMAND tst_practice)

    qt_add_executable(tst_schedule tests/tst_schedule.cpp store/schedule.cpp store/schedule.h store/practicelog.h)
    target_include_directories(tst_schedule PRIVATE store)
    target_link_libraries(tst_schedule PRIVATE Qt6::Core Qt6::Test)
    set_target_properties(tst_schedule PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME schedule COMMAND tst_schedule)

    qt_add_executable(tst_allnotes tests/tst_allnotes.cpp services/allnotes.cpp services/allnotes.h
        services/keyedlistmodel.cpp services/keyedlistmodel.h services/practice.cpp services/practice.h
        services/courses.cpp services/courses.h services/programme.cpp services/programme.h
        store/practicelog.cpp store/practicelog.h store/tablemerge.cpp store/tablemerge.h store/schedule.cpp store/schedule.h
        store/coursebook.cpp store/coursebook.h store/icsreader.cpp store/icsreader.h store/device.h
        platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h catalog/catalog.cpp catalog/catalog.h store/mediastore.cpp store/mediastore.h store/zipwriter.cpp store/zipwriter.h store/notebookexport.cpp store/notebookexport.h)
    target_include_directories(tst_allnotes PRIVATE catalog services store platform)
    target_compile_definitions(tst_allnotes PRIVATE MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")
    target_link_libraries(tst_allnotes PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Test)
    set_target_properties(tst_allnotes PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_dependencies(tst_allnotes mitori)
    add_test(NAME allnotes COMMAND tst_allnotes)

    qt_add_executable(tst_media tests/tst_media.cpp store/mediastore.cpp store/mediastore.h
        services/practice.cpp services/practice.h store/practicelog.cpp store/practicelog.h store/tablemerge.cpp store/tablemerge.h
        store/schedule.cpp store/schedule.h services/courses.cpp services/courses.h
        store/coursebook.cpp store/coursebook.h store/icsreader.cpp store/icsreader.h store/device.h
        platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h catalog/catalog.cpp catalog/catalog.h store/zipwriter.cpp store/zipwriter.h store/notebookexport.cpp store/notebookexport.h)
    target_include_directories(tst_media PRIVATE catalog services store platform)
    target_link_libraries(tst_media PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Test)
    set_target_properties(tst_media PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME media COMMAND tst_media)

    qt_add_executable(tst_backup tests/tst_backup.cpp services/backup.cpp services/backup.h
        store/backuparchive.cpp store/backuparchive.h store/zipreader.cpp store/zipreader.h
        store/zipwriter.cpp store/zipwriter.h store/mediastore.cpp store/mediastore.h
        services/practice.cpp services/practice.h store/practicelog.cpp store/practicelog.h store/tablemerge.cpp store/tablemerge.h
        store/schedule.cpp store/schedule.h services/courses.cpp services/courses.h
        store/coursebook.cpp store/coursebook.h store/icsreader.cpp store/icsreader.h store/device.h
        platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h catalog/catalog.cpp catalog/catalog.h store/notebookexport.cpp store/notebookexport.h)
    target_include_directories(tst_backup PRIVATE catalog services store platform)
    target_link_libraries(tst_backup PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Test)
    set_target_properties(tst_backup PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME backup COMMAND tst_backup)

    qt_add_executable(tst_sync tests/tst_sync.cpp services/sync.cpp services/sync.h services/syncjob.cpp services/syncjob.h
        store/secretstore.cpp store/secretstore.h store/syncaccount.cpp store/syncaccount.h store/webdav.cpp store/webdav.h
        store/backuparchive.cpp store/backuparchive.h store/zipreader.cpp store/zipreader.h
        store/zipwriter.cpp store/zipwriter.h store/mediastore.cpp store/mediastore.h
        services/practice.cpp services/practice.h store/practicelog.cpp store/practicelog.h store/tablemerge.cpp store/tablemerge.h
        store/schedule.cpp store/schedule.h services/courses.cpp services/courses.h
        store/coursebook.cpp store/coursebook.h store/icsreader.cpp store/icsreader.h store/device.h
        platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h catalog/catalog.cpp catalog/catalog.h store/notebookexport.cpp store/notebookexport.h)
    target_include_directories(tst_sync PRIVATE catalog services store platform)
    target_link_libraries(tst_sync PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Concurrent Qt6::Test Qt6Keychain::Qt6Keychain)
    set_target_properties(tst_sync PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME sync COMMAND tst_sync)

    qt_add_executable(tst_export tests/tst_export.cpp services/saveplace.cpp services/saveplace.h platform/typedpath.cpp platform/typedpath.h store/zipwriter.cpp store/zipwriter.h
        store/notebookexport.cpp store/notebookexport.h store/mediastore.cpp store/mediastore.h
        services/courses.cpp services/courses.h store/coursebook.cpp store/coursebook.h store/tablemerge.cpp store/tablemerge.h
        store/icsreader.cpp store/icsreader.h store/device.h platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h
        catalog/catalog.cpp catalog/catalog.h)
    target_include_directories(tst_export PRIVATE catalog services store platform)
    target_link_libraries(tst_export PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Test)
    set_target_properties(tst_export PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME export COMMAND tst_export)

    # Qt's own file dialog, driven with the keys.
    qt_add_executable(tst_filedialog tests/tst_filedialog.cpp platform/typedpath.cpp platform/typedpath.h)
    target_include_directories(tst_filedialog PRIVATE platform)
    target_link_libraries(tst_filedialog PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Test)
    set_target_properties(tst_filedialog PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME filedialog COMMAND tst_filedialog)
    set_tests_properties(filedialog PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

    # Local times without a file system call each.
    qt_add_executable(tst_localtime tests/tst_localtime.cpp platform/localtime.cpp platform/localtime.h)
    target_include_directories(tst_localtime PRIVATE platform)
    target_link_libraries(tst_localtime PRIVATE Qt6::Core Qt6::Test)
    add_test(NAME localtime COMMAND tst_localtime)

    qt_add_executable(tst_keyedlistmodel tests/tst_keyedlistmodel.cpp services/keyedlistmodel.cpp services/keyedlistmodel.h)
    target_include_directories(tst_keyedlistmodel PRIVATE services)
    target_link_libraries(tst_keyedlistmodel PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    set_target_properties(tst_keyedlistmodel PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME keyedlistmodel COMMAND tst_keyedlistmodel)

    qt_add_executable(tst_ics tests/tst_ics.cpp store/icsreader.cpp store/icsreader.h)
    target_include_directories(tst_ics PRIVATE store)
    target_compile_definitions(tst_ics PRIVATE TEST_ICS="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/lehrgaenge.ics")
    target_link_libraries(tst_ics PRIVATE Qt6::Core Qt6::Test)
    set_target_properties(tst_ics PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME ics COMMAND tst_ics)

    qt_add_executable(tst_courses tests/tst_courses.cpp services/courses.cpp services/courses.h
        store/coursebook.cpp store/coursebook.h store/tablemerge.cpp store/tablemerge.h store/icsreader.cpp store/icsreader.h store/device.h
        platform/devicecalendar.cpp platform/devicecalendar.h platform/sharefile.cpp platform/sharefile.h catalog/catalog.cpp catalog/catalog.h store/mediastore.cpp store/mediastore.h store/zipwriter.cpp store/zipwriter.h store/notebookexport.cpp store/notebookexport.h)
    target_include_directories(tst_courses PRIVATE catalog services store platform)
    target_compile_definitions(tst_courses PRIVATE TEST_ICS="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/lehrgaenge.ics"
        MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")
    target_link_libraries(tst_courses PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Sql Qt6::Network Qt6::Test)
    set_target_properties(tst_courses PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_dependencies(tst_courses mitori)
    add_test(NAME courses COMMAND tst_courses)
    # Courses names the techniques in the export.
    foreach(target tst_media tst_backup tst_sync tst_export tst_courses)
        target_sources(${target} PRIVATE services/programme.cpp services/programme.h)
    endforeach()
    # Programme and Videos read the Lernpakete (Lessons, from the bundle shelf).
    foreach(target tst_programme tst_exam tst_allnotes tst_media tst_backup tst_sync tst_export tst_courses)
        target_sources(${target} PRIVATE catalog/lessons.cpp catalog/lessons.h store/bundleshelf.cpp store/bundleshelf.h)
    endforeach()
    target_compile_definitions(tst_export PRIVATE MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")

    qt_add_executable(tst_bundlecrypto tests/tst_bundlecrypto.cpp store/bundlecrypto.cpp store/bundlecrypto.h)
    target_include_directories(tst_bundlecrypto PRIVATE store)
    target_compile_definitions(tst_bundlecrypto PRIVATE TEST_BUNDLE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/bundle")
    target_link_libraries(tst_bundlecrypto PRIVATE Qt6::Core Qt6::Test monocypher)
    set_target_properties(tst_bundlecrypto PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME bundlecrypto COMMAND tst_bundlecrypto)

    qt_add_executable(tst_bundles tests/tst_bundles.cpp services/bundles.cpp services/bundles.h
        services/videos.cpp services/videos.h catalog/catalog.cpp catalog/catalog.h player/decoders.cpp player/decoders.h
        catalog/lessons.cpp catalog/lessons.h services/library.cpp services/library.h store/bundleshelf.cpp store/bundleshelf.h store/bundlecrypto.cpp store/bundlecrypto.h)
    target_include_directories(tst_bundles PRIVATE services store catalog player)
    target_compile_definitions(tst_bundles PRIVATE TEST_BUNDLE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/bundle")
    target_link_libraries(tst_bundles PRIVATE Qt6::Core Qt6::Qml Qt6::Network Qt6::Concurrent Qt6::Test monocypher)
    set_target_properties(tst_bundles PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME bundles COMMAND tst_bundles)

    qt_add_executable(tst_webvtt tests/tst_webvtt.cpp store/webvtt.cpp store/webvtt.h services/subtitletrack.cpp services/subtitletrack.h)
    target_include_directories(tst_webvtt PRIVATE services store)
    target_compile_definitions(tst_webvtt PRIVATE TEST_BUNDLE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/bundle")
    target_link_libraries(tst_webvtt PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    set_target_properties(tst_webvtt PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME webvtt COMMAND tst_webvtt)

    qt_add_executable(tst_storage tests/tst_storage.cpp services/storage.cpp services/storage.h
        store/videomove.cpp store/videomove.h store/bundleshelf.cpp store/bundleshelf.h
        platform/storageplaces.cpp platform/storageplaces.h)
    target_include_directories(tst_storage PRIVATE services store platform)
    target_link_libraries(tst_storage PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    set_target_properties(tst_storage PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME storage COMMAND tst_storage)

    qt_add_executable(tst_lessons tests/tst_lessons.cpp catalog/lessons.cpp catalog/lessons.h
        services/library.cpp services/library.h services/videos.cpp services/videos.h catalog/catalog.cpp catalog/catalog.h
        player/decoders.cpp player/decoders.h store/bundleshelf.cpp store/bundleshelf.h)
    target_include_directories(tst_lessons PRIVATE services store catalog player)
    target_compile_definitions(tst_lessons PRIVATE TEST_BUNDLE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/bundle")
    target_link_libraries(tst_lessons PRIVATE Qt6::Core Qt6::Qml Qt6::Test)
    set_target_properties(tst_lessons PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME lessons COMMAND tst_lessons)

    if(TARGET Qt6::MultimediaPrivate AND TARGET Qt6::CorePrivate)
        qt_add_executable(tst_decoders tests/tst_decoders.cpp player/decoders.cpp player/decoders.h)
        target_include_directories(tst_decoders PRIVATE player)
        target_compile_definitions(tst_decoders PRIVATE MITORI_MULTIMEDIA_PRIVATE)
        target_link_libraries(tst_decoders PRIVATE Qt6::Gui Qt6::Multimedia Qt6::CorePrivate Qt6::MultimediaPrivate Qt6::Test)
        set_target_properties(tst_decoders PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
        add_test(NAME decoders COMMAND tst_decoders)
        set_tests_properties(decoders PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
    endif()

    qt_add_executable(tst_codescanner tests/tst_codescanner.cpp services/codescanner.cpp services/codescanner.h
        platform/qrreader.cpp platform/qrreader.h store/bundlecrypto.cpp store/bundlecrypto.h)
    target_include_directories(tst_codescanner PRIVATE services platform store)
    target_compile_definitions(tst_codescanner PRIVATE MITORI_TEST_CAMERA)
    target_link_libraries(tst_codescanner PRIVATE Qt6::Core Qt6::Gui Qt6::Multimedia Qt6::Qml Qt6::Concurrent Qt6::Test monocypher ZXing)
    set_target_properties(tst_codescanner PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME codescanner COMMAND tst_codescanner)
    set_tests_properties(codescanner PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

    qt_add_executable(tst_levels tests/tst_levels.cpp services/levels.cpp services/levels.h
        platform/devicelevels.cpp platform/devicelevels.h)
    target_include_directories(tst_levels PRIVATE services platform)
    target_link_libraries(tst_levels PRIVATE Qt6::Core Qt6::Qml Qt6::DBus Qt6::Test)
    set_target_properties(tst_levels PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME levels COMMAND tst_levels)

    qt_add_executable(tst_appearance tests/tst_appearance.cpp services/appearance.cpp services/appearance.h
        platform/systembars.cpp platform/systembars.h catalog/catalog.cpp catalog/catalog.h)
    target_include_directories(tst_appearance PRIVATE services platform catalog)
    target_link_libraries(tst_appearance PRIVATE Qt6::Core Qt6::Gui Qt6::Qml Qt6::Test)
    set_target_properties(tst_appearance PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    if(MITORI_SHINKI)
        target_compile_definitions(tst_appearance PRIVATE MITORI_SHINKI)
    endif()
    add_test(NAME appearance COMMAND tst_appearance)

    # The pages with Kirigami and Kante, offscreen; screenshots into <build>/ui-shots. Plays a video
    # only with MITORI_VIDEOS (the videos are not in the repository).
    find_package(Qt6 REQUIRED COMPONENTS QuickTest)
    qt_add_executable(tst_ui tests/tst_ui.cpp)
    target_link_libraries(tst_ui PRIVATE mitori_app mitori_appplugin Qt6::QuickTest ZXing)
    target_compile_definitions(tst_ui PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/qml"
        UI_SHOTS_DIR="${CMAKE_BINARY_DIR}/ui-shots" UI_DATA_DIR="${CMAKE_BINARY_DIR}/ui-data"
        TEST_BUNDLE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/bundle"
        TEST_MEDIA_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/data/media")
    set_target_properties(tst_ui PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME ui COMMAND tst_ui)
    # A key store that cannot answer, the same on every machine: never the developer's wallet.
    set(NO_KEY_STORE "QTKEYCHAIN_BACKEND=kwallet6;DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent")
    set_tests_properties(ui PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Material;${NO_KEY_STORE}")
    # The same pages as Shinki (shinki/README.md, "Prüfen"); its shots in ui-shots/shinki.
    add_test(NAME ui_shinki COMMAND tst_ui)
    set_tests_properties(ui_shinki PROPERTIES ENVIRONMENT
        "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Material;MITORI_TEST_STYLE=shinki;${NO_KEY_STORE}")
    # Style and language changed while the app runs, from Leinen and from Shinki. A file of its own:
    # no other test holds a page's compiled types in the engine's cache (tst_look.qml).
    add_test(NAME look COMMAND tst_ui -input ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml-look/tst_look.qml)
    set_tests_properties(look PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Material;${NO_KEY_STORE}")
    add_test(NAME look_shinki COMMAND tst_ui -input ${CMAKE_CURRENT_SOURCE_DIR}/tests/qml-look/tst_look.qml)
    set_tests_properties(look_shinki PROPERTIES ENVIRONMENT
        "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Material;MITORI_TEST_STYLE=shinki;${NO_KEY_STORE}")
    # The pages' times with five years of use (budgets catch what became slow).
    qt_add_executable(tst_perf tests/tst_perf.cpp)
    target_link_libraries(tst_perf PRIVATE mitori_app mitori_appplugin Qt6::QuickTest Qt6::Sql)
    target_include_directories(tst_perf PRIVATE services store)
    target_compile_definitions(tst_perf PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/perf"
        PERF_DATA_DIR="${CMAKE_BINARY_DIR}/perf-data" MITORI_DATEN_JSON="${MITORI_DATEN_JSON}")
    set_target_properties(tst_perf PROPERTIES QT_QML_MODULE_NO_IMPORT_SCAN ON)
    add_test(NAME perf COMMAND tst_perf)
    set_tests_properties(perf PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_CONTROLS_STYLE=Material;${NO_KEY_STORE}")
    # Both runs share the test data (ui-data): never at the same time.
    set_tests_properties(ui ui_shinki look look_shinki PROPERTIES RESOURCE_LOCK ui_data)
endif()

install(TARGETS mitori
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
    LIBRARY DESTINATION lib
)
