import QtQuick
import Shinki

// The roles of Look.qml under Shinki (shinki/README.md): the same names, from ShinkiStyle.
// Shinki has one colour: red is the accent, errors are red with a word, success is ink.
QtObject {
    readonly property bool shinki: true

    readonly property color backgroundColor: ShinkiStyle.paper
    readonly property color textColor: ShinkiStyle.ink
    readonly property color mutedTextColor: ShinkiStyle.inkMuted
    readonly property color disabledTextColor: ShinkiStyle.inkMuted
    readonly property color accentColor: ShinkiStyle.red
    readonly property color negativeTextColor: ShinkiStyle.red
    readonly property color positiveTextColor: ShinkiStyle.ink
    readonly property color neutralTextColor: ShinkiStyle.inkMuted
    readonly property color cardColor: ShinkiStyle.paperAlt
    readonly property color ruleColor: ShinkiStyle.line
    readonly property color stageColor: ShinkiStyle.video
    readonly property color stageTextColor: ShinkiStyle.videoText
    // The grounds of the areas a page names: the chip, the selected row, the scrim behind a
    // sheet, the text on the accent.
    readonly property color chipColor: ShinkiStyle.chip
    readonly property color selectedColor: ShinkiStyle.selected
    readonly property color scrimColor: ShinkiStyle.scrim
    readonly property color onAccentColor: ShinkiStyle.textOnRed
    readonly property int borderWidth: ShinkiStyle.lineWidth
    // The keyboard focus frame: 2 px ink, apart from red (chosen).
    readonly property color focusColor: ShinkiStyle.ink
    readonly property int focusWidth: ShinkiStyle.focusWidth

    readonly property font defaultFont: Qt.font({ family: ShinkiStyle.uiFamily, pixelSize: ShinkiStyle.uiSize })
    readonly property font smallFont: Qt.font({ family: ShinkiStyle.uiFamily, pixelSize: ShinkiStyle.smallSize })
    // Running text in the book face (Crimson Pro), as the bible's reading text.
    readonly property font readingFont: Qt.font({ family: ShinkiStyle.bookFamily, pixelSize: ShinkiStyle.readingSize })
    // The title of a sheet: the book face in the bible's size for it.
    readonly property font sheetTitleFont: Qt.font({ family: ShinkiStyle.bookFamily, weight: Font.DemiBold,
                                                     pixelSize: ShinkiStyle.sheetTitleSize })
    // The face of a column: the narrow one (PT Sans Narrow), as the bible's small caps lines.
    readonly property font narrowFont: Qt.font({ family: ShinkiStyle.narrowFamily, pixelSize: ShinkiStyle.columnSize, bold: true })
    // The letter spacing of a column, in em ("Sperrung 0,1 em").
    readonly property real columnTracking: ShinkiStyle.columnTracking
    // A change of state (a fade); 0 without motion (bible, "Bewegung").
    readonly property int stateDuration: ShinkiStyle.animate ? ShinkiStyle.stateDuration : 0

    function unit(px) {
        return ShinkiStyle.unit(px)
    }
    function levelColor(level) {
        return ShinkiStyle.levelColor(level)
    }
    // The text on a level's ground: the ink the bible names for it.
    function levelTextColor(level) {
        return ShinkiStyle.levelTextColor(level)
    }
    // Figures in the bible's face with table figures (Shinki has no mono face).
    function monoFont(pointSize) {
        return pointSize > 0 ? Qt.font({ family: ShinkiStyle.uiFamily, pointSize: pointSize, features: { "tnum": 1 } })
                             : Qt.font({ family: ShinkiStyle.uiFamily, pixelSize: ShinkiStyle.smallSize, features: { "tnum": 1 } })
    }
    // Titles in the book face (Crimson Pro), as the sheet and player titles of the bible; without
    // a size the player title's.
    function titleFont(pointSize) {
        return pointSize > 0 ? Qt.font({ family: ShinkiStyle.bookFamily, weight: Font.DemiBold, pointSize: pointSize })
                             : Qt.font({ family: ShinkiStyle.bookFamily, weight: Font.DemiBold, pixelSize: ShinkiStyle.playerTitleSize })
    }
    // Large display text (a mock exam's technique): the book face, as technique names are set.
    function headingFont(pointSize) {
        return Qt.font({ family: ShinkiStyle.bookFamily, weight: Font.DemiBold, pointSize: pointSize })
    }
    // A font in the Mincho, its size as the base has it (points or pixels, never both).
    function japaneseFont(base) {
        const font = base ? base : defaultFont
        return font.pointSize > 0 ? Qt.font({ family: ShinkiStyle.japaneseFamily, pointSize: font.pointSize, weight: font.weight })
                                  : Qt.font({ family: ShinkiStyle.japaneseFamily, pixelSize: font.pixelSize, weight: font.weight })
    }
}
