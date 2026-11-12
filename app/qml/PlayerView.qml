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
// the list (`compact`: picture above the controls, no Back).
//
// With a picture (and not `compact`) the design "Kino" (owner's choice B): a dark page. Sideways
// (`landscape`, also full screen) the picture fills the page; over it the back button and the name
// at the top left, "Notes" at the top right, the four ratings as a column at the right edge and a
// plate at the foot with the timeline and all controls. Upright: the name, the picture, the
// timeline; in the middle how the technique was rated and its last notes (PlayerHistory) with a
// field for a note; in the thumb zone below the controls, the ratings and the way on. Without a
// picture and beside the list the controls below the picture stay as they were. Swipe up/down on the left half of
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
    // The subtitles' text: a share of the picture's height, as on television, so that it grows with
    // the picture (a tablet's is three times a phone's); at Normal never below the smallest that
    // reads on a small upright picture. Settings → Videos scales it (Videos.subtitleScale) after
    // that: Small may go below the minimum on purpose.
    readonly property real subtitleShare: 0.035
    readonly property real subtitleMinPixels: Look.unit(14)
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
    // Kino: the dark page with its own controls; upright its middle shows the history.
    readonly property bool kino: !compact && hasVideo
    readonly property bool upright: kino && !landscape
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
        kinoNote.item?.keepDraft()
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
    // One tempo faster (1) or slower (-1), at the ends no further.
    function stepTempo(direction) {
        const at = Math.max(0, Math.min(tempi.length - 1, tempi.indexOf(player.playbackRate) + direction))
        setSpeed(tempi[at])
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
    // The bar's keys also in Kino, where the bar is not in view and forwards nothing.
    Keys.onPressed: event => {
        // A handler accepts every key unless told otherwise: the others (Back, Escape) go on.
        event.accepted = false
        if (!page.kino) {
            return
        }
        event.accepted = true
        switch (event.key) {
        case Qt.Key_K: page.togglePlay(); break
        case Qt.Key_L: page.looping = !page.looping; break
        case Qt.Key_Home: player.position = page.from; break
        case Qt.Key_Comma: page.step(-1); break
        case Qt.Key_Period: page.step(1); break
        case Qt.Key_Plus:
        case Qt.Key_Equal: page.stepTempo(1); break
        case Qt.Key_Minus: page.stepTempo(-1); break
        default: event.accepted = false
        }
    }
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
                    text: modelData.name
                    tick: page.subtitleLanguage === modelData.language ? LookMenuItem.Tick.On : LookMenuItem.Tick.Off
                    onTriggered: Videos.chooseSubtitles(modelData.language)
                }
            }
        }
    }

    // The timeline of Kino with a mark every few seconds (the video has no chapters inside a
    // technique's cut): 5 s for a short one, 10 and 30 s for a longer, never more than a dozen.
    component Scrub: QQC2.Slider {
        id: scrub

        readonly property real span: Math.max(1, page.to - page.from)
        readonly property real tickMs: span <= 60000 ? 5000 : span <= 120000 ? 10000 : 30000

        from: page.from
        to: page.to > page.from ? page.to : page.from + 1
        value: player.position
        onMoved: player.position = value
        Accessible.name: qsTr("Position")

        LookSliderSkin {
            control: scrub
            trackColor: Qt.alpha(Look.stageTextColor, 0.3)
        }
        Repeater {
            model: Math.max(0, Math.ceil(scrub.span / scrub.tickMs) - 1)

            Rectangle {
                required property int index

                x: scrub.leftPadding + scrub.availableWidth * (index + 1) * scrub.tickMs / scrub.span - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: Look.borderWidth
                height: Look.unit(10)
                color: Qt.alpha(Look.stageTextColor, 0.6)
            }
        }
    }

    // The four tempi as a row of fields (25, 50, 75, 100 %), the one in use filled.
    component TempoRow: Row {
        spacing: Look.unit(4)

        Repeater {
            model: page.tempi

            LookToggle {
                required property real modelData

                onStage: true
                checkable: false
                focusPolicy: Qt.TabFocus    // Space stays with the player
                checked: player.playbackRate === modelData
                leftPadding: Look.unit(6)
                rightPadding: Look.unit(6)
                text: String(Math.round(modelData * 100))
                Accessible.name: qsTr("Tempo %1 %").arg(Math.round(modelData * 100))
                onClicked: page.setSpeed(modelData)
            }
        }
    }

    // The player's switches, kept for the next start: sound (always off in slow motion) and the
    // screen staying on while a video plays.
    component SoundToggle: LookToggle {
        readonly property bool sounds: Levels.sound && player.playbackRate >= 1

        // On only where it sounds: slow motion is always silent.
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
    component AwakeToggle: LookToggle {
        checkable: true
        checked: Levels.awake
        icon.name: "brightness-high"
        text: qsTr("Screen on")
        onClicked: Levels.setAwake(Levels.awake ? Levels.Switch.Off : Levels.Switch.On)
    }

    // The play button, in a circle under Shinki.
    component PlayButton: LookPlayButton {
        readonly property string symbol: player.playing ? "media-playback-pause" : "media-playback-start"

        icon.name: symbol
        icon.color: Look.shinki ? "transparent" : Look.stageTextColor   // Shinki: white on red
        text: player.playing ? qsTr("Pause") : qsTr("Play")
        onClicked: page.togglePlay()
    }

    // "Notes · 3": opens the technique's notes (the page decides how).
    component NotesButton: LookToggle {
        readonly property int noted: Practice.notesRevision >= 0 && page.current.id ? Practice.notes(page.current.id).length : 0

        onStage: true
        checkable: false
        focusPolicy: Qt.TabFocus
        icon.name: "view-pim-notes"
        text: qsTr("Notes · %1").arg(noted)
        onClicked: page.notesRequested(page.current)
    }

    // The ratings at the right edge, or in the thumb zone: a tap rates, the training moves on.
    component RatingBar: PlayerRatings {
        entry: page.current.id || ""
        onRated: {
            if (page.training) {
                page.nextOpen()
            }
        }
    }

    // The dark ground of Kino, upright and sideways (the clickdummy's `.qrail`).
    Rectangle {
        anchors.fill: parent
        visible: page.kino
        color: Look.stageColor
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Upright: the name, the kanji and the notes button above the picture.
        RowLayout {
            objectName: "kinoTitleRow"
            visible: page.upright
            Layout.fillWidth: true
            Layout.leftMargin: Look.unit(8)
            Layout.rightMargin: Look.unit(16)
            Layout.topMargin: Look.unit(8)
            Layout.bottomMargin: Look.unit(8)
            spacing: Look.unit(6)

            RailButton {
                objectName: "kinoBack"
                symbol: page.leaveSymbol
                text: page.leaveText
                onClicked: page.leave()
            }
            // The name may take two lines, the kanji stands below it: nothing is cut on 360 px.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                LookLabel {
                    objectName: "kinoTitle"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: page.titleText
                    color: Look.stageTextColor
                    font: Look.sheetTitleFont
                }
                LookLabel {
                    Layout.fillWidth: true
                    visible: text !== ""
                    elide: Text.ElideRight
                    text: page.current.jp || ""
                    font: Look.japaneseFont(Look.defaultFont)
                    color: Look.stageTextColor
                    opacity: 0.7
                }
            }
            NotesButton {
                objectName: "kinoNotes"
            }
        }
        // The picture: VideoOutput taller than the stage and shifted up, the stage clips the bars.
        Item {
            id: stage

            objectName: "stage"
            visible: page.hasVideo
            readonly property real ratio: page.crop.verhaeltnis || 16 / 9
            Layout.fillWidth: true
            Layout.fillHeight: page.landscape
            Layout.preferredHeight: page.landscape ? -1 : width / ratio
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
                // Sideways the plate lies over the picture's foot; upright the full-screen button lies
                // at its corner: the subtitles keep clear of both.
                SubtitleTrack {
                    id: subtitle

                    objectName: "subtitleTrack"
                    source: page.subtitleLanguage !== "" ? page.subtitleTracks.find(t => t.language === page.subtitleLanguage)?.source ?? "" : ""
                    position: player.position
                }
                Rectangle {
                    id: subtitlePlate

                    objectName: "subtitlePlate"
                    readonly property real inset: Look.unit(8)
                    readonly property real corner: fullButton.visible ? fullButton.width + Look.unit(16) : 0
                    visible: subtitle.text !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    // Sideways above the plate, which covers the foot of the picture.
                    anchors.bottomMargin: page.landscape ? Math.max(Look.unit(10), stage.y + picture.y + picture.height - plate.y + Look.unit(10))
                                                         : Look.unit(10)
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
                        font.pixelSize: Math.max(page.subtitleMinPixels, subtitlePlate.parent.height * page.subtitleShare)
                                        * Videos.subtitleScale
                    }
                }
            }

            LookLabel {
                objectName: "railTitle"
                // The small player has it on the picture too (the clickdummy's `.qname`).
                visible: page.paneColumns && page.hasVideo
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Kirigami.Units.largeSpacing
                text: page.titleText + (!page.compact && page.current.attack ? "  ·  " + page.current.attack : "")
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

            // Into full screen (the clickdummy's `.fs`); sideways the plate has the button.
            RailButton {
                id: fullButton

                objectName: "fullButton"

                visible: !page.big && !page.landscape
                z: 11
                anchors.right: parent.right
                anchors.margins: Look.unit(8)
                y: parent.height - height - Look.unit(8)
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

        // Upright, below the picture: the timeline with its marks, where the technique stands, the time.
        ColumnLayout {
            objectName: "kinoScrub"
            visible: page.upright
            Layout.fillWidth: true
            Layout.leftMargin: Look.unit(16)
            Layout.rightMargin: Look.unit(16)
            spacing: 0

            Scrub {
                objectName: "kinoTimeline"
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Look.unit(10)

                LookLabel {
                    objectName: "kinoPlace"
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: page.placeText
                    color: Look.stageTextColor
                    opacity: 0.7
                    font: Look.smallFont
                }
                LookLabel {
                    objectName: "kinoTime"
                    text: page.timeText2
                    color: Look.stageTextColor
                    font: Look.smallFont
                }
            }
        }

        // Upright, the middle: how it was rated, the last notes and a field for today's. It scrolls
        // when the phone is short; it never ends up empty (PlayerHistory says so).
        Flickable {
            id: middle

            objectName: "kinoMiddle"
            visible: page.upright
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Look.unit(64)
            contentHeight: middleColumn.implicitHeight + Look.unit(16)
            // Too short for the bars, the notes and the field (a small phone): the bars, a "Notes · n"
            // line and a button to the note input instead. A field being typed in stays, whatever the
            // height. `needed` is what the full middle took the last time it was shown (the fonts of
            // the style decide), so the switch follows the style and not a fixed number.
            property real needed: 0
            readonly property bool tight: needed > 0 && height < needed && !(focusedField && focusedField.activeFocus)
            function measure() {
                if (tight || !kinoNote.item) {
                    return
                }
                needed = kinoHistoryRow.implicitHeight + middleColumn.spacing + kinoNote.item.implicitHeight + Look.unit(16)
            }
            onContentHeightChanged: Qt.callLater(measure)
            boundsBehavior: Flickable.StopAtBounds
            clip: true

            // The note field while it has the focus, kept in view as the height changes (keyboard).
            property Item focusedField: null
            function showFocusedField() {
                if (!focusedField || !focusedField.activeFocus) {
                    return
                }
                const y = focusedField.mapToItem(middleColumn, 0, 0).y
                contentY = Math.max(0, Math.min(contentHeight - height,
                                                y - height + focusedField.height + Look.unit(16)))
            }
            onHeightChanged: Qt.callLater(showFocusedField)
            readonly property LookFocusFollow focusFollow: LookFocusFollow { flickable: middle }

            ColumnLayout {
                id: middleColumn

                x: Look.unit(16)
                y: middle.tight ? Look.unit(4) : Look.unit(8)
                width: middle.width - Look.unit(32)
                spacing: Look.unit(10)

                RowLayout {
                    id: kinoHistoryRow

                    Layout.fillWidth: true
                    spacing: Look.unit(12)

                    PlayerHistory {
                        id: kinoHistory

                        objectName: "kinoHistory"
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        compact: middle.tight
                        entry: page.current.id || ""
                    }
                    ColumnLayout {
                        visible: middle.tight
                        Layout.alignment: Qt.AlignTop
                        spacing: Look.unit(2)

                        LookLabel {
                            objectName: "kinoNotesLine"
                            text: qsTr("Notes · %1").arg(kinoHistory.noteCount)
                            color: Look.stageTextColor
                        }
                        LookToggle {
                            objectName: "kinoAddNote"
                            implicitHeight: Look.unit(30)
                            onStage: true
                            checkable: false
                            focusPolicy: Qt.TabFocus
                            icon.name: "view-pim-notes"
                            text: qsTr("Add note")
                            onClicked: page.notesRequested(page.current)
                        }
                    }
                }
                // Only upright: beside the list the one in the controls is the note field.
                Loader {
                    id: kinoNote

                    objectName: "kinoNote"
                    Layout.fillWidth: true
                    active: page.upright && !middle.tight
                    visible: active

                    sourceComponent: NoteRow {
                        fieldOnly: true
                        entry: page.current
                        onFieldFocused: field => {
                            middle.focusedField = field
                            Qt.callLater(middle.showFocusedField)
                        }
                    }
                }

                // The training's playlist and the positions of a sequence below the note field, as
                // in the controls (the picture does not give way to them).
                PlayerTrainingList {
                    Layout.fillWidth: true
                    visible: page.training && page.upright
                    playlist: page.playlist
                    current: page.index
                    practised: page.practisedCount
                    onChosen: index => page.index = index
                }
                Loader {
                    Layout.fillWidth: true
                    active: page.upright

                    sourceComponent: StepList {
                        steps: page.current.steps || []
                    }
                }
            }
        }

        // Upright, the thumb zone: tempo, loop and subtitles; the transport; the ratings; the way on.
        ColumnLayout {
            objectName: "thumbZone"
            visible: page.upright
            Layout.fillWidth: true
            Layout.leftMargin: Look.unit(16)
            Layout.rightMargin: Look.unit(16)
            Layout.topMargin: Look.unit(6)
            Layout.bottomMargin: Look.unit(12)
            // A short phone (360 × 640) gives up some air so that the zone stays in view.
            readonly property bool short: page.height < Look.unit(600)
            spacing: short ? Look.unit(4) : Look.unit(8)

            RowLayout {
                Layout.fillWidth: true

                TempoRow {}
                Item {
                    Layout.fillWidth: true
                }
                LookToggle {
                    objectName: "thumbLoop"
                    onStage: true
                    focusPolicy: Qt.TabFocus
                    icon.name: "media-playlist-repeat"
                    Accessible.name: qsTr("Loop")
                    checkable: false
                    checked: page.looping
                    onClicked: page.looping = !page.looping
                }
                SubtitleSwitch {
                    onStage: true
                    focusPolicy: Qt.TabFocus
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Look.unit(8)

                SoundToggle {
                    objectName: "thumbSound"
                    onStage: true
                    focusPolicy: Qt.TabFocus
                    text: ""
                    Accessible.name: player.playbackRate < 1 ? qsTr("Silent in slow motion") : qsTr("Sound")
                }
                Item {
                    Layout.fillWidth: true
                }
                RailButton {
                    objectName: "thumbFrameBack"
                    symbol: "go-previous"
                    text: qsTr("Frame back")
                    onClicked: page.step(-1)
                }
                PlayButton {
                    objectName: "thumbPlay"
                    Layout.preferredWidth: Look.unit(56)
                    Layout.preferredHeight: Look.unit(56)
                }
                RailButton {
                    objectName: "thumbFrameOn"
                    symbol: "go-next"
                    text: qsTr("Frame on")
                    onClicked: page.step(1)
                }
                Item {
                    Layout.fillWidth: true
                }
                AwakeToggle {
                    objectName: "thumbAwake"
                    onStage: true
                    focusPolicy: Qt.TabFocus
                    text: ""
                    Accessible.name: qsTr("Screen on")
                }
            }
            RatingBar {
                objectName: "kinoRating"
                Layout.fillWidth: true
                buttonHeight: parent.short ? Look.unit(44) : Look.unit(52)
            }
            // Short words: as wide as they need.
            RowLayout {
                objectName: "kinoNeighbours"
                Layout.fillWidth: true

                LookToggle {
                    onStage: true
                    checkable: false
                    focusPolicy: Qt.TabFocus
                    enabled: page.index > 0
                    icon.name: "media-skip-backward"
                    text: qsTr("Previous")
                    Accessible.name: qsTr("Previous technique")
                    onClicked: page.go(-1)
                }
                Item {
                    Layout.fillWidth: true
                }
                LookToggle {
                    onStage: true
                    checkable: false
                    focusPolicy: Qt.TabFocus
                    enabled: page.index < page.playlist.length - 1
                    icon.name: "media-skip-forward"
                    text: qsTr("Next")
                    Accessible.name: qsTr("Next technique")
                    onClicked: page.go(1)
                }
            }
        }
        // The controls scroll when they do not fit.
        Flickable {
            id: controlsView

            objectName: "controlsView"
            visible: !page.kino
            Layout.fillWidth: true
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
                        // Upright all three in a row where they fit, else two and one.
                        readonly property bool oneRow: {
                            let sum = (visibleChildren.length - 1) * columnSpacing
                            for (const child of visibleChildren) {
                                sum += child.implicitWidth
                            }
                            return sum <= controls.width
                        }
                        columns: page.paneColumns ? 1 : oneRow ? 3 : 2

                        SoundToggle {
                            objectName: "soundSwitch"
                        }
                        AwakeToggle {
                            objectName: "awakeSwitch"
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
                PlayerTrainingList {
                    Layout.fillWidth: true
                    visible: page.training && !page.compact
                    playlist: page.playlist
                    current: page.index
                    practised: page.practisedCount
                    onChosen: index => page.index = index
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

    // Sideways, over the picture (design Kino): the name at the top left with a veil behind it, the
    // notes at the top right, the ratings at the right edge and the plate at the foot. All of it
    // stays in view; z above the stage so that a tap lands here and not on the picture's gestures.
    Rectangle {
        objectName: "kinoVeil"
        visible: page.landscape
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: kinoHeader.height + 2 * Look.unit(12)
        z: 19
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Look.stageColor, 0.75) }
            GradientStop { position: 1; color: Qt.alpha(Look.stageColor, 0) }
        }
    }
    RowLayout {
        id: kinoHeader

        objectName: "kinoHeader"
        visible: page.landscape
        anchors.left: parent.left
        anchors.right: kinoNotes.left
        anchors.top: parent.top
        anchors.margins: Look.unit(12)
        spacing: Look.unit(12)
        z: 20

        RailButton {
            objectName: "railBack"
            symbol: page.leaveSymbol
            text: page.leaveText
            onClicked: page.leave()
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: Look.unit(10)

                LookLabel {
                    objectName: "kinoName"
                    // Of the page: the row's own width would feed back into its layout.
                    Layout.maximumWidth: page.current.jp ? page.width * 0.5 : page.width
                    elide: Text.ElideRight
                    text: page.titleText
                    color: Look.stageTextColor
                    font: Look.sheetTitleFont
                }
                LookLabel {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    text: page.current.jp || ""
                    font: Look.japaneseFont(Look.defaultFont)
                    color: Look.stageTextColor
                    opacity: 0.7
                }
            }
            LookLabel {
                Layout.fillWidth: true
                visible: page.placeText !== ""
                elide: Text.ElideRight
                text: page.placeText
                color: Look.stageTextColor
                opacity: 0.7
            }
        }
    }
    NotesButton {
        id: kinoNotes

        objectName: "kinoNotesButton"
        visible: page.landscape
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Look.unit(12)
        z: 20
    }

    // The ratings between the notes button and the plate: the buttons shrink on a short phone.
    Item {
        id: ratingArea

        objectName: "ratingArea"
        visible: page.landscape
        anchors.right: parent.right
        anchors.top: kinoNotes.bottom
        anchors.bottom: plate.top
        anchors.margins: Look.unit(12)
        width: ratingColumn.width
        z: 20

        RatingBar {
            id: ratingColumn

            objectName: "ratingColumn"
            vertical: true
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            buttonHeight: Math.max(Look.unit(36), Math.min(Look.unit(64), (ratingArea.height - 3 * rowSpacing) / 4))
        }
    }

    // The plate: the timeline with its marks, then time | tempo | transport | switches | next.
    Rectangle {
        id: plate

        objectName: "plate"
        visible: page.landscape
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: plateColumn.implicitHeight + 2 * Look.unit(10)
        color: Qt.alpha(Look.stageColor, 0.8)
        z: 20

        ColumnLayout {
            id: plateColumn

            anchors.fill: parent
            anchors.margins: Look.unit(10)
            anchors.leftMargin: Look.unit(14)
            anchors.rightMargin: Look.unit(14)
            spacing: Look.unit(4)

            Scrub {
                objectName: "railTimeline"
                Layout.fillWidth: true
                Layout.preferredHeight: Look.unit(20)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Look.unit(4)

                LookLabel {
                    objectName: "plateTime"
                    Layout.minimumWidth: Look.unit(96)
                    text: page.timeText2
                    color: Look.stageTextColor
                }
                Item {
                    Layout.fillWidth: true
                }
                TempoRow {
                    objectName: "plateTempo"
                }
                Item {
                    Layout.fillWidth: true
                }
                RailButton {
                    objectName: "railFrameBack"
                    symbol: "go-previous"
                    text: qsTr("Frame back")
                    onClicked: page.step(-1)
                }
                PlayButton {
                    objectName: "railPlay"
                    Layout.preferredWidth: Look.unit(48)
                    Layout.preferredHeight: Look.unit(48)
                }
                RailButton {
                    objectName: "railFrameOn"
                    symbol: "go-next"
                    text: qsTr("Frame on")
                    onClicked: page.step(1)
                }
                RailButton {
                    objectName: "plateBack2s"
                    symbol: "media-seek-backward"
                    text: qsTr("2 s back")
                    onClicked: page.jump(-page.jumpMs)
                }
                RailButton {
                    objectName: "plateOn2s"
                    symbol: "media-seek-forward"
                    text: qsTr("2 s on")
                    onClicked: page.jump(page.jumpMs)
                }
                Item {
                    Layout.fillWidth: true
                }
                LookToggle {
                    objectName: "railLoop"
                    onStage: true
                    focusPolicy: Qt.TabFocus
                    icon.name: "media-playlist-repeat"
                    Accessible.name: qsTr("Loop")
                    checkable: false
                    checked: page.looping
                    onClicked: page.looping = !page.looping
                }
                SubtitleSwitch {
                    onStage: true
                    focusPolicy: Qt.TabFocus
                }
                SoundToggle {
                    objectName: "plateSound"
                    onStage: true
                    focusPolicy: Qt.TabFocus
                    text: ""
                    Accessible.name: player.playbackRate < 1 ? qsTr("Silent in slow motion") : qsTr("Sound")
                }
                AwakeToggle {
                    objectName: "plateAwake"
                    onStage: true
                    focusPolicy: Qt.TabFocus
                    text: ""
                    Accessible.name: qsTr("Screen on")
                }
                // Not in full screen, which has its own way out (the back button).
                RailButton {
                    objectName: "plateFull"
                    visible: !page.big
                    symbol: "view-fullscreen"
                    text: qsTr("Full screen")
                    onClicked: page.bigRequested()
                }
                Item {
                    Layout.fillWidth: true
                }
                RailButton {
                    objectName: "plateNext"
                    enabled: page.index < page.playlist.length - 1
                    symbol: "media-skip-forward"
                    text: qsTr("Next technique")
                    onClicked: page.go(1)
                }
            }
        }
    }
}
