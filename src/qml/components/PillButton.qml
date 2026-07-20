import QtQuick
import HungrySnake

// The UI-kit action button. Primary/danger variants are "raised" — a solid face
// over a darker bottom lip that the press pushes down onto (the border-bottom
// trick). Secondary is flat and darkens/insets on press (set `raised:false`).
Item {
    id: root
    property string text: ""
    property color fill: Theme.primary          // face colour
    property color lip:  Qt.darker(fill, 1.34)  // raised bottom edge
    property color ink:  Theme.inkStrong   // dark ink on the green face (5.4:1; white was 2.3:1)
    property real  radius: Theme.r
    property bool  raised: true
    property int   fontSize: 16
    property int   weight: Font.Bold
    property string icon: ""                     // optional leading icon (e.g. "play")
    readonly property int lift: raised ? 4 : 0
    signal clicked

    implicitWidth: content.implicitWidth + 52
    implicitHeight: 46 + lift

    // Whole-button hover lift — a small rise on hover for tactile feedback.
    property real hoverY: (ma.containsMouse && !ma.pressed && root.raised) ? -3 : 0
    Behavior on hoverY { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }
    transform: Translate { y: root.hoverY }

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

        // Glossy top sheen for a rounder, more 3-D face.
        Rectangle {
            visible: root.raised
            width: parent.width; height: parent.height * 0.5
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.22) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }

        Row {
            id: content
            anchors.centerIn: parent
            spacing: 8
            Icon {
                visible: root.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                name: root.icon; color: root.ink
                size: Math.round(root.fontSize * 0.92)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.text; color: root.ink
                font.family: Theme.ui; font.pixelSize: root.fontSize; font.weight: root.weight
            }
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
