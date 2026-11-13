pragma Singleton
import QtQuick

// The roles a page reads (shinki/README.md, section 6). A page names the role
// (Look.mutedTextColor), never KanteStyle or ShinkiStyle. The values come from LookRoles: Kante's
// file or, by the file selector "shinki", Shinki's. A singleton lives as long as its engine, the
// style does not: after a change of the selector `reload` reads the roles anew, and every page
// built then gets them (Appearance::rebuild).
QtObject {
    id: look

    property var roles: load()

    function load() {
        return Qt.createComponent("LookRoles.qml").createObject(look)
    }
    function reload() {
        const old = roles
        roles = load()
        old.destroy()
    }

    readonly property bool shinki: roles.shinki
    readonly property color backgroundColor: roles.backgroundColor
    readonly property color textColor: roles.textColor
    readonly property color mutedTextColor: roles.mutedTextColor
    readonly property color disabledTextColor: roles.disabledTextColor
    readonly property color accentColor: roles.accentColor
    readonly property color negativeTextColor: roles.negativeTextColor
    readonly property color positiveTextColor: roles.positiveTextColor
    readonly property color neutralTextColor: roles.neutralTextColor
    readonly property color cardColor: roles.cardColor
    readonly property color ruleColor: roles.ruleColor
    readonly property color stageColor: roles.stageColor
    readonly property color stageTextColor: roles.stageTextColor
    readonly property color chipColor: roles.chipColor
    readonly property color selectedColor: roles.selectedColor
    readonly property color scrimColor: roles.scrimColor
    readonly property color onAccentColor: roles.onAccentColor
    readonly property int borderWidth: roles.borderWidth
    readonly property color focusColor: roles.focusColor
    readonly property int focusWidth: roles.focusWidth
    readonly property int cardPadding: roles.cardPadding
    readonly property font defaultFont: roles.defaultFont
    readonly property font smallFont: roles.smallFont
    readonly property font readingFont: roles.readingFont
    readonly property font sheetTitleFont: roles.sheetTitleFont
    readonly property font narrowFont: roles.narrowFont
    readonly property real columnTracking: roles.columnTracking
    readonly property int stateDuration: roles.stateDuration

    function unit(px) {
        return roles.unit(px)
    }
    function levelColor(level) {
        return roles.levelColor(level)
    }
    function levelTextColor(level) {
        return roles.levelTextColor(level)
    }
    function monoFont(pointSize) {
        return roles.monoFont(pointSize)
    }
    function headingFont(pointSize) {
        return roles.headingFont(pointSize)
    }
    function titleFont(pointSize) {
        return roles.titleFont(pointSize)
    }
    function japaneseFont(base) {
        return roles.japaneseFont(base)
    }
}
