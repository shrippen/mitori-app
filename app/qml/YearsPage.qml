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

    readonly property int dayMs: 24 * 60 * 60 * 1000

    // The same levels as the statistics' calendar: 1–2, 3–5, 6–9, 10 and more techniques.
    readonly property var bounds: [1, 3, 6, 10]
    function levelOf(count) {
        return page.bounds.filter(b => count >= b).length
    }

    title: qsTr("All years")

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
                // The whole year in the width on a wide window; on a phone the cells keep a size that
                // reads and the year scrolls sideways, from its latest weeks. Weekday names kept.
                Flickable {
                    id: heatBox

                    Layout.fillWidth: true
                    implicitHeight: heat.implicitHeight
                    contentWidth: heat.implicitWidth
                    contentHeight: heat.implicitHeight
                    flickableDirection: Flickable.HorizontalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    // The newest weeks are the ones that count.
                    function toEnd() {
                        contentX = Math.max(0, contentWidth - width)
                    }
                    onWidthChanged: toEnd()
                    onContentWidthChanged: toEnd()

                    LookCalendarHeatmap {
                        id: heat

                        objectName: "yearHeatmap"
                        cellSize: Math.max(Look.unit(10), Math.min(Look.unit(20),
                                               Math.floor((heatBox.width - labelWidth + spacing) / weeks) - spacing))
                        // From the week of 1 January to the last day.
                        weeks: {
                            const jan = new Date(yearBlock.modelData, 0, 1, 12)
                            const offset = (jan.getDay() - firstDayOfWeek % 7 + 7) % 7
                            const days = Math.round((yearBlock.endDate - jan) / page.dayMs) + 1
                            return Math.ceil((offset + days) / 7)
                        }
                        endDate: yearBlock.endDate
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

        LookLabel {
            Layout.fillWidth: true
            text: qsTr("Columns: weeks, rows: weekdays. A technique counts once on each day it is rated.")
            color: Look.mutedTextColor
            font: Look.smallFont
            wrapMode: Text.Wrap
        }
    }
}
