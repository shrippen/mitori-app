import QtQuick
import QtMultimedia
import Mitori

// The small player beside the map (owner, 12.11.2026): the technique's chapter of its video,
// always in a loop and always mute (no audio output at all); a tap on the picture or the button
// plays and pauses, nothing else. It plays by itself when a technique is shown, and stands while
// `active` is off (another page above the map, the app in the background).
Item {
    id: mini

    property var entry: ({})
    property bool active: true
    // The user's pause: a new technique plays again.
    property bool paused: false

    readonly property string video: entry && entry.video ? entry.video.video : ""
    // As in PlayerView: the file now, its cut points and its crop hang on it.
    readonly property url file: Videos.folder !== undefined && video !== "" ? Videos.source(video) : ""
    readonly property bool hasVideo: file.toString() !== ""
    readonly property var place: hasVideo ? Videos.place(entry.id, entry.video) : null
    readonly property real from: place ? place.von * 1000 : 0
    readonly property real to: place ? place.bis * 1000 : 0
    // Never the end of the file: a player there no longer seeks back.
    readonly property real end: player.duration > 0 ? Math.min(to, player.duration - 250) : to
    readonly property var crop: hasVideo ? Videos.crop(video) : ({})
    readonly property real ratio: crop.verhaeltnis || 16 / 9
    readonly property bool playing: player.playing
    // Not in the background; a window that only lost the focus (desktop) plays on.
    readonly property bool shouldPlay: active && !paused && hasVideo && Qt.application.state !== Qt.ApplicationSuspended
                                       && Qt.application.state !== Qt.ApplicationHidden
    property bool loaded: false
    readonly property real plateAlpha: 0.75

    function toggle() {
        paused = !paused
    }

    // Start at the chapter once the file is loaded; before that a seek is lost.
    function follow() {
        if (!loaded) {
            return
        }
        if (shouldPlay) {
            player.play()
            return
        }
        player.pause()
    }

    implicitHeight: hasVideo ? width / ratio : 0
    visible: hasVideo
    clip: true

    onEntryChanged: paused = false
    onShouldPlayChanged: follow()
    // Another technique of the same file: no new load. Later, when `from` has followed the place.
    onPlaceChanged: Qt.callLater(mini.toChapter)

    function toChapter() {
        if (loaded) {
            player.position = from
        }
    }

    MediaPlayer {
        id: player

        objectName: "miniMedia"
        source: mini.file
        videoOutput: output
        onSourceChanged: mini.loaded = false
        onMediaStatusChanged: {
            if (player.mediaStatus !== MediaPlayer.LoadedMedia || mini.loaded) {
                return
            }
            mini.loaded = true
            player.position = mini.from
            mini.follow()
        }
        // The loop: back to the chapter start at its end.
        onPositionChanged: {
            if (mini.to <= 0 || player.position < mini.end) {
                return
            }
            player.position = mini.from
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Look.stageColor
    }

    // As in PlayerView: the output taller than the picture and shifted up, the item clips the bars.
    VideoOutput {
        id: output

        readonly property real factor: mini.crop.h ? mini.height / mini.crop.h : 1
        width: mini.width
        height: mini.crop.hoehe ? mini.crop.hoehe * factor : mini.height
        y: mini.crop.y ? -mini.crop.y * factor : 0
        fillMode: VideoOutput.Stretch
    }

    TapHandler {
        onTapped: mini.toggle()
    }

    // The one control, on a plate of the stage's ground so that it reads on any frame.
    Rectangle {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Look.unit(8)
        width: playButton.implicitWidth
        height: playButton.implicitHeight
        color: Look.shinki ? "transparent" : Qt.alpha(Look.stageColor, mini.plateAlpha)

        LookPlayButton {
            id: playButton

            objectName: "miniPlay"
            icon.name: mini.playing ? "media-playback-pause" : "media-playback-start"
            icon.color: Look.shinki ? "transparent" : Look.stageTextColor   // Shinki: white on red
            text: mini.playing ? qsTr("Pause") : qsTr("Play")
            onClicked: mini.toggle()
        }
    }
}
