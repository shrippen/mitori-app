pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2

// Choice field (bible section 5, Auswahl): the field of section 5 with a small arrow; the list
// opens on paper with a 1 px frame, the row under the pointer or keyboard on `chip` with 3 px red
// at the left (not colour alone), the chosen one bold. Same interface as QQC2.ComboBox (model,
// textRole, currentIndex, activated()); `invalid` frames it red.
QQC2.ComboBox {
    id: box

    property bool invalid: false

    implicitHeight: ShinkiStyle.rowMinSpace
    leftPadding: ShinkiStyle.gridSpace * 3
    rightPadding: ShinkiStyle.rowMinSpace
    font.family: ShinkiStyle.uiFamily
    font.pixelSize: ShinkiStyle.uiSize

    background: Rectangle {
        implicitWidth: ShinkiStyle.unit(170)
        color: ShinkiStyle.paperAlt
        opacity: box.enabled ? 1 : ShinkiStyle.disabledOpacity
        border.width: box.activeFocus ? ShinkiStyle.focusWidth : ShinkiStyle.lineWidth
        border.color: box.invalid ? ShinkiStyle.red : box.activeFocus ? ShinkiStyle.ink : ShinkiStyle.line
    }
    contentItem: QQC2.Label {
        text: box.displayText
        color: ShinkiStyle.ink
        font: box.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    // The arrow: a small triangle in ink, drawn (no font carries one in every face).
    indicator: Canvas {
        x: box.width - width - ShinkiStyle.gridSpace * 3
        y: (box.height - height) / 2
        width: ShinkiStyle.levelDotSize * 1.5
        height: ShinkiStyle.levelDotSize
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.fillStyle = ShinkiStyle.ink
            ctx.beginPath()
            ctx.moveTo(0, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width / 2, height)
            ctx.closePath()
            ctx.fill()
        }
    }

    delegate: QQC2.ItemDelegate {
        id: row

        required property int index
        required property var modelData

        width: ListView.view ? ListView.view.width : implicitWidth
        implicitHeight: ShinkiStyle.rowMinSpace
        highlighted: box.highlightedIndex === index
        text: box.textRole && modelData ? modelData[box.textRole] : modelData
        // The ground fills the row (Breeze insets a delegate's background).
        leftInset: 0
        rightInset: 0
        topInset: 0
        bottomInset: 0

        background: Rectangle {
            color: row.highlighted ? ShinkiStyle.chip : ShinkiStyle.paper

            Rectangle {
                visible: row.highlighted
                width: ShinkiStyle.selectedBarWidth
                height: parent.height
                color: ShinkiStyle.red
            }
        }
        contentItem: QQC2.Label {
            leftPadding: ShinkiStyle.gridSpace * 2
            text: row.text
            color: ShinkiStyle.ink
            font.family: ShinkiStyle.uiFamily
            font.pixelSize: ShinkiStyle.uiSize
            font.bold: box.currentIndex === row.index
            verticalAlignment: Text.AlignVCenter
        }
    }

    popup: QQC2.Popup {
        y: box.height + ShinkiStyle.gridSpace
        width: box.width
        implicitHeight: Math.min(contentItem.implicitHeight + 2 * padding, ShinkiStyle.rowMinSpace * 8)
        padding: ShinkiStyle.lineWidth

        background: Rectangle {
            color: ShinkiStyle.paper
            border.width: ShinkiStyle.lineWidth
            border.color: ShinkiStyle.line
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: box.popup.visible ? box.delegateModel : null
            currentIndex: box.highlightedIndex
            QQC2.ScrollIndicator.vertical: QQC2.ScrollIndicator {}
        }
    }
}
