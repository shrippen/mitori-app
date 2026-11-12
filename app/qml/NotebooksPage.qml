pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// My notebooks (Courses → "My notebooks", owner 06.11.2026): every notebook, the latest course
// first; a tap opens it. A notebook is made from a date on CoursesPage or with its "New course".
//
//   [ 6 ] Daitoryu Aiki Jujutsu         place · 6.–7.6.2026 · teacher       in 12 days
//    Jun                                                                     3 notes
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    readonly property var notebooks: Courses.revision >= 0 ? Courses.notebooks : []

    title: qsTr("My notebooks")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        LookLabel {
            Layout.fillWidth: true
            visible: Courses.errorString !== ""
            text: Courses.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }

        LookLabel {
            objectName: "notebooksEmpty"
            Layout.fillWidth: true
            visible: page.notebooks.length === 0
            text: qsTr("No notebooks yet. Tap a date on the Courses page, or make a course of your own there (+).")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }

        Repeater {
            model: page.notebooks

            CourseRow {
                required property var modelData

                objectName: "notebookRow"
                Layout.fillWidth: true
                course: modelData
                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("CoursePage.qml"), { uid: modelData.uid })
            }
        }
    }
}
