import QtQuick

// Static, per-scene "scenery" that sits behind the board — each scene has its OWN
// background artifacts (never the jungle foliage):
//   sunset   → a low setting sun + warm rolling hills
//   twilight → a distant pine treeline
//   aurora   → jagged snow-capped mountains
//   ember    → a glowing coal / lava ridge
//   snow     → pale rolling snow drifts
// Jungle uses the separate foliage layer instead (kind "none"). Silhouettes are drawn
// once with Canvas (index-hashed, deterministic) — no per-frame cost.
Item {
    id: root
    property string kind: "none"   // sunset | twilight | aurora | ember | snow | none

    onWidthChanged: _repaint()
    onHeightChanged: _repaint()
    onKindChanged: _repaint()
    function _repaint() {
        sunHills.requestPaint(); pines.requestPaint(); mountains.requestPaint();
        emberRidge.requestPaint(); drifts.requestPaint(); moon.requestPaint();
    }

    // ── TWILIGHT: a realistic moon (radial-shaded sphere + soft maria + halo) ──
    Canvas {
        id: moon
        anchors.fill: parent
        visible: root.kind === "twilight"
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var r = Math.min(width, height) * 0.075;
            var cx = width * 0.80, cy = height * 0.19;
            // soft halo
            var halo = ctx.createRadialGradient(cx, cy, r * 0.85, cx, cy, r * 2.3);
            halo.addColorStop(0, "rgba(226,236,255,0.16)");
            halo.addColorStop(1, "rgba(226,236,255,0.0)");
            ctx.fillStyle = halo;
            ctx.beginPath(); ctx.arc(cx, cy, r * 2.3, 0, Math.PI * 2); ctx.fill();
            // sphere — light offset to the upper-left, darkening toward the limb
            var g = ctx.createRadialGradient(cx - r * 0.35, cy - r * 0.35, r * 0.1, cx, cy, r);
            g.addColorStop(0.0, "#f6f8ff");
            g.addColorStop(0.65, "#dee6f5");
            g.addColorStop(1.0, "#b3bdd8");
            ctx.fillStyle = g;
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.fill();
            // maria — soft dark patches, clipped inside the disc
            ctx.save();
            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.clip();
            ctx.fillStyle = "rgba(150,160,190,0.26)";
            function mare(dx, dy, rr) { ctx.beginPath(); ctx.arc(cx + dx * r, cy + dy * r, rr * r, 0, Math.PI * 2); ctx.fill(); }
            mare(-0.22, -0.18, 0.30); mare(0.24, 0.08, 0.24); mare(0.02, 0.34, 0.17); mare(-0.34, 0.22, 0.13);
            ctx.restore();
        }
    }

    // ── SUNSET: a soft setting sun (concentric discs) beside the title ──
    Item {
        id: sun
        visible: root.kind === "sunset"
        width: Math.min(root.width, root.height) * 0.19; height: width
        x: root.width * 0.63 - width / 2
        y: root.height * 0.34 - height / 2
        Rectangle { anchors.centerIn: parent; width: sun.width * 2.7; height: width; radius: width / 2; color: "#ff8a3e"; opacity: 0.11 }
        Rectangle { anchors.centerIn: parent; width: sun.width * 1.7; height: width; radius: width / 2; color: "#ffb057"; opacity: 0.20 }
        Rectangle { anchors.centerIn: parent; width: sun.width;       height: width; radius: width / 2; color: "#ffd680" }
    }
    // ── SUNSET: two warm rolling hills ──
    Canvas {
        id: sunHills
        anchors.fill: parent
        visible: root.kind === "sunset"
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var w = width, h = height;
            ctx.fillStyle = "#3a2038";
            ctx.beginPath(); ctx.moveTo(0, h); ctx.lineTo(0, h * 0.86);
            ctx.quadraticCurveTo(w * 0.28, h * 0.74, w * 0.55, h * 0.85);
            ctx.quadraticCurveTo(w * 0.83, h * 0.95, w, h * 0.80);
            ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
            ctx.fillStyle = "#231327";
            ctx.beginPath(); ctx.moveTo(0, h); ctx.lineTo(0, h * 0.93);
            ctx.quadraticCurveTo(w * 0.42, h * 0.84, w * 0.73, h * 0.95);
            ctx.quadraticCurveTo(w * 0.90, h * 1.01, w, h * 0.92);
            ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
        }
    }

    // ── TWILIGHT: a distant pine treeline (two depth rows) ──
    Canvas {
        id: pines
        anchors.fill: parent
        visible: root.kind === "twilight"
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var w = width, h = height;
            function row(base, color, count, minH, maxH, seed) {
                ctx.fillStyle = color;
                for (var i = 0; i < count; i++) {
                    var cx = (i + 0.5) / count * w;
                    var hh = minH + ((i * 53 + seed) % 100) / 100 * (maxH - minH);
                    var half = hh * 0.42;
                    ctx.beginPath();
                    ctx.moveTo(cx, base - hh);
                    ctx.lineTo(cx + half, base);
                    ctx.lineTo(cx - half, base);
                    ctx.closePath(); ctx.fill();
                }
            }
            row(h * 0.985, "#0b0d26", 17, h * 0.10, h * 0.19, 7);   // back
            row(h * 1.0,   "#050615", 12, h * 0.14, h * 0.26, 3);   // front
        }
    }

    // ── AURORA: jagged snow-capped mountain ranges ──
    Canvas {
        id: mountains
        anchors.fill: parent
        visible: root.kind === "aurora"
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var w = width, h = height;
            function range(base, color, cap, peaks, minH, maxH, seed) {
                ctx.fillStyle = color;
                ctx.beginPath(); ctx.moveTo(0, h); ctx.lineTo(0, base);
                var tops = [];
                for (var i = 0; i <= peaks; i++) {
                    var x = i / peaks * w;
                    var vx = x - (w / peaks) * 0.5;
                    if (vx > 0) ctx.lineTo(vx, base);          // valley
                    var hh = minH + ((i * 61 + seed) % 100) / 100 * (maxH - minH);
                    ctx.lineTo(x, base - hh);                  // peak
                    tops.push([x, base - hh]);
                }
                ctx.lineTo(w, base); ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
                // snow caps
                ctx.fillStyle = cap;
                for (var p = 0; p < tops.length; p++) {
                    var px = tops[p][0], py = tops[p][1], s = h * 0.05;
                    ctx.beginPath();
                    ctx.moveTo(px, py);
                    ctx.lineTo(px + s * 0.7, py + s);
                    ctx.lineTo(px + s * 0.25, py + s * 0.85);
                    ctx.lineTo(px - s * 0.25, py + s * 1.0);
                    ctx.lineTo(px - s * 0.7, py + s);
                    ctx.closePath(); ctx.fill();
                }
            }
            range(h * 0.90, "#0b1030", "#26406a", 5, h * 0.16, h * 0.30, 4);   // back
            range(h * 1.0,  "#05081d", "#3a5686", 4, h * 0.24, h * 0.42, 9);   // front
        }
    }

    // ── EMBER: a molten lava field — hot light rising from the floor, bright molten
    // gaps glowing between dark coals/rocks, each rock rim-lit from below ──
    Canvas {
        id: emberRidge
        anchors.fill: parent
        visible: root.kind === "ember"
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var w = width, h = height;
            function hash(k) { var v = Math.sin(k * 78.233 + 12.9898) * 43758.5453; return v - Math.floor(v); }

            // 1. Ambient heat glow rising off the floor into the lower sky.
            var glow = ctx.createLinearGradient(0, h, 0, h * 0.5);
            glow.addColorStop(0.0, "rgba(255,100,26,0.42)");
            glow.addColorStop(0.55, "rgba(255,74,16,0.13)");
            glow.addColorStop(1.0, "rgba(255,74,16,0.0)");
            ctx.fillStyle = glow;
            ctx.fillRect(0, h * 0.5, w, h * 0.5);

            // 2. A thin bright molten seam at the very base (the rocks sit in the lava).
            var seam = ctx.createLinearGradient(0, h, 0, h * 0.9);
            seam.addColorStop(0.0, "#ffdc46");
            seam.addColorStop(0.5, "#ff7d22");
            seam.addColorStop(1.0, "rgba(255,90,20,0.0)");
            ctx.fillStyle = seam;
            ctx.fillRect(0, h * 0.9, w, h * 0.1);

            // 3. Dark rugged rock silhouette — an IRREGULAR, angular jagged crest (two
            //    octaves: a broad rise/fall + fine spikes) so it reads as rock, not teeth.
            var n = 30;
            var pts = [];
            for (var i = 0; i <= n; i++) {
                var x = i / n * w;
                var broad = 0.5 + 0.5 * Math.sin(i * 0.55 + 1.3);   // slow undulation
                var fine = hash(i * 3 + 1);                          // spiky detail
                var y = h * (0.90 - broad * 0.09 - fine * 0.06);     // crest 0.75h..0.90h
                pts.push([x, y]);
            }
            ctx.beginPath();
            ctx.moveTo(0, h);
            for (var j = 0; j <= n; j++) ctx.lineTo(pts[j][0], pts[j][1]);
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = "#1a0806";
            ctx.fill();

            // 4. Hot rim where the crest catches the glow behind it.
            ctx.beginPath();
            for (var k = 0; k <= n; k++) (k === 0 ? ctx.moveTo(pts[k][0], pts[k][1]) : ctx.lineTo(pts[k][0], pts[k][1]));
            ctx.strokeStyle = "#ff8a3a"; ctx.lineWidth = Math.max(1.5, h * 0.005);
            ctx.globalAlpha = 0.6; ctx.stroke(); ctx.globalAlpha = 1.0;

            // 5. Molten cracks — a few glowing veins running down through the rock.
            ctx.lineCap = "round";
            for (var c = 0; c < 6; c++) {
                var idx = 3 + Math.floor(hash(c * 7) * (n - 4));
                var x0 = pts[idx][0], y0 = pts[idx][1] + h * 0.008;
                var x1 = x0 + (hash(c * 7 + 2) - 0.5) * w * 0.05;
                ctx.beginPath();
                ctx.moveTo(x0, y0);
                ctx.lineTo(x1, y0 + h * 0.05);
                ctx.lineTo(x1 + (hash(c * 7 + 4) - 0.5) * w * 0.05, h);
                ctx.strokeStyle = "#ff7a24"; ctx.lineWidth = Math.max(1.5, h * 0.004);
                ctx.globalAlpha = 0.5; ctx.stroke(); ctx.globalAlpha = 1.0;
            }
        }
    }

    // ── SNOWFALL: pale rolling snow drifts ──
    Canvas {
        id: drifts
        anchors.fill: parent
        visible: root.kind === "snow"
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var w = width, h = height;
            ctx.fillStyle = "#8faccb";
            ctx.beginPath(); ctx.moveTo(0, h); ctx.lineTo(0, h * 0.90);
            ctx.quadraticCurveTo(w * 0.30, h * 0.82, w * 0.60, h * 0.90);
            ctx.quadraticCurveTo(w * 0.85, h * 0.96, w, h * 0.87);
            ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
            ctx.fillStyle = "#d3e2f3";
            ctx.beginPath(); ctx.moveTo(0, h); ctx.lineTo(0, h * 0.95);
            ctx.quadraticCurveTo(w * 0.45, h * 0.88, w * 0.75, h * 0.96);
            ctx.quadraticCurveTo(w * 0.92, h * 1.01, w, h * 0.94);
            ctx.lineTo(w, h); ctx.closePath(); ctx.fill();
        }
    }
}
