import QtQuick
import Quickshell
import "../WindowRegistry.js" as Registry

PanelWindow {
    id: musicWin
    visible: false
    color: "transparent"

    property real uiScale: 1.0
    property real scaleFactor: Registry.getScale(screen.width, screen.height, uiScale)

    width: Registry.s(700, scaleFactor)
    height: Registry.s(650, scaleFactor)

    Loader {
        id: musicLoader
        anchors.fill: parent
        source: "MusicPopup.qml"
    }

    Shortcut {
        sequence: "Escape"
        onActivated: musicWin.visible = false
    }
}