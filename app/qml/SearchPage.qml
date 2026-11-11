pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "playlists.js" as Playlists

// Glossary and search (clickdummy "Glossar & Suche"). Without a query: the glossary A–Z (word,
// kanji, translation in the app's language, a speaker button). With a query: techniques of every
// discipline and grade by name, attack (with its addition), group or Japanese, the glossary (also
// by the translation's words) and the own notes; the glossary first, as the techniques can be up to 50 rows. Case, accents, hyphens and okurigana do not matter; several words
// must all match. A technique opens its sheet, a note its notes page.
//
//   ListView (virtual: about 300 words, or up to 50 techniques and 50 notes found besides)
//   ├─ header   hints
//   ├─ rows     the glossary under A … Z headings without a query; with one the words, techniques
//   │           and notes found, each kind under its heading and with a hint when there are more
//   └─ footer   source of the translations
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
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
            return { searching: false, techniques: [], notes: [], glossary: Glossary.words }
        }
        return { searching: true, techniques: Programme.search(query, page.limit + 1),
                 notes: Practice.notesRevision < 0 ? [] : Practice.searchNotes(query, page.limit + 1),
                 glossary: Glossary.search(query) }
    }
    readonly property var techniques: found.techniques
    readonly property bool more: techniques.length > limit
    readonly property var shown: more ? techniques.slice(0, limit) : techniques
    readonly property var notes: found.notes
    readonly property bool notesMore: notes.length > limit
    readonly property var notesShown: notesMore ? notes.slice(0, limit) : notes
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
        return words.concat(techniques, notes)
    }

    title: qsTr("Glossary & search")

    // A new query shows its results from the top (the list keeps its position when the header
    // with the techniques found changes height, which left it above the first row).
    onQueryChanged: Qt.callLater(list.positionViewAtBeginning)

    header: LookToolBar {
        LookTextField {
            id: field

            objectName: "searchField"
            anchors.fill: parent
            placeholderText: qsTr("Kiriotoshi, 切り落とし or Hüftwurf")
            Accessible.name: qsTr("Search")
            Component.onCompleted: forceActiveFocus()
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

    // Once the page has slid in: what the search compares is built now, not on the first letter.
    Timer {
        running: true
        interval: Kirigami.Units.longDuration
        onTriggered: {
            Programme.prepareSearch()
            Practice.prepareSearch()
        }
    }

    ListView {
        id: list

        objectName: "glossaryList"
        model: page.rows
        reuseItems: true
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
        // A–Z headings in the whole glossary; words found stand under "Glossary", then "Techniques"
        // and "Notes".
        section.property: "section"
        section.delegate: LookSectionLabel {
            required property string section

            objectName: "letterHeading"
            width: ListView.view.width
            topPadding: Kirigami.Units.largeSpacing
            bottomPadding: Kirigami.Units.smallSpacing
            leftPadding: Kirigami.Units.largeSpacing
            text: section
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

        // Hints and headings keep the page's margin; rows bring their own.
        header: ColumnLayout {
            width: ListView.view.width
            spacing: Kirigami.Units.largeSpacing
            onHeightChanged: Qt.callLater(list.toTop)

            // A–Z: the letters with a word, a tap goes to the first (clickdummy "Glossar").
            Flow {
                objectName: "letterBar"
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: !page.searching
                spacing: Look.unit(2)

                Repeater {
                    model: page.searching ? [] : Array.from(new Set(page.glossary.map(w => w.letter)))

                    LookToolButton {
                        required property string modelData

                        objectName: "letterJump"
                        text: modelData
                        Accessible.name: qsTr("Words with %1").arg(modelData)
                        focusPolicy: Qt.NoFocus
                        onClicked: list.positionViewAtIndex(page.glossary.findIndex(w => w.letter === modelData), ListView.Beginning)
                    }
                }
            }
            LookLabel {
                objectName: "glossaryIntro"
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.largeSpacing
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: !page.searching
                text: qsTr("%n Japanese term(s), with kanji and English translation where the lexicon or the programme has them. The search also finds English words, techniques and your notes.", "", Glossary.words.length)
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
                      ? qsTr("This version of Mitori has no speech output, so there is no pronunciation.")
                      : qsTr("No Japanese voice for speech output found. Where the system offers one (Android: settings, text-to-speech output), install it to hear the pronunciation.")
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }

            LookLabel {
                Layout.fillWidth: true
                Layout.leftMargin: Kirigami.Units.largeSpacing
                Layout.rightMargin: Kirigami.Units.largeSpacing
                visible: page.searching && page.techniques.length === 0 && page.notes.length === 0 && page.glossary.length === 0
                text: qsTr("Nothing found for “%1”.").arg(page.query.trim())
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }
        }

        delegate: Loader {
            id: rowLoader

            required property var modelData
            required property int index

            width: ListView.view.width
            sourceComponent: modelData.kind === "hint" ? hintRow : resultRow

            Component {
                id: resultRow

                LookListRow {
                    id: row

                    readonly property var found: rowLoader.modelData.data
                    readonly property string kind: rowLoader.modelData.kind

                    objectName: kind === "word" ? "glossaryRow" : kind === "technique" ? "techniqueResult" : "noteResult"
                    // The list is one Tab stop; Up and Down move in it.
                    activeFocusOnTab: false
                    focusOnClick: false
                    selected: rowLoader.ListView.isCurrentItem && list.activeFocus
                    leadingText: kind === "technique" && found.nr ? String(found.nr) : ""
                    // From the row itself, kind and data together: a reused row gets both at once.
                    text: page.rowText(rowLoader.modelData)
                    subtitle: page.rowSubtitle(rowLoader.modelData)
                    // A tap, or Return and Space on the current row (the list's keys), says the word
                    // or opens the technique or note.
                    onClicked: {
                        list.currentIndex = rowLoader.index
                        page.openRow(rowLoader.modelData)
                    }
                    trailing: LookToolButton {
                        objectName: "sayButton"
                        visible: page.canSpeak && row.kind === "word"
                        focusPolicy: Qt.NoFocus
                        display: QQC2.AbstractButton.IconOnly
                        icon.name: "media-playback-start"
                        text: qsTr("Pronunciation")
                        Accessible.name: qsTr("Pronounce %1").arg(row.found.word)
                        onClicked: Glossary.say(row.found.speech)
                    }
                }
            }

            Component {
                id: hintRow

                LookLabel {
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
            width: ListView.view.width
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

    // What a row says. As in the programme: the technique's and the attack's addition tell rows
    // apart; a note in one line, as the row shows it.
    function rowText(row) {
        const found = row.data
        if (row.kind === "word") {
            return found.word + (found.jp ? "  " + found.jp : "")
        }
        if (row.kind === "technique") {
            return found.title + (found.extra && !found.nr ? " (" + found.extra + ")" : "") + (found.jp ? "  " + found.jp : "")
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

    // A word is said, a technique opens its sheet, a note its technique's notes.
    function openRow(row) {
        if (!row) {
            return
        }
        if (row.kind === "word") {
            Glossary.say(row.data.speech)
        } else if (row.kind === "technique") {
            sheet.entry = row.data
            sheet.playable = !!row.data.video && Videos.available(row.data.video.video)
            sheet.open()
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
