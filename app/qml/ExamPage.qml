pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "grades.js" as Grades

// Exam mode, settings (clickdummy "Prüfungsmodus"): discipline and grade (the practice grade),
// how many points, in which order, and whether samples from earlier grades come first. The
// settings are kept; "Start round" shows the points one by one (ExamRoundPage).
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    readonly property string discipline: Programme.discipline
    readonly property var grades: Exam.grades(discipline)
    readonly property string grade: PracticeGrade.revision >= 0 ? Exam.grade(discipline, PracticeGrade.grade(discipline)) : ""
    readonly property var gradeInfo: grades.find(g => g.id === grade) || ({})
    readonly property string gradeName: gradeInfo.name || ""
    readonly property int size: gradeInfo.count || 0
    readonly property var counts: Exam.countChoices(size)
    // A stored count the grade does not reach means all.
    readonly property int countIndex: Math.max(0, counts.indexOf(Exam.count))
    readonly property bool hasEarlier: Exam.hasEarlier(discipline, grade)
    // An exam planned in this discipline (Courses): its grade is a tap away.
    readonly property var exam: Courses.revision >= 0 ? Courses.nextExam(discipline) : ({})
    readonly property var lastRound: Practice.revision >= 0 ? Practice.rounds(discipline, 1)[0] : undefined

    title: qsTr("Exam mode")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    function averageText(value) {
        return Number(value).toLocaleString(Qt.locale(), "f", 1)
    }

    function start() {
        const points = Exam.draw(page.discipline, page.grade)
        if (points.length === 0) {
            return
        }
        page.Kirigami.PageStack.push(Qt.resolvedUrl("ExamRoundPage.qml"),
                                     { points: points, discipline: page.discipline, grade: page.grade })
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        LookSegmented {
            Layout.fillWidth: true
            model: Programme.disciplines.map(d => d.kurzname)
            currentIndex: Programme.disciplines.findIndex(d => d.id === page.discipline)
            onActivated: index => Programme.discipline = Programme.disciplines[index].id
            Accessible.name: qsTr("Discipline")
        }

        LookHint {
            objectName: "plannedHint"
            Layout.fillWidth: true
            visible: !!page.exam.course
            compact: true
            wrapTitle: true
            importance: LookHint.Importance.Important
            titleText: page.exam.course ? qsTr("Planned: %1").arg(Grades.examText(page.exam)) : ""
            meta: page.exam.place || page.exam.title || ""

            LookButton {
                objectName: "toExamGrade"
                // Only for a grade with material (Exam.grade falls back to the first one otherwise).
                visible: page.exam.grade !== page.grade && page.grades.some(g => g.id === page.exam.grade)
                text: qsTr("This grade")
                onClicked: PracticeGrade.setGrade(page.discipline, page.exam.grade)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.grades

                LookChip {
                    required property var modelData

                    objectName: "grade_" + modelData.id
                    text: modelData.name + " · " + qsTr("%n point(s)", "", modelData.count)
                    checkable: true
                    choice: true        // the page holds the grade: a tap only reports it
                    checked: modelData.id === page.grade
                    onClicked: PracticeGrade.setGrade(page.discipline, modelData.id)
                }
            }
        }

        LookSettingRow {
            Layout.fillWidth: true
            section: qsTr("Mock exam %1").arg(page.gradeName)
            title: qsTr("Points from the %1").arg(page.gradeName)

            LookSegmented {
                objectName: "countChoice"
                model: page.counts.map(n => n === 0 ? qsTr("all %1").arg(page.size) : String(n))
                currentIndex: page.countIndex
                onActivated: index => Exam.count = page.counts[index]
                Accessible.name: qsTr("Number of points")
            }
        }
        LookSettingRow {
            Layout.fillWidth: true
            title: qsTr("Random order")
            narrow: false       // a switch stays at the right, also on a small phone
            hint: qsTr("off: as in the exam programme")

            LookSwitch {
                objectName: "shuffledSwitch"
                checked: Exam.shuffled
                onToggled: Exam.shuffled = checked
                Accessible.name: qsTr("Random order")
            }
        }
        LookSettingRow {
            Layout.fillWidth: true
            title: qsTr("Techniques from earlier grades")
            narrow: false       // a switch stays at the right, also on a small phone
            hint: page.hasEarlier ? qsTr("2–5 samples, always first") : qsTr("first grade, none before")

            LookSwitch {
                objectName: "samplesSwitch"
                enabled: page.hasEarlier
                checked: Exam.samples && page.hasEarlier
                onToggled: Exam.samples = checked
                Accessible.name: qsTr("Techniques from earlier grades")
            }
        }

        LookLabel {
            objectName: "examHint"
            Layout.fillWidth: true
            text: qsTr("Only what is asked is shown (for Shinki Toho only the technique): no video, no time limit. At the end you rate each technique; that sets its rating and goes into the statistics.")
                  + (page.lastRound ? " " + qsTr("Last round: %1, average %2.")
                                                .arg(page.lastRound.at.toLocaleDateString(Qt.locale(), Locale.ShortFormat))
                                                .arg(page.averageText(page.lastRound.average)) : "")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }

        LookButton {
            objectName: "startRound"
            enabled: page.size > 0
            role: LookButton.Role.Primary
            icon.name: "media-playback-start"
            text: qsTr("Start round")
            onClicked: page.start()
        }
    }
}
