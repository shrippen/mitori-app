import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Controls.impl
import QtQuick.Layouts

// An entry of a menu: its symbol and word in the style's ink, the style's ground under the pointer.
// `tick` On or Off: a column before the word with a ✓ while On (one of several choices). Not
// `checkable`: a tap would toggle `checked` itself after `triggered`, breaking a binding to the
// choice (the active entry tapped again lost its tick). The style's own indicator is not drawn.
QQC2.MenuItem {
    id: entry

    enum Tick {
        None,
        Off,
        On
    }
    property int tick: LookMenuItem.Tick.None

    Accessible.checkable: tick !== LookMenuItem.Tick.None
    Accessible.checked: tick === LookMenuItem.Tick.On

    contentItem: RowLayout {
        spacing: Look.unit(8)

        LookLabel {
            Layout.preferredWidth: Look.unit(16)
            visible: entry.tick !== LookMenuItem.Tick.None
            horizontalAlignment: Text.AlignHCenter
            text: entry.tick === LookMenuItem.Tick.On ? "\u2713" : ""
            color: Look.accentColor
        }
        IconImage {
            Layout.preferredWidth: Look.unit(16)
            Layout.preferredHeight: Look.unit(16)
            visible: entry.icon.name !== ""
            name: entry.icon.name
            color: entry.enabled ? Look.textColor : Look.disabledTextColor
        }
        LookLabel {
            Layout.fillWidth: true
            text: entry.text
            color: entry.enabled ? Look.textColor : Look.disabledTextColor
        }
    }
    indicator: null
    background: Rectangle {
        color: entry.highlighted ? Look.chipColor : "transparent"
    }
}
