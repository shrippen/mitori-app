pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// What the technique sheet says (clickdummy `blatt`): name, attack, kanji, how well it sits
// (rate 1–4), the last note, the way on to the video, the notes and the comment, and the positions
// of a sequence (the Kamae exercise of Shinki Toho). TechniqueSheet shows it as a dialog; on a
// tablet the programme shows it beside the list (`inPane`).
ColumnLayout {
    id: body

    property var entry: ({})
    property bool playable: false
    // Beside the list: its own head in every style, without grip and ✕.
    property bool inPane: false
    readonly property bool hasVideo: playable && !!entry.video
    readonly property bool hasComment: !!entry.comment
    // A technique of a Lernpaket (Lessons::kDiscipline): it has a description and may name the same
    // technique in the exam programme.
    readonly property bool lesson: entry.discipline === "lern"
    readonly property var programmeIds: lesson ? (entry.wie || []).filter(id => Programme.techniqueLabel(id) !== "") : []
    readonly property var steps: entry.steps || []
    readonly property var lastNote: Practice.notesRevision >= 0 && entry.id ? Practice.lastNote(entry.id) : ({})
    // Its notes and the course entries linked to it: the notes page shows both.
    readonly property int noteCount: Practice.notesRevision >= 0 && Courses.revision >= 0 && entry.id
                                     ? Practice.notes(entry.id).length + Courses.linkedEntries(entry.id).length : 0
    // The form's number before the name, as in the list ("3 · Kote-gaeshi").
    readonly property string title: (entry.nr ? entry.nr + " · " : "") + (entry.title || "")
    // The sheet from the bottom: its head (grip, ✕) stands in here instead of Kirigami's.
    readonly property bool shinkiSheet: Look.shinki && !inPane

    signal playRequested(var entry)
    signal commentRequested(var entry)
    signal notesRequested(var entry)
    // The same technique in the exam programme (its entry): the host shows that one instead.
    signal programmeRequested(var entry)
    // Without the video on the device: to the videos and DVD codes.
    signal videosRequested()
    // The ✕, or on the way to another page: a dialog closes.
    signal closeRequested()
    // Up/Down, Page Up/Down, Home and End: whoever holds the body scrolls it.
    signal scrollKey(var event)

    // A body taller than its place: the key's step in the flickable holding it.
    function scrollIn(f, event) {
        const line = Kirigami.Units.gridUnit * 2
        const step = {
            [Qt.Key_Up]: -line, [Qt.Key_Down]: line,
            [Qt.Key_PageUp]: f ? -f.height * 0.9 : 0, [Qt.Key_PageDown]: f ? f.height * 0.9 : 0,
            [Qt.Key_Home]: -Infinity, [Qt.Key_End]: Infinity
        }[event.key]
        if (!f || step === undefined) {
            return
        }
        f.contentY = Math.max(0, Math.min(Math.max(0, f.contentHeight - f.height), f.contentY + step))
        event.accepted = true
    }

    spacing: Kirigami.Units.smallSpacing
    Keys.onPressed: event => body.scrollKey(event)

    // The head of the sheet under Shinki (the clickdummy): the grip, the name in the book face,
    // its Japanese below it. Beside the list the name stands here in every style.
    Item {
        objectName: "shinkiSheetHead"

        Layout.fillWidth: true
        Layout.preferredHeight: sheetHead.implicitHeight + (body.inPane ? 0 : Look.unit(16))
        visible: body.shinkiSheet || body.inPane

        // The keys above (Page Down, Home, End) scroll the sheet, as in Kirigami's header.
        Keys.onPressed: event => body.scrollKey(event)

        // The grip: the sheet is pulled up from the bottom.
        Rectangle {
            visible: !body.inPane
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            width: Look.unit(40)
            height: Look.unit(4)
            color: Look.ruleColor
        }

        ColumnLayout {
            id: sheetHead

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: body.inPane ? 0 : Look.unit(8)
            spacing: 0

            LookLabel {
                objectName: "sheetTitle"
                Layout.fillWidth: true
                text: body.title
                font: Look.sheetTitleFont
                wrapMode: Text.Wrap
            }
            LookLabel {
                Layout.fillWidth: true
                visible: !!body.entry.jp
                text: body.entry.jp || ""
                font: Look.japaneseFont(Look.defaultFont)
                color: Look.mutedTextColor
            }
        }

        LookToolButton {
            objectName: "sheetClose"
            visible: !body.inPane
            anchors.top: parent.top
            anchors.right: parent.right
            icon.name: "window-close"
            text: qsTr("Close")
            display: QQC2.AbstractButton.IconOnly
            onClicked: body.closeRequested()
        }
    }

    // Where it stands: attack, its addition, grade ("Shomen-uchi · Irimi · 5. Kyu").
    LookLabel {
        objectName: "sheetEyebrow"
        Layout.fillWidth: true
        text: [body.entry.attack, body.entry.attackExtra, body.entry.gradeName].filter(x => !!x).join(" · ")
        visible: text !== ""
        color: Look.disabledTextColor
        wrapMode: Text.Wrap
    }
    LookHeading {
        Layout.fillWidth: true
        visible: !body.shinkiSheet && !body.inPane && !!body.entry.jp      // the head above has it
        level: 2
        text: body.entry.jp || ""
    }
    LookLabel {
        Layout.fillWidth: true
        visible: !!body.entry.extra && !body.entry.uchidachi
        text: body.entry.extra || ""
        wrapMode: Text.Wrap
    }
    // A Lernpaket's description of the technique.
    LookLabel {
        objectName: "sheetLessonText"
        Layout.fillWidth: true
        visible: body.lesson && !!body.entry.text
        text: body.entry.text || ""
        wrapMode: Text.Wrap
    }
    // Where the technique stands in the exam programme: a tap shows its sheet.
    Flow {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        visible: body.programmeIds.length > 0

        Repeater {
            model: body.programmeIds

            LookChip {
                required property string modelData

                objectName: "sheetProgramme"
                width: Math.min(implicitWidth, parent.width)
                text: qsTr("In the programme: %1").arg(Programme.techniqueLabel(modelData))
                onClicked: body.programmeRequested(Programme.entry(modelData))
            }
        }
    }
    // A form: who stands how, what is hit and how it ends (the booklet's columns).
    GridLayout {
        objectName: "sheetFacts"
        Layout.fillWidth: true
        visible: !!body.entry.uchidachi
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Look.unit(2)

        Repeater {
            model: !body.entry.uchidachi ? [] : [
                qsTr("Uchidachi"), body.entry.uchidachi, qsTr("Shidachi"), body.entry.shidachi,
                qsTr("Hit"), body.entry.treffer, qsTr("Zanshin"), body.entry.zanshin]

            LookLabel {
                required property string modelData
                required property int index

                Layout.fillWidth: index % 2 === 1
                text: modelData
                color: index % 2 === 0 ? Look.mutedTextColor : Look.textColor
                wrapMode: Text.Wrap
            }
        }
    }
    LookLabel {
        objectName: "sheetOpenQuestion"
        Layout.fillWidth: true
        visible: !!body.entry.open
        text: qsTr("Open question: the sources do not agree here, it is not settled yet.")
        color: Look.mutedTextColor
        font: Look.smallFont
        wrapMode: Text.Wrap
    }
    RatingRow {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        entry: body.entry.id || ""
    }
    LookLabel {
        objectName: "sheetLastNote"
        Layout.fillWidth: true
        // A photo or voice note without text is named as such.
        readonly property string shown: (body.lastNote.text || (Media.kind(body.lastNote.media || "") === Media.Kind.Photo ? qsTr("Photo")
                           : Media.kind(body.lastNote.media || "") === Media.Kind.Voice ? qsTr("Voice note") : ""))
        visible: shown !== ""
        text: shown === "" ? "" : qsTr("Last note, %1: %2").arg(body.lastNote.created.toLocaleDateString(Qt.locale(), Locale.ShortFormat)).arg(shown)
        color: Look.mutedTextColor
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
    // Without the video: no video for this grade at all, or one to load with the DVD's code.
    LookHint {
        objectName: "sheetNoVideo"
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: !body.hasVideo
        titleText: body.entry.video ? qsTr("Video not loaded. The DVD's code loads it onto the device.")
                                : qsTr("There is no video of this technique.")

        LookButton {
            objectName: "sheetCodeButton"
            visible: !!body.entry.video
            text: qsTr("Enter code")
            onClicked: {
                body.closeRequested()
                body.videosRequested()
            }
        }
        LookButton {
            objectName: "sheetDvdButton"
            visible: !!body.entry.video
            text: qsTr("DVD on shinkiryu.de")
            onClicked: Qt.openUrlExternally("https://www.shinkiryu.de/shinkiryu/de/DVD.php")
        }
    }
    // Wraps on a small phone: a row would make the whole sheet wider than the screen.
    Flow {
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.smallSpacing

        LookButton {
            visible: body.hasVideo
            role: LookButton.Role.Primary
            icon.name: "media-playback-start"
            text: qsTr("Watch video")
            onClicked: body.playRequested(body.entry)
        }
        LookButton {
            objectName: "sheetNotesButton"
            icon.name: "view-pim-notes"
            text: body.noteCount > 0 ? qsTr("Notes (%1)").arg(body.noteCount) : qsTr("Notes")
            onClicked: {
                body.closeRequested()
                body.notesRequested(body.entry)
            }
        }
        LookButton {
            visible: body.hasComment
            icon.name: "documentinfo"
            text: qsTr("Comment")
            onClicked: {
                body.closeRequested()
                body.commentRequested(body.entry)
            }
        }
    }

    // The description of a sequence (Kamae exercise), after the rating and the buttons, so
    // those stay in view.
    StepList {
        objectName: "sheetSteps"
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        steps: body.steps
    }
}
