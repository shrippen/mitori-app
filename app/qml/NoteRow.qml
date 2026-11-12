import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import Mitori

// The last note on a technique and a field for a new one (player); "Notes" opens them all.
// A note begun for one technique stays with it: when the player moves on before it is added
// (training moves on after a rating), it is saved for the technique it was typed for.
ColumnLayout {
    id: noteRow

    required property var entry
    readonly property var last: Practice.notesRevision >= 0 && entry.id ? Practice.lastNote(entry.id) : ({})
    // Today's notes on it ("Noted today"); without one the last note stands there.
    readonly property var today: Practice.notesRevision >= 0 && Practice.today && entry.id ? Practice.notesToday(entry.id) : []
    // The technique the field's text belongs to.
    property string draftFor: ""
    // Only the field and Add: the upright player lists the notes and opens them itself.
    property bool fieldOnly: false

    signal notesRequested()
    // The field got the keyboard focus (the player scrolls it into view above the keyboard).
    signal fieldFocused(Item field)

    // Saves a begun note for its technique; the field empties only when it was saved.
    function keepDraft() {
        if (draftFor === "" || field.text.trim() === "") {
            field.clear()
            draftFor = ""
            return
        }
        if (Practice.addNote(draftFor, field.text)) {
            field.clear()
            draftFor = ""
        }
    }

    onEntryChanged: {
        if (draftFor !== entry.id) {
            keepDraft()
        }
    }
    // Leaving the player (Back, the training's last rating) keeps the draft too.
    Component.onDestruction: keepDraft()

    spacing: Look.unit(6)

    // A photo or voice note without text is named as such.
    function noteText(note) {
        if (note.text) {
            return note.text
        }
        const kind = Media.kind(note.media || "")
        if (kind === Media.Kind.Photo) {
            return qsTr("Photo")
        }
        return kind === Media.Kind.Voice ? qsTr("Voice note") : ""
    }

    LookLabel {
        objectName: "notedToday"
        Layout.fillWidth: true
        visible: !noteRow.fieldOnly && noteRow.today.length > 0
        text: qsTr("Noted today: %1").arg(noteRow.today.map(n => noteRow.noteText(n)).join(" · "))
        color: Look.mutedTextColor
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
    }
    LookLabel {
        Layout.fillWidth: true
        readonly property string shown: noteRow.today.length > 0 ? "" : noteRow.noteText(noteRow.last)
        visible: !noteRow.fieldOnly && shown !== ""
        text: qsTr("Last note: %1").arg(shown)
        color: Look.mutedTextColor
        wrapMode: Text.Wrap
        maximumLineCount: 3
        elide: Text.ElideRight
    }
    RowLayout {
        Layout.fillWidth: true

        LookTextField {
            id: field

            objectName: "noteField"
            Layout.fillWidth: true
            placeholderText: qsTr("Note for today …")
            Accessible.name: qsTr("New note")
            onAccepted: add()
            onTextChanged: {
                if (text !== "" && noteRow.draftFor === "") {
                    noteRow.draftFor = noteRow.entry.id
                }
            }
            onActiveFocusChanged: {
                if (activeFocus) {
                    noteRow.fieldFocused(field)
                }
            }

            function add() {
                if (Practice.addNote(noteRow.draftFor || noteRow.entry.id, text)) {
                    clear()
                    noteRow.draftFor = ""
                }
            }
        }
        // The send button (clickdummy `.qnote button`): red, filled, white text; only when the
        // field has something to send.
        LookButton {
            objectName: "addNote"
            enabled: field.text.trim() !== ""
            role: LookButton.Role.Primary
            text: qsTr("Add")
            onClicked: field.add()
        }
        LookToolButton {
            icon.name: "view-pim-notes"
            text: qsTr("Notes")
            display: QQC2.AbstractButton.IconOnly
            objectName: "openNotes"
            visible: !noteRow.fieldOnly
            onClicked: noteRow.notesRequested()
        }
    }
}
