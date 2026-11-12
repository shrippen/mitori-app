import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// A tile of the start menu (the bento). The kanji stands top left at once, the title (and the hint)
// at the bottom; what the tile shows once its summary has arrived (StartBoard) lies between them,
// until then a quiet placeholder. The ground, frame and focus are the look's tile (LookTile).
//
//   ┌───────────────────────────┐
//   │ kanji               aside │   aside: top right (a figure, the discipline)
//   │          body             │   body: the value (default slot)
//   │ title / hint      corner │   corner: bottom right (a button)
//   └───────────────────────────┘
//
// `titleOnTop`: the big programme tile puts its title with the aside, and its bottom is the body's.
LookTile {
    id: tile

    // The summary has arrived.
    property bool filled: false
    // The body takes the tile's free height (a map, the programme tile's stand); else it sits in
    // the middle.
    property bool stretch: false
    // The title with the aside (top right) instead of at the bottom.
    property bool titleOnTop: false
    // The hint under the title (what a screen reader hears besides): shown unless a tile says its
    // own.
    property bool showHint: true
    // A line under the title at the top (the discipline on the programme tile).
    property string subtitle: ""
    // The height of one cell of the grid, and so of this tile: its rows, with the gaps between.
    property real cellHeight: 0
    default property alias body: bodyLayout.data
    property alias aside: asideLayout.data
    property alias corner: cornerLayout.data

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
            // The kanji stays at the top: only the body takes the free height.
            Layout.maximumHeight: implicitHeight
            spacing: Look.unit(8)

            QQC2.Label {
                Layout.alignment: Qt.AlignTop
                visible: tile.glyph !== ""
                text: tile.glyph
                color: Look.accentColor
                font: Look.japaneseFont(Look.titleFont(tile.base * (tile.big ? 6.5 : 1.8)))
                Accessible.ignored: true
            }
            Item {
                Layout.fillWidth: true
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignTop | Qt.AlignRight
                Layout.fillWidth: tile.titleOnTop
                spacing: 0

                LookLabel {
                    Layout.fillWidth: true
                    visible: tile.titleOnTop
                    text: tile.titleOnTop ? tile.text : ""
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
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
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
                ColumnLayout {
                    id: asideLayout

                    Layout.alignment: Qt.AlignRight
                    visible: tile.filled
                    spacing: 0
                }
            }
        }

        Item {
            Layout.fillHeight: !tile.stretch
            Layout.preferredHeight: 0
            visible: tile.filled
        }
        ColumnLayout {
            id: bodyLayout

            Layout.fillWidth: true
            Layout.fillHeight: tile.stretch
            visible: tile.filled
            spacing: tile.gap
        }
        Item {
            Layout.fillHeight: !tile.stretch
            Layout.preferredHeight: 0
            visible: tile.filled
        }

        // What stands until the summary comes.
        ColumnLayout {
            objectName: "tilePlaceholder"
            Layout.fillWidth: true
            Layout.fillHeight: true
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

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumHeight: implicitHeight
            spacing: Look.unit(8)

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignBottom
                visible: !tile.titleOnTop
                spacing: 0

                LookLabel {
                    Layout.fillWidth: true
                    text: tile.titleOnTop ? "" : tile.text
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                LookLabel {
                    objectName: "tileHint"
                    Layout.fillWidth: true
                    visible: tile.showHint && tile.hint !== ""
                    text: tile.hint
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }
            Item {
                Layout.fillWidth: true
                visible: tile.titleOnTop
            }
            ColumnLayout {
                id: cornerLayout

                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                visible: tile.filled
                spacing: 0
            }
        }
    }
}
