pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "coursedays.js" as CourseDays
import "grades.js" as Grades
import "playlists.js" as Playlists

// Start menu (clickdummy "Startmenü", variant C "Bento"): tiles of different sizes; the programme
// tile is always twice as wide and twice as high as the others. The tiles show what is theirs (the
// next technique, what is due, the exam's countdown, the last days ...). What they show comes from
// StartBoard, worked out off the GUI thread: the page draws at once, each tile fills in a moment later.
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's,
    // and the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    // The mark of the app and the small caps line (the head shows them; the other pages have
    // the way back instead).
    readonly property string headLogo: "神氣"

    readonly property string practiceGrade: PracticeGrade.revision >= 0 ? PracticeGrade.grade(Programme.discipline) : ""
    // What the tiles show, by tile (StartBoard).
    readonly property var board: StartBoard.tiles

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
    readonly property real gap: Kirigami.Units.largeSpacing
    // The smallest height of a cell: what the tiles of one cell need (the programme tile's two cells
    // and the gap between), and a floor, so that the tiles do not jump when their content arrives.
    readonly property real cellNeed: Math.max.apply(null, [Look.unit(120), (programmeTile.implicitHeight - gap) / 2]
                                                    .concat(smallTiles.filter(t => t.visible).map(t => t.implicitHeight)))
    // The rows of the grid: the programme tile's two, today's, and the others by the columns.
    readonly property int gridRows: {
        const others = smallTiles.filter(t => t.visible && t !== todayTile).length
        return wide ? 3 + (lessonsTile.visible ? 1 : 0) : 3 + Math.ceil(others / 2)
    }
    // A tablet gives its height to the tiles, to the maximum; a phone keeps what they need.
    readonly property real cellHeight: {
        if (!tablet || !flickable) {
            return cellNeed
        }
        const free = flickable.height - topPadding - bottomPadding - head.height - column.spacing
        return Math.max(cellNeed, Math.min(tileMaxHeight, (free - (gridRows - 1) * gap) / gridRows))
    }
    readonly property var smallTiles: [todayTile, examTile, statsTile, coursesTile, mapTile, glossaryTile, notesTile, lessonsTile]

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

    // Today's training, as the Today page starts it: every due technique, one after the other.
    function startTraining() {
        const playlist = Practice.due(Programme.practiceEntries(Programme.discipline, practiceGrade))
        if (playlist.length === 0) {
            return
        }
        page.Kirigami.PageStack.push(Qt.resolvedUrl("PlayerPage.qml"), { playlist: playlist, index: 0, training: true })
    }

    // The technique the programme tile leads to, in its player.
    function openTechnique(id) {
        const entry = Programme.entry(id)
        if (!entry.id) {
            return
        }
        page.Kirigami.PageStack.push(Qt.resolvedUrl("PlayerPage.qml"), Playlists.around(Programme, Videos, Library, entry))
    }

    ColumnLayout {
        id: column

        spacing: Kirigami.Units.largeSpacing

        ColumnLayout {
            id: head

            Layout.fillWidth: true
            spacing: column.spacing

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

            // The greeting of the day (the clickdummy's start menu).
            LookHeading {
                objectName: "greeting"
                Layout.fillWidth: true
                level: 1
                text: page.greeting
            }
        }

        // Two columns on the phone, four on a tablet in landscape. The programme tile takes two
        // columns and two rows, today's practice two columns; every cell is as high as the next.
        GridLayout {
            id: tiles

            objectName: "tiles"
            // The small tiles shown (all but the big programme tile).
            readonly property int smallTiles: visibleChildren.length - (programmeTile.visible ? 1 : 0)

            Layout.fillWidth: true
            columns: page.wide ? 4 : 2
            uniformCellWidths: true
            rowSpacing: page.gap
            columnSpacing: page.gap

            StartTile {
                id: programmeTile

                objectName: "programmeTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.programme || ({})
                readonly property var current: page.disciplineInfo(Programme.discipline)

                Layout.columnSpan: 2
                Layout.rowSpan: 2
                visible: Programme.errorString === ""
                big: true
                titleOnTop: true
                stretch: true
                filled: !!t.ready
                glyph: "技"
                text: qsTr("Programme")
                subtitle: current.title
                hint: current.title + " · " + current.grade
                      + (filled ? " · " + qsTr("%1 of %2 exam-ready").arg(t.exam).arg(t.total) : "")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ProgrammePage.qml"))

                // Top right, under the title: how many techniques sit, as a figure.
                aside: [
                    LookLabel {
                        objectName: "sureNumber"
                        Layout.alignment: Qt.AlignRight
                        text: String(programmeTile.t.sure || 0)
                        font: Look.headingFont(programmeTile.base * 3.2)
                    },
                    LookLabel {
                        Layout.alignment: Qt.AlignRight
                        text: qsTr("of %1 sure").arg(programmeTile.t.total || 0)
                        color: Look.mutedTextColor
                    }
                ]

                // Above the stand: where to go on (a tap leads to it), set off by a rule.
                Item {
                    Layout.fillHeight: true
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    visible: !!programmeTile.t.next
                    color: Look.ruleColor
                }
                Item {
                    id: next

                    objectName: "nextTechnique"
                    readonly property var technique: programmeTile.t.next

                    Layout.fillWidth: true
                    Layout.preferredHeight: nextRow.implicitHeight
                    visible: !!technique
                    Accessible.role: Accessible.Button
                    Accessible.name: nextText.text
                    Accessible.onPressAction: page.openTechnique(technique.id)

                    RowLayout {
                        id: nextRow

                        width: parent.width
                        spacing: Look.unit(8)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            LookKicker {
                                Layout.fillWidth: true
                                text: qsTr("Continue with")
                            }
                            LookLabel {
                                id: nextText

                                Layout.fillWidth: true
                                text: next.technique ? next.technique.title + (next.technique.attack ? " · " + next.technique.attack : "") : ""
                                font: Look.headingFont(programmeTile.base * 1.7)
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                        LookLabel {
                            text: qsTr("Open ›")
                            color: Look.accentColor
                            font.bold: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: page.openTechnique(next.technique.id)
                    }
                }
                // The stand at the bottom: the grades, the levels of everything up to the practice
                // grade in one bar, and in words.
                Flow {
                    objectName: "gradeLadder"
                    Layout.fillWidth: true
                    spacing: Look.unit(3)

                    Repeater {
                        model: programmeTile.t.ladder || []

                        Rectangle {
                            id: step

                            required property var modelData
                            readonly property bool current: modelData.state === "current"
                            readonly property bool done: modelData.state === "done"

                            width: Math.max(Look.unit(26), stepName.implicitWidth + Look.unit(10))
                            height: Look.unit(20)
                            color: current ? Look.accentColor : done ? Look.selectedColor : "transparent"
                            border.width: current || done ? 0 : 1
                            border.color: Look.ruleColor

                            LookLabel {
                                id: stepName

                                anchors.centerIn: parent
                                text: step.modelData.name
                                font: Look.smallFont
                                color: step.current ? Look.onAccentColor : step.done ? Look.textColor : Look.mutedTextColor
                            }
                        }
                    }
                }
                LookProgressBar {
                    objectName: "levelBar"
                    Layout.fillWidth: true
                    parts: {
                        const t = programmeTile.t
                        if (!t.counts || t.total === 0) {
                            return []
                        }
                        return [4, 3, 2, 1].map(level => ({
                            value: t.counts[level] / t.total,
                            color: Look.levelColor(level),
                            text: Practice.levelNames[level] + ": " + t.counts[level]
                        }))
                    }
                }
                LookLabel {
                    objectName: "levelText"
                    Layout.fillWidth: true
                    text: qsTr("up to %1 · %2 of %3 sure · %4 exam-ready")
                          .arg(programmeTile.t.gradeName).arg(programmeTile.t.sure).arg(programmeTile.t.total).arg(programmeTile.t.exam)
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }

            StartTile {
                id: todayTile

                objectName: "todayTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.today || ({})
                readonly property int due: t.due || 0

                Layout.columnSpan: 2
                visible: Programme.errorString === ""
                filled: !!t.ready
                showHint: false
                glyph: "稽"
                text: qsTr("Practice today")
                hint: (filled ? (due > 0 ? qsTr("%n due", "", due) : qsTr("all practised")) + " · " : "") + programmeTile.current.title
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("TodayPage.qml"))

                // Top right: the number due, as large as a heading, and what it is made of.
                aside: [
                    LookLabel {
                        objectName: "dueNumber"
                        Layout.alignment: Qt.AlignRight
                        text: String(todayTile.due)
                        font: Look.headingFont(todayTile.base * 3.2)
                    },
                    LookLabel {
                        objectName: "dueText"
                        Layout.alignment: Qt.AlignRight
                        text: todayTile.due > 0 ? qsTr("%1 unsure · %2 new").arg(todayTile.t.unsure).arg(todayTile.t.fresh)
                                                : qsTr("all practised")
                        color: Look.mutedTextColor
                    }
                ]
                // Bottom right: the way into the training.
                corner: LookButton {
                    objectName: "startTraining"
                    visible: todayTile.due > 0
                    role: LookButton.Role.Primary
                    icon.name: "media-playback-start"
                    text: qsTr("Start training")
                    onClicked: page.startTraining()
                }
            }

            StartTile {
                id: examTile

                objectName: "examTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.exam || ({})
                readonly property bool planned: !!t.planned
                readonly property int days: t.days || 0
                readonly property int percent: Math.round((t.share || 0) * 100)

                visible: Programme.errorString === ""
                filled: !!t.ready
                glyph: "試"
                text: qsTr("Exam mode")
                hint: filled ? qsTr("Mock exam %1").arg(t.mock) : ""
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ExamPage.qml"))

                // The planned exam on the calendar: its countdown, and how much of it is sure.
                RowLayout {
                    objectName: "examCountdown"
                    Layout.fillWidth: true
                    visible: examTile.planned
                    spacing: Look.unit(10)

                    StartRing {
                        objectName: "examRing"
                        Layout.preferredWidth: Look.unit(52)
                        Layout.preferredHeight: Look.unit(52)
                        value: examTile.t.share || 0
                        label: qsTr("%1 %").arg(examTile.percent)
                        Accessible.name: qsTr("%1 % of the exam's techniques sure or better").arg(examTile.percent)
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        LookLabel {
                            objectName: "examDays"
                            Layout.fillWidth: true
                            text: examTile.days > 0 ? qsTr("in %n day(s)", "", examTile.days) : qsTr("today")
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                        LookLabel {
                            Layout.fillWidth: true
                            text: examTile.t.name || ""
                            font: Look.smallFont
                            color: Look.mutedTextColor
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: !examTile.planned
                    text: qsTr("No exam planned")
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }

            StartTile {
                id: statsTile

                objectName: "statsTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.stats || ({})
                readonly property int days: t.days || 0

                visible: Programme.errorString === ""
                filled: !!t.ready
                glyph: "記"
                text: qsTr("Statistics")
                hint: qsTr("%n practice day(s) in 30 days", "", days)
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("StatsPage.qml"))

                StartDays {
                    objectName: "statsDays"
                    Layout.fillWidth: true
                    Layout.preferredHeight: implicitHeight
                    counts: statsTile.t.cells || []
                }
                LookLabel {
                    objectName: "statsStreak"
                    Layout.fillWidth: true
                    text: qsTr("%n day(s) in a row", "", statsTile.t.streak || 0)
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                LookLabel {
                    Layout.fillWidth: true
                    text: qsTr("%n technique(s)", "", statsTile.t.techniques || 0)
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }

            StartTile {
                id: coursesTile

                objectName: "coursesTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.courses || ({})
                readonly property bool has: !!t.has
                readonly property int days: t.days || 0

                filled: !!t.ready
                showHint: !has
                glyph: "講"
                text: qsTr("Courses")
                hint: !filled || !has ? qsTr("Calendar and notebooks")
                                      : (t.place || t.title) + " · " + (days > 0 ? qsTr("in %n day(s)", "", days) : qsTr("today"))
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ListAndPage.qml"), { listSource: "CoursesPage.qml" })

                // The next date, its title and teacher, and what the notebook holds so far.
                LookLabel {
                    objectName: "courseDate"
                    Layout.fillWidth: true
                    visible: coursesTile.has
                    text: coursesTile.has ? Grades.shortDate(coursesTile.t.first) + " · "
                                            + (coursesTile.days > 0 ? qsTr("in %n day(s)", "", coursesTile.days) : qsTr("today")) : ""
                    font: Look.smallFont
                    color: Look.accentColor
                    wrapMode: Text.Wrap
                }
                LookLabel {
                    objectName: "courseTitle"
                    Layout.fillWidth: true
                    visible: coursesTile.has
                    text: coursesTile.t.title || ""
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: coursesTile.has && !!coursesTile.t.teacher
                    text: coursesTile.t.teacher || ""
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    elide: Text.ElideRight
                }
                LookLabel {
                    objectName: "courseEntries"
                    Layout.fillWidth: true
                    visible: coursesTile.has && (coursesTile.t.entries || 0) >= 0
                    text: qsTr("%n note(s) in the notebook", "", coursesTile.t.entries || 0)
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }

            StartTile {
                id: mapTile

                objectName: "mapTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.map || ({})

                visible: Programme.errorString === ""
                stretch: true
                filled: !!t.ready
                glyph: "図"
                text: qsTr("Technique map")
                hint: qsTr("Attack × technique")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("TechniqueMapPage.qml"))

                StartMap {
                    objectName: "mapMiniature"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Look.unit(30)
                    levels: mapTile.t.levels || []
                    columns: mapTile.t.columns || 0
                }
            }

            StartTile {
                id: glossaryTile

                objectName: "glossaryTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.glossary || ({})

                visible: Programme.errorString === ""
                filled: !!t.ready
                glyph: "辞"
                text: qsTr("Glossary")
                hint: qsTr("Kanji · pronunciation")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("SearchPage.qml"))

                // The word of the day.
                LookLabel {
                    objectName: "wordKanji"
                    Layout.fillWidth: true
                    text: glossaryTile.t.jp || ""
                    font: Look.japaneseFont(Look.titleFont(glossaryTile.base * 1.8))
                    elide: Text.ElideRight
                }
                LookLabel {
                    objectName: "wordName"
                    Layout.fillWidth: true
                    text: glossaryTile.t.word || ""
                    font.bold: true
                    elide: Text.ElideRight
                }
                LookLabel {
                    Layout.fillWidth: true
                    text: glossaryTile.t.meaning || ""
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            StartTile {
                id: notesTile

                objectName: "notesTile"
                cellHeight: page.cellHeight
                readonly property var t: page.board.notes || ({})
                readonly property int count: (t.techniques || 0) + (t.courses || 0)

                visible: Programme.errorString === ""
                filled: !!t.ready
                glyph: "帳"
                text: qsTr("Notes")
                hint: qsTr("Technique notes and notebooks")
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("AllNotesPage.qml"))

                // The latest note: its day and first words, and how many there are.
                LookLabel {
                    objectName: "noteDate"
                    Layout.fillWidth: true
                    visible: notesTile.count > 0
                    text: notesTile.count > 0 ? notesTile.t.at.toLocaleDateString(Qt.locale(), Locale.ShortFormat) : ""
                    font: Look.smallFont
                    color: Look.accentColor
                }
                LookLabel {
                    objectName: "noteText"
                    Layout.fillWidth: true
                    visible: notesTile.count > 0
                    text: notesTile.t.text || (notesTile.t.media ? qsTr("Photo or voice note") : "")
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                LookLabel {
                    objectName: "noteCount"
                    Layout.fillWidth: true
                    text: notesTile.count > 0 ? qsTr("%n note(s)", "", notesTile.count) : qsTr("No notes yet")
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }

            // The Lernpakete: video bundles with techniques of their own (not part of any exam). Only
            // with a package: before its code the app shows nothing of them.
            StartTile {
                id: lessonsTile

                objectName: "lessonsTile"
                cellHeight: page.cellHeight
                readonly property int techniques: Library.packages.reduce((sum, p) => sum + p.count, 0)

                // Last of an odd number of small tiles on the phone: over both columns, no gap.
                Layout.columnSpan: !page.wide && (tiles.smallTiles - 1) % 2 === 1 ? 2 : 1
                visible: Library.packages.length > 0
                filled: true
                glyph: "学"
                text: qsTr("Learning videos")
                hint: qsTr("%n package(s)", "", Library.packages.length) + " · " + qsTr("%n technique(s)", "", techniques)
                // Beside its package on a tablet.
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("ListAndPage.qml"), { listSource: "LessonsPage.qml" })
            }
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
