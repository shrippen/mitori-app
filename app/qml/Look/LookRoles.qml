import QtQuick
import Kante

// The roles of Look.qml from Kante: Breeze, Material, Kante and Leinen. Under Shinki the file
// selector takes +shinki/LookRoles.qml with the same names.
QtObject {
    readonly property bool shinki: false

    readonly property color backgroundColor: KanteStyle.backgroundColor
    readonly property color textColor: KanteStyle.textColor
    readonly property color mutedTextColor: KanteStyle.mutedTextColor
    readonly property color disabledTextColor: KanteStyle.disabledTextColor
    readonly property color accentColor: KanteStyle.focusColor
    readonly property color negativeTextColor: KanteStyle.negativeTextColor
    readonly property color positiveTextColor: KanteStyle.positiveTextColor
    readonly property color neutralTextColor: KanteStyle.neutralTextColor
    readonly property color cardColor: KanteStyle.cardColor
    readonly property color ruleColor: KanteStyle.ruleColor
    readonly property color stageColor: KanteStyle.stageColor
    readonly property color stageTextColor: KanteStyle.stageTextColor
    // The grounds of the areas a page names: the chip, the selected row, the scrim behind a
    // sheet, the text on the accent.
    readonly property color chipColor: KanteStyle.sunkenColor
    readonly property color selectedColor: KanteStyle.tintHighlightColor
    readonly property color scrimColor: KanteStyle.scrimColor
    readonly property color onAccentColor: KanteStyle.primaryTextColor
    readonly property int borderWidth: KanteStyle.borderWidth
    // The keyboard focus frame.
    readonly property color focusColor: KanteStyle.focusColor
    readonly property int focusWidth: KanteStyle.borderWidth

    readonly property font defaultFont: KanteStyle.defaultFont
    readonly property font smallFont: KanteStyle.smallFont
    // Running text: Kante reads in its own face; a theme with a book face sets its own here.
    readonly property font readingFont: defaultFont
    // The title of a sheet (the technique sheet): the style's title face.
    readonly property font sheetTitleFont: KanteStyle.titleFont(KanteStyle.unit(25))
    // The face of a column: a narrow one for the small caps lines (a kicker). A theme without a
    // narrow face uses its own.
    readonly property font narrowFont: defaultFont
    // The letter spacing of a column, in em (the kicker's wide spacing).
    readonly property real columnTracking: 0
    // A change of state (a fade); 0 without motion.
    readonly property int stateDuration: KanteStyle.durationFast

    function unit(px) {
        return KanteStyle.unit(px)
    }
    // Level 0..4 (open … exam-ready).
    function levelColor(level) {
        return KanteStyle.levelColor(level)
    }
    // The text on a level's ground: the ink that reads on it.
    function levelTextColor(level) {
        return KanteStyle.readable(KanteStyle.levelColor(level), KanteStyle.cardColor)
    }
    // Figures that line up (times, counts).
    function monoFont(pointSize) {
        return KanteStyle.monoFont(pointSize)
    }
    // Large display text (a mock exam's technique).
    function headingFont(pointSize) {
        return KanteStyle.headingFont(pointSize)
    }
    function titleFont(pointSize) {
        return KanteStyle.titleFont(pointSize)
    }
    function japaneseFont(base) {
        return KanteStyle.japaneseFont(base)
    }
}
