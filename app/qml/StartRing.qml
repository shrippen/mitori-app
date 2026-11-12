import QtQuick
import QtQuick.Shapes
import Mitori

// A share as a ring with its figure in the middle ("24 %"): the exam tile. No axes, as the tiles
// have none.
Item {
    id: ring

    // 0..1
    property real value: 0
    property string label: ""
    readonly property real stroke: Look.unit(6)

    implicitWidth: Look.unit(60)
    implicitHeight: implicitWidth

    Shape {
        anchors.fill: parent
        antialiasing: true

        ShapePath {
            strokeColor: Look.ruleColor
            strokeWidth: ring.stroke
            fillColor: "transparent"

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (ring.width - ring.stroke) / 2
                radiusY: (ring.height - ring.stroke) / 2
                startAngle: -90
                sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: Look.accentColor
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            PathAngleArc {
                centerX: ring.width / 2
                centerY: ring.height / 2
                radiusX: (ring.width - ring.stroke) / 2
                radiusY: (ring.height - ring.stroke) / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.value))
            }
        }
    }
    LookLabel {
        anchors.centerIn: parent
        text: ring.label
        font: Look.smallFont
    }
}
