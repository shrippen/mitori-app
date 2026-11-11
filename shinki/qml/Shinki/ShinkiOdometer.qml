import QtQuick

// Counter (bible section 4, motion; the Kante odometer's counterpart): every digit is a reel in the
// narrow face that rolls to its value, straight and in 150 ms, all reels at once, no spring. Without
// motion the reels just show it. Leading zeros stay (`digits`). Same interface as KanteOdometer.
Item {
    id: odo

    property int value: 0
    property int digits: 3
    property font font: Qt.font({ family: ShinkiStyle.narrowFamily, pixelSize: ShinkiStyle.columnSize, bold: true })
    property color color: ShinkiStyle.ink
    readonly property string padded: String(Math.max(0, value)).padStart(digits, "0")

    implicitWidth: row.implicitWidth
    implicitHeight: metric.height

    TextMetrics {
        id: metric

        font: odo.font
        text: "0"
    }

    Row {
        id: row

        Repeater {
            model: odo.digits

            Item {
                id: reel

                required property int index
                readonly property int digit: parseInt(odo.padded.charAt(index)) || 0

                width: metric.advanceWidth
                height: metric.height
                clip: true

                Column {
                    y: -reel.digit * metric.height

                    Behavior on y {
                        NumberAnimation {
                            duration: ShinkiStyle.animate ? ShinkiStyle.stateDuration : 0
                            easing.type: Easing.Linear
                        }
                    }

                    Repeater {
                        model: 10

                        Text {
                            required property int index

                            width: reel.width
                            height: metric.height
                            horizontalAlignment: Text.AlignHCenter
                            text: index
                            font: odo.font
                            color: odo.color
                        }
                    }
                }
            }
        }
    }
}
