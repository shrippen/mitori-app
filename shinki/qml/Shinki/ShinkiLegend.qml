import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// Legend (bible section 5, "Diagramme"): a square of each colour and its words, 11 px inkMuted.
//   model  [{color, value, text}]: "12 sure"
// Wrapped lines are balanced: the legend takes the narrowest width that needs no more lines, so
// the last line does not hold one key alone (as KanteLegend).
Flow {
    id: legend

    property var model: []

    // The keys' widths, kept by _measure(); the free width goes to the end of the lines.
    property var _itemWidths: []
    readonly property real _slack: width > 0 ? width - _balancedWidth() : 0

    spacing: ShinkiStyle.gridSpace * 3
    leftPadding: effectiveLayoutDirection === Qt.RightToLeft ? _slack : 0
    rightPadding: effectiveLayoutDirection === Qt.RightToLeft ? 0 : _slack

    // The lines a Flow `room` wide fills with the keys, as Flow wraps them.
    function _lineCount(room) {
        let lines = 1
        let x = 0
        for (const w of _itemWidths) {
            if (x > 0 && x + w > room) {
                lines++
                x = 0
            }
            x += w + spacing
        }
        return lines
    }

    // The narrowest width of a run of keys that needs no more lines than the whole width.
    function _balancedWidth() {
        const lines = _lineCount(width)
        if (lines <= 1) {
            return width
        }
        let best = width
        for (let i = 0; i < _itemWidths.length; i++) {
            let run = -spacing
            for (let j = i; j < _itemWidths.length; j++) {
                run += _itemWidths[j] + spacing
                if (run >= best) {
                    break
                }
                // Half a pixel more, so rounding does not wrap a key that fits.
                if (_lineCount(run + 0.5) === lines) {
                    best = run + 0.5
                }
            }
        }
        return best
    }

    function _measure() {
        const widths = []
        for (let i = 0; i < keys.count; i++) {
            const key = keys.itemAt(i)
            if (!key) {
                return
            }
            widths.push(key.implicitWidth)
        }
        _itemWidths = widths
    }

    Repeater {
        id: keys

        model: legend.model
        onItemAdded: legend._measure()
        onItemRemoved: legend._measure()

        Row {
            required property var modelData

            onImplicitWidthChanged: legend._measure()

            spacing: ShinkiStyle.gridSpace

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: ShinkiStyle.levelDotSize
                height: width
                color: parent.modelData.color
                border.width: ShinkiStyle.lineWidth
                border.color: ShinkiStyle.line
            }
            QQC2.Label {
                text: (parent.modelData.value !== undefined ? parent.modelData.value + " " : "") + (parent.modelData.text || "")
                color: ShinkiStyle.inkMuted
                font.family: ShinkiStyle.uiFamily
                font.pixelSize: ShinkiStyle.columnSize
                font.features: { "tnum": 1 }
            }
        }
    }
}
