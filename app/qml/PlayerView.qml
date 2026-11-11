pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Controls.impl
import QtQuick.Layouts
import QtMultimedia
import org.kde.kirigami as Kirigami
import Mitori

// The player (clickdummy "Player" and "Querformat"): the technique's chapter of the exam video,
// without the black bars, in a loop by default; the style's transport bar with four tempi (sound off
// below 100 %) and single frames; double tap left/right = 2 s back/on. Landscape: the controls in
// a column on the right, or around the picture when there is room. PlayerPage shows it as a page; on a tablet the programme shows it beside
// the list (`compact`: picture above the controls, no Back). Swipe up/down on the left half of
// the picture: the screen's brightness, on the right half: the volume (Levels); the picture's
// height is the whole range. Leaving the player gives the screen its brightness back.
Item {
    id: page

    required property var playlist
    property int index: 0
    // Beside the list on a tablet: always the picture above the controls, no Back button.
    property bool compact: false
    // Full screen (the clickdummy's ⤢ "Player groß"): the page decides what that means.
    property bool big: false
    // Where the first chapter starts, once (the small player's place when it goes full screen).
    property real startAt: -1
    // The old row while list and place change together (setList): no row of the new list at the
    // old place on the way.
    property var heldRow: null
    readonly property var current: heldRow || playlist[index] || ({})
    readonly property string video: current.video ? current.video.video : ""
    // A technique of the training may have no video on the device: a card stands for the picture.
    // The video's file now; it reports only a real change. All that belongs to a file hangs on it:
    // when a bundle comes or goes, picture, times and cut change together.
    readonly property url file: Videos.folder !== undefined ? Videos.source(video) : ""
    readonly property bool hasVideo: video !== "" && file.toString() !== ""
    // The subtitle tracks of the video's bundle ([{language, source}]), shown on by default: the
    // user's choice (off, or a language) lives in Videos and holds over all videos of the run.
    readonly property var subtitleTracks: Videos.folder !== undefined && hasVideo ? Videos.subtitles(video) : []
    // The language shown, "" for none (off, or the video has no track). The choice's signal and the
    // tracks make the binding read it anew.
    readonly property string subtitleLanguage: Videos.subtitlesOn !== undefined && Videos.subtitleChoice !== undefined
                                               && subtitleTracks.length >= 0 ? Videos.subtitleLanguage(video) : ""
    readonly property real subtitlePlateAlpha: 0.75
    // Where the technique stands: attack · addition · grade · position ("Shomen-uchi · 5. Kyu · 3 / 8").
    readonly property string placeText: [current.attack, current.attackExtra, current.gradeName,
                                         playlist.length > 1 ? (index + 1) + " / " + playlist.length : ""]
                                        .filter(x => !!x).join(" · ")
    // How many of the playlist are rated today (the training's progress).
    readonly property int practisedCount: Practice.revision >= 0 ? playlist.filter(r => Practice.ratedToday(r.id)).length : 0
    // A loaded bundle brings its own cut points; they fit its file.
    readonly property var place: current.video && file !== undefined ? Videos.place(current.id, current.video) : null
    readonly property real from: place ? place.von * 1000 : 0
    readonly property real to: place ? place.bis * 1000 : 0
    // Where the loop turns: the chapter end, but never the end of the file (the last chapter of a
    // video ends with it, and a player at the end of the file no longer seeks back).
    readonly property real end: player.duration > 0 ? Math.min(to, player.duration - 250) : to
    readonly property var crop: file !== undefined ? Videos.crop(video) : ({})
    // Beside the list with room (the clickdummy's `.trow`, `.tbelow`): the switches beside the
    // transport, and below them two columns. A narrow pane keeps the one column.
    readonly property bool paneColumns: compact && width >= Look.unit(560)
    // The note field holds the focus (the page keeps the player while the keyboard shrinks it).
    readonly property bool noteFocused: !!controlsView.focusedField && controlsView.focusedField.activeFocus
    // Sideways only with a picture; without a video the card and the controls stand as upright.
    // By the window's height: the page's own changes with the head that this property hides.
    readonly property bool landscape: !compact && hasVideo && (big || width > Window.height)
    // On the rail: 62 px on the phone (CD .qrail), 84 px on a tablet in landscape (CD .tab .qrail).
    // The phone held sideways is about 360 dp tall, a tablet sideways 720 dp.
    readonly property bool tabletSideways: page.landscape && height >= Tablet.minHeight
    // Enough room above and below the picture (a tablet 16:10, a wide video): the title and the
    // controls stand there instead of on the rail (the clickdummy's `.qbands`).
    readonly property bool bands: landscape && bandHeight * 2 >= Look.unit(120)
    readonly property real bandHeight: (height - width / stage.ratio) / 2
    readonly property bool onRail: landscape && !bands
    readonly property string titleWithAddition: (current.title || "") + (current.extra && !current.nr ? " (" + current.extra + ")" : "")
    readonly property string titleText: (current.nr ? current.nr + " · " : "") + titleWithAddition
    readonly property string timeText2: timeText(player.position - from) + " / " + timeText(to - from)
    readonly property var tempi: [0.25, 0.5, 0.75, 1]
    readonly property int frameMs: 40       // 25 frames per second (PAL DVDs)
    readonly property int jumpMs: 2000      // double tap
    property bool looping: true
    // Each technique starts at 1× (owner, 06.11.2026): its loop and full screen keep the tempo.
    readonly property real normalRate: 1
    // The technique on screen: only another one restarts, a list made anew brings new objects for it.
    property string shownEntry: ""
    // The double tap shows what it did, for a moment (the clickdummy): "2 s ››" on the side that
    // was tapped. The text is a symbol, not a word: it stays the same in every language.
    property string jumpHint: ""
    property bool jumpRight: true
    // The tempo (the rail's fields).
    function setSpeed(rate) {
        player.playbackRate = rate
    }
    // "0,25×": the tempo in the locale's numbers.
    readonly property string tempoText: String(player.playbackRate).replace(".", Qt.locale().decimalPoint) + "\u00D7"
    function showJump(right) {
        jumpRight = right
        jumpHint = right ? "2 s \u203A\u203A" : "\u2039\u2039 2 s"
        jumpTimer.restart()
    }
    Timer {
        id: jumpTimer
        interval: 500
        onTriggered: page.jumpHint = ""
    }
    // Training (today's practice): rating a technique moves on to the next one not yet
    // practised today.
    property bool training: false
    // Start at the chapter once per loaded file: the FFmpeg backend reports LoadedMedia again
    // after every seek, and restarting there would undo each step, jump and timeline move.
    property bool startPending: true
    // Whether a newly loaded chapter plays (off while another page lies above the small player,
    // or before its first tap: it loads at the chapter start and waits).
    property bool autoPlay: true
    // For the UI test: where the video stands (ms) and whether it plays.
    readonly property alias position: player.position
    readonly property alias playing: player.playing
    readonly property alias duration: player.duration
    readonly property alias rate: player.playbackRate
    readonly property alias source: player.source

    // A note begun: saved now (the page is left, but stays).
    function keepDraft() {
        noteRow.keepDraft()
    }

    // The entry on screen, for the programme list to mark it when the user comes back.
    signal shown(string id)
    // Back (landscape), the training's end and the notes of the technique: the page decides.
    signal backRequested()
    signal trainingEnded()
    signal notesRequested(var entry)
    signal commentRequested(var entry)
    signal bigRequested()
    signal bigLeft()
    // The user asked for play; the small player's page needs that for its first tap.
    signal playTapped()

    onCurrentChanged: {
        if (!current.id || current.id === shownEntry) {
            return
        }
        // On creating the page there was no technique before: startAt is the caller's (full screen).
        if (shownEntry !== "") {
            startAt = -1
        }
        shownEntry = current.id
        shown(current.id)
        player.playbackRate = normalRate

        // What waited for a tap or was loaded belonged to the technique before.
        holdStart = false
        loadedSource = ""

        // After the bindings of the new entry (from, to): onCurrentChanged runs before them.
        Qt.callLater(page.restartLoaded)
    }
    Component.onCompleted: {
        shownEntry = current.id || ""
        shown(current.id)
    }
    Component.onDestruction: {
        player.stop()
        Levels.restore()
    }

    function restart() {
        // Outside the chapter: the small player was still loading.
        player.position = startAt >= from && startAt <= to ? startAt : from
        startAt = -1
        loadedSource = player.source
        if (autoPlay && !holdStart) {
            player.play()
        }
        holdStart = false
    }
    // Another file is still loading: its LoadedMedia restarts.
    function restartLoaded() {
        if (!startPending) {
            restart()
        }
    }

    // The next restart stands. The file changed under the open player (a bundle came or was
    // updated, or went): it waits at the chapter's start for a tap instead of sounding by itself,
    // say under the notes. A first load replaces nothing. Ends with the technique or a tap.
    property url loadedSource
    property bool holdStart: false
    Connections {
        target: Videos
        function onFolderChanged() {
            const loaded = page.loadedSource.toString()
            if (loaded !== "" && Videos.source(page.video).toString() !== loaded) {
                page.holdStart = true
            }
        }
    }
    // Whether it plays, or will when its file is loaded.
    function willPlay() {
        return player.playing || (startPending && autoPlay && !holdStart)
    }
    // Where it stands, or will stand when its file is loaded.
    function placeNow() {
        return startPending ? startAt : player.position
    }
    // What a pane made anew needs of this one (the programme's small player).
    function restState() {
        return { id: current.id, rate: player.playbackRate, looping: looping, playing: willPlay(),
                 source: player.source.toString(), position: placeNow() }
    }
    // Another list, keeping technique `id` if it is in it, else its first. Not the user's choice:
    // a standing video stands at the new technique.
    function setList(list, id) {
        const before = current.id
        const stands = !willPlay()

        heldRow = current
        playlist = list
        index = Math.max(0, list.findIndex(r => r.id === id))
        heldRow = null

        if (current.id !== before) {
            holdStart = stands
        }
    }
    // Play from the chapter start when the video stands at (or after) the chapter end.
    function togglePlay() {
        if (player.playing) {
            player.pause()
            return
        }
        playTapped()    // first: restart() asks autoPlay
        holdStart = false
        if (player.position >= end - frameMs || player.mediaStatus === MediaPlayer.EndOfMedia) {
            restart()
        } else {
            player.play()
        }
    }
    function pause() {
        player.pause()
    }
    function resume() {
        player.play()
    }
    function seek(ms) {
        player.position = Math.max(page.from, Math.min(page.end, ms))
    }
    function step(direction) {
        player.pause()
        player.position = Math.max(from, Math.min(to, player.position + direction * frameMs))
    }
    function jump(ms) {
        player.position = Math.max(from, Math.min(to, player.position + ms))
    }
    // Training: the next technique not practised today, after this one and then from the start
    // (one skipped with "next"); when all are, the training ends.
    function nextOpen() {
        for (let k = 1; k < playlist.length; ++k) {
            const i = (index + k) % playlist.length
            if (!Practice.ratedToday(playlist[i].id)) {
                index = i
                return
            }
        }
        trainingEnded()
    }
    function go(direction) {
        const next = index + direction
        if (next >= 0 && next < playlist.length) {
            index = next
        }
    }
    // The button at the rail or the band: out of full screen, else back.
    readonly property string leaveSymbol: big ? "view-restore" : "go-previous-view"
    readonly property string leaveText: big ? qsTr("Exit full screen") : qsTr("Back")
    function leave() {
        if (big) {
            bigLeft()
            return
        }
        backRequested()
    }
    function timeText(ms) {
        const s = Math.max(0, Math.round(ms / 100) / 10)
        return s.toLocaleString(Qt.locale(), "f", 1) + " s"
    }

    MediaPlayer {
        id: player

        source: page.file
        videoOutput: output
        audioOutput: AudioOutput {
            muted: player.playbackRate < 1 || !Levels.sound
            volume: Levels.playerVolume
        }
        // The screen stays on while it plays (the switch "Screen on"), not while it stands.
        onPlayingChanged: Levels.setPlayback(playing ? Levels.Playback.Playing : Levels.Playback.Stopped)
        onSourceChanged: page.startPending = true
        onMediaStatusChanged: {
            if (player.mediaStatus === MediaPlayer.LoadedMedia && page.startPending) {
                page.startPending = false
                page.restart()
            }
        }
        onPositionChanged: {
            if (page.to <= 0 || player.position < page.end) {
                return
            }
            if (page.looping) {
                player.position = page.from
            } else {
                player.pause()
            }
        }
    }

    // The bar's keys (K, L, Home, + −, , .) work as soon as the player opens, not only after a
    // click into the bar; it lets Space and the arrows through to the handlers below.
    Keys.forwardTo: [transport]
    Keys.onSpacePressed: page.togglePlay()
    Keys.onLeftPressed: page.step(-1)
    Keys.onRightPressed: page.step(1)
    Keys.onEscapePressed: event => {
        // Beside the programme's list there is nothing to leave.
        event.accepted = page.big || !page.compact || page.training
        if (page.big) {
            page.bigLeft()
        } else if (event.accepted) {
            page.backRequested()
        }
    }

    // A symbol on the dark ground, drawn here with room for its caption below (the buttons draw
    // theirs in the middle, in their own ink).
    component StageIcon: IconImage {
        anchors.centerIn: parent
        sourceSize.width: Look.unit(22)
        sourceSize.height: Look.unit(22)
        color: Look.stageTextColor
    }
    component RailButton: LookToolButton {
        property string symbol
        property string caption

        focusPolicy: Qt.TabFocus    // Space stays with the player
        display: QQC2.AbstractButton.IconOnly
        StageIcon {
            anchors.verticalCenterOffset: parent.caption !== "" ? -Look.unit(6) : 0
            name: parent.symbol
        }
        LookLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            visible: parent.caption !== ""
            text: parent.caption
            color: Look.stageTextColor
            opacity: 0.7
            font: Look.smallFont
        }
    }

    // The subtitles' switch: one track toggles, several open a menu (Off, then each language by
    // its own name). Only for a video that has tracks.
    component SubtitleSwitch: LookToggle {
        id: sw

        objectName: "subtitleButton"
        readonly property bool several: page.subtitleTracks.length > 1
        visible: page.subtitleTracks.length > 0
        checkable: false
        checked: page.subtitleLanguage !== ""
        icon.name: "media-view-subtitles-symbolic"
        Accessible.name: qsTr("Subtitles")
        onClicked: {
            if (several) {
                menu.open()
            } else if (checked) {
                Videos.hideSubtitles()
            } else {
                Videos.showSubtitles()
            }
        }

        LookMenu {
            id: menu

            objectName: "subtitleMenu"
            // The entries' width follows the menu's (they fill it): the menu itself needs one.
            width: Look.unit(180)
            LookMenuItem {
                objectName: "subtitleOff"
                text: qsTr("Off")
                tick: page.subtitleLanguage === "" ? LookMenuItem.Tick.On : LookMenuItem.Tick.Off
                onTriggered: Videos.hideSubtitles()
            }
            Repeater {
                model: sw.several ? page.subtitleTracks : []

                LookMenuItem {
                    required property var modelData

                    objectName: "subtitleLanguage"
                    text: Qt.locale(modelData.language).nativeLanguageName
                    tick: page.subtitleLanguage === modelData.language ? LookMenuItem.Tick.On : LookMenuItem.Tick.Off
                    onTriggered: Videos.chooseSubtitles(modelData.language)
                }
            }
        }
    }

    // Sideways everything stands on the dark ground (the clickdummy's `.qrail`, `.qbands`).
    Rectangle {
        anchors.fill: parent
        visible: page.landscape
        color: Look.stageColor
    }

    GridLayout {
        anchors.fill: parent
        columns: page.onRail ? 2 : 1
        rowSpacing: 0
        columnSpacing: 0

        // Above the picture when there is room: back, where the technique stands, its name.
        RowLayout {
            objectName: "bandTop"
            visible: page.bands
            Layout.fillWidth: true
            Layout.preferredHeight: page.bandHeight
            Layout.leftMargin: Look.unit(24)
            Layout.rightMargin: Look.unit(24)
            spacing: Look.unit(14)

            RailButton {
                objectName: "bandBack"
                symbol: page.leaveSymbol
                text: page.leaveText
                onClicked: page.leave()
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                LookLabel {
                    Layout.fillWidth: true
                    visible: page.placeText !== ""
                    elide: Text.ElideRight
                    text: page.placeText
                    color: Look.stageTextColor
                    opacity: 0.7
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Look.unit(10)

                    LookLabel {
                        objectName: "bandTitle"
                        // Of the page: the row's own width would feed back into its layout (upright, narrow).
                        Layout.maximumWidth: page.current.jp ? page.width * 0.6 : page.width
                        elide: Text.ElideRight
                        text: page.titleText
                        color: Look.stageTextColor
                        font: Look.sheetTitleFont
                    }
                    LookLabel {
                        objectName: "bandJapanese"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: page.current.jp || ""
                        font: Look.japaneseFont(Look.defaultFont)
                        color: Look.stageTextColor
                        opacity: 0.7
                    }
                }
            }
        }

        // The picture: VideoOutput taller than the stage and shifted up, the stage clips the bars.
        Item {
            id: stage

            objectName: "stage"
            visible: page.hasVideo
            readonly property real ratio: page.crop.verhaeltnis || 16 / 9
            Layout.fillWidth: true
            Layout.fillHeight: page.onRail
            Layout.preferredHeight: page.onRail ? -1 : width / ratio
            // Beside the list the controls keep the room they need, on a small tablet half the height,
            // less if the transport bar would leave the view (a taller head, Shinki).
            Layout.maximumHeight: page.compact ? Math.max(page.height - controlsView.neededHeight,
                                                          Math.min(page.height / 2, page.height - controlsView.barHeight))
                                               : Number.POSITIVE_INFINITY

            Rectangle {
                anchors.fill: parent
                color: Look.stageColor
            }

            Item {
                id: picture

                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height * stage.ratio)
                height: width / stage.ratio
                clip: true

                VideoOutput {
                    id: output

                    readonly property real factor: page.crop.h ? picture.height / page.crop.h : 1
                    width: picture.width
                    height: page.crop.hoehe ? page.crop.hoehe * factor : picture.height
                    y: page.crop.y ? -page.crop.y * factor : 0
                    fillMode: VideoOutput.Stretch
                }

                // The subtitle at the foot of the visible picture (this item is it: the bars are
                // clipped). The text on a plate of the stage's ground, so that it reads on any frame.
                // On the rail the timeline and the time lie over the picture's foot; upright the
                // full-screen button lies at its corner: the plate keeps clear of both.
                SubtitleTrack {
                    id: subtitle

                    objectName: "subtitleTrack"
                    source: page.subtitleLanguage !== "" ? page.subtitleTracks.find(t => t.language === page.subtitleLanguage).source : ""
                    position: player.position
                }
                Rectangle {
                    id: subtitlePlate

                    objectName: "subtitlePlate"
                    readonly property real inset: Look.unit(8)
                    readonly property real corner: fullButton.visible && !page.onRail ? fullButton.width + Look.unit(16) : 0
                    visible: subtitle.text !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: page.onRail ? Look.unit(64) : Look.unit(10)
                    width: Math.min(subtitleText.implicitWidth, maxWidth - 2 * inset) + 2 * inset
                    height: subtitleText.height + 2 * inset
                    readonly property real maxWidth: Math.min(parent.width * 0.9, parent.width - 2 * corner)
                    color: Qt.alpha(Look.stageColor, page.subtitlePlateAlpha)

                    LookLabel {
                        id: subtitleText

                        objectName: "subtitleText"
                        x: subtitlePlate.inset
                        y: subtitlePlate.inset
                        width: subtitlePlate.width - 2 * subtitlePlate.inset
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: subtitle.text
                        color: Look.stageTextColor
                    }
                }
            }

            LookLabel {
                objectName: "railTitle"
                // The small player has it on the picture too (the clickdummy's `.qname`).
                visible: page.onRail || (page.paneColumns && page.hasVideo)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.largeSpacing
                text: page.titleText + (!page.compact && page.current.attack ? "  ·  " + page.current.attack : "")
                color: Look.stageTextColor
                style: Text.Outline
                styleColor: Look.stageColor
            }

            // The time at the foot of the picture, above the timeline (the clickdummy's `.qtb`).
            LookLabel {
                objectName: "railTime"
                visible: page.onRail
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: Look.unit(14)
                anchors.bottomMargin: Look.unit(34)
                z: 4
                text: page.timeText2
                color: Look.stageTextColor
                style: Text.Outline
                styleColor: Look.stageColor
            }

            // What the double tap did, on the side that was tapped (the clickdummy).
            Rectangle {
                objectName: "jumpHintArea"

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width / 2
                x: page.jumpRight ? parent.width / 2 : 0
                visible: page.jumpHint !== ""
                color: Look.stageColor
                opacity: 0.45
                z: 4
            }
            LookLabel {
                objectName: "jumpHintText"

                anchors.verticalCenter: parent.verticalCenter
                x: (parent.width / 2 - width) / 2 + (page.jumpRight ? parent.width / 2 : 0)
                visible: page.jumpHint !== ""
                text: page.jumpHint
                color: Look.stageTextColor
                font.bold: true
                z: 5
            }

            ColumnLayout {
                objectName: "levelShown"
                anchors.centerIn: parent
                width: Math.min(parent.width / 2, Kirigami.Units.gridUnit * 12)
                visible: swipe.active && value >= 0
                readonly property real value: swipe.level === Levels.Level.Brightness ? Levels.brightness : Levels.volume

                LookLabel {
                    Layout.alignment: Qt.AlignHCenter
                    text: (swipe.level === Levels.Level.Brightness ? qsTr("Brightness %1 %") : qsTr("Volume %1 %"))
                          .arg(Math.round(parent.value * 100))
                    color: Look.stageTextColor
                    style: Text.Outline
                    styleColor: Look.stageColor
                }
                LookProgressBar {
                    Layout.fillWidth: true
                    value: parent.value
                }
            }

            // The gestures above the picture: they take the events, the picture would swallow
            // them (the swipe on the picture changes the brightness and the volume). Both handlers
            // in one item: they share the events (the tap and the swipe must not fight).
            Item {
                anchors.fill: parent
                z: 10

                TapHandler {
                    onTapped: page.togglePlay()
                    onDoubleTapped: (eventPoint, button) => {
                        const right = eventPoint.position.x >= stage.width / 2
                        page.showJump(right)
                        page.jump(right ? page.jumpMs : -page.jumpMs)
                    }
                }

                // Swipe: brightness (left half) or volume (right half), shown while the finger moves.
                DragHandler {
                    id: swipe

                    property int level: Levels.Level.Brightness
                    property real lastY: 0

                    target: null
                    xAxis.enabled: false
                    onActiveChanged: {
                        if (!active) {
                            return
                        }
                        Levels.refresh()
                        level = centroid.pressPosition.x < stage.width / 2 ? Levels.Level.Brightness : Levels.Level.Volume
                        lastY = 0
                    }
                    onTranslationChanged: {
                        if (!active) {
                            return
                        }
                        const dy = translation.y - lastY
                        lastY = translation.y
                        Levels.change(level, -dy / stage.height)
                    }
                }
            }

            // Into full screen (the clickdummy's `.fs`); on the rail the time holds that corner.
            RailButton {
                id: fullButton

                objectName: "fullButton"

                visible: !page.big
                z: 11
                anchors.right: parent.right
                anchors.margins: Look.unit(8)
                y: page.onRail ? Look.unit(8) : parent.height - height - Look.unit(8)
                symbol: "view-fullscreen"
                text: qsTr("Full screen")
                onClicked: page.bigRequested()

                Rectangle {
                    anchors.fill: parent
                    z: -1
                    color: Look.stageColor
                    opacity: 0.45
                }
            }
        }

        // Sideways: a narrow rail on the right with the buttons (the clickdummy). Phone 62 px (CD
        // .qrail), tablet 84 px (CD .tab .qrail). With room around the picture the same buttons
        // stand in a row below it (CD .qrow2), the time on the left. Upright: the controls below.
        GridLayout {
            id: rail

            objectName: "rail"
            visible: page.landscape
            columns: page.bands ? 5 : 1
            Layout.preferredWidth: page.bands ? -1 : page.tabletSideways ? Look.unit(84) : Look.unit(62)
            Layout.fillWidth: page.bands
            Layout.fillHeight: page.onRail
            Layout.preferredHeight: page.bands ? page.bandHeight - Layout.topMargin : -1
            Layout.topMargin: page.bands ? railTimeline.height + Look.unit(2) : 0
            Layout.leftMargin: page.bands ? Look.unit(24) : 0
            Layout.rightMargin: page.bands ? Look.unit(24) : 0
            rowSpacing: Look.unit(6)
            columnSpacing: page.bands ? Look.unit(18) : 0

            // A third of the row each side, so the transport stands in the middle.
            Item {
                visible: page.bands
                Layout.fillWidth: true
                Layout.preferredWidth: 0
                Layout.preferredHeight: bandTime.implicitHeight

                LookLabel {
                    id: bandTime

                    objectName: "bandTime"
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.timeText2
                    color: Look.stageTextColor
                }
            }
            RailButton {
                objectName: "railBack"
                visible: !page.bands
                Layout.alignment: Qt.AlignHCenter
                symbol: page.leaveSymbol
                text: page.leaveText
                onClicked: page.leave()
            }
            RailButton {
                objectName: "railFrameBack"
                caption: page.bands ? qsTr("1 frame") : qsTr("Frame")
                Layout.alignment: Qt.AlignCenter
                symbol: "go-previous"
                text: qsTr("Frame back")
                onClicked: page.step(-1)
            }
            // The play button: under Shinki the red circle (the clickdummy).
            LookPlayButton {
                objectName: "railPlay"
                readonly property string symbol: player.playing ? "media-playback-pause" : "media-playback-start"
                Layout.alignment: Qt.AlignCenter
                Layout.preferredWidth: page.bands ? Math.min(Look.unit(56), page.bandHeight - railTimeline.height - Look.unit(2)) : page.tabletSideways ? Look.unit(52) : Look.unit(40)
                Layout.preferredHeight: Layout.preferredWidth
                icon.name: symbol
                icon.color: Look.shinki ? "transparent" : Look.stageTextColor   // Shinki: white on red
                text: player.playing ? qsTr("Pause") : qsTr("Play")
                onClicked: page.togglePlay()
            }
            RailButton {
                objectName: "railFrameOn"
                caption: page.bands ? qsTr("1 frame") : qsTr("Frame")
                Layout.alignment: Qt.AlignCenter
                symbol: "go-next"
                text: qsTr("Frame on")
                onClicked: page.step(1)
            }
            GridLayout {
                columns: page.bands ? 4 : 1
                Layout.alignment: Qt.AlignCenter
                Layout.fillWidth: page.bands
                Layout.preferredWidth: page.bands ? 0 : -1
                rowSpacing: rail.rowSpacing
                columnSpacing: Look.unit(8)

                Item {
                    visible: page.bands
                    Layout.fillWidth: true
                }
                // The tempo: a tap goes on to the next (the clickdummy; four fields do not fit a phone).
                LookToggle {
                    objectName: "railTempo"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Look.unit(52)
                    onStage: true
                    checkable: false
                    text: page.tempoText
                    Accessible.name: qsTr("Tempo")
                    onClicked: page.setSpeed(page.tempi[(page.tempi.indexOf(player.playbackRate) + 1) % page.tempi.length])
                }
                // On the rail only the symbol (no word fits it in every language), in the row with
                // the word (the clickdummy).
                LookToggle {
                    objectName: "railLoop"
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: page.bands ? -1 : Look.unit(52)
                    onStage: true
                    icon.name: "media-playlist-repeat"
                    text: page.bands ? qsTr("Loop") : ""
                    Accessible.name: qsTr("Loop")
                    checkable: false
                    checked: page.looping
                    onClicked: page.looping = !page.looping
                }
                SubtitleSwitch {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: page.bands ? -1 : Look.unit(52)
                    onStage: true
                    text: page.bands ? qsTr("Subtitles") : ""
                }
            }
        }

        // The controls scroll when they do not fit.
        Flickable {
            id: controlsView

            objectName: "controlsView"
            visible: !page.landscape
            Layout.fillWidth: !page.landscape
            Layout.fillHeight: true             // portrait: the picture stays at the top
            contentHeight: controls.implicitHeight + Kirigami.Units.largeSpacing * 2
            // What the controls need without the positions of a sequence (they scroll below).
            readonly property real neededHeight: contentHeight
                                                 - (stepList.visible ? stepList.height + stepList.Layout.topMargin + controls.spacing : 0)
            // Down to the transport bar, which stays in view.
            readonly property real barHeight: controls.y + transportRow.y + transport.y + transport.height + Kirigami.Units.largeSpacing
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

            // The note field while it has the focus (NoteRow), kept in view as the height changes.
            property Item focusedField: null
            function showFocusedField() {
                if (!focusedField || !focusedField.activeFocus) {
                    return
                }
                const y = focusedField.mapToItem(controls, 0, 0).y
                contentY = Math.max(0, Math.min(contentHeight - height,
                                                y - height + focusedField.height + Kirigami.Units.largeSpacing))
            }
            onHeightChanged: Qt.callLater(showFocusedField)
            // Tab below the edge (the small player beside the list): the column follows the focus.
            readonly property LookFocusFollow focusFollow: LookFocusFollow { flickable: controlsView }

            ColumnLayout {
                id: controls

                x: Kirigami.Units.largeSpacing
                y: Kirigami.Units.largeSpacing
                width: controlsView.width - Kirigami.Units.largeSpacing * 2
                spacing: Kirigami.Units.largeSpacing

                LookLabel {
                    Layout.fillWidth: true
                    visible: page.compact && !page.paneColumns
                    objectName: "compactTitle"
                    text: (page.current.nr ? page.current.nr + " · " : "") + page.titleWithAddition
                          + (page.current.jp ? "  " + page.current.jp : "")
                    font.bold: true
                    wrapMode: Text.Wrap
                }

                LookLabel {
                    objectName: "placeText"
                    Layout.fillWidth: true
                    visible: !page.landscape && !page.paneColumns && page.placeText !== ""
                    text: page.placeText
                    color: Look.disabledTextColor
                    wrapMode: Text.Wrap
                }

                // Without a video: the technique's name and what to do (the training goes on).
                LookHint {
                    objectName: "noVideoCard"
                    Layout.fillWidth: true
                    visible: !page.hasVideo
                    titleText: (page.current.nr ? page.current.nr + " · " : "") + (page.current.title || "")
                    // No video at all (the higher grades) or one not loaded on this device.
                    text: page.video === "" ? qsTr("There is no video of this technique. Practise it from memory, then rate it.")
                                            : qsTr("Its video is not on this device. Practise it from memory, then rate it.")
                }

                QQC2.Slider {
                    id: timeline

                    Layout.fillWidth: true
                    visible: page.hasVideo && !page.landscape
                    from: page.from
                    to: page.to > page.from ? page.to : page.from + 1
                    value: player.position
                    onMoved: player.position = value
                    Accessible.name: qsTr("Position")

                    LookSliderSkin { control: timeline }
                }

                // Beside the list: the neighbours around the bar, the switches after them (the
                // clickdummy's `.trow`). Elsewhere one below the other.
                GridLayout {
                    id: transportRow

                    Layout.fillWidth: true
                    visible: page.hasVideo
                    columns: page.paneColumns ? 4 : 1
                    rowSpacing: controls.spacing
                    columnSpacing: Kirigami.Units.smallSpacing

                    LookToolButton {
                        objectName: "panePrevious"
                        visible: page.paneColumns
                        icon.width: Look.unit(18)
                        icon.height: Look.unit(18)
                        enabled: page.index > 0
                        icon.name: "media-skip-backward"
                        text: qsTr("Previous")
                        display: QQC2.AbstractButton.IconOnly
                        Accessible.name: qsTr("Previous technique")
                        onClicked: page.go(-1)
                    }
                    LookTransportBar {
                        id: transport

                        objectName: "transportBar"
                        Layout.fillWidth: true
                        visible: page.hasVideo
                        Layout.preferredWidth: 0        // wraps in the column instead of widening it
                        playing: player.playing
                        looping: page.looping
                        speed: player.playbackRate
                        speedSteps: page.tempi
                        metronomeVisible: false
                        countInVisible: false
                        frameStep: true
                        positionText: page.timeText2
                        rewindText: qsTr("Chapter start")
                        playText: qsTr("Play")
                        pauseText: qsTr("Pause")
                        loopText: qsTr("Loop")
                        speedText: qsTr("Tempo")
                        frameBackText: qsTr("Frame back")
                        frameOnText: qsTr("Frame on")
                        positionName: qsTr("Position")
                        accessibleName: qsTr("Playback")
                        onPlayToggled: page.togglePlay()
                        onLoopToggled: page.looping = !page.looping
                        onSpeedChangeRequested: speed => player.playbackRate = speed
                        onRewind: player.position = page.from
                        onFrameStepRequested: direction => page.step(direction)
                    }

                    LookToolButton {
                        objectName: "paneNext"
                        visible: page.paneColumns
                        icon.width: Look.unit(18)
                        icon.height: Look.unit(18)
                        enabled: page.index < page.playlist.length - 1
                        icon.name: "media-skip-forward"
                        text: qsTr("Next")
                        display: QQC2.AbstractButton.IconOnly
                        Accessible.name: qsTr("Next technique")
                        onClicked: page.go(1)
                    }

                    // The player's switches, kept for the next start: sound (always off in slow
                    // motion) and the screen staying on while a video plays.
                    GridLayout {
                        Layout.fillWidth: !page.paneColumns
                        visible: page.hasVideo
                        columns: page.paneColumns ? 1 : 2

                        LookToggle {
                            objectName: "soundSwitch"
                            // On only where it sounds: slow motion is always silent.
                            readonly property bool sounds: Levels.sound && player.playbackRate >= 1
                            enabled: player.playbackRate >= 1     // a tap in slow motion would change it unseen
                            checkable: true
                            checked: sounds
                            icon.name: sounds ? "audio-volume-high" : "audio-volume-muted"
                            text: player.playbackRate < 1 ? qsTr("Silent in slow motion") : qsTr("Sound")
                            onClicked: {
                                checked = Qt.binding(() => sounds)
                                Levels.setSound(Levels.sound ? Levels.Switch.Off : Levels.Switch.On)
                            }
                        }
                        LookToggle {
                            objectName: "awakeSwitch"
                            checkable: true
                            checked: Levels.awake
                            icon.name: "brightness-high"
                            text: qsTr("Screen on")
                            onClicked: Levels.setAwake(Levels.awake ? Levels.Switch.Off : Levels.Switch.On)
                        }
                        SubtitleSwitch {
                            text: qsTr("Subtitles")
                        }
                    }
                }

                // Beside the list two columns (the clickdummy's `.tbelow`): the technique and how
                // it sits, then the notes and the comment. Elsewhere one below the other.
                GridLayout {
                    Layout.fillWidth: true
                    columns: page.paneColumns ? 2 : 1
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: controls.spacing

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: Kirigami.Units.smallSpacing

                        LookLabel {
                            objectName: "paneTitle"
                            Layout.fillWidth: true
                            visible: page.paneColumns
                            text: (page.current.nr ? page.current.nr + " · " : "") + page.titleWithAddition
                                  + (page.current.jp ? "  " + page.current.jp : "")
                            font.bold: true
                            wrapMode: Text.Wrap
                        }
                        LookLabel {
                            objectName: "panePlace"
                            Layout.fillWidth: true
                            visible: page.paneColumns && page.placeText !== ""
                            text: page.placeText
                            color: Look.disabledTextColor
                            wrapMode: Text.Wrap
                        }
                        RatingRow {
                            objectName: "ratingRow"
                            Layout.fillWidth: true
                            entry: page.current.id || ""
                            onRated: {
                                if (page.training) {
                                    page.nextOpen()
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: controls.spacing

                        NoteRow {
                            id: noteRow

                            Layout.fillWidth: true
                            entry: page.current
                            onNotesRequested: page.notesRequested(page.current)
                            // Above the on-screen keyboard: scroll the field into view when it gets the
                            // focus and again when the keyboard opens (the window shrinks: adjustResize).
                            onFieldFocused: field => {
                                controlsView.focusedField = field
                                Qt.callLater(controlsView.showFocusedField)
                            }
                        }

                        // Beside the list on a tablet the sheet does not open: the comment is here.
                        LookButton {
                            objectName: "commentButton"
                            visible: page.compact && !!page.current.comment
                            icon.name: "documentinfo"
                            text: qsTr("Comment")
                            onClicked: page.commentRequested(page.current)
                        }
                    }
                }

                // Short words: both buttons are as wide as they need, and with another font the
                // long ones pushed the whole column past the edge of a 360 px phone.
                RowLayout {
                    objectName: "neighbourRow"
                    Layout.fillWidth: true
                    visible: !page.landscape && !page.paneColumns

                    LookToolButton {
                        enabled: page.index > 0
                        icon.name: "media-skip-backward"
                        text: qsTr("Previous")
                        Accessible.name: qsTr("Previous technique")
                        onClicked: page.go(-1)
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    LookToolButton {
                        enabled: page.index < page.playlist.length - 1
                        icon.name: "media-skip-forward"
                        text: qsTr("Next")
                        Accessible.name: qsTr("Next technique")
                        onClicked: page.go(1)
                    }
                }

                // The training's playlist: numbered, ✓ for the rated ones, a tap jumps there.
                ColumnLayout {
                    objectName: "trainingList"
                    Layout.fillWidth: true
                    visible: page.training && !page.compact
                    spacing: 0

                    LookSectionLabel {
                        Layout.fillWidth: true
                        rule: true
                        text: qsTr("Today's playlist · %1 of %2 practised").arg(page.practisedCount).arg(page.playlist.length)
                    }
                    Repeater {
                        model: page.training && !page.compact ? page.playlist : []

                        LookListRow {
                            id: trainingRow

                            required property var modelData
                            required property int index
                            readonly property bool done: Practice.revision >= 0 && Practice.ratedToday(modelData.id)

                            objectName: "trainingRow"
                            Layout.fillWidth: true
                            focusOnClick: false     // Space stays with the player (play, pause)
                            selected: trainingRow.index === page.index
                            text: (trainingRow.index + 1) + ". " + (modelData.title || "")
                            subtitle: [modelData.attack, modelData.gradeName].filter(x => !!x).join(" · ")
                            trailing: LookLabel {
                                text: trainingRow.done ? "✓" : ""
                                color: Look.positiveTextColor
                                Accessible.name: trainingRow.done ? qsTr("practised") : ""
                            }
                            onClicked: page.index = trainingRow.index
                        }
                    }
                }

                // The positions of a sequence (Kamae exercise): beside the list on a tablet no
                // sheet opens, and in the player they go along with the video. Last, so the
                // rating and the way on stay in view; the picture does not give way to them.
                StepList {
                    id: stepList

                    Layout.fillWidth: true
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    steps: page.current.steps || []
                }
            }
        }
    }

    // The timeline in landscape: at the foot of the picture beside the rail (the clickdummy's
    // `.qb .qtrk`), or under the picture above the row (`.qbot`); z above the stage so a tap on the
    // track lands on the slider and not on a gesture.
    QQC2.Slider {
        id: railTimeline

        objectName: "railTimeline"
        x: page.bands ? Look.unit(24) : Look.unit(10)
        width: page.bands ? parent.width - 2 * x : parent.width - rail.width - 2 * x
        height: page.bands ? Look.unit(20) : implicitHeight
        y: page.bands ? stage.y + stage.height + Look.unit(2) : parent.height - height - Look.unit(10)
        visible: page.landscape
        z: 20
        from: page.from
        to: page.to > page.from ? page.to : page.from + 1
        value: player.position
        onMoved: player.position = value
        Accessible.name: qsTr("Position")

        LookSliderSkin {
            control: railTimeline
            trackColor: Qt.alpha(Look.stageTextColor, 0.3)      // the clickdummy's `.qtrk`
        }
    }
}
