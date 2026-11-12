pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "playlists.js" as Playlists

// Technique map (clickdummy "Landkarte"): every grade up to the chosen one, one group at a time
// (app-entscheidungen.md: groups apart), techniques against attacks, each place coloured by how
// well it sits; Shinki Toho as the numbered Ô-dachi forms. A place opens the technique sheet, on a wide window it shows the technique beside the map.
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's,
    // and the style's page ground (the scope's background role is the dialog colour).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }
    // Tab and the arrow keys keep the focused place in view.
    property LookFocusFollow focusFollow: LookFocusFollow { flickable: page.flickable }

    property string discipline: Programme.discipline
    readonly property var grades: Programme.grades(discipline)
    // Up to which grade: starts at the practice grade, then only this page's (browsing).
    property string grade: PracticeGrade.grade(discipline)
    readonly property string gradeName: (grades.find(g => g.id === grade) || {}).name || ""
    readonly property var grids: Programme.techniqueMap(discipline, grade)
    // The group shown, by title; the first one when the chosen one has nothing up to this grade.
    property string group: ""
    readonly property var shown: grids.find(g => g.title === group) || grids[0] || null
    readonly property bool matrix: !!shown && shown.kind === "matrix"
    readonly property bool wide: Tablet.wide(width, height)
    // Wide: the technique shown in the panel, and the place marked (grid title, row, column).
    property var paneEntry: null
    property string markTitle: ""
    property int markRow: 0
    property int markColumn: 0
    property Item ring: null

    title: qsTr("Technique map")

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // The filters stand together and wrap: discipline, "up to" grade, group (groups apart: one
        // grid at a time).
        Flow {
            id: filters

            objectName: "mapFilters"
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            LookSegmented {
                // A phone: a line of its own.
                width: page.wide ? implicitWidth : filters.width
                model: Programme.disciplines.map(d => d.kurzname)
                currentIndex: Programme.disciplines.findIndex(d => d.id === page.discipline)
                onActivated: index => {
                    page.discipline = Programme.disciplines[index].id
                    page.grade = PracticeGrade.grade(page.discipline)
                }
            }

            LookComboBox {
                objectName: "gradeBox"
                model: page.grades.map(g => g.name)
                currentIndex: page.grades.findIndex(g => g.id === page.grade)
                displayText: qsTr("up to %1").arg(page.gradeName)
                Accessible.name: qsTr("Grade")
                onActivated: index => page.grade = page.grades[index].id
            }

            Repeater {
                model: page.matrix ? page.grids : []

                LookChip {
                    required property var modelData

                    objectName: "groupChip"
                    text: modelData.title
                    checkable: true
                    checked: !!page.shown && modelData.title === page.shown.title
                    onClicked: page.group = modelData.title
                }
            }
        }

        LookLabel {
            Layout.fillWidth: true
            visible: !page.shown
            text: qsTr("No techniques with an attack up to %1.").arg(page.gradeName)
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing

            // The map, centred in its area on a wide window.
            ColumnLayout {
                id: area

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.largeSpacing

                LookSectionLabel {
                    visible: !!page.shown
                    text: page.shown ? page.shown.title + (page.shown.jp ? "  " + page.shown.jp : "") : ""
                }

                // Techniques × attacks of one group (LookHeatGrid); a blank gap where a
                // technique does not answer an attack up to the grade.
                LookHeatGrid {
                    id: heat

                    readonly property var rows: page.matrix ? page.shown.rows : []
                    readonly property var columns: page.matrix ? page.shown.columns : []

                    objectName: "techniqueMatrix"
                    // Phone: the width, scrolling sideways. Wide: its own width, centred in the area.
                    Layout.fillWidth: !page.wide
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: area.width
                    visible: page.matrix
                    minValue: 0
                    maxValue: 4                     // whole values are the levels
                    showEmpty: false
                    columnLabelsVertical: true
                    columnLabelMaxLength: Kirigami.Units.gridUnit * 9
                    rowLabelWidth: page.wide ? Look.unit(220) : page.width * 0.4
                    rowLabelFont: Look.smallFont     // long technique names, readable on a phone
                    cellSize: page.wide ? Look.unit(34) : Look.unit(26)
                    rowTitle: qsTr("Technique")
                    columnTitle: qsTr("Attack")
                    rowLabels: rows.map(r => r.title)
                    columnLabels: columns.map(c => page.attackName(c))
                    columnTips: columns.map(c => c.jp ? page.attackName(c) + "  " + c.jp : "")
                    // Rows and columns of the same grid (not heat.columns, which may follow a moment later).
                    cells: {
                        const g = page.matrix && Practice.revision >= 0 ? page.shown : { rows: [], columns: [] }
                        return g.rows.map(r => r.cells.map((c, i) => c.ids ? page.place(c, r.title, page.attackName(g.columns[i])) : null))
                    }
                    legendLabels: page.levelWords()
                    noDataText: qsTr("no such combination")
                    onActivated: (row, column) => page.pick(rows[row].cells[column].entry, row, column)
                }

                // Shinki Toho: the Ô-dachi forms, numbered, a fixed number per row filling the width.
                LookHeatGrid {
                    id: forms

                    readonly property var list: page.shown && !page.matrix ? page.shown.cells : []
                    readonly property int perRow: page.wide ? 11 : 8

                    objectName: "formGrid"
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.maximumWidth: Look.unit(560)
                    visible: !!page.shown && !page.matrix
                    minValue: 0
                    maxValue: 4
                    showEmpty: false
                    scrollable: false
                    fillWidth: true
                    cells: {
                        const out = []
                        for (let i = 0; Practice.revision >= 0 && i < list.length; i += perRow) {
                            const row = list.slice(i, i + perRow).map(f => page.place(f, String(f.entry.nr), f.entry.title, page.formLabel(f)))
                            while (row.length < perRow) {
                                row.push(null)
                            }
                            out.push(row)
                        }
                        return out
                    }
                    legendLabels: page.levelWords()      // the number after the dot
                    noDataText: ""
                    onActivated: (row, column) => page.pick(list[row * perRow + column].entry, row, column)
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: !!page.shown
                    text: page.matrix
                          ? qsTr("Rows: technique, columns: attack. An empty place does not occur up to %1. Tap a place to open the technique.").arg(page.gradeName)
                          : qsTr("A place per form: its number, after the dot its level (12·3). Tap a place to open the form.")
                    color: Look.mutedTextColor
                    font: Look.smallFont
                    wrapMode: Text.Wrap
                }

            }

            // Beside the map: the place tapped (wide window); a phone opens the sheet instead.
            Rectangle {
                id: panel

                objectName: "mapPanel"
                Layout.preferredWidth: Look.unit(360)
                Layout.alignment: Qt.AlignTop
                implicitHeight: (paneBody.visible ? paneBody.implicitHeight : panelHint.implicitHeight) + 2 * Look.unit(16)
                visible: page.wide
                color: Look.backgroundColor
                border.width: Look.borderWidth
                border.color: Look.ruleColor

                LookLabel {
                    id: panelHint

                    objectName: "mapPanelHint"
                    x: Look.unit(16)
                    y: Look.unit(16)
                    width: panel.width - 2 * x
                    visible: !page.paneEntry
                    text: qsTr("Tap a place to see it here.")
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }

                TechniqueBody {
                    id: paneBody

                    objectName: "paneSheet"
                    x: Look.unit(16)
                    y: Look.unit(16)
                    width: panel.width - 2 * x
                    visible: !!page.paneEntry
                    inPane: true
                    entry: page.paneEntry || ({})
                    playable: page.paneEntry ? page.playable(page.paneEntry) : false
                    onScrollKey: event => paneBody.scrollIn(page.flickable, event)
                    onPlayRequested: entry => page.play(entry)
                    onProgrammeRequested: entry => page.paneEntry = entry
                    onLessonRequested: entry => page.paneEntry = entry
                    onCommentRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("CommentPage.qml"), { entry: entry })
                    onNotesRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), { entry: entry })
                    onVideosRequested: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
                }
            }
        }
    }

    function attackName(column) {
        return column.extra ? column.title + " · " + column.extra : column.title
    }
    // A cell of a grid: the best level of its entries, its tip "row · column · grades: level" (every
    // grade of its entries: "5. Kyu, 4. Kyu"). The level as its number unless `label` is given (a
    // form's number).
    function place(cell, rowName, columnName, label) {
        const level = Practice.bestLevel(cell.ids)
        const more = cell.ids.length > 1 ? " · " + qsTr("%n entries", "", cell.ids.length) : ""
        return {
            value: level,
            label: label !== undefined ? label : (level > 0 ? String(level) : ""),
            tip: qsTr("%1 · %2 · %3: %4").arg(rowName).arg(columnName).arg(cell.gradeNames.join(", ")).arg(Practice.levelNames[level]) + more
        }
    }
    // A form's place: its number, and its level after a dot once rated ("12·3"), so the colour is
    // not the only sign of the level.
    function formLabel(form) {
        const level = Practice.bestLevel(form.ids)
        return level > 0 ? form.entry.nr + "·" + level : String(form.entry.nr)
    }
    // The legend's words by level, the number first, as the places show it.
    function levelWords() {
        return Practice.levelNames.map((name, l) => l > 0 ? l + " " + name : name)
    }

    function playable(entry) {
        return !!entry.video && Videos.available(entry.video.video)
    }

    function open(entry) {
        sheet.entry = entry
        sheet.playable = page.playable(entry)
        sheet.open()
    }

    function play(entry) {
        sheet.close()
        const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
        window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), Playlists.around(Programme, Videos, Library, entry))
    }

    // A tap: wide, the panel shows the place and a ring marks it; a phone opens the sheet.
    function pick(entry, row, column) {
        if (!page.wide) {
            page.open(entry)
            return
        }
        page.paneEntry = entry
        page.markRow = row
        page.markColumn = column
        page.markTitle = page.shown.title
        Qt.callLater(page.mark)
    }

    // The ring on the tapped place: a child of its cell, so it follows a scroll; made anew when the
    // grid builds its cells again.
    function mark() {
        if (page.ring) {
            page.ring.destroy()
            page.ring = null
        }
        if (!page.wide || !page.paneEntry || !page.shown || page.markTitle !== page.shown.title) {
            return
        }
        const grid = page.matrix ? heat : forms
        const cell = grid.cellAt(page.markRow, page.markColumn)
        if (cell) {
            page.ring = ringComponent.createObject(cell)
        }
    }

    // Another grid (discipline, grade, group): the places moved, the mark goes.
    onShownChanged: {
        page.paneEntry = null
        Qt.callLater(page.mark)
    }
    onWideChanged: Qt.callLater(page.mark)

    Connections {
        target: heat
        function onCellsChanged() { Qt.callLater(page.mark) }
    }

    Connections {
        target: forms
        function onCellsChanged() { Qt.callLater(page.mark) }
    }

    Component {
        id: ringComponent

        Rectangle {
            objectName: "placeRing"
            // Outside the cell, above the grid's own focus ring, a line of ground between ring and
            // cell: the cell's fill may be the focus colour (level 4).
            anchors.fill: parent
            anchors.margins: -3 * Look.borderWidth
            z: 1
            color: "transparent"
            border.width: 2 * Look.borderWidth
            border.color: Look.focusColor

            Rectangle {
                anchors.fill: parent
                anchors.margins: 2 * Look.borderWidth
                color: "transparent"
                border.width: Look.borderWidth
                border.color: Look.backgroundColor
            }
        }
    }

    TechniqueSheet {
        id: sheet

        objectName: "techniqueSheet"
        onPlayRequested: entry => page.play(entry)
        onCommentRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("CommentPage.qml"), { entry: entry })
        onNotesRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), { entry: entry })
        onVideosRequested: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
    }
}
