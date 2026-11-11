import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import Mitori

// Technique sheet (clickdummy "Programm", row tapped): TechniqueBody as a dialog.
Kirigami.Dialog {
    id: sheet

    property var entry: ({})
    property bool playable: false
    readonly property bool hasVideo: column.hasVideo
    readonly property var steps: column.steps
    readonly property int noteCount: column.noteCount
    // The dialog's scrolling content (Kirigami puts the column into a ScrollView).
    readonly property Flickable flickable: ((contentItem as QQC2.ScrollView)?.contentItem as Flickable) ?? null

    signal playRequested(var entry)
    signal commentRequested(var entry)
    signal notesRequested(var entry)
    // Without the video on the device: to the videos and DVD codes.
    signal videosRequested()

    title: column.title
    preferredWidth: Kirigami.Units.gridUnit * 24
    // Under Shinki the sheet is a sheet from the bottom, the whole width (the clickdummy); under
    // the other styles it stays the centred dialog.
    readonly property bool shinkiSheet: Look.shinki
    width: shinkiSheet && parent ? parent.width : Math.min(preferredWidth, absoluteMaximumWidth)
    // Centred without Kirigami's move on opening (y follows the opacity): with the Kamae exercise
    // the sheet grows while it fades in, and y ran into a binding loop.
    // From the bottom it grows with its content (a new last note); Kirigami's height stays as it opened.
    height: shinkiSheet && flickable ? Math.min(flickable.contentHeight + topPadding + bottomPadding + 2 * Look.borderWidth,
                                                maximumHeight)
                                     : implicitHeight
    y: parent ? (shinkiSheet ? Math.round(parent.height - height) : Math.round((parent.height - height) / 2)) : 0
    padding: shinkiSheet ? Look.unit(16) : Kirigami.Units.largeSpacing

    // The panel: the style's ground, its frame, no rounding (the clickdummy's sheet).
    background: Rectangle {
        color: Look.backgroundColor
        border.width: Look.borderWidth
        border.color: Look.ruleColor
    }

    // Not a content child: the dialog's scroll view sizes itself by its only child, the column.
    property Item lookScope: LookScope { target: sheet.contentItem }
    // The head lies beside the content: without it, its title and ✕ kept the platform's colours.
    property Item headScope: LookScope { target: sheet.header }

    // Up/Down, Page Up/Down, Home and End scroll a sheet taller than the window (the Kamae
    // exercise on a phone); the mouse wheel does already. From the content and from the header
    // (Close may hold the focus).
    function scrollKey(event) {
        column.scrollIn(sheet.flickable, event)
    }

    // The header: Kirigami's, with the keys above; under Shinki the sheet's own (a grip, the name
    // in the book face, its Japanese below it).
    header: Kirigami.DialogHeader {
        dialog: sheet
        // Under Shinki the sheet has its own head (in the content): the grip, the name in the book
        // face, its Japanese.
        visible: !sheet.shinkiSheet
        height: sheet.shinkiSheet ? 0 : implicitHeight
        contentItem: Kirigami.DialogHeaderTopContent {
            dialog: sheet
            // Kirigami's ✕ keeps the platform's colour whatever the scope says: dark on Kante's dark.
            showCloseButton: false

            LookToolButton {
                objectName: "sheetClose"
                icon.name: "window-close-symbolic"
                text: qsTr("Close")
                display: QQC2.AbstractButton.IconOnly
                onClicked: sheet.close()
            }
        }
        Keys.onPressed: event => sheet.scrollKey(event)
    }

    // The popup itself holds the focus when it opens; the column takes it for the keys.
    onOpened: column.forceActiveFocus()

    TechniqueBody {
        id: column

        entry: sheet.entry
        playable: sheet.playable
        onScrollKey: event => sheet.scrollKey(event)
        onCloseRequested: sheet.close()
        onPlayRequested: entry => sheet.playRequested(entry)
        onCommentRequested: entry => sheet.commentRequested(entry)
        onNotesRequested: entry => sheet.notesRequested(entry)
        // The same technique in the programme: this sheet takes its entry, whoever hosts it.
        onProgrammeRequested: entry => {
            sheet.entry = entry
            sheet.playable = !!entry.video && Videos.available(entry.video.video)
        }
        // The same technique in a learning video: likewise.
        onLessonRequested: entry => {
            sheet.entry = entry
            sheet.playable = !!entry.video && Videos.available(entry.video.video)
        }
        onVideosRequested: sheet.videosRequested()
    }
}
