import QtQuick
import QtQuick.Shapes
import HungrySnake

// The "Goof" mascot — a front-facing snake head that matches the app icon
// (mismatched googly eyes, open grin, red tongue). Drawn in a fixed 112×96 design
// space and scaled to `size` (the head height), so the proportions stay exact.
Item {
    id: root
    property real size: 120
    readonly property real s: size / 96
    implicitWidth: 112 * s
    implicitHeight: 96 * s

    Item {
        width: 112; height: 96
        transformOrigin: Item.TopLeft
        scale: root.s

        Rectangle { width: 112; height: 96; radius: 34; color: "#2fb268"; antialiasing: true }   // head
        Rectangle { width: 112; height: 42; radius: 21; color: "#1f8f56"; antialiasing: true }   // top band
        Rectangle {                                                                              // right-flank shadow
            x: 56; width: 56; height: 96; color: "#000000"; opacity: 0.13; antialiasing: true
            topLeftRadius: 0; bottomLeftRadius: 0; topRightRadius: 34; bottomRightRadius: 34
        }
        Shape {                                                                                  // grin
            anchors.fill: parent; antialiasing: true; preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: "transparent"; strokeColor: "#14603f"; strokeWidth: 7
                capStyle: ShapePath.RoundCap
                startX: 40; startY: 58
                PathQuad { controlX: 60; controlY: 78; x: 82; y: 54 }
            }
        }
        Rectangle { x: 65;   y: 61;   width: 14; height: 14; radius: 7;   color: "#e63a3a"; antialiasing: true }  // tongue
        Rectangle { x: 19;   y: 3;    width: 42; height: 42; radius: 21;  color: "#ffffff"; antialiasing: true }  // eye 1 (big)
        Rectangle { x: 64;   y: 4;    width: 32; height: 32; radius: 16;  color: "#ffffff"; antialiasing: true }  // eye 2 (small)
        Rectangle { x: 37;   y: 19;   width: 18; height: 18; radius: 9;   color: "#14603f"; antialiasing: true }  // pupil 1
        Rectangle { x: 78;   y: 16;   width: 14; height: 14; radius: 7;   color: "#14603f"; antialiasing: true }  // pupil 2
        Rectangle { x: 46;   y: 21;   width: 6;  height: 6;  radius: 3;   color: "#ffffff"; antialiasing: true }  // catchlight 1
        Rectangle { x: 84.5; y: 17.5; width: 5;  height: 5;  radius: 2.5; color: "#ffffff"; antialiasing: true }  // catchlight 2
    }
}
