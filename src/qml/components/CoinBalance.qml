import QtQuick
import HungrySnake

// The player's Coin balance (icon + count), for screen headers / store.
Row {
    id: root
    property int   value: 0
    property int   iconSize: 26
    property color ink: Theme.inkStrong
    spacing: 6

    Item {
        width: root.iconSize; height: root.iconSize
        anchors.verticalCenter: parent.verticalCenter
        Icon { anchors.centerIn: parent; name: "coin"; size: root.iconSize }
    }
    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.ink
        font.family: Theme.ui
        font.pixelSize: Math.round(root.iconSize * 0.82); font.weight: Font.Bold
    }
}
