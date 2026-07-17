import QtQuick
import QtQuick.Effects
import HungrySnake

// A labelled sliding switch row (kit style). Promoted from Main.qml's settings
// dialog. Two-way: bind `checked` and handle `toggled` to flip the source.
Item {
    id: root
    property string label: ""
    property bool   checked: false
    signal toggled

    width: parent ? parent.width : 200
    height: 50

    Text {
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        text: root.label; color: Theme.inkStrong
        font.family: Theme.ui; font.pixelSize: 17; font.weight: Font.DemiBold
    }
    Rectangle {
        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
        width: 52; height: 28; radius: 14
        color: root.checked ? Theme.primary : "#a9825a"
        Behavior on color { ColorAnimation { duration: 160 } }
        Rectangle {
            width: 22; height: 22; radius: 11; color: "white"; y: 3
            x: root.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true; shadowColor: "#000000"; shadowBlur: 0.4
                shadowOpacity: 0.28; shadowVerticalOffset: 2; autoPaddingEnabled: true
            }
        }
        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.toggled()
        }
    }
}
