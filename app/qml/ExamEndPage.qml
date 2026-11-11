pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// The end of an exam round (clickdummy "Wie lief es?"): every point rated 1–4. "Apply" (once all
// are rated) sets the techniques' ratings, keeps the round for the statistics and shows them.
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    required property var points        // Exam.draw()
    required property string discipline
    required property string grade
    // The level per point, 0 = not yet rated.
    property var levels: points.map(() => 0)
    readonly property bool complete: levels.length > 0 && levels.every(l => l > 0)
    readonly property bool started: levels.some(l => l > 0)

    // Back (button, Android, Alt+Left) after a rating asks first: it drops the round. Qt 6.12
    // hands `event` over as a copy, so Kirigami's goBack() never sees `accepted` and steps back
    // anyway: the page takes the stack back right after it (the same event, before a frame).
    onBackRequested: event => {
        if (!page.started) {
            return
        }
        event.accepted = true
        const stack = (page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow).pageStack
        const index = page.Kirigami.ColumnView.index
        Qt.callLater(() => {
            stack.currentIndex = index
            discardDialog.open()
        })
    }

    title: qsTr("How did it go?")

    function rate(index, level) {
        const l = page.levels.slice()
        l[index] = level
        page.levels = l
    }

    // What a row says under the name: attack (or group), and whether it was a sample.
    function subtitle(point) {
        const what = point.attack ? [point.attack, point.attackExtra].filter(x => x).join(" · ") : point.group
        return [what, point.sample ? qsTr("Sample %1").arg(point.gradeName) : ""].filter(x => x).join(" · ")
    }

    function apply() {
        if (!page.complete) {
            return
        }
        const results = page.points.map((p, i) => ({ id: p.id, level: page.levels[i] }))
        if (!Practice.saveRound(page.discipline, page.grade, results)) {
            return
        }
        // To the statistics, with the start menu behind them (clickdummy: menu › statistics).
        const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
        const stack = window.pageStack
        stack.pop(stack.items[0])
        stack.push(Qt.resolvedUrl("StatsPage.qml"), { discipline: page.discipline })
    }

    LookDialog {
        id: discardDialog

        objectName: "discardDialog"
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        modal: true
        span: LookDialog.Span.Small
        destructive: true
        title: qsTr("Discard the round?")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        acceptText: qsTr("Discard")
        rejectText: qsTr("Keep the round")
        onAccepted: page.Kirigami.PageStack.pop()

        LookLabel {
            id: discardText

            objectName: "discardText"

            width: parent.width
            wrapMode: Text.Wrap
            text: qsTr("Your ratings of this round are not kept.")
        }
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: page.points

            ColumnLayout {
                id: pointRow

                required property var modelData
                required property int index

                objectName: "ratedPoint"
                Layout.fillWidth: true
                spacing: Look.unit(4)

                LookLabel {
                    Layout.fillWidth: true
                    text: (pointRow.modelData.nr ? pointRow.modelData.nr + " · " : "") + pointRow.modelData.title
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: page.subtitle(pointRow.modelData)
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
                LookLevelPicker {
                    objectName: "pointPicker"
                    Layout.fillWidth: true
                    value: page.levels[pointRow.index]
                    names: Practice.levelNames
                    onPicked: level => page.rate(pointRow.index, level)
                    Accessible.name: qsTr("Rating of %1").arg(pointRow.modelData.title)
                }
            }
        }

        LookLabel {
            Layout.fillWidth: true
            text: [1, 2, 3, 4].map(l => l + " " + Practice.levelNames[l]).join(" · ") + ". "
                  + qsTr("Apply sets the rating of the techniques and keeps the round in the statistics.")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }
        LookLabel {
            Layout.fillWidth: true
            visible: Practice.errorString !== ""
            text: Practice.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }
        LookLabel {
            objectName: "openPoints"
            Layout.fillWidth: true
            visible: !page.complete
            text: qsTr("%n point(s) still to rate.", "", page.levels.filter(l => l === 0).length)
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }
        LookButton {
            objectName: "applyRound"
            enabled: page.complete
            role: LookButton.Role.Primary
            text: qsTr("Apply")
            onClicked: page.apply()
        }
    }
}
