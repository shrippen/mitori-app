pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Mitori

// How well does it sit? (the player's design "Kino"): the four levels as buttons on the dark
// ground, the entry's level filled. A column along the right edge sideways, a row in the thumb
// zone upright. A tap rates the entry now; the same level again counts as practice (as RatingRow).
GridLayout {
    id: rating

    required property string entry
    readonly property int level: Practice.revision >= 0 ? Practice.level(entry) : 0
    // One below the other (sideways) or side by side (upright).
    property bool vertical: false
    property real buttonHeight: Look.unit(52)
    property real buttonWidth: Look.unit(84)

    // A tap (and the UI test): the entry is rated, then `rated` says so (the training moves on).
    signal picked(int level)
    signal rated(int level)

    columns: vertical ? 1 : 4
    rowSpacing: Look.unit(6)
    columnSpacing: Look.unit(6)
    Accessible.name: qsTr("Rating")

    onPicked: level => {
        if (Practice.rate(entry, level)) {
            rated(level)
        }
    }

    Repeater {
        model: 4

        QQC2.AbstractButton {
            id: cell

            required property int index
            readonly property int level: index + 1
            readonly property bool chosen: rating.level === level
            readonly property string word: Practice.levelNames.length > level ? String(Practice.levelNames[level]) : ""
            readonly property color ink: chosen ? Look.stageColor : Look.stageTextColor

            Layout.fillWidth: !rating.vertical
            Layout.preferredWidth: rating.vertical ? rating.buttonWidth : 0
            Layout.preferredHeight: rating.buttonHeight
            focusPolicy: Qt.TabFocus        // Space stays with the player
            padding: Look.unit(4)
            onClicked: rating.picked(level)
            Accessible.role: Accessible.RadioButton
            Accessible.name: level + " " + word
            Accessible.checked: chosen

            background: Rectangle {
                color: cell.chosen ? Look.stageTextColor : Qt.alpha(Look.stageColor, 0.7)
                border.width: cell.visualFocus ? Look.focusWidth : Look.borderWidth
                border.color: cell.visualFocus ? Look.focusColor : Qt.alpha(Look.stageTextColor, 0.45)
            }

            contentItem: Column {
                spacing: 0

                LookLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: cell.level
                    color: cell.ink
                    font: Look.headingFont(15)
                }
                LookLabel {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.word
                    color: cell.ink
                    font: Look.smallFont
                }
            }
        }
    }
}
