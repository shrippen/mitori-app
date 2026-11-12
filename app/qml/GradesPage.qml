pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "coursedays.js" as CourseDays
import "grades.js" as Grades

// My grades (clickdummy "Meine Grade"): per discipline the grades passed with day and place, the
// next grade with its waiting time (from the programme data, Shinki Toho Shoden from the start of
// training) and a planned exam. They are the
// ground for the waiting times on a course and the hints before an exam.
//
//   AIKIDO · last 4. Kyu
//   4. Kyu        09.03.25 · Mainz                         [×]
//   Next: 3. Kyu · from 09.03.26 · planned: Bonn, 12.06.26
//   [3. Kyu ▾] [2026-11-02] [Place      ] [Add]
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    readonly property var grades: Courses.revision >= 0 ? Courses.grades : []

    // On a tablet sideways: two columns in a page of its own width, in the middle.
    readonly property TypingHold hold: TypingHold { target: page }
    readonly property bool wide: hold.wide
    leftPadding: wide ? Tablet.sidePadding(width, padding) : padding
    rightPadding: leftPadding

    title: qsTr("My grades")

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        LookLabel {
            Layout.fillWidth: true
            visible: Courses.errorString !== ""
            text: Courses.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }

        TwoColumns {
            wide: page.wide

            Repeater {
                model: Programme.disciplines

                ColumnLayout {
                    id: block

                    required property var modelData
                    readonly property string discipline: modelData.id
                    readonly property var passed: page.grades.filter(g => g.discipline === discipline)
                    // The highest grade passed (by rank, not by day: a day may be entered later).
                    readonly property var highest: ladder.filter(g => g.passed).pop()
                    readonly property var ladder: Courses.revision >= 0 ? Courses.ladder(discipline) : []
                    readonly property string next: Courses.revision >= 0 ? Courses.nextGrade(discipline) : ""
                    readonly property var exam: Courses.revision >= 0 ? Courses.nextExam(discipline) : ({})

                    objectName: "grades_" + discipline
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: Kirigami.Units.smallSpacing

                    LookSectionLabel {
                        objectName: "gradesHeading"
                        Layout.fillWidth: true
                        rule: true
                        text: block.modelData.kurzname + " · "
                              + (block.highest ? qsTr("last %1").arg(block.highest.name) : qsTr("no grade yet"))
                    }

                    Repeater {
                        model: block.passed

                        LookListRow {
                            id: passedRow

                            required property var modelData

                            objectName: "passedRow"
                            Layout.fillWidth: true
                            text: modelData.name
                            subtitle: [Grades.shortDate(modelData.day), modelData.place].filter(x => x).join(" · ")
                            trailing: LookToolButton {
                                objectName: "removeGrade"
                                icon.name: "edit-delete"
                                text: qsTr("Remove %1").arg(passedRow.modelData.name)
                                display: QQC2.AbstractButton.IconOnly
                                onClicked: Courses.removeGrade(passedRow.modelData.uid)
                            }
                        }
                    }

                    // Where a waiting time counts from the start of training (Shinki Toho Shoden): its day,
                    // saved as it is typed or picked; emptied, it goes.
                    RowLayout {
                        Layout.fillWidth: true
                        visible: Courses.countsFromStart(block.discipline)

                        LookLabel {
                            text: qsTr("Training since:")
                        }
                        LookDateField {
                            id: startField

                            // The saved day; a pick sets `date` itself, so the binding comes back after
                            // it (a sync or a failed save shows the day that counts).
                            function saved() {
                                const day = Courses.revision >= 0 ? Courses.trainingStart(block.discipline) : ""
                                return day ? CourseDays.day(day) : null
                            }

                            objectName: "trainingStart"
                            format: qsTr("yyyy-MM-dd", "date format")
                            dayNames: [qsTr("MO"), qsTr("TU"), qsTr("WE"), qsTr("TH"), qsTr("FR"), qsTr("SA"), qsTr("SU")]
                            todayText: qsTr("Today")
                            date: saved()
                            Accessible.name: qsTr("Start of training")
                            onDateEdited: day => {
                                Courses.setTrainingStart(block.discipline, day ? CourseDays.iso(day) : "")
                                startField.date = Qt.binding(() => startField.saved())
                            }
                        }
                    }

                    LookLabel {
                        objectName: "nextGrade"
                        Layout.fillWidth: true
                        visible: block.next !== ""
                        text: {
                            if (block.next === "") {
                                return ""
                            }
                            const name = (block.ladder.find(g => g.id === block.next) || {}).name || ""
                            const parts = [qsTr("Next: %1").arg(name), Grades.waitText(Courses.waiting(block.discipline, block.next))]
                            if (block.exam.course) {
                                parts.push(qsTr("planned: %1, %2").arg(block.exam.place || block.exam.title).arg(Grades.shortDate(block.exam.first)))
                            }
                            return parts.join(" · ")
                        }
                        color: Look.mutedTextColor
                        wrapMode: Text.Wrap
                    }

                    // A passed grade: the next one is chosen, today's day; with all passed none (the
                    // same grade again would overwrite its day).
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        // Grade and day fill the row, place and "Add" the next: the edges stand flush.
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            LookComboBox {
                                id: gradeBox

                                objectName: "gradeBox"
                                model: block.ladder.map(g => g.name)
                                currentIndex: block.ladder.findIndex(g => g.id === block.next)
                                Accessible.name: qsTr("Grade")
                            }
                            LookDateField {
                                id: dayField

                                objectName: "gradeDay"
                                Layout.fillWidth: true
                                format: qsTr("yyyy-MM-dd", "date format")
                                dayNames: [qsTr("MO"), qsTr("TU"), qsTr("WE"), qsTr("TH"), qsTr("FR"), qsTr("SA"), qsTr("SU")]
                                todayText: qsTr("Today")
                                date: new Date()
                                Accessible.name: qsTr("Day of the exam")
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            LookTextField {
                                id: placeField

                                objectName: "gradePlace"
                                Layout.fillWidth: true
                                placeholderText: qsTr("Place")
                                Accessible.name: qsTr("Place")
                            }
                            LookButton {
                                objectName: "addGrade"
                                icon.name: "list-add"
                                text: qsTr("Add")
                                enabled: gradeBox.currentIndex >= 0 && !!dayField.date && !dayField.invalid
                                onClicked: {
                                    const grade = block.ladder[gradeBox.currentIndex]
                                    if (grade && Courses.addGrade(block.discipline, grade.id, CourseDays.iso(dayField.date), placeField.text)) {
                                        placeField.clear()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        LookLabel {
            Layout.fillWidth: true
            text: qsTr("The ground for waiting times and the hints before an exam. The same grade again corrects its day and place.")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }
    }
}
