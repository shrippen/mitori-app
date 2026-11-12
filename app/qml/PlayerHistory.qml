pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Mitori

// The middle of the upright player (design "Kino"): how the technique was rated over time (the
// last ratings as bars by level, oldest left) and its last two notes, on the dark ground. It is
// never empty: without ratings or notes it says so.
ColumnLayout {
    id: history

    required property string entry
    // Only the bars and their span (a short middle): no heading, no list of notes.
    property bool compact: false
    readonly property int count: 8
    readonly property int levels: 4
    // [{day, at, level}], oldest first.
    readonly property var ratings: Practice.revision >= 0 && entry !== "" ? Practice.ratingHistory(entry, count) : []
    // How many notes the technique has.
    readonly property int noteCount: Practice.notesRevision >= 0 && entry !== "" ? Practice.notes(entry).length : 0
    // The newest two notes, newest first.
    readonly property var lastNotes: {
        if (Practice.notesRevision < 0 || entry === "") {
            return []
        }
        return Practice.notes(entry).slice(-2).reverse()
    }
    // "Sep → today": the month of the first bar (with the year when it is another), "today" if all
    // are today.
    readonly property string span: {
        if (ratings.length === 0) {
            return ""
        }
        const first = ratings[0].at
        const now = new Date()
        if (first.toDateString() === now.toDateString()) {
            return qsTr("today")
        }
        const sameYear = first.getFullYear() === now.getFullYear()
        const month = first.toLocaleDateString(Qt.locale(), sameYear ? "MMM" : "MMM yyyy")
        return qsTr("%1 → today").arg(month)
    }

    spacing: Look.unit(6)

    function dayText(date) {
        return date.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    LookLabel {
        Layout.fillWidth: true
        visible: !history.compact
        text: qsTr("Ratings")
        color: Look.stageTextColor
        opacity: 0.7
        font: Look.smallFont
    }

    // The chart: the level scale at the left (4 at the top), a bar per rating, the span below.
    RowLayout {
        id: chart

        objectName: "ratingHistory"
        Layout.fillWidth: true
        spacing: Look.unit(6)

        Column {
            Layout.alignment: Qt.AlignTop
            Layout.preferredHeight: bars.height
            spacing: 0

            Repeater {
                model: history.levels

                LookLabel {
                    required property int index
                    width: Look.unit(14)
                    height: bars.height / history.levels
                    verticalAlignment: Text.AlignTop
                    horizontalAlignment: Text.AlignRight
                    text: history.levels - index
                    color: Look.stageTextColor
                    // Short chart: only the ends of the scale, the rest would overlap.
                    opacity: history.compact && index > 0 && index < history.levels - 1 ? 0 : 0.7
                    font: Look.smallFont
                }
            }
        }

        Item {
            id: bars

            Layout.fillWidth: true
            Layout.preferredHeight: history.compact ? Look.unit(32) : Look.unit(56)

            // The scale's base line.
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Look.borderWidth
                color: Qt.alpha(Look.stageTextColor, 0.45)
            }
            LookLabel {
                anchors.centerIn: parent
                visible: history.ratings.length === 0
                text: qsTr("Not rated yet.")
                color: Look.stageTextColor
                opacity: 0.7
            }

            Row {
                anchors.fill: parent
                spacing: Look.unit(6)

                Repeater {
                    model: history.ratings

                    Item {
                        id: bar

                        required property var modelData
                        readonly property string word: Practice.levelNames[modelData.level]

                        width: Math.min(Look.unit(28), (bars.width - (history.count - 1) * Look.unit(6)) / history.count)
                        height: bars.height

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.height * bar.modelData.level / history.levels
                            // Lighter with the level: the level palette is too dark for the stage at the low end.
                            color: Qt.alpha(Look.stageTextColor, 0.25 + 0.75 * bar.modelData.level / history.levels)
                        }
                        HoverHandler {
                            id: hover
                        }
                        QQC2.ToolTip.visible: hover.hovered
                        QQC2.ToolTip.text: history.dayText(bar.modelData.at) + ": " + bar.modelData.level + " " + bar.word
                    }
                }
            }
        }
    }
    LookLabel {
        Layout.fillWidth: true
        Layout.leftMargin: Look.unit(20)
        visible: history.span !== ""
        text: history.span
        color: Look.stageTextColor
        opacity: 0.7
        font: Look.smallFont
    }

    LookLabel {
        Layout.fillWidth: true
        Layout.topMargin: Look.unit(4)
        visible: !history.compact
        text: qsTr("Last notes")
        color: Look.stageTextColor
        opacity: 0.7
        font: Look.smallFont
    }
    LookLabel {
        objectName: "noNotes"
        Layout.fillWidth: true
        visible: !history.compact && history.lastNotes.length === 0
        text: qsTr("No notes yet.")
        color: Look.stageTextColor
        opacity: 0.7
    }
    Repeater {
        model: history.compact ? [] : history.lastNotes

        LookLabel {
            required property var modelData

            objectName: "lastNote"
            Layout.fillWidth: true
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            text: history.dayText(modelData.created) + " · " + (modelData.text || qsTr("Photo or voice note"))
            color: Look.stageTextColor
        }
    }
}
