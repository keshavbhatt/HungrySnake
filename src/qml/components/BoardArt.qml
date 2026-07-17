import QtQuick
import HungrySnake

// A miniature of the play-field for Store previews: a checkerboard of top-lit,
// rounded "pillow" tiles over dark grout, inside the wooden frame — the same recipe
// Board.qml uses (bright top edge → base → shadowed bottom), just at preview scale.
Item {
    id: root
    property color tileA:   Theme.tileA
    property color tileB:   Theme.tileB
    property color tileGap: Theme.tileGap
    property color frame:   Theme.frame
    property color frameHi: Theme.frameHi
    property int   cols: 4
    property int   rows: 3

    implicitWidth: 120
    implicitHeight: 84

    Rectangle {                                   // wooden frame, lit from above
        anchors.fill: parent
        radius: Theme.rsm
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Qt.lighter(root.frameHi, 1.12) }
            GradientStop { position: 0.30; color: root.frame }
            GradientStop { position: 1.0;  color: Qt.darker(root.frame, 1.42) }
        }
    }
    Rectangle {                                   // recessed grout the tiles sit on
        id: field
        anchors.fill: parent
        anchors.margins: Math.max(3, root.width * 0.05)
        color: root.tileGap
        radius: 3
        antialiasing: true

        Grid {
            anchors.centerIn: parent
            rows: root.rows; columns: root.cols
            spacing: Math.max(1, field.width * 0.012)
            Repeater {
                model: root.rows * root.cols
                delegate: Rectangle {
                    required property int index
                    readonly property int r: Math.floor(index / root.cols)
                    readonly property int c: index % root.cols
                    readonly property color base: ((r + c) % 2 === 0) ? root.tileA : root.tileB
                    width:  (field.width  - field.width * 0.012 * (root.cols + 1)) / root.cols
                    height: (field.height - field.width * 0.012 * (root.rows + 1)) / root.rows
                    radius: width * 0.22
                    antialiasing: true
                    // Top-lit bevel: bright top edge → base → shadowed bottom.
                    gradient: Gradient {
                        GradientStop { position: 0.0;  color: Qt.lighter(base, 1.18) }
                        GradientStop { position: 0.16; color: Qt.lighter(base, 1.04) }
                        GradientStop { position: 0.6;  color: base }
                        GradientStop { position: 1.0;  color: Qt.darker(base, 1.13) }
                    }
                }
            }
        }
    }
}
