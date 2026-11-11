import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// Stand bar (bible section 5, "Stand-Leiste"): the parts [{value 0..1, color, text}] side by side
// in one bar of the slider track's height on `line`; each part's text is its tooltip. Without
// parts, `value` (0..1) fills it in red (a level, as the player's brightness). `indeterminate`
// (the stand is unknown, as a download waiting for Wi-Fi): a red piece runs across, straight and
// without spring; without motion it stands in the middle.
Item {
    id: bar

    property var parts: []
    property real value: 0
    property bool indeterminate: false
    readonly property real pieceWidth: width / 4
    // The run of the piece, 0 (before the left edge) to 1 (past the right).
    property real phase: 0
    readonly property var shown: parts.length > 0 ? parts : [{ value: bar.value, color: ShinkiStyle.red, text: "" }]

    clip: true
    implicitHeight: ShinkiStyle.sliderTrackSize * 2
    implicitWidth: ShinkiStyle.unit(200)
    Accessible.role: Accessible.ProgressBar
    Accessible.description: bar.shown.map(p => p.text).filter(t => !!t).join(", ")

    Rectangle {
        anchors.fill: parent
        color: ShinkiStyle.line
    }
    Rectangle {
        id: piece

        visible: bar.indeterminate
        x: ShinkiStyle.animate ? bar.phase * (bar.width + width) - width : (bar.width - width) / 2
        width: bar.pieceWidth
        height: bar.height
        color: ShinkiStyle.red

        NumberAnimation {
            target: bar
            property: "phase"
            from: 0
            to: 1
            duration: ShinkiStyle.sweepDuration
            easing.type: Easing.Linear
            loops: Animation.Infinite
            running: bar.indeterminate && ShinkiStyle.animate && bar.visible
        }
    }
    Row {
        anchors.fill: parent
        visible: !bar.indeterminate

        Repeater {
            model: bar.shown

            Rectangle {
                id: part

                required property var modelData

                width: Math.round(bar.width * Math.max(0, Math.min(1, modelData.value)))
                height: bar.height
                color: modelData.color

                HoverHandler {
                    id: hover
                }
                QQC2.ToolTip.visible: hover.hovered && !!part.modelData.text
                QQC2.ToolTip.text: part.modelData.text || ""
            }
        }
    }
}
