import QtQuick
import Mitori

// A miniature of a technique map group: one square per place, coloured by its level, none where
// no technique answers; no text. The map page has the labels.
Canvas {
    id: map

    // [[level -1..4]]
    property var levels: []
    property int columns: 0
    readonly property real spacing: Look.unit(1)

    implicitWidth: Look.unit(80)
    implicitHeight: Look.unit(40)

    onLevelsChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        const rows = levels.length
        if (rows === 0 || columns === 0) {
            return
        }

        // Square places that fit the width and the height.
        const cell = Math.max(1, Math.floor(Math.min((width + spacing) / columns, (height + spacing) / rows) - spacing))
        for (let r = 0; r < rows; ++r) {
            for (let c = 0; c < levels[r].length; ++c) {
                if (levels[r][c] < 0) {
                    continue
                }
                ctx.fillStyle = Look.levelColor(levels[r][c])
                ctx.fillRect(c * (cell + spacing), r * (cell + spacing), cell, cell)
            }
        }
    }

    // A new style paints the places anew.
    Connections {
        target: Look

        function onRolesChanged() {
            map.requestPaint()
        }
    }
}
