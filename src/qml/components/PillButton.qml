import QtQuick
import Snecko

// A soft filled pill/rounded button used for primary actions (Play, Continue).
Item {
    id: root
    property string text: ""
    property color fill: Theme.good
    property color ink: "#ffffff"
    property real radius: Theme.rsm + 4
    signal clicked

    implicitWidth: label.implicitWidth + 52
    implicitHeight: 54

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: ma.pressed ? Qt.darker(root.fill, 1.10)
             : ma.containsMouse ? Qt.lighter(root.fill, 1.06)
             : root.fill
        border.width: 2
        border.color: Qt.darker(root.fill, 1.22)
        Behavior on color { ColorAnimation { duration: 120 } }
        scale: ma.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 90 } }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: root.ink
            font.pixelSize: 19
            font.weight: Font.Bold
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
