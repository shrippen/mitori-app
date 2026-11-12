pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import Mitori

// Links a notebook entry to techniques (⌗): those linked, those its text names, and a search. A
// tap links or unlinks; nothing links by itself. The technique's notes then show the entry.
Kirigami.ScrollablePage {
    id: page

    // ScrollablePage keeps the platform's colours (Theme.inherit: false): give it the style's, and
    // the style's page ground (Look: Kante or Shinki).
    property Item lookScope: LookScope { target: page }
    background: Rectangle { color: Look.backgroundColor }

    required property string course
    required property string entryUid

    readonly property var entry: Courses.revision >= 0 ? (Courses.entries(course).find(e => e.uid === entryUid) || ({})) : ({})
    readonly property var linked: entry.techniques || []
    readonly property var named: Programme.suggest(entry.text || "", namedLimit, linked)
    readonly property int namedLimit: 8
    // The query searched (follows the field after a short pause while typing).
    property string query: ""
    // At most `limit` techniques are listed; one more found says there are more.
    readonly property int limit: 30
    readonly property var found: query.trim() === "" ? [] : Programme.search(query, limit + 1)
    readonly property var foundShown: found.filter(t => !isLinked(t.id)).slice(0, limit)

    function isLinked(id) {
        return linked.indexOf(id) >= 0
    }

    objectName: "techniquePicker"
    title: qsTr("Link technique")

    // On a wide window a page of reading width in the middle (Tablet.pageWidth), as its search bar.
    leftPadding: Tablet.sidePadding(width, padding)
    rightPadding: leftPadding

    header: LookToolBar {
        LookTextField {
            id: field

            objectName: "pickerSearch"
            anchors.fill: parent
            placeholderText: qsTr("Search techniques")
            Accessible.name: qsTr("Search techniques")
            onTextChanged: pause.restart()
            onAccepted: page.query = text
        }
    }

    Timer {
        id: pause

        interval: Kirigami.Units.shortDuration
        onTriggered: page.query = field.text
    }

    // A technique as in the search: a tap links it, or unlinks one that is linked.
    component TechniqueRow: LookListRow {
        required property var modelData
        readonly property bool isLinked: page.isLinked(modelData.id)

        objectName: isLinked ? "linkedTechnique" : "techniqueChoice"
        Layout.fillWidth: true
        selected: isLinked
        leadingText: modelData.nr ? String(modelData.nr) : ""
        text: modelData.title + (modelData.extra ? " (" + modelData.extra + ")" : "")
        subtitle: [(modelData.attack || "") + (modelData.attackExtra ? " (" + modelData.attackExtra + ")" : ""),
                   modelData.disciplineName + " " + modelData.gradeName].filter(x => x).join(" · ")
        Accessible.description: subtitle + ". " + (isLinked ? qsTr("Linked; removes the link") : qsTr("Links the technique"))
        onClicked: isLinked ? Courses.unlinkTechnique(page.entryUid, modelData.id)
                            : Courses.linkTechnique(page.entryUid, modelData.id)
    }

    ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        LookLabel {
            objectName: "pickerEntry"
            Layout.fillWidth: true
            visible: text !== ""
            text: page.entry.text || ""
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        LookLabel {
            Layout.fillWidth: true
            visible: Courses.errorString !== ""
            text: Courses.errorString
            color: Look.negativeTextColor
            wrapMode: Text.Wrap
        }

        LookSectionLabel {
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: page.linked.length > 0
            text: qsTr("Linked")
        }
        Repeater {
            // A technique no longer in the programme (a newer catalogue) can still be unlinked.
            model: page.linked.map(id => {
                const known = Programme.entry(id)
                return known.id ? known : { id: id, title: qsTr("Technique no longer in the programme"), disciplineName: "", gradeName: "" }
            })

            TechniqueRow {}
        }

        LookSectionLabel {
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: page.named.length > 0
            text: qsTr("Named in this entry")
        }
        Repeater {
            model: page.named

            TechniqueRow {}
        }

        LookLabel {
            objectName: "pickerNoneNamed"
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: page.named.length === 0 && page.query.trim() === ""
            text: qsTr("No other technique is named in this entry. Search above.")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }

        LookSectionLabel {
            Layout.topMargin: Kirigami.Units.largeSpacing
            visible: page.query.trim() !== ""
            text: qsTr("Found")
        }
        Repeater {
            model: page.foundShown

            TechniqueRow {}
        }

        LookLabel {
            objectName: "pickerNotFound"
            Layout.fillWidth: true
            visible: page.query.trim() !== "" && page.found.length === 0
            text: qsTr("No technique found.")
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }
        LookLabel {
            Layout.fillWidth: true
            visible: page.found.length > page.limit
            text: qsTr("More than %1 techniques found. Add a word to narrow the search.").arg(page.limit)
            color: Look.mutedTextColor
            wrapMode: Text.Wrap
        }
    }
}
