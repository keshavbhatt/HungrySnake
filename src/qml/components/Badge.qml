import QtQuick
import Snecko

// A small pill badge — a count, "NEW", "LOCKED", etc.
Rectangle {
    id: root
    property alias text: label.text
    property color bg: Theme.danger
    property color ink: "#ffffff"

    implicitWidth: Math.max(height, label.implicitWidth + 12)
    implicitHeight: 20
    radius: height / 2
    color: bg

    Text {
        id: label
        anchors.centerIn: parent
        color: root.ink
        font.family: Theme.ui; font.pixelSize: 12; font.weight: Font.Bold
    }
}
