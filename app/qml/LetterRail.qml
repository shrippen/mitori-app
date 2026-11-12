pragma ComponentBehavior: Bound

import QtQuick
import Mitori

// A vertical rail of letters (the glossary's A–Z). A letter without entries is grey and does not
// react. A tap or a drag over the rail picks the letter under the finger (`picked`); the letter of
// the section in view is `current`. With `bubble` the letter touched shows beside the finger
// (phone: the finger covers the rail). With the focus (Tab), Up and Down go to the letter before and
// after, Home and End to the first and the last; each letter is a button for a screen reader.
//
//   A      ┐
//   B      │ one cell each, the rail's height shared
//   C  (C) ┘ bubble while dragging
Item {
    id: rail

    property var letters: []
    // The letters with entries.
    property var available: []
    property string current: ""
    property bool bubble: false
    readonly property real cellHeight: letters.length > 0 ? height / letters.length : 0
    readonly property string touched: touch.pressed ? cell(touch.mouseY) : ""
    // A drag within one cell jumps once.
    property string lastPicked: ""
    // The letter the keys went to last: a jump to a section too short to reach the top leaves
    // `current` behind, the next key goes on from here.
    property string keyLetter: ""

    signal picked(string letter)

    implicitWidth: Look.unit(28)
    activeFocusOnTab: true
    Accessible.role: Accessible.List
    Accessible.name: qsTr("Letters")
    onCurrentChanged: keyLetter = ""

    // The next letter with words after index `from` in `direction` (1 or -1).
    function step(from, direction) {
        for (let i = from + direction; i >= 0 && i < letters.length; i += direction) {
            if (available.indexOf(letters[i]) >= 0) {
                keyLetter = letters[i]
                picked(letters[i])
                return
            }
        }
    }

    Keys.onDownPressed: step(letters.indexOf(keyLetter !== "" ? keyLetter : current), 1)
    Keys.onUpPressed: step(letters.indexOf(keyLetter !== "" ? keyLetter : current), -1)
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Home) {
            step(-1, 1)
        } else if (event.key === Qt.Key_End) {
            step(letters.length, -1)
        } else {
            return
        }
        event.accepted = true
    }

    function cell(y) {
        if (letters.length === 0) {
            return ""
        }
        return letters[Math.max(0, Math.min(letters.length - 1, Math.floor(y / cellHeight)))]
    }

    function pick(y) {
        const letter = cell(y)
        if (available.indexOf(letter) < 0 || letter === lastPicked) {
            return
        }
        lastPicked = letter
        picked(letter)
    }

    Column {
        anchors.fill: parent

        Repeater {
            model: rail.letters

            Rectangle {
                id: item

                required property string modelData
                readonly property bool has: rail.available.indexOf(modelData) >= 0
                readonly property bool isCurrent: modelData === rail.current

                objectName: "railLetter"
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Words with %1").arg(modelData)
                Accessible.onPressAction: {
                    if (has) {
                        rail.picked(modelData)
                    }
                }
                width: rail.width
                height: rail.cellHeight
                color: isCurrent && has ? Look.selectedColor : "transparent"

                LookLabel {
                    anchors.centerIn: parent
                    text: item.modelData
                    font: Look.smallFont
                    color: !item.has ? Look.disabledTextColor : item.isCurrent ? Look.accentColor : Look.textColor
                }
            }
        }
    }

    // The keyboard focus.
    Rectangle {
        anchors.fill: parent
        visible: rail.activeFocus
        color: "transparent"
        border.color: Look.focusColor
        border.width: Look.focusWidth
    }

    MouseArea {
        id: touch

        anchors.fill: parent
        preventStealing: true
        onPressed: mouse => rail.pick(mouse.y)
        onPositionChanged: mouse => rail.pick(mouse.y)
        onPressedChanged: {
            if (!pressed) {
                rail.lastPicked = ""
            }
        }
    }

    Rectangle {
        objectName: "railBubble"
        visible: rail.bubble && touch.pressed && rail.touched !== ""
        width: Look.unit(52)
        height: width
        radius: width / 2
        x: -width - Look.unit(12)
        y: Math.max(0, Math.min(rail.height - height, touch.mouseY - height / 2))
        color: Look.stageColor

        LookLabel {
            anchors.centerIn: parent
            text: rail.touched
            font: Look.titleFont(Look.defaultFont.pointSize * 1.6)
            color: Look.stageTextColor
        }
    }
}
