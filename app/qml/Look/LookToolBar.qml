import QtQuick
import QtQuick.Controls as QQC2

// A bar of actions at the foot of a page: the style's ground, the actions as the page puts them
// (the buttons themselves are the style's).
QQC2.ToolBar {
    // All four: Material sets each side itself (the safe area), so `padding` would not reach them.
    // On a wide window the content keeps the page's reading width (Tablet.pageWidth), in the middle.
    leftPadding: Tablet.sidePadding(width, Look.unit(8) + SafeArea.margins.left)
    rightPadding: Tablet.sidePadding(width, Look.unit(8) + SafeArea.margins.right)
    topPadding: Look.unit(8) + SafeArea.margins.top
    bottomPadding: Look.unit(8) + SafeArea.margins.bottom

    background: Rectangle {
        color: Look.backgroundColor
    }
}
