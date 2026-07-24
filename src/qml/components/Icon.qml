import QtQuick
import HungrySnake

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
        "trophy":  '<path d="M8 21h8M12 17v4M7 4h10v4a5 5 0 0 1-10 0V4z"/><path d="M7 6H4v1a3 3 0 0 0 3 3M17 6h3v1a3 3 0 0 1-3 3"/>',
        "home":    '<path d="M4 11l8-7 8 7"/><path d="M6 9.5V20h12V9.5"/><path d="M10 20v-5h4v5"/>',
        "gear":    '<circle cx="12" cy="12" r="3.1"/><path d="M19.4 12a7.4 7.4 0 0 0-.1-1.3l2-1.6-2-3.4-2.4 1a7.3 7.3 0 0 0-2.2-1.3L14.3 2h-4l-.4 2.4a7.3 7.3 0 0 0-2.2 1.3l-2.4-1-2 3.4 2 1.6a7.4 7.4 0 0 0 0 2.6l-2 1.6 2 3.4 2.4-1a7.3 7.3 0 0 0 2.2 1.3l.4 2.4h4l.4-2.4a7.3 7.3 0 0 0 2.2-1.3l2.4 1 2-3.4-2-1.6c.1-.4.1-.8.1-1.3z"/>',
        "store":   '<path d="M5.5 8.5h13l-1 11.5H6.5l-1-11.5z"/><path d="M9 8.5V6a3 3 0 0 1 6 0v2.5"/>',
        "medal":   '<circle cx="12" cy="14.5" r="5"/><circle cx="12" cy="14.5" r="1.9"/><path d="M8.7 10.2 5.9 3.6M15.3 10.2 18.1 3.6"/>',
        "calendar":'<rect x="4" y="5" width="16" height="16" rx="2"/><path d="M4 9.5h16M8 3v4M16 3v4"/>',
        "lock":    '<rect x="5" y="11" width="14" height="9" rx="2"/><path d="M8 11V8a4 4 0 0 1 8 0v3"/>',
        "check":   '<polyline points="5 12.5 10 17.5 19 6.5"/>',
        "heart":   '<path d="M12 20.5C6.5 16.2 3.5 12.9 3.5 9 3.5 6.4 5.5 4.5 8 4.5c1.7 0 3.2.9 4 2.3.8-1.4 2.3-2.3 4-2.3 2.5 0 4.5 1.9 4.5 4.5 0 3.9-3 7.2-8.5 11.5z"/>',
        "chevron": '<polyline points="9 6 15 12 9 18"/>',
        "sparkle": '<path d="M12 3l1.7 5.5L19 10l-5.3 1.5L12 17l-1.7-5.5L5 10l5.3-1.5L12 3z"/>',
        // Winner's podium (2-1-3) — a monochrome ranks/leaderboard glyph matching the
        // other line icons (the full-colour trophy lives in _rich for HUD/celebrations).
        "ranks":   '<rect x="3" y="12" width="5.6" height="9" rx="1"/><rect x="9.2" y="7" width="5.6" height="14" rx="1"/><rect x="15.4" y="15" width="5.6" height="6" rx="1"/>',
        "edit":    '<path d="M12 20h9"/><path d="M16.5 3.5a2.12 2.12 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5z"/>',
        "power":   '<path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2.5" x2="12" y2="12"/>'
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
          + '<rect x="6.9" y="17.1" width="10.2" height="2.5" rx="1.2" fill="#c98a2a"/>',
        "coin":   // the Coins currency glyph — a shiny gold coin with a star
            '<circle cx="12" cy="12" r="8.6" fill="#e8b53a"/>'
          + '<circle cx="12" cy="12" r="8.6" fill="none" stroke="#a9781a" stroke-width="1.1"/>'
          + '<circle cx="12" cy="12" r="6.1" fill="none" stroke="#caa02a" stroke-width="1.1"/>'
          + '<path d="M12 8.5 l1.06 2.15 2.37.35 -1.72 1.67 .41 2.36 -2.12 -1.11 -2.12 1.11 .41 -2.36 -1.72 -1.67 2.37 -.35 z" fill="#fff3cf"/>'
          + '<ellipse cx="9.3" cy="9" rx="1.9" ry="2.5" fill="#ffffff" fill-opacity="0.45" transform="rotate(-25 9.3 9)"/>'
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
        // URL-encoded (not base64) data URI: sidesteps the deprecated Qt.btoa(string)
        // overload, and encodeURIComponent escapes the '#' in the SVG colour attrs.
        source: "data:image/svg+xml;utf8," + encodeURIComponent(root._svg())
    }
}
