import QtQuick
import Snecko

// A soft round icon button (top bar). `icon` is an SVG icon name (see Icon.qml).
Item {
    id: root
    property string icon: ""
    property real iconSize: 24
    property color color: Theme.cardInk
    property color bg: Theme.card
    property color bgBorder: Theme.cardBorder
    signal clicked

    implicitWidth: 52
    implicitHeight: 52

    Rectangle {
        anchors.fill: parent
        radius: Theme.rsm + 4
        color: ma.pressed ? Qt.darker(root.bg, 1.12)
             : ma.containsMouse ? Qt.lighter(root.bg, 1.05)
             : root.bg
        border.width: 2
        border.color: root.bgBorder
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: ma.pressed ? 0.94 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }

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
