import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// The conflicts of the sync (clickdummy "Konflikte"): a note or notebook entry changed on two
// devices since the last sync. Per conflict both texts and the choice: this device's, the
// other's, or both (the other's as a new note). The choice syncs to every device.
Kirigami.ScrollablePage {
    id: page

    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    title: qsTr("Conflicts")

    ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Repeater {
            model: Sync.conflicts

            QQC2.Control {
                id: card

                required property var modelData

                objectName: "conflict"
                Layout.fillWidth: true
                padding: Look.cardPadding
                background: LookCard {}

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    LookHeading {
                        Layout.fillWidth: true
                        level: 3
                        text: (card.modelData.kind === "note" ? qsTr("Note") : qsTr("Notebook entry")) + " · " + page.where(card.modelData)
                        wrapMode: Text.Wrap
                    }
                    Repeater {
                        model: [
                            {who: qsTr("This device"), at: card.modelData.mineChanged, text: card.modelData.mine},
                            {who: card.modelData.device || qsTr("Other device"), at: card.modelData.theirsChanged, text: card.modelData.theirs}
                        ]

                        ColumnLayout {
                            required property var modelData

                            Layout.fillWidth: true
                            spacing: 0

                            LookSectionLabel {
                                Layout.fillWidth: true
                                text: modelData.who + ", " + modelData.at.toLocaleString(Qt.locale(), Locale.ShortFormat)
                            }
                            LookLabel {
                                Layout.fillWidth: true
                                text: modelData.text
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        LookButton {
                            text: qsTr("This device")
                            onClicked: Sync.resolve(card.modelData.index, Sync.Mine)
                        }
                        LookButton {
                            text: card.modelData.device || qsTr("Other device")
                            onClicked: Sync.resolve(card.modelData.index, Sync.Theirs)
                        }
                        LookButton {
                            objectName: "keepBoth"
                            text: qsTr("Keep both")
                            onClicked: Sync.resolve(card.modelData.index, Sync.Both)
                        }
                    }
                }
            }
        }

        LookLabel {
            objectName: "noConflicts"
            Layout.fillWidth: true
            visible: Sync.conflicts.length === 0
            text: qsTr("No conflicts. All devices are at the same state.")
            wrapMode: Text.Wrap
        }
        LookLabel {
            Layout.fillWidth: true
            text: qsTr("Ratings need no choice: the newer counts, the other stays in the history.")
            color: Look.disabledTextColor
            wrapMode: Text.Wrap
        }
    }

    // The technique of a note, the notebook of an entry.
    function where(c) {
        if (c.kind === "note") {
            const e = Programme.entry(c.parent)
            return e && e.title ? e.title : c.parent
        }
        const n = Courses.notebook(c.parent)
        return n && n.title ? n.title : ""
    }
}
