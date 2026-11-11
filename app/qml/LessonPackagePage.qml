pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori
import "playlists.js" as Playlists

// One Lernpaket: its sections and techniques in order, as the programme lists them. A row opens the
// technique sheet, ▶ goes straight to the player; "Play all" plays the package's techniques whose
// video is on the device.
//
//   Basic techniques                        (section; its text below)
//   Irimi-nage  Shomen-uchi · variant       ●●○○ ▶
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    // The package's id ("uid", as ListAndPage asks for the page beside the list).
    required property string uid
    // Follows a package that came or went.
    readonly property var info: Library.packages.find(p => p.id === uid) || null
    readonly property var rows: info ? Library.rows(uid) : []
    readonly property var playlist: rows.filter(r => page.playable(r))

    // ListAndPage, beside the list: the same page, so the pane may ask for it.
    property var paneHost: null

    title: info ? info.title : qsTr("Learning videos")

    // Reads Videos.folder so that bindings calling it follow a new folder from the settings.
    function playable(row) {
        return Videos.folder !== undefined && row.kind === "entry" && !!row.video && Videos.available(row.video.video)
    }

    function open(entry) {
        sheet.entry = entry
        sheet.playable = page.playable(entry)
        sheet.open()
    }

    function play(entry) {
        sheet.close()
        const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
        window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), Playlists.around(Programme, Videos, Library, entry))
    }

    function playAll() {
        const window = page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow
        window.pageStack.push(Qt.resolvedUrl("PlayerPage.qml"), { playlist: page.playlist, index: 0 })
    }

    ListView {
        id: list

        objectName: "lessonList"
        model: page.rows
        reuseItems: true

        header: ColumnLayout {
            width: ListView.view.width
            spacing: Kirigami.Units.smallSpacing

            LookLabel {
                objectName: "packageText"
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: !!page.info && !!page.info.text
                text: page.info ? page.info.text : ""
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }
            LookLabel {
                objectName: "packageGone"
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.largeSpacing
                visible: !page.info
                text: qsTr("This package is not on the device any more.")
                color: Look.mutedTextColor
                wrapMode: Text.Wrap
            }
            LookButton {
                objectName: "playAll"
                Layout.margins: Kirigami.Units.largeSpacing
                visible: page.playlist.length > 0
                role: LookButton.Role.Primary
                icon.name: "media-playback-start"
                text: qsTr("Play all")
                onClicked: page.playAll()
            }
        }

        delegate: Loader {
            id: rowLoader

            required property var modelData

            width: ListView.view.width
            sourceComponent: modelData.kind === "group" ? groupRow : entryRow

            Component {
                id: groupRow

                Item {
                    implicitHeight: heading.implicitHeight + (note.visible ? note.implicitHeight : 0) + Kirigami.Units.largeSpacing * 2

                    LookGroupHead {
                        id: heading

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.topMargin: Kirigami.Units.largeSpacing
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        title: rowLoader.modelData.title
                        japanese: rowLoader.modelData.jp || ""
                    }
                    LookLabel {
                        id: note

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: heading.bottom
                        anchors.leftMargin: Kirigami.Units.largeSpacing
                        anchors.rightMargin: Kirigami.Units.largeSpacing
                        visible: !!rowLoader.modelData.text
                        text: rowLoader.modelData.text || ""
                        color: Look.mutedTextColor
                        wrapMode: Text.Wrap
                    }
                }
            }

            Component {
                id: entryRow

                LookListRow {
                    id: entryItem

                    readonly property var entry: rowLoader.modelData
                    readonly property bool playable: page.playable(entry)

                    objectName: "lessonRow"
                    text: entry.title
                    subtitle: [entry.attack, entry.extra, entry.jp].filter(x => x).join(" · ")
                    onClicked: page.open(entry)
                    trailing: RowLayout {
                        spacing: Kirigami.Units.smallSpacing

                        LookLevelDots {
                            value: Practice.revision >= 0 ? Practice.level(entryItem.entry.id) : 0
                            names: Practice.levelNames
                            color: Look.levelColor(value)     // as in the programme
                        }
                        LookPlayButton {
                            // Without a video the place stays empty: the dots stay in line.
                            objectName: "rowPlay"
                            opacity: entryItem.playable ? 1 : 0
                            enabled: entryItem.playable
                            activeFocusOnTab: false     // Enter on the row: the sheet plays it
                            text: qsTr("Play")
                            onClicked: page.play(entryItem.entry)
                        }
                    }
                }
            }
        }
    }

    TechniqueSheet {
        id: sheet

        objectName: "techniqueSheet"
        onPlayRequested: entry => page.play(entry)
        onCommentRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("CommentPage.qml"), { entry: entry })
        onNotesRequested: entry => page.Kirigami.PageStack.push(Qt.resolvedUrl("NotesPage.qml"), { entry: entry })
        onVideosRequested: page.Kirigami.PageStack.push(Qt.resolvedUrl("VideosPage.qml"))
    }
}
