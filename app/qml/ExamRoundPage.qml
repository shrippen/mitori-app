import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// An exam round (clickdummy "Prüfungsrunde"): one point at a time on the board, samples from
// earlier grades marked. "Next" (Space, Enter) moves on; after the last the round is rated
// (ExamEndPage). No video, no time limit. Cancel goes back to the settings.
Kirigami.Page {
    id: page

    // The page keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    required property var points        // Exam.draw()
    required property string discipline
    required property string grade
    property int index: 0
    readonly property var current: points[index] || ({})
    // A tablet or a phone held sideways: the board grows with the room.
    readonly property bool wide: width > height
    readonly property bool tablet: Math.min(width, height) >= 460     // a tablet, not a phone

    title: qsTr("Mock exam")

    actions: [
        Kirigami.Action {
            icon.name: "dialog-cancel"
            text: qsTr("Cancel")
            objectName: "cancelRound"
            onTriggered: page.cancel()
        }
    ]

    // Past the first point there is something to lose: ask (the action and Back).
    function cancel() {
        if (page.index === 0) {
            page.Kirigami.PageStack.pop()
            return
        }
        cancelDialog.open()
    }
    onBackRequested: event => {
        if (page.index === 0) {
            return
        }
        event.accepted = true
        const stack = (page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow).pageStack
        const place = page.Kirigami.ColumnView.index
        Qt.callLater(() => {
            stack.currentIndex = place
            cancelDialog.open()
        })
    }
    LookDialog {
        id: cancelDialog

        objectName: "cancelRoundDialog"
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        span: LookDialog.Span.Small
        destructive: true
        title: qsTr("Discard the round?")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        acceptText: qsTr("Discard")
        rejectText: qsTr("Keep the round")
        onAccepted: page.Kirigami.PageStack.pop(page.Kirigami.PageStack.pageStack.items[page.Kirigami.ColumnView.index - 1])

        LookLabel {
            width: parent.width
            // Empty while closed: a turning window made the closed dialog wrap this text anew, a
            // binding loop in its height (as the merge dialog in BackupPage).
            text: !cancelDialog.visible ? "" : qsTr("You are at point %1 of %2. Nothing has been rated yet, the round is simply dropped.").arg(page.index + 1).arg(page.points.length)
            wrapMode: Text.Wrap
        }
    }

    function next() {
        if (page.index < page.points.length - 1) {
            page.index++
            return
        }
        const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
        window.pageStack.replace(Qt.resolvedUrl("ExamEndPage.qml"),
                                 { points: page.points, discipline: page.discipline, grade: page.grade })
    }

    focus: true
    Keys.onSpacePressed: page.next()
    Keys.onReturnPressed: page.next()
    Keys.onEnterPressed: page.next()
    Component.onCompleted: forceActiveFocus()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        LookLabel {
            objectName: "counter"
            Layout.alignment: Qt.AlignRight
            text: (page.index + 1) + " / " + page.points.length
            color: Look.mutedTextColor
            font: Look.monoFont(0, false)
            Accessible.name: qsTr("Point %1 of %2").arg(page.index + 1).arg(page.points.length)
        }

        // The board in the middle of the free room; it scrolls if a long name does not fit.
        LookScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            Item {
                width: parent.width
                implicitHeight: Math.max(column.implicitHeight, page.height * 0.5)

                ColumnLayout {
                    id: column

                    anchors.centerIn: parent
                    width: Math.min(parent.width, Kirigami.Units.gridUnit * (page.tablet ? 40 : 28))
                    spacing: Kirigami.Units.largeSpacing

                    ExamBoard {
                        objectName: "examBoard"
                        Layout.fillWidth: true
                        point: page.current
                        techniqueOnly: page.discipline === "shinkitoho"
                        zoom: page.tablet ? 1.6 : 1
                    }
                    LookChip {
                        objectName: "sampleMark"
                        Layout.alignment: Qt.AlignHCenter
                        visible: !!page.current.sample
                        interactive: false
                        text: qsTr("Sample %1").arg(page.current.gradeName || "")
                    }
                }
            }
        }

        LookButton {
            objectName: "nextButton"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width, Kirigami.Units.gridUnit * 20)
            role: LookButton.Role.Primary
            text: page.index < page.points.length - 1 ? qsTr("Next") : qsTr("Rate the round")
            onClicked: page.next()
        }
        LookLabel {
            Layout.fillWidth: true
            visible: !page.wide || page.tablet
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("You rate every technique at the end of the round.")
            color: Look.mutedTextColor
            font: Look.smallFont
            wrapMode: Text.Wrap
        }
    }
}
