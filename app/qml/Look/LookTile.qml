import QtQuick
import QtQuick.Layouts
import Kante

// A start-menu tile: kanji, name, one line under it; `big` the wide programme tile. Kante:
// KanteOptionTile as a launch tile; tiles of one row as high as the highest. Under Shinki +shinki/LookTile.qml (ShinkiTile).
KanteOptionTile {
    property bool big: false

    Layout.fillHeight: true

    checkable: false
    autoExclusive: false
}
