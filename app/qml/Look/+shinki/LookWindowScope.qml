import QtQuick
import Shinki

// Shinki has its own head, no Kirigami bar: the scope of the content only.
Item {
    required property QtObject window

    visible: false

    ShinkiScope { target: window.contentItem }
}
