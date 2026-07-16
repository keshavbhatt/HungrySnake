import QtQuick
import Snecko

// A simple rounded progress track (achievements / daily progress).
Rectangle {
    id: root
    property real  value: 0
    property real  to: 1
    property color fill: Theme.primary
    readonly property real frac: to > 0 ? Math.max(0, Math.min(1, value / to)) : 0

    implicitWidth: 160
    implicitHeight: 10
    radius: height / 2
    color: Qt.rgba(0, 0, 0, 0.16)

    Rectangle {
        height: parent.height
        width: parent.width * root.frac
        radius: parent.radius
        color: root.fill
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
    }
}
