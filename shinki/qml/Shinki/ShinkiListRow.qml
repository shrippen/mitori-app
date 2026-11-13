import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

// List row (bible section 5, `.li`): the name in the book face, a line under it in inkMuted, on
// the right the trailing items (level dots, play). Selected: 3 px red on the left on `selected`.
// Rows part by a line in paperAlt. At least 44 px high (a finger). Enter and Space click.
//   glyph        a kanji before the name, red in the Japanese face (a settings row: 映)
//   leadingText  a figure before the name (a form's number)
//   meta         a small figure on the right, before the trailing items ("in 3 weeks")
//   trailing     items on the right
//   focusOnClick false: a tap leaves the focus where it is
QQC2.ItemDelegate {
    id: row

    property string subtitle: ""
    property string glyph: ""
    property string leadingText: ""
    property string meta: ""
    property bool selected: false
    property bool focusOnClick: true
    property alias trailing: trailingSlot.data

    hoverEnabled: true
    focusPolicy: focusOnClick ? Qt.StrongFocus : Qt.TabFocus
    padding: ShinkiStyle.cardSpace
    leftPadding: ShinkiStyle.pageSpace
    implicitHeight: Math.max(ShinkiStyle.rowMinSpace, implicitContentHeight + topPadding + bottomPadding)
    highlighted: selected

    Accessible.role: Accessible.ListItem
    Accessible.name: text
    Accessible.description: subtitle

    Keys.onReturnPressed: row.clicked()
    Keys.onEnterPressed: row.clicked()
    Keys.onSpacePressed: row.clicked()

    background: Rectangle {
        color: row.selected ? ShinkiStyle.selected : row.hovered || row.down ? ShinkiStyle.paperAlt : ShinkiStyle.paper
        border.width: row.visualFocus ? ShinkiStyle.focusWidth : 0
        border.color: ShinkiStyle.ink

        Rectangle {
            visible: row.selected
            width: ShinkiStyle.selectedBarWidth
            height: parent.height
            color: ShinkiStyle.red
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: ShinkiStyle.lineWidth
            color: ShinkiStyle.paperAlt
        }
    }

    contentItem: RowLayout {
        spacing: ShinkiStyle.cardSpace

        QQC2.Label {
            objectName: "rowGlyph"
            visible: row.glyph !== ""
            text: row.glyph
            color: ShinkiStyle.red
            font.family: ShinkiStyle.japaneseFamily
            font.pixelSize: ShinkiStyle.tileKanjiSize
            Accessible.ignored: true
        }
        QQC2.Label {
            visible: row.leadingText !== ""
            Layout.alignment: Qt.AlignTop
            text: row.leadingText
            color: ShinkiStyle.inkMuted
            font.family: ShinkiStyle.uiFamily
            font.pixelSize: ShinkiStyle.uiSize
            font.features: { "tnum": 1 }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            QQC2.Label {
                objectName: "listRowText"
                Layout.fillWidth: true
                text: row.text
                color: ShinkiStyle.ink
                font.family: ShinkiStyle.bookFamily
                font.weight: Font.DemiBold
                font.pixelSize: ShinkiStyle.listRowSize
                wrapMode: Text.Wrap
            }
            QQC2.Label {
                objectName: "listRowSubtitle"
                Layout.fillWidth: true
                visible: row.subtitle !== ""
                text: row.subtitle
                color: ShinkiStyle.inkMuted
                font.family: ShinkiStyle.uiFamily
                font.pixelSize: ShinkiStyle.smallSize
                wrapMode: Text.Wrap
            }
        }
        QQC2.Label {
            visible: row.meta !== ""
            Layout.alignment: Qt.AlignVCenter
            text: row.meta
            color: ShinkiStyle.inkMuted
            font.family: ShinkiStyle.uiFamily
            font.pixelSize: ShinkiStyle.smallSize
            font.features: { "tnum": 1 }
        }
        RowLayout {
            id: trailingSlot

            Layout.alignment: Qt.AlignVCenter
        }
    }
}
