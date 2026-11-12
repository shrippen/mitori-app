import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// The first-start wizard (and Settings → Appearance → "Show the introduction"): what Mitori
// is, the style, a short tour of the functions. Leaving it in any way (Start, Skip, Back) marks
// it done, so it does not come again.
//
//   1 Welcome   →   2 Style (StyleChoice)   →   3 Tour   →   Start: back to the start menu
Kirigami.ScrollablePage {
    id: page

    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    title: qsTr("Welcome")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    property int step: 0
    readonly property int lastStep: 2

    // The tour: what each part of the app does, in the start menu's order.
    readonly property var tour: [
        { glyph: "技", title: qsTr("Programme"), text: qsTr("Tap a technique: its place in the exam video plays, slow, in a loop. A note on each technique, with photos and voice notes.") },
        { glyph: "稽", title: qsTr("Practice today"), text: qsTr("The techniques due today, as a training with the videos. Rate each one: how well does it sit?") },
        { glyph: "試", title: qsTr("Exam mode"), text: qsTr("Techniques at random, as in the exam, with or without the video.") },
        { glyph: "記", title: qsTr("Statistics"), text: qsTr("Your practice days per year and your grades.") },
        { glyph: "講", title: qsTr("Courses"), text: qsTr("The seminars from the calendar, a notebook for each.") }
    ]

    // A new window (a change of style) comes back here, on this step (Main.keptPageList).
    readonly property string keptPage: "WelcomePage.qml"
    readonly property var keptState: ({ step: page.step })

    // At once: a page popped may live on for the forward arrow.
    function finish() {
        Appearance.welcome()
        page.Kirigami.PageStack.pop()
    }
    Component.onDestruction: Appearance.welcome()

    // Back goes a step, as the button below does. As on ExamEndPage: Qt 6.12 hands `event` over as
    // a copy, so the page takes the stack back right after Kirigami's step.
    onBackRequested: event => {
        if (page.step === 0) {
            return
        }
        event.accepted = true
        page.step -= 1
        const stack = (page.QQC2.ApplicationWindow.window as Kirigami.ApplicationWindow).pageStack
        const index = page.Kirigami.ColumnView.index
        Qt.callLater(() => stack.currentIndex = index)
    }

    actions: [
        Kirigami.Action {
            text: qsTr("Skip")
            visible: page.step < page.lastStep
            onTriggered: page.finish()
        }
    ]

    ColumnLayout {
        spacing: Look.unit(12)

        LookSteps {
            objectName: "welcomeStepper"
            Layout.fillWidth: true
            model: [qsTr("Welcome"), qsTr("Style"), qsTr("Tour")]
            current: page.step
            stepText: qsTr("Step %1 of %2")
            stateNames: ({ done: qsTr("done"), current: qsTr("current"), upcoming: qsTr("to come"), skipped: qsTr("skipped") })
        }

        StackLayout {
            objectName: "welcomeSteps"
            Layout.fillWidth: true
            // The height of the step shown, not of the tallest (the tour): the button stands below
            // the text.
            Layout.preferredHeight: children[currentIndex].implicitHeight
            currentIndex: page.step

            ColumnLayout {
                spacing: Look.unit(8)

                LookHeading {
                    Layout.fillWidth: true
                    level: 1
                    text: "Mitori 見取り"
                }
                LookLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("Mitori means learning by watching. Here are the exam programmes of Aikido Shinki Rengo, Daitoryu and Itto-den Shinki Toho, with the exam videos of the DVDs: watch, practise, rate, note.")
                }
            }

            ColumnLayout {
                spacing: Look.unit(8)

                LookLabel {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: qsTr("How should Mitori look? You can change it later in Settings → Appearance.")
                }
                StyleChoice {
                    Layout.fillWidth: true
                }
            }

            ColumnLayout {
                spacing: Look.unit(8)

                Repeater {
                    model: page.tour

                    // The tile's kanji, then what the part does (wrapped, never elided).
                    RowLayout {
                        id: tourRow

                        required property var modelData

                        objectName: "tourRow"
                        Layout.fillWidth: true
                        spacing: Look.unit(12)

                        LookLabel {
                            Layout.alignment: Qt.AlignTop
                            text: tourRow.modelData.glyph
                            font: Look.japaneseFont(Look.titleFont())
                            color: Look.focusColor
                            Accessible.ignored: true
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            LookLabel {
                                Layout.fillWidth: true
                                text: tourRow.modelData.title
                                font.bold: true
                                wrapMode: Text.Wrap
                            }
                            LookLabel {
                                Layout.fillWidth: true
                                text: tourRow.modelData.text
                                color: Look.mutedTextColor
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true

            LookButton {
                visible: page.step > 0
                icon.name: "go-previous"
                text: qsTr("Back")
                onClicked: page.step -= 1
            }
            Item { Layout.fillWidth: true }
            LookButton {
                objectName: "welcomeNext"
                role: LookButton.Role.Primary
                icon.name: page.step < page.lastStep ? "go-next" : "media-playback-start"
                text: page.step < page.lastStep ? qsTr("Next") : qsTr("Start")
                onClicked: {
                    if (page.step < page.lastStep) {
                        page.step += 1
                        return
                    }
                    page.finish()
                }
            }
        }
    }
}
