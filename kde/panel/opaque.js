// Plasma panel without Panel Colorizer: opaque (the Plasma style's dark background), 32 px.
// Run once: qdbus6 org.kde.plasmashell /PlasmaShell evaluateScript "$(cat opaque.js)"
for (const p of panels()) {
    for (const w of p.widgets()) {
        if (w.type == "luisbocanegra.panel.colorizer") w.remove();
    }
    p.opacity = "opaque";
    p.height = 32;
}
