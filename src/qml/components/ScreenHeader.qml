import QtQuick
import HungrySnake

// A screen title bar: an optional back button on the left + a title. Right-side
// content (e.g. a CoinBalance) is placed by the screen itself, anchored right.
Item {
    id: root
    property string title: ""
    property bool   showBack: true
    signal back()

    implicitHeight: 56
    width: parent ? parent.width : 320

    IconButton {
        id: backBtn
        visible: root.showBack
        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
        icon: "back"; iconSize: 20
        onClicked: root.back()
    }
    Text {
        anchors.left: root.showBack ? backBtn.right : parent.left
        anchors.leftMargin: root.showBack ? 14 : 0
        anchors.verticalCenter: parent.verticalCenter
        text: root.title; color: Theme.text
        font.family: Theme.ui; font.pixelSize: 26; font.weight: Font.Bold
    }
}
