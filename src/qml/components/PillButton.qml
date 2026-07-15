import QtQuick
import Snecko

// The UI-kit action button. Primary/danger variants are "raised" — a solid face
// over a darker bottom lip that the press pushes down onto (the border-bottom
// trick). Secondary is flat and darkens/insets on press (set `raised:false`).
Item {
    id: root
    property string text: ""
    property color fill: Theme.primary          // face colour
    property color lip:  Qt.darker(fill, 1.34)  // raised bottom edge
    property color ink:  "#ffffff"
    property real  radius: Theme.r
    property bool  raised: true
    property int   fontSize: 16
    property int   weight: Font.Bold
    readonly property int lift: raised ? 4 : 0
    signal clicked

    implicitWidth: label.implicitWidth + 52
    implicitHeight: 46 + lift

    // Raised lip (the "border-bottom") sits under the face.
    Rectangle {
        visible: root.raised
        anchors.fill: parent
        radius: root.radius
        color: root.lip
    }

    // The button face — drops onto the lip when pressed.
    Rectangle {
        id: face
        width: parent.width
        height: parent.height - root.lift
        radius: root.radius
        y: ma.pressed ? root.lift : 0
        Behavior on y { NumberAnimation { duration: 60; easing.type: Easing.OutQuad } }
        color: ma.pressed       ? Qt.darker(root.fill, 1.07)
             : ma.containsMouse  ? Qt.lighter(root.fill, 1.04)
             : root.fill
        Behavior on color { ColorAnimation { duration: 110 } }

        // Flat buttons get a subtle inset darkening when pressed.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: !root.raised
            color: "black"
            opacity: ma.pressed ? 0.12 : 0
            Behavior on opacity { NumberAnimation { duration: 90 } }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: root.ink
            font.family: Theme.ui
            font.pixelSize: root.fontSize
            font.weight: root.weight
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
