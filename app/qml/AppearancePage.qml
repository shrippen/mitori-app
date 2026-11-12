import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// Settings → Appearance: the style and the language, each with a preview and applied by one tap;
// the introduction again, and about Mitori (version, programme data, sources).
Kirigami.ScrollablePage {
    id: page

    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    title: qsTr("Appearance")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as Today.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding
    // A new window (a change of style) comes back here (Main.keptPageList).
    readonly property string keptPage: "AppearancePage.qml"

    ColumnLayout {
        spacing: Look.unit(12)

        LookSectionLabel {
            Layout.fillWidth: true
            rule: true
            text: qsTr("Style")
        }
        StyleChoice {
            Layout.fillWidth: true
        }

        LookSectionLabel {
            Layout.fillWidth: true
            rule: true
            text: qsTr("Language")
        }
        LanguageChoice {
            Layout.fillWidth: true
        }

        LookButton {
            objectName: "introButton"
            icon.name: "documentinfo"
            text: qsTr("Show the introduction")
            onClicked: page.Kirigami.PageStack.push(Qt.resolvedUrl("WelcomePage.qml"))
        }

        LookSectionLabel {
            Layout.fillWidth: true
            rule: true
            text: qsTr("About Mitori")
        }
        LookLabel {
            objectName: "aboutText"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: qsTr("Mitori %1. The exam programmes of Aikido Shinki Rengo, Daitoryu and Itto-den Shinki Toho, with the exam videos of the DVDs.").arg(Appearance.version)
        }
        LookLabel {
            objectName: "dataVersion"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Look.mutedTextColor
            text: qsTr("Programme data %1").arg(Programme.dataVersion)
        }
        Repeater {
            model: Programme.disciplines

            LookLabel {
                required property var modelData

                objectName: "programmeDate"
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Look.mutedTextColor
                // The programme's date as the data has it, in the app's language.
                text: [modelData.titel, modelData.stand].filter(x => !!x).join(" · ")
            }
        }
        LookLabel {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: Look.mutedTextColor
            text: qsTr("Sources: the exam regulations and lists of the dojo, the comments of shinkiryu.de and the Aiki-Budo lexicon.")
        }
        LookLabel {
            objectName: "licences"
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            color: Look.mutedTextColor
            text: Appearance.licences
        }
    }
}
