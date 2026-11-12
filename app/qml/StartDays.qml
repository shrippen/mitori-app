pragma ComponentBehavior: Bound

import QtQuick
import Mitori

// The last days as small squares, oldest first, today last: a month at a glance for the statistics
// tile. No labels, as the tiles have none; the statistics page has them.
Item {
    id: days

    // Techniques practised per day.
    property var counts: []
    readonly property int perRow: 10
    readonly property real spacing: Look.unit(3)
    readonly property real maxCell: Look.unit(16)
    readonly property real cell: Math.max(1, Math.min(maxCell, Math.floor((width - spacing * (perRow - 1)) / perRow)))
    // The counts from which a day is a level (the same as today's practice calendar).
    readonly property var bounds: [1, 3, 6, 10]

    implicitWidth: Look.unit(120)
    implicitHeight: Math.ceil(counts.length / perRow) * (cell + spacing) - spacing

    function level(n) {
        return bounds.filter(b => n >= b).length
    }

    Repeater {
        model: days.counts

        Rectangle {
            required property int index
            required property int modelData

            x: (index % days.perRow) * (days.cell + days.spacing)
            y: Math.floor(index / days.perRow) * (days.cell + days.spacing)
            width: days.cell
            height: days.cell
            color: Look.levelColor(days.level(modelData))
        }
    }
}
