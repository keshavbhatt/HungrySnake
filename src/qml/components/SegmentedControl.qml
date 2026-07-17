import QtQuick
import HungrySnake

// A pill of mutually-exclusive tabs (store categories, etc.). `model` is a list
// of strings, or of objects with a `label`. Two-way via `currentIndex`.
Rectangle {
    id: root
    property var model: []
    property int currentIndex: 0
    signal activated(int index)

    implicitHeight: 40
    implicitWidth: row.implicitWidth + 8
    radius: height / 2
    color: Theme.insetTan
    border.width: 2; border.color: Theme.insetEdge

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.model
            delegate: Rectangle {
                id: seg
                required property int index
                required property var modelData
                readonly property bool sel: root.currentIndex === index
                readonly property string lbl:
                    (modelData && modelData.label !== undefined) ? modelData.label : modelData

                height: root.height - 8
                width: segLabel.implicitWidth + 26
                radius: height / 2
                color: sel ? Theme.primary : "transparent"
                Behavior on color { ColorAnimation { duration: 140 } }

                Text {
                    id: segLabel
                    anchors.centerIn: parent
                    text: seg.lbl
                    color: seg.sel ? "#ffffff" : Theme.inkSoft
                    font.family: Theme.ui; font.pixelSize: 14; font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.currentIndex = seg.index; root.activated(seg.index); }
                }
            }
        }
    }
}
