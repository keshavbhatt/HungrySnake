import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import HungrySnake

// The apple/fruit art, shared by the board and the Store previews so a preview is
// literally the same drawing the player sees in-game (not a lookalike).
//
// NOTE the origin: like the board's apple, this Item's (0,0) is the fruit's CENTRE —
// the body is centred on it and the leaf sits above. Place it at the centre point.
Item {
    id: root
    property real  d: 40                    // body diameter
    property color body: Theme.apple
    property color leaf: Theme.appleLeaf
    property bool  shadow: true             // the board wants it; tiny previews may not

    Shape {                                 // body — a shaded sphere (light from top-left)
        id: appleBody
        width: root.d; height: root.d
        anchors.centerIn: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        // Real drop shadow: straight down in screen space (the fruit never rotates).
        layer.enabled: root.shadow
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowBlur: 0.9
            blurMax: 28
            shadowOpacity: 0.6
            shadowVerticalOffset: 8
            autoPaddingEnabled: true
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: root.d * 0.38; centerY: root.d * 0.32
                centerRadius: root.d * 0.78
                focalX: root.d * 0.38; focalY: root.d * 0.32
                GradientStop { position: 0.0;  color: Qt.lighter(root.body, 1.55) }
                GradientStop { position: 0.45; color: root.body }
                GradientStop { position: 1.0;  color: Qt.darker(root.body, 1.7) }
            }
            startX: root.d; startY: root.d / 2
            PathAngleArc {
                centerX: root.d / 2; centerY: root.d / 2
                radiusX: root.d / 2; radiusY: root.d / 2
                startAngle: 0; sweepAngle: 360
            }
        }
        Rectangle {                          // glossy specular streak, top-left
            x: root.d * 0.19; y: root.d * 0.14
            width: root.d * 0.2; height: root.d * 0.27
            radius: width / 2; rotation: -22
            antialiasing: true
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.9) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }
    Rectangle {                              // leaf
        anchors.horizontalCenter: parent.horizontalCenter
        y: -root.d / 2
        width: root.d * 0.35; height: root.d * 0.2
        radius: height / 2; rotation: -28
        color: root.leaf
        antialiasing: true
    }
}
