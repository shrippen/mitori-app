import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "coursedays.js" as CourseDays
import "grades.js" as Grades

// Start menu (clickdummy "Startmenü", variant 1): tiles; the programme tile shows the discipline
// chosen last and its practice grade. More tiles come with their features (ROADMAP.md).
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's,
    // and the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    // The mark of the app and the small caps line (the head shows them; the other pages have
    // the way back instead).
    readonly property string headLogo: "神氣"

    // How many of the grade's techniques are exam-ready (the clickdummy's start menu: "3 of 8
    // exam-ready" under the programme tile).
    readonly property string practiceGrade: PracticeGrade.revision >= 0 ? PracticeGrade.grade(Programme.discipline) : ""
    readonly property var gradeRows: Programme.revision >= 0 ? Programme.entries(Programme.discipline, practiceGrade) : []
    readonly property var gradeIds: gradeRows.filter(r => r.kind === "entry").map(r => r.id)
    readonly property var gradeCounts: Practice.revision >= 0 ? Practice.counts(gradeIds) : [0, 0, 0, 0, 0]

    // The next exam on the calendar (clickdummy: its hint box above the tiles; the courses tile
    // repeats the same text in its hint).
    readonly property var exam: Courses.revision >= 0 ? Courses.nextExam() : ({})

    // The greeting of the day (the clickdummy's start menu).
    readonly property string greeting: {
        const hour = new Date().getHours()
        return hour < 11 ? qsTr("Good morning") : hour < 18 ? qsTr("Good day") : qsTr("Good evening")
    }

    title: "Mitori 見取り"

    // The course tile names the next date, and updates of the video bundles show here: calendar and
    // manifest load when the last load is a few hours old.
    Component.onCompleted: {
        Courses.reload(Courses.Reload.Older)
        Bundles.reload(Bundles.Reload.Older)
    }

    readonly property bool wide: Tablet.wide(width, height)
    readonly property bool tablet: width >= Tablet.minWidth && height >= Tablet.minHeight
    // The tiles grow with a tall page (a tablet), up to this: higher they would read as stretched.
    readonly property real tileMaxHeight: Look.unit(240)

    actions: [
        Kirigami.Action {
            icon.name: "search"
            text: qsTr("Search")
            displayHint: Kirigami.DisplayHint.IconOnly
            onTriggered: page.Kirigami.PageStack.push(Qt.resolvedUrl("SearchPage.qml"))
        },
        Kirigami.Action {
            icon.name: "configure"
            text: qsTr("Settings")
            displayHint: Kirigami.DisplayHint.IconOnly
            onTriggered: page.Kirigami.PageStack.push(Qt.resolvedUrl("ListAndPage.qml"), { listSource: "SettingsPage.qml" })
        }
    ]

    ColumnLayout {
        // On a tablet the page's height at least: the tiles share what the hints leave (Kirigami
        // gives the content only its own height). A phone keeps its tiles.
        height: page.tablet && page.flickable ? Math.max(implicitHeight, page.flickable.height - page.topPadding - page.bottomPadding)
                                              : implicitHeight
        spacing: Kirigami.Units.largeSpacing

        LookEmptyState {
            Layout.fillWidth: true
            visible: Programme.errorString !== ""
            iconName: "data-error"
            title: qsTr("Programme data missing")
            explanation: Programme.errorString
        }

        LookHint {
            Layout.fillWidth: true
            visible: Practice.errorString !== ""
            importance: LookHint.Importance.Error
            titleText: qsTr("Ratings are not saved")
            text: Practice.errorString
        }

        // A new version of a loaded video bundle (its own hint, apart from the app's updates).
        LookHint {
            objectName: "bundleUpdate"
            Layout.fillWidth: true
            visible: Bundles.updates > 0
            importance: LookHint.Importance.Info
            titleText: qsTr("New video version")
            text: qsTr("%n video bundle(s) can be updated.", "", Bundles.updates)

            LookButton {
                text: qsTr("Videos")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
            }
        }

        // A planned exam on the calendar: a hint above the tiles (clickdummy).
        LookHint {
            objectName: "plannedExam"
            Layout.fillWidth: true
            visible: page.exam.course !== undefined && page.exam.course !== null
            importance: LookHint.Importance.Info
            titleText: qsTr("Planned exam")
            text: Grades.examText(page.exam)
        }

        // The greeting of the day (the clickdummy's start menu).
        LookHeading {
            objectName: "greeting"
            Layout.fillWidth: true
            level: 1
            text: page.greeting
        }

        // Two columns on the phone, four on a tablet in landscape (the clickdummy: a grid of
        // tiles, app-entscheidungen.md).
        GridLayout {
            id: tiles

            objectName: "tiles"
            // The small tiles shown (all but the big programme tile).
            readonly property int smallTiles: visibleChildren.length - (programmeTile.visible ? 1 : 0)

            Layout.fillWidth: true
            Layout.fillHeight: true         // the page's height below the hints, to the tiles' maximum
            columns: page.wide ? 4 : 2
            uniformCellHeights: true    // every row as high as the highest, so no tile is smaller
            rowSpacing: Kirigami.Units.largeSpacing
            columnSpacing: Kirigami.Units.largeSpacing

            LookTile {
                id: programmeTile

                objectName: "programmeTile"
                readonly property var current: page.disciplineInfo(Programme.discipline)

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                Layout.columnSpan: page.wide ? 1 : 2    // on the phone over the whole width
                visible: Programme.errorString === ""
                big: true
                glyph: "技"
                text: qsTr("Programme")
                hint: current.title + " · " + current.grade + " · "
                      + qsTr("%1 of %2 exam-ready").arg(page.gradeCounts[4]).arg(page.gradeIds.length)
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ProgrammePage.qml"))
            }

            LookTile {
                objectName: "todayTile"

                readonly property int due: Practice.revision >= 0 && Practice.intervals.length === 4 && Practice.today.getTime() > 0
                                           ? Practice.due(Programme.practiceEntries(Programme.discipline, page.practiceGrade)).length : 0

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                visible: Programme.errorString === ""
                glyph: "稽"
                text: qsTr("Practice today")
                hint: (due > 0 ? qsTr("%n due", "", due) : qsTr("all practised")) + " · " + programmeTile.current.title
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("TodayPage.qml"))
            }

            LookTile {
                objectName: "examTile"

                readonly property string grade: Exam.grade(Programme.discipline, page.practiceGrade)
                readonly property string gradeName: Programme.revision >= 0
                                                    ? (Exam.grades(Programme.discipline).find(g => g.id === grade) || {}).name || "" : ""

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                visible: Programme.errorString === ""
                glyph: "試"
                text: qsTr("Exam mode")
                hint: qsTr("Mock exam %1").arg(gradeName)
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ExamPage.qml"))
            }

            LookTile {
                objectName: "statsTile"

                readonly property int days: Practice.revision >= 0 && Practice.today.getTime() > 0
                                            ? Object.keys(Practice.practisedPerDay(30)).length : 0

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                visible: Programme.errorString === ""
                glyph: "記"
                text: qsTr("Statistics")
                hint: qsTr("%n practice day(s) in 30 days", "", days)
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("StatsPage.qml"))
            }

            LookTile {
                objectName: "coursesTile"

                // Standing alone (no hint box): the next coming date. The hint box above keeps
                // the planned exam; for that, the tile's hint stays the upcoming course.
                readonly property var next: Courses.upcoming.length > 0 ? Courses.upcoming[0] : null
                readonly property int days: next ? Math.max(0, CourseDays.fromToday(next.first)) : 0

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                glyph: "講"
                text: qsTr("Courses")
                hint: !next ? qsTr("Calendar and notebooks")
                            : (next.place || next.title) + " · " + (days > 0 ? qsTr("in %n day(s)", "", days) : qsTr("today"))
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ListAndPage.qml"), { listSource: "CoursesPage.qml" })
            }

            LookTile {
                objectName: "mapTile"
                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                visible: Programme.errorString === ""
                glyph: "図"
                text: qsTr("Technique map")
                hint: qsTr("Attack × technique")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("TechniqueMapPage.qml"))
            }

            LookTile {
                objectName: "glossaryTile"

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                visible: Programme.errorString === ""
                glyph: "辞"
                text: qsTr("Glossary")
                hint: qsTr("Kanji · pronunciation")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("SearchPage.qml"))
            }

            // The Lernpakete: video bundles with techniques of their own (not part of any exam). Only
            // with a package: before its code the app shows nothing of them.
            LookTile {
                objectName: "lessonsTile"

                readonly property int techniques: Library.packages.reduce((sum, p) => sum + p.count, 0)

                Layout.fillWidth: true
                Layout.preferredWidth: 1          // equal columns
                Layout.maximumHeight: page.tileMaxHeight
                // Last of an odd number of small tiles on the phone: over both columns, no gap.
                Layout.columnSpan: !page.wide && tiles.smallTiles % 2 === 1 ? 2 : 1
                visible: Library.packages.length > 0
                glyph: "学"
                text: qsTr("Learning videos")
                hint: qsTr("%n package(s)", "", Library.packages.length) + " · " + qsTr("%n technique(s)", "", techniques)
                // Beside its package on a tablet.
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ListAndPage.qml"), { listSource: "LessonsPage.qml" })
            }
        }

        // What the tiles' maximum leaves goes below them, not between the hints and the tiles.
        Item {
            Layout.fillHeight: true
            Layout.preferredHeight: 0
        }
    }

    // A discipline's short name (`title`: "Aikido") and the name of its practice grade.
    function disciplineInfo(id) {
        const d = Programme.disciplines.find(x => x.id === id)
        if (!d) {
            return { title: "", grade: "" }
        }
        const gradeId = PracticeGrade.revision >= 0 ? PracticeGrade.grade(id) : ""
        const g = d.grade.find(x => x.id === gradeId)
        return { title: d.kurzname, grade: g ? g.name : "" }
    }
}
