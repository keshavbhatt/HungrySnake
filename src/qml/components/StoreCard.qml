import QtQuick
import Snecko

// A cosmetic tile for the Store: a preview swatch, a name, and a state-driven
// action pill (Coin price to buy → Equip → Equipped). Pass the preview as a
// Component so each slot (snake skin, board theme, …) can draw its own swatch.
Rectangle {
    id: root
    property string name: ""
    property int    price: 0
    property bool   owned: false
    property bool   equipped: false
    property bool   affordable: true
    property bool   locked: false        // a Supporter-only item, not yet unlocked
    property Component preview: null
    signal buy()
    signal equip()
    signal unlock()                      // locked item tapped → go redeem Supporter

    implicitWidth: 150
    implicitHeight: 178
    radius: Theme.r
    color: Theme.cardTan
    border.width: 2
    border.color: equipped ? Theme.success : Theme.cardEdge

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Rectangle {                              // preview swatch
            width: parent.width; height: 92
            radius: Theme.rsm
            color: Theme.insetTan
            clip: true
            Loader { anchors.fill: parent; sourceComponent: root.preview }
        }
        Text {
            width: parent.width
            text: root.name
            color: Theme.inkStrong; font.family: Theme.ui
            font.pixelSize: 15; font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
        }
        Rectangle {                              // state-driven action pill
            width: parent.width; height: 34; radius: Theme.r
            readonly property bool actionable: root.locked || (!root.equipped && (root.owned || root.affordable))
            color: root.locked     ? Theme.locked
                 : root.equipped   ? Theme.insetTan
                 : root.owned      ? Theme.primary
                 : root.affordable ? Theme.primaryDeep : Theme.disabled
            Row {
                anchors.centerIn: parent; spacing: 5
                Item {
                    visible: root.locked || !root.owned
                    width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                    Icon { anchors.centerIn: parent; name: root.locked ? "lock" : "coin"
                           color: Theme.cream; size: root.locked ? 15 : 18 }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.locked   ? qsTr("Supporter")
                        : root.equipped ? qsTr("Equipped")
                        : root.owned    ? qsTr("Equip")
                        : root.price
                    color: root.equipped ? Theme.success : "#ffffff"
                    font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.Bold
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: parent.actionable
                cursorShape: Qt.PointingHandCursor
                onClicked: root.locked ? root.unlock() : (root.owned ? root.equip() : root.buy())
            }
        }
    }
}
