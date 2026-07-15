import QtQuick
import Snecko

// A themeable vector icon rendered from real SVG markup (via Qt's SVG image
// backend) so the UI looks identical on every platform. Pick an icon by `name`;
// the stroke colour follows `color`.
Item {
    id: root
    property string name: ""
    property color color: Theme.text
    property real size: 22

    implicitWidth: size
    implicitHeight: size

    // Stroke-based (Feather-style) icon bodies, 24×24 viewBox.
    readonly property var _paths: ({
        "menu":    '<line x1="4" y1="7" x2="20" y2="7"/><line x1="4" y1="12" x2="20" y2="12"/><line x1="4" y1="17" x2="20" y2="17"/>',
        "back":    '<polyline points="15 18 9 12 15 6"/>',
        "restart": '<polyline points="3 3 3 9 9 9"/><path d="M4 15a8 8 0 1 0 2-8.5L3 9"/>',
        "play":    '<polygon points="7 5 19 12 7 19 7 5"/>',
        "pause":   '<rect x="7" y="6" width="3.4" height="12" rx="1"/><rect x="13.6" y="6" width="3.4" height="12" rx="1"/>',
        "close":   '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>',
        "sound":   '<polygon points="4 9 8 9 12 5 12 19 8 15 4 15 4 9"/><path d="M16 8a5 5 0 0 1 0 8"/>',
        "mute":    '<polygon points="4 9 8 9 12 5 12 19 8 15 4 15 4 9"/><line x1="16" y1="9" x2="21" y2="15"/><line x1="21" y1="9" x2="16" y2="15"/>',
        "sun":     '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
        "moon":    '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
        "trophy":  '<path d="M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0V4z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3"/>'
    })

    // Filled, full-colour icons that match the game art (flat + saturated) — used
    // for the pictographic HUD glyphs instead of thin monochrome line icons. These
    // carry their own theme colours, so `color` is ignored for them.
    readonly property var _rich: ({
        "apple":
            '<ellipse cx="12" cy="14.2" rx="7.4" ry="7" fill="#e23b2c"/>'
          + '<path d="M12 14.2 a7.4 7 0 0 1 7.4 0" fill="none"/>'
          + '<path d="M12 8.1 C12 6 12.6 4.6 13.7 3.9" fill="none" stroke="#7a4a25" stroke-width="1.7" stroke-linecap="round"/>'
          + '<ellipse cx="15.2" cy="5.7" rx="3.3" ry="1.75" fill="#57b845" transform="rotate(-30 15.2 5.7)"/>'
          + '<ellipse cx="9.2" cy="11.3" rx="1.7" ry="2.5" fill="#ffffff" fill-opacity="0.5" transform="rotate(-25 9.2 11.3)"/>',
        "trophy":
            '<path d="M7 5 H4.1 a2.7 2.7 0 0 0 3 3.5" fill="none" stroke="#c98a2a" stroke-width="1.8" stroke-linecap="round"/>'
          + '<path d="M17 5 H19.9 a2.7 2.7 0 0 1 -3 3.5" fill="none" stroke="#c98a2a" stroke-width="1.8" stroke-linecap="round"/>'
          + '<path d="M6.4 3.5 H17.6 V7.3 a5.6 5.6 0 0 1 -11.2 0 Z" fill="#e6a93a"/>'
          + '<path d="M9 5 a2.6 4 0 0 0 0 4" fill="none" stroke="#fff3cf" stroke-width="1.2" stroke-linecap="round" opacity="0.65"/>'
          + '<rect x="10.9" y="12.2" width="2.2" height="3.3" fill="#c98a2a"/>'
          + '<rect x="8.2" y="15.2" width="7.6" height="1.9" rx="0.9" fill="#e6a93a"/>'
          + '<rect x="6.9" y="17.1" width="10.2" height="2.5" rx="1.2" fill="#c98a2a"/>'
    })

    // SVG only understands #RRGGBB (not Qt's #AARRGGBB), so pass the opaque RGB
    // and apply any alpha via the Image's opacity instead.
    function _hex() {
        function h(v) { return ("0" + Math.round(v * 255).toString(16)).slice(-2); }
        return "#" + h(color.r) + h(color.g) + h(color.b);
    }
    function _svg() {
        if (_rich[name] !== undefined)
            return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
                 + _rich[name] + '</svg>';
        var body = _paths[name] || "";
        return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="'
             + _hex() + '" stroke-width="2.1" stroke-linecap="round" stroke-linejoin="round">'
             + body + '</svg>';
    }

    Image {
        anchors.fill: parent
        smooth: true
        fillMode: Image.PreserveAspectFit
        opacity: root._rich[root.name] !== undefined ? 1.0 : root.color.a
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        source: "data:image/svg+xml;base64," + Qt.btoa(root._svg())
    }
}
