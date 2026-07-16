import QtQuick
import QtQuick.Effects
import Snecko

// A transient notification chip (icon + message) that fades in, holds, fades out.
// Call show(message, iconName) to trigger it.
Rectangle {
    id: root
    property string text: ""
    property string icon: "sparkle"
    property int    duration: 1800

    radius: Theme.r
    color: Theme.hudWood
    border.width: 2; border.color: Theme.hudEdge
    implicitWidth: content.implicitWidth + 28
    implicitHeight: 44
    opacity: 0
    visible: opacity > 0

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true; shadowColor: Theme.shadow; shadowBlur: 0.7
        shadowOpacity: 0.4; shadowVerticalOffset: 4; autoPaddingEnabled: true
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8
        Item {
            width: 24; height: 24; anchors.verticalCenter: parent.verticalCenter
            Icon { anchors.centerIn: parent; name: root.icon; color: Theme.cream; size: 22 }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.text; color: Theme.cream
            font.family: Theme.ui; font.pixelSize: 15; font.weight: Font.DemiBold
        }
    }

    SequentialAnimation {
        id: anim
        NumberAnimation { target: root; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        PauseAnimation { duration: root.duration }
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 260; easing.type: Easing.InCubic }
    }

    function show(message, iconName) {
        if (message !== undefined) root.text = message;
        if (iconName !== undefined) root.icon = iconName;
        anim.restart();
    }
}
