import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Controls.impl
import QtQuick.Layouts

// An entry of a menu: its symbol and word in the style's ink, the style's ground under the pointer.
// A checkable entry has a ✓ before the word while it is checked (the style's own indicator is not drawn).
QQC2.MenuItem {
    id: entry

    contentItem: RowLayout {
        spacing: Look.unit(8)

        LookLabel {
            Layout.preferredWidth: Look.unit(16)
            visible: entry.checkable
            horizontalAlignment: Text.AlignHCenter
            text: entry.checked ? "\u2713" : ""
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
