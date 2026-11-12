pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Mitori

// The training's playlist under the player: numbered, ✓ for the rated ones, a tap jumps there.
// Rows exist only while it is shown.
ColumnLayout {
    id: list

    required property var playlist
    required property int current
    required property int practised

    signal chosen(int index)

    objectName: "trainingList"
    spacing: 0

    LookSectionLabel {
        Layout.fillWidth: true
        rule: true
        text: qsTr("Today's playlist · %1 of %2 practised").arg(list.practised).arg(list.playlist.length)
    }
    Repeater {
        model: list.visible ? list.playlist : []

        LookListRow {
            id: trainingRow

            required property var modelData
            required property int index
            readonly property bool done: Practice.revision >= 0 && Practice.ratedToday(modelData.id)

            objectName: "trainingRow"
            Layout.fillWidth: true
            focusOnClick: false     // Space stays with the player (play, pause)
            selected: trainingRow.index === list.current
            text: (trainingRow.index + 1) + ". " + (modelData.title || "")
            subtitle: [modelData.attack, modelData.gradeName].filter(x => !!x).join(" · ")
            trailing: LookLabel {
                text: trainingRow.done ? "✓" : ""
                color: Look.positiveTextColor
                Accessible.name: trainingRow.done ? qsTr("practised") : ""
            }
            onClicked: list.chosen(trainingRow.index)
        }
    }
}
