pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "coursedays.js" as CourseDays
import "grades.js" as Grades

// A course's notebook (clickdummy "Lehrgang"): the course (days, place, teacher), "In the
// calendar" and the official announcement where the calendar names one, then the entries by
// day; a field at the foot adds one. Press and hold an entry (or Enter on it) to change or
// delete it. Notes stay on the device; export comes with photos and voice notes.
// ⌗ links an entry to techniques (TechniquePickerPage); its chips lead to their notes.
// On a course that has not ended an exam can be planned (discipline and grade), with its
// waiting time checked against the course's first day.
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    required property string uid
    // ListAndPage, beside the list on a tablet: another row takes this page away, so a begun entry
    // is saved then (not when the notebook itself went).
    property var paneHost: null
    Component.onDestruction: keepBegun()
    function keepBegun() {
        if (paneHost && !gone && compose.text.trim() !== "") {
            page.add()
        }
    }
    // A running recording: another row waits for it (ListAndPage), and it becomes an entry.
    readonly property bool busy: media.recording
    function finishBusy() {
        media.finish()
    }
    // Out of the stack, also from the middle; the top page stays the one shown.
    function leave() {
        if (paneHost) {
            paneHost.clearPane()
            return
        }
        const row = page.Kirigami.PageStack.pageStack
        row.removePage(page)
        row.currentIndex = row.depth - 1
    }
    // An entry to show on opening (from a technique's notes): scrolled to, with the focus.
    property string entryUid: ""
    property Item entryShown: null
    onEntryShownChanged: {
        if (entryShown) {
            showTimer.restart()
        }
    }
    // After the first layout: only then the entry has its place.
    Timer {
        id: showTimer

        interval: Kirigami.Units.shortDuration
        onTriggered: {
            const view = page.flickable
            const item = page.entryShown
            if (!item) {
                return
            }
            const y = item.mapToItem(view.contentItem, 0, 0).y - Kirigami.Units.largeSpacing
            view.contentY = Math.max(0, Math.min(y, view.contentHeight - view.height))
            item.forceActiveFocus()
            page.entryUid = ""      // later changes on the page leave the view where it is
        }
    }
    readonly property var course: Courses.revision >= 0 ? Courses.notebook(uid) : ({})
    // The notebook deleted (here, on a second page of it, by a sync): no empty page stays behind.
    readonly property bool gone: !course.uid
    onGoneChanged: {
        if (gone) {
            Qt.callLater(page.leave)
        }
    }
    readonly property var entries: Courses.revision >= 0 ? Courses.entries(uid) : []
    // [{key, day: Date, entries: [...]}] in the order written (a course's days run forward).
    readonly property var days: {
        const result = []
        for (const e of entries) {
            const key = e.created.toDateString()
            let day = result.find(d => d.key === key)
            if (!day) {
                day = { key: key, day: e.created, entries: [] }
                result.push(day)
            }
            day.entries.push(e)
        }
        return result
    }

    title: qsTr("Notebook")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    actions: [
        // The notebook as a ZIP (notizbuch.md, photos, voice notes): the sheet shows, shares, saves it.
        Kirigami.Action {
            objectName: "exportCourse"
            icon.name: "document-export"
            text: qsTr("Export")
            onTriggered: exportSheet.show()
        },
        Kirigami.Action {
            objectName: "deleteCourse"
            icon.name: "edit-delete"
            text: qsTr("Delete notebook")
            displayHint: Kirigami.DisplayHint.AlwaysHide
            onTriggered: removeDialog.open()
        }
    ]

    readonly property bool coming: !!course.last && CourseDays.fromToday(course.last) >= 0
    readonly property bool planned: !!course.examGrade
    // The exam being chosen: the planned one, else the programme's discipline and its next grade.
    property bool choosing: false
    property string examDiscipline: ""
    property string examGrade: ""
    readonly property var examLadder: Courses.revision >= 0 && examDiscipline !== "" ? Courses.ladder(examDiscipline) : []

    function choose() {
        page.examDiscipline = page.course.examDiscipline || Programme.discipline
        page.examGrade = page.course.examGrade || Courses.nextGrade(page.examDiscipline)
        page.choosing = true
    }

    function add() {
        if (Courses.addEntry(page.uid, compose.text)) {
            compose.clear()
            return true
        }
        return false
    }

    // On a phone an entry typed and not added asks before it goes (Back, the window's close);
    // beside the list it is saved (keepBegun).
    readonly property LeaveDialog leaveAsk: leaveDialog
    // A changed entry in the open editor (Main.mayClose; ListAndPage passes it on).
    readonly property LeaveDialog editAsk: editor.leaveAsk
    LeaveDialog {
        id: leaveDialog

        objectName: "leaveEntry"
        stackPage: page
        asking: !page.paneHost && !page.gone && compose.text.trim() !== ""
        busy: !page.paneHost && page.busy
        finish: () => page.finishBusy()
        title: qsTr("Save the entry?")
        text: qsTr("“%1” is not saved yet.").arg(compose.text.trim())
        save: () => page.add()
        discard: () => compose.clear()
    }

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        // The course on a card.
        QQC2.Control {
            Layout.fillWidth: true
            padding: Look.cardPadding
            background: LookCard {}

            contentItem: ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                LookSectionLabel {
                    Layout.fillWidth: true
                    text: CourseDays.range(page.course.first, page.course.last) + " · "
                          + (page.course.calendarUid ? qsTr("from the calendar") : qsTr("own entry"))
                }
                LookHeading {
                    objectName: "courseTitle"
                    Layout.fillWidth: true
                    level: 2
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: page.course.title || ""
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: [page.course.place, page.course.teacher].filter(x => x).join(" · ")
                    wrapMode: Text.Wrap
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    LookButton {
                        objectName: "toCalendar"
                        icon.name: "view-calendar"
                        text: qsTr("In the calendar")
                        onClicked: {
                            if (!Courses.addToDeviceCalendar(page.uid)) {
                                calendarFailed.visible = true
                            }
                        }
                    }
                    LookButton {
                        objectName: "announcement"
                        visible: !!page.course.announcement
                        icon.name: "internet-services"
                        text: qsTr("Announcement")
                        onClicked: Qt.openUrlExternally(page.course.announcement)
                    }
                }
                LookLabel {
                    objectName: "exportedTo"
                    Layout.fillWidth: true
                    visible: page.exported !== ""
                    text: qsTr("Exported: %1").arg(page.exported)
                          + (page.exportMissing > 0 ? " " + qsTr("%n file(s) were not on this device and are missing.", "", page.exportMissing) : "")
                    color: Look.positiveTextColor
                    wrapMode: Text.Wrap
                }
                LookLabel {
                    id: calendarFailed

                    Layout.fillWidth: true
                    visible: false
                    text: qsTr("No calendar app could be opened.")
                    color: Look.neutralTextColor
                    wrapMode: Text.Wrap
                }
            }
        }

        // The exam on this course: planned (with its waiting time) or "Plan an exam here …".
        ColumnLayout {
            objectName: "examBlock"
            Layout.fillWidth: true
            visible: page.planned || page.coming
            spacing: Kirigami.Units.smallSpacing

            // The chip and "Change" in a row; the waiting time below, in the full width.
            ColumnLayout {
                Layout.fillWidth: true
                visible: page.planned && !page.choosing
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true

                    LookChip {
                        objectName: "examChip"
                        text: qsTr("Exam %1").arg(page.course.examName || "")
                        checkable: true
                        checked: true
                        interactive: false
                    }
                    Item { Layout.fillWidth: true }
                    LookButton {
                        objectName: "changeExam"
                        visible: page.coming
                        text: qsTr("Change")
                        onClicked: page.choose()
                    }
                }
                LookLabel {
                    objectName: "examWait"
                    Layout.fillWidth: true
                    readonly property var wait: Courses.revision >= 0 && page.planned
                                                ? Courses.waiting(page.course.examDiscipline, page.course.examGrade, page.course.first) : ({})
                    text: Grades.waitText(wait)
                    color: Grades.tooEarly(wait) ? Look.neutralTextColor : Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }
            LookButton {
                objectName: "planExam"
                visible: !page.planned && page.coming && !page.choosing
                icon.name: "view-calendar"
                text: qsTr("Plan an exam here …")
                onClicked: page.choose()
            }

            // Choosing: discipline, grade (the next one marked), its waiting time.
            QQC2.Control {
                Layout.fillWidth: true
                visible: page.choosing
                padding: Look.cardPadding
                background: LookCard {}

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    LookHeading {
                        Layout.fillWidth: true
                        level: 3
                        text: qsTr("Plan an exam here")
                    }
                    LookSegmented {
                        Layout.fillWidth: true
                        model: Programme.disciplines.map(d => d.kurzname)
                        currentIndex: Programme.disciplines.findIndex(d => d.id === page.examDiscipline)
                        onActivated: index => {
                            page.examDiscipline = Programme.disciplines[index].id
                            page.examGrade = Courses.nextGrade(page.examDiscipline)
                        }
                        Accessible.name: qsTr("Discipline")
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Repeater {
                            model: page.examLadder

                            LookChip {
                                required property var modelData
                                readonly property bool next: modelData.id === Courses.nextGrade(page.examDiscipline)

                                objectName: "examGrade_" + modelData.id
                                text: modelData.name + (next ? " · " + qsTr("next") : modelData.passed ? " · " + qsTr("passed") : "")
                                checkable: true
                                checked: modelData.id === page.examGrade
                                onClicked: page.examGrade = modelData.id
                            }
                        }
                    }
                    LookLabel {
                        objectName: "choiceWait"
                        Layout.fillWidth: true
                        readonly property var wait: page.examGrade !== "" ? Courses.waiting(page.examDiscipline, page.examGrade, page.course.first) : ({})
                        text: page.examGrade !== "" ? qsTr("Waiting time: %1").arg(Grades.waitText(wait)) : qsTr("All grades passed.")
                        color: Grades.tooEarly(wait) ? Look.neutralTextColor : Look.mutedTextColor
                        wrapMode: Text.Wrap
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        LookButton {
                            objectName: "examPlan"
                            role: LookButton.Role.Primary
                            enabled: page.examGrade !== ""
                            text: qsTr("Plan")
                            onClicked: {
                                if (Courses.planExam(page.uid, page.examDiscipline, page.examGrade)) {
                                    page.choosing = false
                                }
                            }
                        }
                        LookButton {
                            objectName: "examNone"
                            text: qsTr("No exam")
                            onClicked: {
                                if (Courses.planExam(page.uid, "", "")) {
                                    page.choosing = false
                                }
                            }
                        }
                        LookButton {
                            text: qsTr("Cancel")
                            onClicked: page.choosing = false
                        }
                    }
                }
            }
        }

        LookLabel {
            Layout.fillWidth: true
            visible: Courses.errorString !== ""
            text: Courses.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }

        LookLabel {
            Layout.fillWidth: true
            visible: page.entries.length === 0
            text: qsTr("No entries yet. Write below what was shown.")
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
                    text: dayBlock.modelData.day.toLocaleDateString(Qt.locale(), "dddd, " + Qt.locale().dateFormat(Locale.ShortFormat))
                }
                Repeater {
                    model: dayBlock.modelData.entries

                    ColumnLayout {
                        id: entryItem

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        LookLabel {
                            id: entryItemLabel

                            // The note, also for tests that find the label.
                            readonly property var modelData: entryItem.modelData

                            objectName: "courseEntry"
                            Component.onCompleted: {
                                if (entryItem.modelData.uid === page.entryUid) {
                                    page.entryShown = entryItemLabel
                                }
                            }
                            Layout.fillWidth: true
                            text: entryItem.modelData.created.toLocaleTimeString(Qt.locale(), Locale.ShortFormat) + "  " + (entryItem.modelData.text || page.mediaWord(entryItem.modelData.media))
                            wrapMode: Text.Wrap
                            padding: Kirigami.Units.smallSpacing
                            activeFocusOnTab: true
                            background: Rectangle {
                                color: Look.cardColor
                                border.width: entryItemLabel.activeFocus ? Look.focusWidth : 0
                                border.color: Look.focusColor
                            }
                            Accessible.role: Accessible.Button
                            Accessible.name: entryItem.modelData.text || page.mediaWord(entryItem.modelData.media)
                            Accessible.description: qsTr("Change or delete")
                            Accessible.onPressAction: editor.edit(entryItem.modelData)
                            Keys.onReturnPressed: editor.edit(entryItem.modelData)
                            Keys.onEnterPressed: editor.edit(entryItem.modelData)

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                onLongPressed: editor.edit(entryItem.modelData)
                            }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: editor.edit(entryItem.modelData)
                            }
                        }
                        MediaView {
                            Layout.fillWidth: true
                            media: entryItem.modelData.media || ""
                        }

                        // Its techniques (a chip opens their notes) and ⌗ to change them.
                        Flow {
                            id: techniqueFlow

                            Layout.fillWidth: true
                            spacing: Kirigami.Units.smallSpacing

                            Repeater {
                                model: entryItem.modelData.techniques

                                LookChip {
                                    required property var modelData
                                    readonly property string label: Programme.techniqueLabel(modelData)

                                    objectName: "entryTechnique"
                                    width: Math.min(implicitWidth, techniqueFlow.width)
                                    text: "↗ " + (label || qsTr("Technique no longer in the programme"))
                                    onClicked: {
                                        const known = Programme.entry(modelData)
                                        page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), {
                                            entry: known.id ? known : { id: modelData, title: qsTr("Technique no longer in the programme") }
                                        })
                                    }
                                }
                            }
                            LookButton {
                                objectName: "linkTechnique"
                                role: LookButton.Role.Quiet
                                text: "⌗ " + qsTr("Link technique")
                                onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("TechniquePickerPage.qml"), {
                                    course: page.uid,
                                    entryUid: entryItem.modelData.uid
                                })
                                Accessible.name: qsTr("Link technique")
                            }
                        }
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

                objectName: "courseCompose"
                Layout.fillWidth: true
                placeholderText: qsTr("What was shown?")
                Accessible.name: qsTr("New entry")
                onAccepted: page.add()
            }
            // A photo or voice note becomes an entry at once, with the text typed so far.
            MediaCompose {
                id: media

                objectName: "courseMedia"
                stackPage: page
                onAttached: name => {
                    if (Courses.addEntry(page.uid, compose.text, name)) {
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

    // Where the export went, shown under the course ("" before one), and how many of its media
    // files were not on the device.
    property string exported: ""
    property int exportMissing: 0

    ExportSheet {
        id: exportSheet

        objectName: "exportSheet"
        uid: page.uid
        onSaveRequested: exportDialog.ask(Courses.exportName(page.uid))
    }

    SaveFileDialog {
        id: exportDialog

        objectName: "exportDialog"
        anchor: page
        title: qsTr("Export notebook")
        onChosen: target => page.exportTo(target)
    }

    // A local file shows its name; Android's picker gives a content:// URL with a document id, so
    // there the name the dialog was offered.
    function exportTo(url) {
        const missing = Courses.exportNotebook(page.uid, url)
        const local = String(url).startsWith("file:")
        page.exportMissing = Math.max(0, missing)
        page.exported = missing < 0 ? "" : local ? decodeURIComponent(String(url).replace(/^file:\/\//, "")) : Courses.exportName(page.uid)
    }

    // A note without text says what it holds.
    function mediaWord(name) {
        const kind = Media.kind(name || "")
        return kind === Media.Kind.Photo ? qsTr("Photo") : kind === Media.Kind.Voice ? qsTr("Voice note") : ""
    }

    NoteEditor {
        id: editor

        title: qsTr("Entry")
        changedText: qsTr("The entry has been changed but not saved.")
        save: (uid, text) => Courses.changeEntry(uid, text)
        remove: uid => Courses.deleteEntry(uid)
    }

    LookDialog {
        id: removeDialog

        objectName: "removeCourse"
        modal: true
        destructive: true
        span: LookDialog.Span.Small
        title: qsTr("Delete notebook?")
        acceptText: qsTr("Delete")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onAccepted: Courses.remove(page.uid)

        // Built on opening: made with the page, the wrapping text looped the dialog's
        // implicitHeight (a short text did not; Kante's dialog alone does not).
        Loader {
            active: removeDialog.visible
            width: parent.width
            sourceComponent: LookLabel {
                text: qsTr("The notebook and its %n entry(s) go from this device.", "", page.entries.length)
                wrapMode: Text.Wrap
            }
        }
    }
}
