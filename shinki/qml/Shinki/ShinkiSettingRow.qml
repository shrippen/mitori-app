import QtQuick
import QtQuick.Layouts

// Setting row (bible section 5, Einstellungszeile): title and hint on the left, the control
// (children) on the right, a line under it. `modified`: a red square at the title and "Reset" as
// a link (resetRequested()). `section`: a column above the row. `narrow`: the control below the
// texts. `titleWidth` > 0: a shared title column for a group. Same interface as KanteSettingRow.
//
//   RANDOM ORDER ─────────────────────        section
//   Random order ■               [▮  ]       title, mark, control
//   off: as in the exam programme             hint
Item {
    id: row

    property string title: ""
    property string hint: ""
    property bool modified: false
    property string resetText: qsTr("Reset")
    property bool narrow: width > 0 && width < ShinkiStyle.unit(360)
    property real titleWidth: 0
    property string section: ""
    default property alias control: controlSlot.data

    signal resetRequested()

    readonly property real implicitTitleWidth: Math.min(ShinkiStyle.unit(280),
        Math.max(titleText.implicitWidth + ShinkiStyle.cardSpace, hintText.implicitWidth))

    implicitWidth: ShinkiStyle.unit(420)
    implicitHeight: column.implicitHeight + 2 * ShinkiStyle.gridSpace * 2

    ColumnLayout {
        id: column

        y: ShinkiStyle.gridSpace * 2
        width: parent.width
        spacing: ShinkiStyle.gridSpace * 2

        ShinkiSectionLabel {
            Layout.fillWidth: true
            visible: row.section !== ""
            text: row.section
        }

        GridLayout {
            Layout.fillWidth: true
            columns: row.narrow ? 1 : 2
            columnSpacing: ShinkiStyle.pageSpace
            rowSpacing: ShinkiStyle.gridSpace * 2

            ColumnLayout {
                Layout.fillWidth: row.narrow || row.titleWidth <= 0
                Layout.preferredWidth: !row.narrow && row.titleWidth > 0 ? row.titleWidth : -1
                Layout.alignment: Qt.AlignTop
                spacing: ShinkiStyle.gridSpace

                Row {
                    spacing: ShinkiStyle.gridSpace * 2

                    Text {
                        id: titleText

                        text: row.title
                        color: ShinkiStyle.ink
                        font.family: ShinkiStyle.uiFamily
                        font.pixelSize: ShinkiStyle.uiSize
                    }
                    Rectangle {
                        visible: row.modified
                        anchors.verticalCenter: parent.verticalCenter
                        width: ShinkiStyle.levelDotSize
                        height: width
                        color: ShinkiStyle.red
                    }
                }
                Text {
                    id: hintText

                    Layout.fillWidth: true
                    visible: row.hint !== ""
                    text: row.hint
                    color: ShinkiStyle.inkMuted
                    font.family: ShinkiStyle.uiFamily
                    font.pixelSize: ShinkiStyle.smallSize
                    wrapMode: Text.WordWrap
                }
            }
            RowLayout {
                Layout.fillWidth: !row.narrow && row.titleWidth > 0
                Layout.alignment: Qt.AlignVCenter | (row.narrow || row.titleWidth > 0 ? Qt.AlignLeft : Qt.AlignRight)
                spacing: ShinkiStyle.gridSpace * 2

                Item {
                    id: controlSlot

                    implicitWidth: childrenRect.width
                    implicitHeight: childrenRect.height
                }
                ShinkiButton {
                    visible: row.modified
                    link: true
                    text: row.resetText
                    onClicked: row.resetRequested()
                }
                Item {
                    visible: !row.narrow && row.titleWidth > 0
                    Layout.fillWidth: true
                }
            }
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: ShinkiStyle.lineWidth
        color: ShinkiStyle.line
    }
}
