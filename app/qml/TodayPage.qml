pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "playlists.js" as Playlists
import "grades.js" as Grades

// Today's practice (clickdummy "Heute üben"): one discipline per session, up to the practice
// grade (from "My grades" or chosen here). Due is what is unsure or long unpractised (days per level, set
// below), and up to two new techniques of the current grade. "Start training" plays them.
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    property string discipline: Programme.discipline
    readonly property var disciplineInfo: Programme.disciplines.find(d => d.id === discipline) || ({})
    readonly property var grades: Programme.grades(discipline)
    readonly property string grade: PracticeGrade.revision >= 0 ? PracticeGrade.grade(discipline) : ""
    readonly property bool manualGrade: PracticeGrade.revision >= 0 && PracticeGrade.manual(discipline)
    readonly property bool anyPassed: Courses.revision >= 0 && Courses.ladder(discipline).some(g => g.passed)
    readonly property string gradeName: (grades.find(g => g.id === grade) || {}).name || ""
    // The calendar of the last 12 weeks (clickdummy "Heute"); the levels as in the statistics.
    readonly property var perDay: Practice.revision >= 0 && Practice.today.getTime() > 0 ? Practice.practisedPerDay(84) : ({})
    // Re-read after every rating and when the intervals change.
    readonly property var due: Practice.revision >= 0 && Practice.intervals.length === 4 && Practice.today.getTime() > 0
                               ? Practice.due(Programme.practiceEntries(discipline, grade)) : []
    readonly property int unsure: due.filter(r => r.level === 1 || r.level === 2).length
    readonly property int longAgo: due.filter(r => r.level >= 3).length
    readonly property int fresh: due.filter(r => r.level === 0).length
    // The due ones with a video on the device; the hint counts the others (a card in the training).
    readonly property var playable: due.filter(r => !!r.video && Videos.available(r.video.video))
    // An exam planned in this discipline (Courses): its hint leads to the mock exam.
    readonly property var exam: Courses.revision >= 0 ? Courses.nextExam(discipline) : ({})
    // The due rows and the interval fields are made (they come after the page is drawn).
    readonly property bool built: below.status === Loader.Ready

    // On a tablet sideways: two columns in a page of its own width, in the middle.
    readonly property TypingHold hold: TypingHold { target: page }
    readonly property bool wide: hold.wide
    leftPadding: wide ? Tablet.sidePadding(width, padding) : padding
    rightPadding: leftPadding

    title: qsTr("Practice today")

    function reason(row) {
        if (row.level === 0) {
            return qsTr("new in %1").arg(row.gradeName)
        }
        if (row.level <= 2) {
            return qsTr("%1 · %n day(s) ago", "", row.days).arg(Practice.levelNames[row.level])
        }
        return qsTr("not practised for %n day(s)", "", row.days)
    }

    function openSheet(entry) {
        sheetLoader.active = true
        const sheet = sheetLoader.item as TechniqueSheet
        sheet.entry = entry
        sheet.playable = !!entry.video && Videos.available(entry.video.video)
        sheet.open()
    }

    // Every due technique; one without a video on the device shows as a card in the player. What
    // was rated today is not due: a training done today has nothing to open again.
    function startTraining() {
        const playlist = page.due
        if (playlist.length === 0) {
            return
        }
        const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
        window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), { playlist: playlist, index: 0, training: true })
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        LookSectionLabel {
            text: qsTr("Today I practise")
        }
        LookSegmented {
            Layout.fillWidth: true
            model: Programme.disciplines.map(d => d.kurzname)
            currentIndex: Programme.disciplines.findIndex(d => d.id === page.discipline)
            onActivated: index => page.discipline = Programme.disciplines[index].id
            Accessible.name: qsTr("Discipline")
        }
        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.grades

                LookChip {
                    required property var modelData

                    objectName: "practice_" + modelData.id
                    text: modelData.name
                    checkable: true
                    choice: true        // the page holds the grade: a tap only reports it
                    checked: modelData.id === page.grade
                    onClicked: PracticeGrade.setGrade(page.discipline, modelData.id)
                }
            }
        }
        LookLabel {
            objectName: "practiceGradeHint"
            Layout.fillWidth: true
            text: page.manualGrade ? qsTr("up to %1 (chosen by you)").arg(page.gradeName)
                  : page.anyPassed ? qsTr("up to %1 (from My grades)").arg(page.gradeName)
                                   : qsTr("up to %1 (first grade, nothing for this discipline in My grades yet)").arg(page.gradeName)
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }
        // Made only with an exam planned: most days there is none.
        Loader {
            Layout.fillWidth: true
            active: !!page.exam.course
            visible: active

            sourceComponent: LookHint {
                objectName: "plannedHint"
                compact: true
                importance: LookHint.Importance.Important
                titleText: page.exam.course ? Grades.examText(page.exam) : ""
                meta: page.exam.place || page.exam.title || ""

                LookButton {
                    objectName: "toMockExam"
                    // Only for a grade the exam mode has material for (not Shinki Toho Hon-Menkyo).
                    visible: !!page.exam.course && Exam.grades(page.exam.discipline).some(g => g.id === page.exam.grade)
                    text: qsTr("Mock exam")
                    onClicked: {
                        Programme.discipline = page.exam.discipline
                        PracticeGrade.setGrade(page.exam.discipline, page.exam.grade)
                        page.Kirigami.PageStack.push(Qt.resolvedUrl("ExamPage.qml"))
                    }
                }
            }
        }

        // What is due and the way to it; beside it the practice days.
        TwoColumns {
            wide: page.wide

            ColumnLayout {
                objectName: "dueLeft"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.largeSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    LookKpi {
                        objectName: "dueCount"
                        value: String(page.due.length)
                        label: qsTr("techniques due")
                    }
                    LookLabel {
                        Layout.fillWidth: true
                        text: page.due.length === 0 ? qsTr("Everything is practised for today.")
                              : qsTr("%1 unsure · %2 long ago · %3 new").arg(page.unsure).arg(page.longAgo).arg(page.fresh)
                        color: Look.mutedTextColor
                        wrapMode: Text.Wrap
                    }
                }
                LookButton {
                    objectName: "startTraining"
                    visible: page.due.length > 0
                    role: LookButton.Role.Primary
                    icon.name: "media-playback-start"
                    text: qsTr("Start training")
                    onClicked: page.startTraining()
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: page.due.length > 0 && page.playable.length < page.due.length
                    text: qsTr("%n of them without a video on this device: the training shows their name, practise from memory.", "", page.due.length - page.playable.length)
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }
            ColumnLayout {
                objectName: "dueRight"
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.largeSpacing

                LookCalendarHeatmap {
                    objectName: "todayHeatmap"
                    weeks: 12
                    levels: {
                        const bounds = [1, 3, 6, 10]
                        const l = {}
                        for (const d in page.perDay) {
                            l[d] = bounds.filter(b => page.perDay[d] >= b).length
                        }
                        return l
                    }
                    // A text per count, not per day.
                    tips: {
                        const t = {}
                        const texts = {}
                        for (const d in page.perDay) {
                            const n = page.perDay[d]
                            if (!(n in texts)) {
                                texts[n] = qsTr("%n technique(s)", "", n)
                            }
                            t[d] = texts[n]
                        }
                        return t
                    }
                    Accessible.name: qsTr("Practice days of the last 12 weeks")
                }
                LookLegend {
                    objectName: "todayLegend"
                    Layout.fillWidth: true
                    model: [{ color: Look.levelColor(0), text: qsTr("no practice") },
                            { color: Look.levelColor(1), text: qsTr("1–2 techniques") },
                            { color: Look.levelColor(2), text: "3–5" },
                            { color: Look.levelColor(3), text: "6–9" },
                            { color: Look.levelColor(4), text: qsTr("10 and more") }]
                }
            }
        }

        // Below the first screen on a phone: made after the page is drawn, a part each frame,
        // so the page comes at once (with five years of use about half of its time).
        Loader {
            id: below

            Layout.fillWidth: true
            asynchronous: true

            sourceComponent: ColumnLayout {
                spacing: Kirigami.Units.largeSpacing

                LookSectionLabel {
                    visible: page.due.length > 0
                    text: qsTr("Due")
                }
                Repeater {
                    model: page.due

                    LookListRow {
                        id: dueRow

                        required property var modelData

                        objectName: "dueRow"
                        Layout.fillWidth: true
                        leadingText: modelData.nr ? String(modelData.nr) : ""
                        text: modelData.title
                        subtitle: [modelData.attack, page.reason(modelData)].filter(x => x).join(" · ")
                        onClicked: page.openSheet(dueRow.modelData)
                        trailing: LookLevelDots {
                            value: dueRow.modelData.level
                            names: Practice.levelNames
                            color: Look.levelColor(dueRow.modelData.level)
                        }
                    }
                }

                LookSectionLabel {
                    text: qsTr("Intervals · days until due again")
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.wide ? 4 : 2
                    columnSpacing: Kirigami.Units.largeSpacing

                    Repeater {
                        model: 4

                        ColumnLayout {
                            id: interval

                            required property int index

                            LookLabel {
                                text: (interval.index + 1) + " " + Practice.levelNames[interval.index + 1]
                                color: Look.mutedTextColor
                            }
                            LookSpinBox {
                                objectName: "intervalDays"
                                from: 1
                                to: 365
                                value: Practice.intervals[interval.index]
                                editable: true
                                Accessible.name: qsTr("Days for %1").arg(Practice.levelNames[interval.index + 1])
                                onValueModified: {
                                    const days = Practice.intervals.slice()
                                    days[interval.index] = value
                                    Practice.intervals = days
                                }
                            }
                        }
                    }
                }
                LookLabel {
                    Layout.fillWidth: true
                    text: qsTr("New techniques of the current grade come on top, at most two a day.")
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }
        }
    }

    // Made at the first tap on a row.
    Loader {
        id: sheetLoader

        active: false

        sourceComponent: TechniqueSheet {
            id: sheet

            objectName: "techniqueSheet"
            onPlayRequested: entry => {
                sheet.close()
                const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
                window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), Playlists.around(Programme, Videos, Library, entry))
            }
            onCommentRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("CommentPage.qml"), { entry: entry })
            onNotesRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), { entry: entry })
            onVideosRequested: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
        }
    }
}
