pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Colours from matugen, written to ~/.local/state/yunagi/colors.json from the template in
// ~/.config/matugen/templates; until then Yunagi's dark defaults
Singleton {
    readonly property var c: {
        try { return JSON.parse(file.text()); } catch (e) { return {}; }
    }
    readonly property color primary: c.primary || "#52d5ff"
    readonly property color surface: c.surface || "#04090a"
    readonly property color surfaceContainer: c.surfaceContainer || "#0f1619"
    readonly property color surfaceContainerHigh: c.surfaceContainerHigh || "#192124"
    readonly property color surfaceContainerHighest: c.surfaceContainerHighest || "#222b2f"
    readonly property color secondaryContainer: c.secondaryContainer || "#2c4a60"
    readonly property color text: c.text || "#d9e4ea"
    readonly property color textDim: c.textDim || "#bdc8ce"
    readonly property color outline: c.outline || "#879298"
    readonly property color tertiary: c.tertiary || "#abc8f7"
    readonly property color outlineVariant: c.outlineVariant || "#3d484d"

    FileView {
        id: file
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/yunagi/colors.json"
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }
}
