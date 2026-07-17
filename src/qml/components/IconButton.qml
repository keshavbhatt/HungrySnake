import QtQuick
import HungrySnake

// A square icon button (kit style — 48px, 14px radius). Defaults to the tan
// "secondary" surface; pass bg/bgBorder/color to place it on wood (HUD) etc.
// `icon` is an SVG icon name (see Icon.qml).
Item {
    id: root
    property string icon: ""
    property real iconSize: 22
    property color color: Theme.inkStrong
    property color bg: Theme.insetTan
    property color bgBorder: Theme.insetEdge
    property real borderWidth: 2
    signal clicked

    implicitWidth: 48
    implicitHeight: 48

    Rectangle {
        anchors.fill: parent
        radius: Theme.r
        color: ma.pressed ? Qt.darker(root.bg, 1.12)
             : ma.containsMouse ? Qt.lighter(root.bg, 1.05)
             : root.bg
        border.width: root.borderWidth
        border.color: root.bgBorder
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: ma.pressed ? 0.94 : ma.containsMouse ? 1.07 : 1.0   // grow on hover, dip on press
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        Icon {
            anchors.centerIn: parent
            name: root.icon
            size: root.iconSize
            color: root.color
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
