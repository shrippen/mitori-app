pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// The glossary's detail pane (wide window): a word as the glossary gives it ({word, jp, reading,
// meaning, speech}): the kanji large, the word, its reading, the translation, the pronunciation
// button, and the techniques the search finds for the word.
ColumnLayout {
    id: detail

    property var word: null
    // Techniques that name the word as a whole word, one more than shown to know there are more.
    readonly property int maxHits: 50
    readonly property var found: word ? Programme.techniquesNamed(word.word, maxHits + 1) : []
    readonly property var hits: found.slice(0, maxHits)
    readonly property bool canSpeak: Glossary.speech === Glossary.Ready

    signal techniqueRequested(var technique)

    spacing: Kirigami.Units.largeSpacing

    LookLabel {
        objectName: "detailHint"
        Layout.fillWidth: true
        visible: !detail.word
        text: qsTr("Tap a word to see it here.")
        color: Look.mutedTextColor
        wrapMode: Text.Wrap
    }

    LookLabel {
        objectName: "detailKanji"
        Layout.fillWidth: true
        visible: !!detail.word && detail.word.jp !== ""
        text: detail.word ? detail.word.jp : ""
        font: Look.japaneseFont(Look.titleFont(Look.defaultFont.pointSize * 3))
        wrapMode: Text.WrapAnywhere
    }

    LookLabel {
        objectName: "detailWord"
        Layout.fillWidth: true
        visible: !!detail.word
        text: detail.word ? detail.word.word : ""
        font: Look.titleFont(Look.defaultFont.pointSize * 1.6)
        wrapMode: Text.Wrap
    }

    LookLabel {
        objectName: "detailReading"
        Layout.fillWidth: true
        visible: !!detail.word && detail.word.reading !== "" && detail.word.reading !== detail.word.jp
        text: detail.word ? detail.word.reading : ""
        font: Look.japaneseFont(Look.defaultFont)
        color: Look.mutedTextColor
    }

    LookLabel {
        objectName: "detailMeaning"
        Layout.fillWidth: true
        visible: !!detail.word
        text: detail.word ? (detail.word.meaning || qsTr("No translation in the lexicon")) : ""
        wrapMode: Text.Wrap
    }

    LookToolButton {
        objectName: "detailSay"
        visible: detail.canSpeak && !!detail.word
        focusPolicy: Qt.NoFocus
        icon.name: "media-playback-start"
        text: qsTr("Pronunciation")
        display: QQC2.AbstractButton.TextBesideIcon
        onClicked: Glossary.say(detail.word.speech)
    }

    LookSectionLabel {
        objectName: "detailHitsHead"
        Layout.fillWidth: true
        Layout.topMargin: Kirigami.Units.largeSpacing
        visible: detail.hits.length > 0
        text: qsTr("In techniques")
    }

    Repeater {
        model: detail.hits

        LookListRow {
            required property var modelData

            objectName: "detailHit"
            leadingText: modelData.nr ? String(modelData.nr) : ""
            Layout.fillWidth: true
            text: modelData.title + (modelData.extra && !modelData.nr ? " (" + modelData.extra + ")" : "")
            // As the search's row: the attack tells apart the same technique of one grade.
            subtitle: [modelData.disciplineName + " " + modelData.gradeName, modelData.groupName,
                       (modelData.attack || "") + (modelData.attackExtra ? " (" + modelData.attackExtra + ")" : ""),
                       modelData.nr ? modelData.extra : ""]
                      .filter(x => x).join(" · ")
            onClicked: detail.techniqueRequested(modelData)
        }
    }

    LookLabel {
        objectName: "detailHitsMore"
        Layout.fillWidth: true
        visible: detail.found.length > detail.maxHits
        text: qsTr("Only the first %1 techniques.").arg(detail.maxHits)
        color: Look.mutedTextColor
        wrapMode: Text.Wrap
    }
}
