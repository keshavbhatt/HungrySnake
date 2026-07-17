import QtQuick
import QtQuick.Effects
import HungrySnake

// A HUD stat chip — a themed icon glyph + a value, on a shadowed wood chip.
// Promoted from Main.qml so the HUD, Game Over card and future screens share it.
Rectangle {
    id: root
    property string glyph: ""          // an Icon name (see Icon.qml)
    property int    value: 0
    property color  bg:   Theme.hudWood
    property color  edge: Theme.hudEdge
    property color  ink:  Theme.cream
    property int    iconSize: 32

    width: 132; height: 64
    radius: Theme.r
    color: bg
    border.width: 3
    border.color: edge
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true; shadowColor: Theme.shadow; shadowBlur: 0.6
        shadowOpacity: 0.3; shadowVerticalOffset: 4; autoPaddingEnabled: true
    }

    Row {
        anchors.centerIn: parent
        spacing: 12
        Item {
            width: root.iconSize + 2; height: root.iconSize + 2
            anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.centerIn: parent; name: root.glyph; size: root.iconSize }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            color: root.ink
            font.family: Theme.display; font.pixelSize: 30; font.weight: Font.Bold
        }
    }
}
