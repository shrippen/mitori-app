pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "playlists.js" as Playlists

// Technique map (clickdummy "Landkarte"): every grade up to the chosen one, one group at a time
// (app-entscheidungen.md: groups apart), techniques against attacks, each place coloured by how
// well it sits; Shinki Toho as the numbered Ô-dachi forms. A place opens the technique sheet.
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

    title: qsTr("Technique map")

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        LookSegmented {
            Layout.fillWidth: true
            model: Programme.disciplines.map(d => d.kurzname)
            currentIndex: Programme.disciplines.findIndex(d => d.id === page.discipline)
            onActivated: index => {
                page.discipline = Programme.disciplines[index].id
                page.grade = PracticeGrade.grade(page.discipline)
            }
        }

        Flow {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.grades

                LookChip {
                    required property var modelData

                    objectName: "gradeChip"
                    text: qsTr("up to %1").arg(modelData.name)
                    checkable: true
                    checked: modelData.id === page.grade
                    onClicked: page.grade = modelData.id
                }
            }
        }

        // Groups apart: one grid at a time.
        Flow {
            Layout.fillWidth: true
            visible: page.matrix
            spacing: Kirigami.Units.smallSpacing

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
            Layout.fillWidth: true
            visible: page.matrix
            minValue: 0
            maxValue: 4                     // whole values are the levels
            showEmpty: false
            columnLabelsVertical: true
            columnLabelMaxLength: Kirigami.Units.gridUnit * 9
            rowLabelWidth: page.width * 0.4
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
            onActivated: (row, column) => page.open(rows[row].cells[column].entry)
        }

        // Shinki Toho: the Ô-dachi forms, numbered, a fixed number per row filling the width.
        LookHeatGrid {
            id: forms

            readonly property var list: page.shown && !page.matrix ? page.shown.cells : []
            readonly property int perRow: page.wide ? 11 : 8

            objectName: "formGrid"
            Layout.fillWidth: true
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
            onActivated: (row, column) => page.open(list[row * perRow + column].entry)
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

    function open(entry) {
        sheet.entry = entry
        sheet.playable = !!entry.video && Videos.available(entry.video.video)
        sheet.open()
    }

    TechniqueSheet {
        id: sheet

        objectName: "techniqueSheet"
        onPlayRequested: entry => {
            sheet.close()
            const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
            window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), Playlists.around(Programme, Videos, Library, entry))
        }
        onCommentRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("CommentPage.qml"), { entry: entry })
        onNotesRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), { entry: entry })
        onVideosRequested: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
    }
}
