import QtQuick
import QtQuick.Controls as QQC2

// Grade chip (bible section 5, `.gchip`): the name bold in a 1 px frame; chosen: a red frame and
// 3 px red inside at the bottom (not colour alone: the bar). `stand` ("12/30", empty: none) sits
// below the name in table figures. As KanteChip: `checkable` toggles on
// a tap, `choice` (one of a set the app holds) only reports the tap and keeps the app's binding
// of `checked`. Return and Space act as a tap. `interactive` false: a plain label (a state, a
// mark): no focus, no tap, no hover.
Item {
    id: chip

    property string text: ""
    property string stand: ""
    property bool checkable: false
    property bool checked: false
    property bool choice: false
    property bool interactive: true
    readonly property bool hovered: hover.hovered
    signal clicked()

    function activate() {
        if (checkable && !choice) {
            checked = !checked
        }
        clicked()
    }

    implicitWidth: Math.max(label.implicitWidth, standLabel.implicitWidth) + 4 * ShinkiStyle.gridSpace
    implicitHeight: Math.max(ShinkiStyle.chipMinSpace, column.implicitHeight + 2 * ShinkiStyle.gridSpace)
    activeFocusOnTab: interactive

    Accessible.role: !interactive ? Accessible.StaticText : checkable ? Accessible.RadioButton : Accessible.Button
    Accessible.name: text
    Accessible.checked: checked
    Accessible.focusable: interactive
    Accessible.onPressAction: chip.activate()

    Keys.onReturnPressed: chip.activate()
    Keys.onEnterPressed: chip.activate()
    Keys.onSpacePressed: chip.activate()

    Rectangle {
        anchors.fill: parent
        color: chip.hovered && chip.interactive ? ShinkiStyle.chip : ShinkiStyle.paper
        border.width: chip.activeFocus ? ShinkiStyle.focusWidth : ShinkiStyle.lineWidth
        border.color: chip.activeFocus ? ShinkiStyle.ink : chip.checked ? ShinkiStyle.red : ShinkiStyle.line

        Rectangle {
            visible: chip.checked
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: ShinkiStyle.lineWidth
            height: ShinkiStyle.selectedBarWidth
            color: ShinkiStyle.red
        }
    }
    Column {
        id: column

        anchors.centerIn: parent

        QQC2.Label {
            id: label

            anchors.horizontalCenter: parent.horizontalCenter
            text: chip.text
            color: ShinkiStyle.ink
            font.family: ShinkiStyle.uiFamily
            font.bold: true
            font.pixelSize: ShinkiStyle.uiSize
        }
        QQC2.Label {
            id: standLabel

            objectName: "chipStand"
            anchors.horizontalCenter: parent.horizontalCenter
            visible: chip.stand !== ""
            text: chip.stand
            color: ShinkiStyle.inkMuted
            font.family: ShinkiStyle.uiFamily
            font.pixelSize: ShinkiStyle.chipStandSize
            font.features: { "tnum": 1 }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
        enabled: chip.interactive
        onTapped: chip.activate()
    }
}
