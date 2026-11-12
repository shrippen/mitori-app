pragma ComponentBehavior: Bound

import QtCore
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// All notes (clickdummy "Alle Notizen"): the notes on every technique and the entries of every
// course notebook by day, newest first, with a filter per discipline and one for the courses. A
// tap opens the technique's notes or the notebook, press and hold changes or deletes a note. The
// rows come from C++ (AllNotes): fast with thousands of notes.
Kirigami.Page {
    id: page

    // The style's colours and page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    // "" = all, a discipline's id, or "courses"; kept for the next time.
    property string filter: ""
    Settings {
        id: settings

        property alias allNotesFilter: page.filter
    }
    // A remembered discipline that no longer exists: all (also when Settings loads it). Another
    // filter starts at the top of the list.
    onFilterChanged: {
        if (filter !== "" && filter !== page.coursesFilter && filter !== page.lessonsFilter
                && !Programme.disciplines.some(d => d.id === filter)) {
            Qt.callLater(() => page.filter = "")     // not inside the change (Settings records it)
        }
        // Learning videos without notes any more (a remembered filter): later, the model may not have its rows yet.
        if (filter === page.lessonsFilter) {
            Qt.callLater(() => {
                if (page.filter === page.lessonsFilter && notesModel.lessonNotes === 0) {
                    page.filter = ""
                }
            })
        }
        settings.setValue("allNotesFilter", filter)  // now, not a moment later (the page may go)
        if (filter !== listFilter) {
            listFilter = filter
            Qt.callLater(() => list.positionViewAtBeginning())
        }
    }
    // The filter the list was last at the top for (Settings reports the same filter again).
    property string listFilter: ""
    readonly property string coursesFilter: "courses"     // AllNotes::kCourses
    readonly property string lessonsFilter: "lern"        // the discipline of a Lernpaket's techniques (Lessons::kDiscipline)
    // The chip for the learning videos: when there are notes on them (or it is the filter kept). A bool of its
    // own: the chips are made anew when it changes, not with every note.
    readonly property bool hasLessonChip: notesModel.lessonNotes > 0 || filter === lessonsFilter
    // The rows shown (AllNotes): {uid, kind, text, created, day, title, discipline, entry, course}.
    readonly property var shown: notesModel.rows
    // The list's model: a change rebuilds the rows in C++ and changes only those that changed, so
    // the list keeps its place and its current note after an edit, a deletion or a new note.
    AllNotes {
        id: notesModel

        practice: Practice
        courses: Courses
        programme: Programme
        filter: page.filter
    }

    title: qsTr("All notes")

    // A section's day ("YYYY-MM-DD"); Practice.today only makes the names follow a new day.
    function dayName(iso) {
        const d = iso.split("-").map(Number)
        const day = new Date(d[0], d[1] - 1, d[2], 12)
        if (Practice.today && day.toDateString() === new Date().toDateString()) {
            return qsTr("Today")
        }
        return day.toLocaleDateString(Qt.locale(), Locale.ShortFormat)
    }
    padding: 0
    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    // The filter, then the list: in this order also for Tab.
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Flow {
            Layout.fillWidth: true
            padding: Kirigami.Units.smallSpacing
            objectName: "filter"
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: notesView.rightPadding        // in line with the notes
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: [{ id: "", name: qsTr("All") }].concat(Programme.disciplines.map(d => ({ id: d.id, name: d.kurzname })))
                                                     .concat(page.hasLessonChip
                                                             ? [{ id: page.lessonsFilter, name: qsTr("Learning videos") }] : [])
                                                     .concat([{ id: page.coursesFilter, name: qsTr("Courses") }])

                LookChip {
                    required property var modelData

                    objectName: "filter_" + (modelData.id || "all")
                    text: modelData.name
                    checkable: true
                    checked: page.filter === modelData.id
                    onClicked: page.filter = modelData.id
                }
            }
        }

        LookScrollView {
            id: notesView

            objectName: "notesView"
            Layout.fillWidth: true
            Layout.fillHeight: true
            // The notes keep a margin, the scroll bar stands at the window's edge.
            leftPadding: Kirigami.Units.largeSpacing
            rightPadding: Math.max(Kirigami.Units.largeSpacing, effectiveScrollBarWidth)
            clip: true                                  // the notes scroll under the filter, not over it

            // A virtual list (years of notes): the day as its section.
            ListView {
                id: list

                objectName: "notesList"
                model: notesModel
                spacing: Kirigami.Units.smallSpacing
                // The keyboard moves through every note (Up, Down), Enter opens, the menu key edits; the
                // list follows the current note.
                activeFocusOnTab: true
                keyNavigationEnabled: true
                currentIndex: -1
                // Coming in with Tab: the first note in view, not one far away.
                onActiveFocusChanged: {
                    if (activeFocus && (currentIndex < 0 || currentIndex < firstShown() || currentIndex > lastShown())) {
                        currentIndex = firstShown()
                    }
                }
                // The first and last note in view (a day's heading or the gap between notes is no note).
                function firstShown() {
                    for (let y = contentY; y < contentY + height; y += Kirigami.Units.smallSpacing) {
                        const i = indexAt(width / 2, y)
                        if (i >= 0) {
                            return i
                        }
                    }
                    return count > 0 ? 0 : -1
                }
                function lastShown() {
                    for (let y = contentY + height - 1; y > contentY; y -= Kirigami.Units.smallSpacing) {
                        const i = indexAt(width / 2, y)
                        if (i >= 0) {
                            return i
                        }
                    }
                    return firstShown()
                }
                Keys.onReturnPressed: page.openCurrent(false)
                Keys.onEnterPressed: page.openCurrent(false)
                Keys.onMenuPressed: page.openCurrent(true)
                // Only a key moves the view (a new or deleted note above shifts the index, not the
                // view), also when the index stays (the last note again after scrolling away).
                Keys.onPressed: event => {
                    const keys = [Qt.Key_Up, Qt.Key_Down, Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Home, Qt.Key_End]
                    if (!keys.includes(event.key)) {
                        return
                    }
                    if (count === 0) {
                        event.accepted = true               // nothing to move to
                        return
                    }
                    // At the first note the count above it shows too.
                    Qt.callLater(() => currentIndex === 0 ? positionViewAtBeginning()
                                                          : positionViewAtIndex(currentIndex, ListView.Contain))
                    if (event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) {
                        const step = Math.max(1, lastShown() - firstShown())
                        currentIndex = event.key === Qt.Key_PageDown ? Math.min(count - 1, currentIndex + step)
                                                                     : Math.max(0, currentIndex - step)
                    } else if (event.key === Qt.Key_Home) {
                        currentIndex = 0
                    } else if (event.key === Qt.Key_End) {
                        currentIndex = count - 1
                    } else {
                        return                              // Up and Down: the list moves the index
                    }
                    event.accepted = true
                }
                section.property: "day"
                section.delegate: LookSectionLabel {
                    required property string section
                    Accessible.role: Accessible.Heading
                    width: ListView.view.width
                    topPadding: Kirigami.Units.largeSpacing
                    text: page.dayName(section)
                }

                header: LookLabel {
                    objectName: "count"
                    width: ListView.view.width
                    bottomPadding: Kirigami.Units.largeSpacing
                    text: notesModel.count > 0
                          ? qsTr("%n note(s). Tap one to open its technique or notebook, press and hold to change or delete it.", "", notesModel.count)
                          : page.filter === page.coursesFilter ? qsTr("No entries in course notebooks yet.")
                          : page.filter !== "" && notesModel.total > 0 ? qsTr("No notes in this discipline.")
                          : qsTr("No notes yet. Notes are written on a technique or in the player.")
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }

                delegate: ColumnLayout {
                    id: noteItem

                    required property var row
                    required property int index

                    objectName: "note"

                    width: ListView.view.width
                    spacing: 0
                    readonly property bool current: ListView.isCurrentItem && ListView.view.activeFocus
                    Accessible.role: Accessible.Button
                    Accessible.name: row.title + ": " + row.text
                    Accessible.description: row.kind === "course" ? qsTr("Opens the notebook; press and hold or the menu key to change or delete")
                                                                  : qsTr("Opens the technique's notes; press and hold or the menu key to change or delete")
                    Accessible.onPressAction: page.open(row)

                    LookLabel {
                        Layout.fillWidth: true
                        objectName: "noteTitle"
                        // A course's day has several sessions: its entries say when.
                        text: (noteItem.row.kind === "course"
                               ? noteItem.row.created.toLocaleTimeString(Qt.locale(), Locale.ShortFormat) + " · " : "")
                              + noteItem.row.title
                        color: Look.mutedTextColor
                        font: Look.smallFont
                        elide: Text.ElideRight
                        leftPadding: Kirigami.Units.smallSpacing
                    }
                    LookLabel {
                        Layout.fillWidth: true
                        text: noteItem.row.text || (Media.kind(noteItem.row.media || "") === Media.Kind.Photo ? qsTr("Photo")
                                                    : Media.kind(noteItem.row.media || "") === Media.Kind.Voice ? qsTr("Voice note") : "")
                        wrapMode: Text.Wrap
                        padding: Kirigami.Units.smallSpacing
                        background: Rectangle {
                            color: Look.cardColor
                            border.width: noteItem.current ? Look.focusWidth : 0
                            border.color: Look.focusColor
                        }
                    }

                    MediaView {
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        media: noteItem.row.media || ""
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        onTapped: page.open(noteItem.row)
                        onLongPressed: page.edit(noteItem.row)
                    }
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: page.edit(noteItem.row)
                    }
                }
            }
        }
    }

    // Enter or the menu key on the note the keyboard is on.
    function openCurrent(edit) {
        const note = page.shown[list.currentIndex]
        if (!note) {
            return
        }
        if (edit) {
            editor.returnFocus = list
            page.edit(note)
        } else {
            page.open(note)
        }
    }

    function open(note) {
        if (note.kind === "course") {
            page.Kirigami.PageStack.push(Qt.resolvedUrl("CoursePage.qml"), { uid: note.course })
            return
        }
        // The notes page's "All notes" comes back here instead of opening another list.
        const e = Programme.entry(note.entry)
        page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), {
            entry: e.title ? e : { id: note.entry, title: qsTr("Technique no longer in the programme") },
            fromAllNotes: true
        })
    }

    // A course entry is saved and deleted by Courses, a technique's note by Practice.
    function edit(note) {
        const course = note.kind === "course"
        editor.save = course ? (uid, text) => Courses.changeEntry(uid, text) : (uid, text) => Practice.changeNote(uid, text)
        editor.remove = course ? uid => Courses.deleteEntry(uid) : uid => Practice.deleteNote(uid)
        editor.edit(note)
    }

    // A changed note in the open editor (Main.mayClose).
    readonly property LeaveDialog editAsk: editor.leaveAsk
    NoteEditor {
        id: editor

        // Edited with the keyboard: the list gets the focus back, on the same note.
        property Item returnFocus: null
        onClosed: {
            if (returnFocus) {
                returnFocus.forceActiveFocus()
                returnFocus = null
            }
        }
    }
}
