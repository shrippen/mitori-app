pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "coursedays.js" as CourseDays
import "playlists.js" as Playlists

// Glossary and search (clickdummy "Glossar & Suche"). Without a query: the glossary A–Z (word,
// kanji, translation in the app's language, a speaker button). With a query: techniques of every
// discipline and grade by name, attack (with its addition), group or Japanese, the glossary (also
// by the translation's words), the own notes, the Shinki Toho comments and the course notebooks'
// entries; the glossary first, as the techniques can be up to 50 rows. Case, accents, hyphens and
// okurigana do not matter; several words must all match. A technique opens its sheet, a note its
// notes page, a comment hit the comment, an entry its notebook (scrolled to the entry).
//
// Wide window (a tablet sideways): letter rail | list | detail of the word tapped. A phone: the list
// with a slim rail at its right edge; dragging over it jumps, a bubble shows the letter.
//
//   [A-Z rail] [ListView (virtual: about 300 words, or up to 50 rows of each other kind found)] [detail]
//                ├─ header   hints
//                ├─ rows     the glossary under pinned A … Z headings without a query; with one the
//                │           words, techniques, notes, comments and course notes found, each kind
//                │           under its heading and with a hint when there are more
//                └─ footer   source of the translations
Kirigami.Page {
    id: page

    padding: 0
    // The on-screen keyboard shrinks the window: the columns stay while a field is typed in.
    readonly property TypingHold hold: TypingHold { target: page }
    readonly property bool wide: hold.wide
    // The word the detail shows (wide): the one tapped, else the first found.
    property var chosen: null
    readonly property var detailWord: chosen || (glossary.length > 0 ? glossary[0] : null)
    readonly property var alphabet: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("")
    // The letters with a word (the glossary without a query).
    readonly property var usedLetters: searching ? [] : Array.from(new Set(glossary.map(w => w.letter)))
    readonly property real railWidth: Look.unit(28)

    // A page keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    // The query searched (follows the field after a short pause while typing).
    property string query: ""
    readonly property bool searching: query.trim() !== ""
    // At most `limit` techniques are listed; one more found says there are more.
    readonly property int limit: 50
    // What the query finds, all at once: the rows below follow once for a new query, not once for
    // each part found (four new lists for the list view, each made anew).
    readonly property var found: {
        const query = page.query
        if (query.trim() === "") {
            return { searching: false, techniques: [], notes: [], comments: [], entries: [], glossary: Glossary.words }
        }
        return { searching: true, techniques: Programme.search(query, page.limit + 1),
                 notes: Practice.notesRevision < 0 ? [] : Practice.searchNotes(query, page.limit + 1),
                 comments: Programme.searchComments(query, page.limit + 1),
                 entries: Courses.revision < 0 ? [] : Courses.searchEntries(query, page.limit + 1),
                 glossary: Glossary.search(query) }
    }
    readonly property var techniques: found.techniques
    readonly property bool more: techniques.length > limit
    readonly property var shown: more ? techniques.slice(0, limit) : techniques
    readonly property var notes: found.notes
    readonly property bool notesMore: notes.length > limit
    readonly property var notesShown: notesMore ? notes.slice(0, limit) : notes
    readonly property var comments: found.comments
    readonly property var courseEntries: found.entries
    // The glossary rows: every word, or the words found.
    readonly property var glossary: found.glossary
    readonly property bool canSpeak: Glossary.speech === Glossary.Ready
    // The list's rows: {kind: "word", "technique", "note" or "hint", section, data}. The words come
    // first, row i is glossary[i]. One virtual list: only the rows on screen are made, not every
    // technique and note found (100 rows, 0.1 s on the first letter).
    readonly property var rows: {
        const found = page.found
        const words = found.glossary.map(w => ({ kind: "word", section: found.searching ? qsTr("Glossary") : w.letter, data: w }))
        const techniques = found.techniques.slice(0, page.limit).map(t => ({ kind: "technique", section: qsTr("Techniques"), data: t }))
        if (found.techniques.length > page.limit) {
            techniques.push({ kind: "hint", section: qsTr("Techniques"), data: { name: "moreHint",
                             text: qsTr("More than %1 techniques found. Add a word to narrow the search.").arg(page.limit) } })
        }
        const notes = found.notes.slice(0, page.limit).map(n => ({ kind: "note", section: qsTr("Notes"), data: n }))
        if (found.notes.length > page.limit) {
            notes.push({ kind: "hint", section: qsTr("Notes"), data: { name: "notesMoreHint",
                        text: qsTr("More than %1 notes found. Add a word to narrow the search.").arg(page.limit) } })
        }
        const comments = found.comments.slice(0, page.limit).map(c => ({ kind: "comment", section: qsTr("In comments"), data: c }))
        if (found.comments.length > page.limit) {
            comments.push({ kind: "hint", section: qsTr("In comments"), data: { name: "commentsMoreHint",
                           text: qsTr("More than %1 comments found. Add a word to narrow the search.").arg(page.limit) } })
        }
        const entries = found.entries.slice(0, page.limit).map(e => ({ kind: "courseEntry", section: qsTr("In course notes"), data: e }))
        if (found.entries.length > page.limit) {
            entries.push({ kind: "hint", section: qsTr("In course notes"), data: { name: "courseEntriesMoreHint",
                          text: qsTr("More than %1 course notes found. Add a word to narrow the search.").arg(page.limit) } })
        }
        return words.concat(techniques, notes, comments, entries)
    }

    title: qsTr("Glossary & search")

    // A new query shows its results from the top (the list keeps its position when the header
    // with the techniques found changes height, which left it above the first row).
    onQueryChanged: {
        chosen = null
        Qt.callLater(list.positionViewAtBeginning)
    }

    // A tap on a letter: its section at the top.
    function jumpTo(letter) {
        list.positionViewAtIndex(page.glossary.findIndex(w => w.letter === letter), ListView.Beginning)
    }

    header: LookToolBar {
        LookTextField {
            id: field

            objectName: "searchField"
            anchors.fill: parent
            placeholderText: qsTr("Kiriotoshi, 切り落とし or Hüftwurf")
            Accessible.name: qsTr("Search")
            onTextChanged: pause.restart()
            onAccepted: page.query = text
            // Down goes into the list.
            Keys.onDownPressed: {
                list.currentIndex = Math.max(0, list.currentIndex)
                list.forceActiveFocus()
            }
        }
    }

    // A short pause: a search takes some 20 ms, a letter typed fast comes after about 100.
    Timer {
        id: pause

        interval: 100
        onTriggered: page.query = field.text
    }

    // Once the page has slid in: the field has the focus, and what the search compares is built now,
    // not on the first letter.
    Timer {
        running: true
        interval: Kirigami.Units.longDuration
        onTriggered: {
            // The field takes the focus once the page has its size: TypingHold keeps the columns and
            // the height of the moment typing starts.
            // Not once the reader has typed or gone into the list.
            if (field.text === "" && !list.activeFocus) {
                field.forceActiveFocus()
            }
            Programme.prepareSearch()
            Practice.prepareSearch()
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // Wide: the rail stays in place at the left while the list scrolls.
        LetterRail {
            objectName: "letterRail"
            Layout.fillHeight: true
            Layout.preferredWidth: page.railWidth
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: page.wide && !page.searching
            letters: page.alphabet
            available: page.usedLetters
            current: list.currentSection
            onPicked: letter => page.jumpTo(letter)
        }

    ListView {
        id: list

        objectName: "glossaryList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: page.rows
        reuseItems: true
        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
        // The list stays at its top while the head changes height (a query's results, the speech
        // hint, letters wrapping anew), only if it stood there: not once the reader has moved it
        // (flick, wheel, keys, a letter). A head that changes height leaves contentY as it is.
        property bool keepTop: true
        onContentYChanged: keepTop = atYBeginning

        function toTop() {
            if (keepTop) {
                positionViewAtBeginning()
            }
        }
        currentIndex: -1
        activeFocusOnTab: true
        // A–Z headings in the whole glossary; words found stand under "Glossary", then "Techniques",
        // "Notes", "In comments" and "In course notes".
        section.property: "section"
        // The heading stays at the top while its section scrolls, on the page's ground.
        section.labelPositioning: ViewSection.InlineLabels | ViewSection.CurrentLabelAtStart
        section.delegate: Rectangle {
            required property string section

            width: list.width
            height: heading.implicitHeight
            color: Look.backgroundColor

            LookSectionLabel {
                id: heading

                objectName: "letterHeading"
                width: parent.width
                topPadding: Kirigami.Units.largeSpacing
                bottomPadding: Kirigami.Units.smallSpacing
                leftPadding: Kirigami.Units.largeSpacing
                text: parent.section
            }
        }

        // Up from the first row goes back to the field; Return or Space say the current word or open
        // the current technique or note.
        Keys.onUpPressed: event => {
            if (currentIndex > 0) {
                event.accepted = false
                return
            }
            field.forceActiveFocus()
        }
        Keys.onReturnPressed: page.openRow(page.rows[list.currentIndex])
        Keys.onEnterPressed: page.openRow(page.rows[list.currentIndex])
        Keys.onSpacePressed: page.openRow(page.rows[list.currentIndex])

        // The hints; rows and headings bring their own margin.
        header: ColumnLayout {
            width: list.width
            spacing: Kirigami.Units.smallSpacing
            onHeightChanged: Qt.callLater(list.toTop)

            LookLabel {
                objectName: "glossaryIntro"
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: !page.searching
                text: qsTr("%n Japanese term(s), with kanji and translation.", "", Glossary.words.length)
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }

            LookLabel {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                objectName: "speechHint"
                // Once with the glossary, not above every result.
                visible: !page.searching && (Glossary.speech === Glossary.NoVoice || Glossary.speech === Glossary.Unsupported)
                text: Glossary.speech === Glossary.Unsupported
                      ? qsTr("No speech output in this version: no pronunciation.")
                      : qsTr("No Japanese voice found: no pronunciation (Android: settings, text-to-speech).")
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }

            LookLabel {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: page.searching && page.techniques.length === 0 && page.notes.length === 0 && page.comments.length === 0
                         && page.courseEntries.length === 0 && page.glossary.length === 0
                text: qsTr("Nothing found for “%1”.").arg(page.query.trim())
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }
        }

        delegate: Loader {
            id: rowLoader

            required property var modelData
            required property int index

            // Full width, so that the view's own placing of its items does not matter: the row
            // inside keeps the reading width.
            width: ListView.view.width
            sourceComponent: modelData.kind === "hint" ? hintRow : resultRow

            Component {
                id: resultRow

                LookListRow {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    readonly property var found: rowLoader.modelData.data
                    readonly property string kind: rowLoader.modelData.kind

                    objectName: kind === "word" ? "glossaryRow" : kind === "technique" ? "techniqueResult"
                                : kind === "comment" ? "commentResult" : kind === "courseEntry" ? "courseEntryResult" : "noteResult"
                    // The list is one Tab stop; Up and Down move in it.
                    activeFocusOnTab: false
                    focusOnClick: false
                    selected: (rowLoader.ListView.isCurrentItem && list.activeFocus)
                              || (page.wide && kind === "word" && !!page.detailWord && found.word === page.detailWord.word)
                    leadingText: kind === "technique" && found.nr ? String(found.nr) : ""
                    meta: kind === "comment" ? found.gradeName : ""
                    // From the row itself, kind and data together: a reused row gets both at once.
                    text: page.rowText(rowLoader.modelData)
                    subtitle: page.rowSubtitle(rowLoader.modelData)
                    // A tap, or Return and Space on the current row (the list's keys), says the word
                    // or opens the technique or note.
                    onClicked: {
                        list.currentIndex = rowLoader.index
                        page.openRow(rowLoader.modelData)
                    }
                    // The kanji at the right end, as large as the word (the row's meta figure is small);
                    // the button in a Loader: an invisible one would still keep its room.
                    trailing: Item {
                        // Sized by hand: the row hides a slot whose children have no size yet.
                        implicitWidth: kanji.width + (voice.active ? voice.width + Kirigami.Units.smallSpacing : 0)
                        implicitHeight: Math.max(kanji.height, voice.height)

                        LookLabel {
                            id: kanji

                            objectName: "rowKanji"
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.kind === "word" ? row.found.jp : ""
                            font: Look.japaneseFont(Look.titleFont(Look.defaultFont.pointSize * 1.25))
                            color: Look.mutedTextColor
                        }

                        Loader {
                            id: voice

                            x: kanji.width + Kirigami.Units.smallSpacing
                            anchors.verticalCenter: parent.verticalCenter
                            active: page.canSpeak && row.kind === "word"
                            sourceComponent: LookToolButton {
                                objectName: "sayButton"
                                focusPolicy: Qt.NoFocus
                                display: QQC2.AbstractButton.IconOnly
                                icon.name: "media-playback-start"
                                text: qsTr("Pronunciation")
                                Accessible.name: qsTr("Pronounce %1").arg(row.found.word)
                                onClicked: Glossary.say(row.found.speech)
                            }
                        }
                    }
                }
            }

            Component {
                id: hintRow

                LookLabel {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    objectName: rowLoader.modelData.data.name
                    leftPadding: Kirigami.Units.largeSpacing
                    rightPadding: Kirigami.Units.largeSpacing
                    topPadding: Kirigami.Units.smallSpacing
                    bottomPadding: Kirigami.Units.smallSpacing
                    text: rowLoader.modelData.data.text
                    color: Look.mutedTextColor
                    wrapMode: Text.Wrap
                }
            }
        }

        footer: ColumnLayout {
            width: list.width
            spacing: Kirigami.Units.largeSpacing

            LookLabel {
                objectName: "glossarySource"
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: page.glossary.length > 0
                text: qsTr("Translations: %1").arg(Glossary.source)
                font: Look.smallFont
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }
        }
    }


        // Phone: a slim rail at the right edge; dragging over it jumps, a bubble shows the letter.
        LetterRail {
            objectName: "letterRailPhone"
            Layout.fillHeight: true
            Layout.preferredWidth: page.railWidth
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.smallSpacing
            visible: !page.wide && !page.searching
            bubble: true
            letters: page.alphabet
            available: page.usedLetters
            current: list.currentSection
            onPicked: letter => page.jumpTo(letter)
        }

        // Wide: the word tapped.
        Rectangle {
            objectName: "glossaryDetail"
            visible: page.wide
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(page.width * 0.4)
            color: Look.cardColor

            Rectangle {
                width: Look.borderWidth
                height: parent.height
                color: Look.ruleColor
            }

            QQC2.ScrollView {
                id: detailScroll

                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing * 2
                contentWidth: availableWidth

                WordDetail {
                    width: detailScroll.availableWidth
                    word: page.detailWord
                    onTechniqueRequested: technique => page.openRow({ kind: "technique", data: technique })
                }
            }
        }
    }

    // What a row says. As in the programme: the technique's and the attack's addition tell rows
    // apart; a note in one line, as the row shows it.
    function rowText(row) {
        const found = row.data
        if (row.kind === "word") {
            return found.word
        }
        if (row.kind === "technique") {
            return found.title + (found.extra && !found.nr ? " (" + found.extra + ")" : "") + (found.jp ? "  " + found.jp : "")
        }
        if (row.kind === "comment") {
            return found.title
        }
        if (row.kind === "courseEntry") {
            return found.excerpt
        }
        return row.kind === "note" ? found.text.replace(/\s+/g, " ") : ""
    }

    function rowSubtitle(row) {
        const found = row.data
        if (row.kind === "word") {
            return found.meaning || qsTr("No translation in the lexicon")
        }
        if (row.kind === "technique") {
            return [found.disciplineName + " " + found.gradeName, found.groupName,
                    (found.attack || "") + (found.attackExtra ? " (" + found.attackExtra + ")" : ""),
                    found.nr ? found.extra : ""].filter(x => x).join(" · ")
        }
        if (row.kind === "comment") {
            return found.excerpt
        }
        if (row.kind === "courseEntry") {
            return [found.title, CourseDays.range(found.first, found.last)].filter(x => x).join(" · ")
        }
        if (row.kind !== "note") {
            return ""
        }
        return [page.noteEntry(found.entry).title, found.created.toLocaleDateString(Qt.locale(), Locale.ShortFormat)].filter(x => x).join(" · ")
    }

    // A note's technique; one no longer in the programme (a newer catalogue) keeps its notes.
    function noteEntry(id) {
        const found = Programme.entry(id)
        return found.id ? found : { id: id, title: qsTr("Technique no longer in the programme") }
    }

    // A word is said, a technique opens its sheet, a note its technique's notes, a comment hit the
    // comment, a course note its notebook at that entry.
    function openRow(row) {
        if (!row) {
            return
        }
        if (row.kind === "word" && page.wide) {
            page.chosen = row.data
        } else if (row.kind === "word") {
            Glossary.say(row.data.speech)
        } else if (row.kind === "technique") {
            sheet.entry = row.data
            sheet.playable = !!row.data.video && Videos.available(row.data.video.video)
            sheet.open()
        } else if (row.kind === "comment") {
            page.Kirigami.PageStack.push(Qt.resolvedUrl("CommentPage.qml"), { entry: row.data })
        } else if (row.kind === "courseEntry") {
            page.Kirigami.PageStack.push(Qt.resolvedUrl("CoursePage.qml"), { uid: row.data.course, entryUid: row.data.uid })
        } else if (row.kind === "note") {
            page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), { entry: page.noteEntry(row.data.entry) })
        }
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
