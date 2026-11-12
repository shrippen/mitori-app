pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "coursedays.js" as CourseDays

// Notes on a technique (clickdummy "Notizen"): by day, newest day first; a field at the foot
// adds a note for today. Press and hold a note (or right-click) to change or delete it.
// Below them the course notes linked to it (⌗ in the notebook); a tap opens one in its notebook.
// Photos and voice notes come with the platform layer (ROADMAP.md).
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    required property var entry
    // A note begun elsewhere (the player's short middle): it goes into the field, not saved yet.
    property string draft: ""
    Component.onCompleted: {
        if (draft !== "") {
            compose.text = draft
        }
    }
    // Opened from "All notes": its action goes back there instead of stacking another list.
    property bool fromAllNotes: false
    readonly property var notes: Practice.notesRevision >= 0 ? Practice.notes(entry.id) : []
    readonly property var courseNotes: Courses.revision >= 0 ? Courses.linkedEntries(entry.id) : []
    // [{day: Date, notes: [...]}], newest day first; within a day in the order written.
    readonly property var days: {
        const result = []
        for (const n of notes) {
            const key = n.created.toDateString()
            let day = result.find(d => d.key === key)
            if (!day) {
                day = { key: key, day: n.created, notes: [] }
                result.push(day)
            }
            day.notes.push(n)
        }
        return result.reverse()
    }

    title: qsTr("Notes")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    actions: [
        Kirigami.Action {
            icon.name: "view-list-details"
            text: qsTr("All notes")
            onTriggered: page.fromAllNotes ? leaveDialog.leaveOrAsk()
                                           : page.Kirigami.PageStack.push(Qt.resolvedUrl("AllNotesPage.qml"))
        }
    ]

    // Practice.today only makes the names follow a new day: as a QDate it reaches JS as
    // midnight UTC, the day before west of UTC.
    function dayName(day) {
        if (Practice.today && day.toDateString() === new Date().toDateString()) {
            return qsTr("Today")
        }
        return day.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }

    function add() {
        if (Practice.addNote(page.entry.id, compose.text)) {
            compose.clear()
            return true
        }
        return false
    }

    // A running recording: Back and the window's close finish it first, and it becomes a note.
    readonly property bool busy: media.recording
    function finishBusy() {
        media.finish()
    }

    // A note typed and not added: leaving asks (Back, "All notes", the window's close).
    readonly property LeaveDialog leaveAsk: leaveDialog
    // A changed note in the open editor (Main.mayClose).
    readonly property LeaveDialog editAsk: editor.leaveAsk
    LeaveDialog {
        id: leaveDialog

        objectName: "leaveNote"
        stackPage: page
        asking: compose.text.trim() !== ""
        busy: page.busy
        finish: () => page.finishBusy()
        title: qsTr("Save the note?")
        text: qsTr("“%1” is not saved yet.").arg(compose.text.trim())
        save: () => page.add()
        discard: () => compose.clear()
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                LookLabel {
                    Layout.fillWidth: true
                    text: (page.entry.nr ? page.entry.nr + " · " : "") + (page.entry.title || "")
                          + (page.entry.extra && !page.entry.nr ? " (" + page.entry.extra + ")" : "")
                    font.bold: true
                    wrapMode: Text.Wrap
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [page.entry.attack, page.entry.jp].filter(x => x).join(" · ")
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }
            LookLevelDots {
                value: Practice.revision >= 0 ? Practice.level(page.entry.id) : 0
                names: Practice.levelNames
                color: Look.levelColor(value)
            }
        }

        LookLabel {
            Layout.fillWidth: true
            visible: Practice.errorString !== ""
            text: Practice.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }

        LookLabel {
            Layout.fillWidth: true
            visible: page.notes.length === 0 && page.courseNotes.length === 0
            text: qsTr("No notes on this technique yet.")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }

        Repeater {
            model: page.days

            ColumnLayout {
                id: dayBlock

                required property var modelData

                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                LookSectionLabel {
                    objectName: "dayName"
                    text: page.dayName(dayBlock.modelData.day)
                }
                Repeater {
                    model: dayBlock.modelData.notes

                    ColumnLayout {
                        id: noteItem

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        LookLabel {
                            id: noteItemLabel

                            // The note, also for tests that find the label.
                            readonly property var modelData: noteItem.modelData

                            objectName: "note"
                            Layout.fillWidth: true
                            text: noteItem.modelData.text || page.mediaWord(noteItem.modelData.media)
                            wrapMode: Text.Wrap
                            padding: Kirigami.Units.smallSpacing
                            // Keyboard and screen readers: Tab to the note, Enter (or the press action)
                            // opens the editor.
                            activeFocusOnTab: true
                            background: Rectangle {
                                color: Look.cardColor
                                border.width: noteItemLabel.activeFocus ? Look.focusWidth : 0
                                border.color: Look.focusColor
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: text
                            Accessible.description: qsTr("Change or delete")
                            Accessible.onPressAction: editor.edit(noteItem.modelData)
                            Keys.onReturnPressed: editor.edit(noteItem.modelData)
                            Keys.onEnterPressed: editor.edit(noteItem.modelData)

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onLongPressed: editor.edit(noteItem.modelData)
                            }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: editor.edit(noteItem.modelData)
                            }
                        }
                        MediaView {
                            Layout.fillWidth: true
                            media: noteItem.modelData.media || ""
                        }
                    }
                }
            }
        }

        LookLabel {
            Layout.fillWidth: true
            visible: page.notes.length > 0
            text: qsTr("Press and hold a note (or Enter on it) to change or delete it.")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }

        LookSectionLabel {
            objectName: "fromCourses"
            visible: page.courseNotes.length > 0
            text: qsTr("From a course")
        }
        Repeater {
            model: page.courseNotes

            ColumnLayout {
                id: courseNote

                required property var modelData
                readonly property string courseLine: modelData.title + " · " + CourseDays.range(modelData.first, modelData.last)

                function open() {
                    page.Kirigami.PageStack.push(Qt.resolvedUrl("CoursePage.qml"), {
                        uid: modelData.course,
                        entryUid: modelData.uid
                    })
                }

                Layout.fillWidth: true
                spacing: 0

                LookLabel {
                    Layout.fillWidth: true
                    text: courseNote.courseLine
                    font: Look.smallFont
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
                LookLabel {
                    id: courseNoteLabel

                    objectName: "courseNote"
                    Layout.fillWidth: true
                    text: courseNote.modelData.text || page.mediaWord(courseNote.modelData.media)
                    wrapMode: Text.Wrap
                    padding: Kirigami.Units.smallSpacing
                    activeFocusOnTab: true
                    background: Rectangle {
                        color: Look.cardColor
                        border.width: courseNoteLabel.activeFocus ? Look.focusWidth : 0
                        border.color: Look.focusColor
                    }
                    Accessible.role: Accessible.Button
                    Accessible.name: text
                    Accessible.description: courseNote.courseLine
                    Accessible.onPressAction: courseNote.open()
                    Keys.onReturnPressed: courseNote.open()
                    Keys.onEnterPressed: courseNote.open()

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: courseNote.open()
                    }
                }
            }
        }
    }

    footer: LookToolBar {
        RowLayout {
            anchors.fill: parent

            LookTextField {
                id: compose

                objectName: "compose"
                Layout.fillWidth: true
                placeholderText: qsTr("Note for today …")
                Accessible.name: qsTr("New note")
                onAccepted: page.add()
            }
            // A photo or voice note becomes a note at once, with the text typed so far.
            MediaCompose {
                id: media

                objectName: "noteMedia"
                stackPage: page
                onAttached: name => {
                    if (Practice.addNote(page.entry.id, compose.text, name)) {
                        compose.clear()
                    } else {
                        Media.discard(name)
                    }
                }
            }
            LookButton {
                role: LookButton.Role.Primary
                enabled: compose.text.trim() !== ""
                icon.name: "list-add"
                text: qsTr("Add")
                display: page.width < Kirigami.Units.gridUnit * 26 ? QQC2.AbstractButton.IconOnly : QQC2.AbstractButton.TextBesideIcon
                onClicked: page.add()
            }
        }
    }

    // A note without text says what it holds.
    function mediaWord(name) {
        const kind = Media.kind(name || "")
        return kind === Media.Kind.Photo ? qsTr("Photo") : kind === Media.Kind.Voice ? qsTr("Voice note") : ""
    }

    NoteEditor {
        id: editor
    }
}
