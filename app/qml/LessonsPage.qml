pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// Learning videos (start tile "Learning videos"): the Lernpakete, video bundles that bring techniques
// of their own (not part of any exam). Without one: what they are and the way to the code. With
// packages: one row each; a tap opens the package (LessonPackagePage), on a tablet sideways beside
// the list (ListAndPage).
//
//   Aikido with Shirakawa Sensei        12 techniques     (no package: the explanation, [Enter code])
//   Daitoryu basics                      8 techniques
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    readonly property var packages: Library.packages

    // ListAndPage, when it shows this page: the first package stands beside the list before one is chosen.
    property var paneHost: null
    readonly property var firstPane: packages.length > 0 ? { source: "LessonPackagePage.qml", props: { uid: packages[0].id } } : null

    title: qsTr("Learning videos")

    function open(id) {
        if (!page.paneHost || !page.paneHost.show("LessonPackagePage.qml", { uid: id })) {
            page.Kirigami.PageStack.push(Qt.resolvedUrl("LessonPackagePage.qml"), { uid: id })
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        LookEmptyState {
            objectName: "lessonsEmpty"
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            visible: page.packages.length === 0
            iconName: "media-playback-start"
            title: qsTr("No learning videos yet")
            explanation: qsTr("Learning videos come with techniques of their own, apart from the exam programme. Like the DVD videos, they are loaded onto this device with a code.")
        }
        LookButton {
            objectName: "lessonsCode"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: page.packages.length === 0
            role: LookButton.Role.Primary
            text: qsTr("Enter code")
            onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
        }

        Repeater {
            model: page.packages

            LookListRow {
                required property var modelData

                objectName: "packageRow"
                Layout.fillWidth: true
                text: modelData.title
                subtitle: modelData.text
                meta: qsTr("%n technique(s)", "", modelData.count)
                selected: !!page.paneHost && page.paneHost.isShown("LessonPackagePage.qml", modelData.id)
                onClicked: page.open(modelData.id)
            }
        }
    }
}
