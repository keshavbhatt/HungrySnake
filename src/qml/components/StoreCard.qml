import QtQuick
import HungrySnake

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
    signal needCoins()                   // can't-afford item tapped → propose Supporter (Coin bundle)

    implicitWidth: 150
    implicitHeight: 178
    radius: Theme.r
    // The equipped card is lifted out of the tan pack: a light-green fill, a thicker
    // green border, and a corner check badge — so "which one is on" reads at a glance
    // (the old thin border alone was too easy to miss).
    color: equipped ? Theme.equippedTint : Theme.cardTan
    border.width: equipped ? 3 : 2
    border.color: equipped ? Theme.success : Theme.cardEdge

    Rectangle {                              // corner "equipped" check badge
        visible: root.equipped
        z: 2
        width: 28; height: 28; radius: 14
        color: Theme.success
        border.width: 2; border.color: Theme.equippedTint
        anchors { right: parent.right; top: parent.top; rightMargin: -6; topMargin: -6 }
        Icon { anchors.centerIn: parent; name: "check"; color: "#ffffff"; size: 17 }
    }

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
            // Everything but the already-equipped item is tappable now: a can't-afford
            // price still clicks through to a Supporter proposal (the 800-Coin bundle).
            readonly property bool actionable: !root.equipped
            // A can't-afford price is now tappable (it opens the Supporter upsell), so it
            // uses the same green actionable pill as Buy/Equip — no more disabled-grey look.
            // Dark ink on that green is 5.4:1 (white-on-green was only 2.3:1); the equipped
            // pill stays the pale tan "done" state, and locked keeps cream on dark.
            color: root.locked   ? Qt.darker(Theme.locked, 1.5)
                 : root.equipped ? Theme.insetTan
                                 : Theme.primary
            Row {
                anchors.centerIn: parent; spacing: 5
                Item {
                    visible: root.locked || root.equipped || !root.owned
                    width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter
                    Icon {
                        anchors.centerIn: parent
                        name: root.locked ? "lock" : root.equipped ? "check" : "coin"
                        // The equipped check was success-green on the tan pill (~1.5:1, invisible);
                        // dark ink reads clearly and the card's green border still signals "equipped".
                        color: root.locked ? Theme.cream : Theme.inkStrong
                        size: root.locked ? 15 : root.equipped ? 16 : 18
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.locked   ? qsTr("Supporter")
                        : root.equipped ? qsTr("Equipped")
                        : root.owned    ? qsTr("Equip")
                        : root.price
                    color: root.locked ? Theme.cream : Theme.inkStrong
                    font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.Bold
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: parent.actionable
                cursorShape: Qt.PointingHandCursor
                onClicked: root.locked   ? root.unlock()
                         : root.owned     ? root.equip()
                         : root.affordable ? root.buy()
                                          : root.needCoins()
            }
        }
    }
}
