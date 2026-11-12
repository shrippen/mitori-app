import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// A tile of the start menu (the bento): kanji and title at once, then what the tile shows once its
// summary has arrived (StartBoard); until then a quiet placeholder. The ground, frame and focus are
// the look's tile (LookTile); `hint` is what a screen reader hears. The tile's own content goes
// into the body (a ColumnLayout).
LookTile {
    id: tile

    // The summary has arrived.
    property bool filled: false
    // A line beside the title (the discipline on the programme tile).
    property string subtitle: ""
    // The height of one cell of the grid, and so of this tile: its rows, with the gaps between.
    property real cellHeight: 0
    // The body takes the tile's free height (a map that fills it); else it sits at the top.
    property bool stretch: false
    default property alias body: bodyLayout.data

    readonly property real base: Look.defaultFont.pointSize > 0 ? Look.defaultFont.pointSize : 10
    // The spacing between the tile's blocks.
    readonly property real gap: Look.unit(6)

    Layout.fillWidth: true
    Layout.preferredWidth: 1            // equal columns, whatever the content
    Layout.minimumWidth: 0
    Layout.preferredHeight: cellHeight * Layout.rowSpan + Kirigami.Units.largeSpacing * (Layout.rowSpan - 1)
    Layout.minimumHeight: Layout.preferredHeight
    Layout.maximumHeight: Layout.preferredHeight

    contentItem: ColumnLayout {
        spacing: tile.gap

        RowLayout {
            Layout.fillWidth: true
            spacing: Look.unit(8)

            QQC2.Label {
                Layout.alignment: Qt.AlignTop
                visible: tile.glyph !== ""
                text: tile.glyph
                color: Look.accentColor
                font: Look.japaneseFont(Look.titleFont(tile.base * (tile.big ? 2.2 : 1.6)))
                Accessible.ignored: true
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 0

                LookLabel {
                    Layout.fillWidth: true
                    text: tile.text
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                LookLabel {
                    objectName: "tileSubtitle"
                    Layout.fillWidth: true
                    visible: tile.subtitle !== ""
                    text: tile.subtitle
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    elide: Text.ElideRight
                }
            }
        }

        ColumnLayout {
            id: bodyLayout

            Layout.fillWidth: true
            Layout.fillHeight: tile.stretch
            Layout.alignment: Qt.AlignTop
            visible: tile.filled
            spacing: tile.gap
        }

        // What stands until the summary comes.
        ColumnLayout {
            objectName: "tilePlaceholder"
            Layout.fillWidth: true
            visible: !tile.filled
            spacing: tile.gap

            Repeater {
                model: 2

                Rectangle {
                    required property int index

                    Layout.fillWidth: index === 0
                    Layout.preferredWidth: Look.unit(56)
                    Layout.preferredHeight: Look.unit(8)
                    color: Look.ruleColor
                    opacity: 0.6
                }
            }
        }

        // The free height below a body that does not take it.
        Item {
            Layout.fillHeight: !tile.stretch
            Layout.preferredHeight: 0
        }
    }
}
