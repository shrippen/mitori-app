pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "grades.js" as Grades

// All years (clickdummy "Übungstage, alle Jahre"): one calendar per year, the newest first, from
// the year of the first rating; all disciplines or one. Each year names its practice days, the
// techniques and the grades passed in it.
//
//   [All] [Aikido] [Daitoryu] [Shinki Toho]
//   2026 · 48 practice days · 312 techniques · Aikido 4. Kyu
//   ▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦▦   the whole year in the width
Kirigami.ScrollablePage {
    id: page

    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    // "" all, else a discipline's id.
    property string discipline: ""
    // Today as a date; reading Practice.today makes it follow midnight (a new year included).
    readonly property date todayDate: {
        Practice.today
        return new Date()
    }
    readonly property var years: {
        Practice.revision
        const list = []
        for (let y = page.todayDate.getFullYear(); y >= Practice.firstYear(); y--) {
            list.push(y)
        }
        return list
    }

    // The width the years have: not their own, which follows their heatmaps' implicit width.
    readonly property real bodyWidth: width - leftPadding - rightPadding

    readonly property int dayMs: 24 * 60 * 60 * 1000

    // The same levels as the statistics' calendar: 1–2, 3–5, 6–9, 10 and more techniques.
    readonly property var bounds: [1, 3, 6, 10]
    function levelOf(count) {
        return page.bounds.filter(b => count >= b).length
    }

    title: qsTr("All years")

    // Not shown: its label width, spacing and first weekday size the years' heatmaps.
    LookCalendarHeatmap {
        id: probe

        visible: false
        weeks: 1
    }

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        LookSegmented {
            objectName: "yearsDiscipline"
            Layout.fillWidth: true
            model: [qsTr("All")].concat(Programme.disciplines.map(d => d.kurzname))
            currentIndex: page.discipline === "" ? 0 : 1 + Programme.disciplines.findIndex(d => d.id === page.discipline)
            onActivated: index => page.discipline = index === 0 ? "" : Programme.disciplines[index - 1].id
        }
        LookLegend {
            objectName: "yearsLegend"
            Layout.fillWidth: true
            model: [{ color: Look.levelColor(0), text: qsTr("no practice") },
                    { color: Look.levelColor(1), text: qsTr("1–2 techniques") },
                    { color: Look.levelColor(2), text: "3–5" },
                    { color: Look.levelColor(3), text: "6–9" },
                    { color: Look.levelColor(4), text: qsTr("10 and more") }]
        }

        Repeater {
            model: page.years

            ColumnLayout {
                id: yearBlock

                required property int modelData
                readonly property var perDay: (modelData === page.todayDate.getFullYear() ? Practice.revision : Practice.historyRevision) >= 0 ? Practice.practisedInYear(modelData, page.discipline) : ({})
                readonly property var days: Object.keys(perDay)
                readonly property var grades: (Courses.revision >= 0 ? Courses.grades : [])
                    .filter(g => g.day.startsWith(String(modelData)) && (page.discipline === "" || g.discipline === page.discipline))
                // The year's last day shown: today in the current year.
                readonly property date endDate: modelData === page.todayDate.getFullYear()
                                                ? page.todayDate : new Date(modelData, 11, 31, 12)

                // The heatmaps of the year for a page `width` wide: the whole year where its cells keep
                // Look.unit(8), else January to the week of 30 June and the weeks after it. Each is
                // its last day, its number of weeks and the weeks that set the cell size (the same in both).
                function parts(width) {
                    const jan = new Date(modelData, 0, 1, 12)
                    const offset = (jan.getDay() - probe.firstDayOfWeek % 7 + 7) % 7
                    const days = Math.round((endDate - jan) / page.dayMs) + 1
                    const weeks = Math.ceil((offset + days) / 7)
                    const whole = { end: endDate, weeks: weeks, span: weeks }
                    if (Math.floor((width - probe.labelWidth + probe.spacing) / weeks) - probe.spacing >= Look.unit(8)) {
                        return [whole]
                    }
                    // The week of 30 June is the last of the first half; none for a year that has not got there.
                    const june = Math.round((new Date(modelData, 5, 30, 12) - jan) / page.dayMs)
                    const first = Math.floor((offset + june) / 7) + 1
                    if (first >= weeks) {
                        return [whole]
                    }
                    const firstEnd = new Date(modelData, 0, 1 - offset + first * 7 - 1, 12)
                    return [{ end: firstEnd, weeks: first, span: first }, { end: endDate, weeks: weeks - first, span: first }]
                }

                objectName: "year_" + modelData
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                LookSectionLabel {
                    objectName: "yearHeading"
                    Layout.fillWidth: true
                    rule: true
                    text: [String(yearBlock.modelData),
                           qsTr("%n practice day(s)", "", yearBlock.days.length),
                           qsTr("%n technique(s)", "", yearBlock.days.reduce((sum, d) => sum + yearBlock.perDay[d], 0))]
                          .concat(yearBlock.grades.map(g => (Programme.disciplines.find(d => d.id === g.discipline) || {}).kurzname + " " + g.name))
                          .join(" · ")
                }
                // The whole year in the width on a wide window. Where its cells would be smaller than
                // Look.unit(8), two halves one above the other (January to June, then the rest), each
                // with its weekday and month names. Weekday names kept.
                ColumnLayout {
                    id: heatBox

                    // Whole or in halves; the heatmaps are built anew only when that changes, not at
                    // every pixel a window is resized (a year's tips take their time).
                    readonly property bool split: yearBlock.parts(page.bodyWidth).length > 1
                    readonly property var shown: yearBlock.parts(split ? 0 : Number.MAX_VALUE)

                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Repeater {
                        model: heatBox.shown

                        LookCalendarHeatmap {
                            id: heat

                            required property var modelData

                            objectName: "yearHeatmap"
                            cellSize: Math.max(Look.unit(4), Math.min(Look.unit(20),
                                               Math.floor((page.bodyWidth - labelWidth + spacing) / modelData.span) - spacing))
                            weeks: modelData.weeks
                            endDate: modelData.end
                            levels: {
                                const l = {}
                                for (const d of yearBlock.days) {
                                    l[d] = page.levelOf(yearBlock.perDay[d])
                                }
                                return l
                            }
                            // Every day of the year says what it was, also one without practice. A text
                            // per count, not per day (five years of days took 120 ms), from the
                            // heatmap's dates (no Date per day).
                            tips: {
                                const t = {}
                                const texts = { 0: qsTr("no practice") }
                                const year = String(yearBlock.modelData)
                                for (const cell of heat.cells) {
                                    if (!cell.shown || !cell.iso.startsWith(year)) {
                                        continue
                                    }
                                    const n = yearBlock.perDay[cell.iso] || 0
                                    if (!(n in texts)) {
                                        texts[n] = qsTr("%n technique(s)", "", n)
                                    }
                                    t[cell.iso] = texts[n]
                                }
                                return t
                            }
                            Accessible.name: qsTr("Practice days %1").arg(yearBlock.modelData)
                        }
                    }
                }
            }
        }

        LookLabel {
            Layout.fillWidth: true
            text: qsTr("Columns: weeks, rows: weekdays. A technique counts once on each day it is rated.")
            color: Look.mutedTextColor
            font: Look.smallFont
            wrapMode: Text.Wrap
        }
    }
}
