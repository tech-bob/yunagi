import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Monitor layout picker: extend, external only, one output, mirror.
PanelWindow {
    id: win

    signal closeRequested()
    readonly property bool swedishUi: Qt.locale().name.startsWith("sv")
    property int sel: 0
    property var monitors: []

    readonly property var modes: {
        const internal = monitors.filter(m => Outputs.isInternal(m.name));
        const external = monitors.filter(m => !Outputs.isInternal(m.name));
        const out = [];
        if (monitors.length > 1) {
            out.push({ id: "extend", label: "󰍺  " + (swedishUi ? "utökad" : "extend") });
            if (internal.length && external.length)
                out.push({ id: "external", label: "󰍹  " + (swedishUi ? "bara extern" : "external only") });
        }
        for (const mon of monitors) {
            out.push({ id: "only:" + mon.name, label: Outputs.isInternal(mon.name)
                ? "󰌢  " + (swedishUi ? "bara laptop" : "laptop only")
                : "󰍹  " + (swedishUi ? "bara " : "only ") + mon.name });
        }
        if (monitors.length > 1)
            out.push({ id: "mirror", label: "󰑖  " + (swedishUi ? "spegla" : "mirror") });
        return out;
    }
    onModesChanged: sel = 0
    onVisibleChanged: if (visible) {
        sel = 0;
        list.running = true;
    }

    function cycle() {
        sel = (sel + 1) % Math.max(1, modes.length);
    }

    // Applies from the last listing; the list refreshes on open and hotplug.
    function apply(mode) {
        const mons = monitors;
        if (!mode || !mons.length)
            return;
        closeRequested();
        const internal = mons.filter(m => Outputs.isInternal(m.name));
        const external = mons.filter(m => !Outputs.isInternal(m.name));
        const primary = internal[0] || mons.find(m => m.focused) || mons[0];
        // Preserve each output's resolution and scale when switching layouts.
        const on = (m, mirror = "") => {
            const resolution = m.width > 0 && m.height > 0 && m.refreshRate > 0
                ? `${m.width}x${m.height}@${m.refreshRate}` : "preferred";
            return `hl.monitor({ output = ${JSON.stringify(m.name)}, mode = "${resolution}", position = "auto", scale = "${m.scale || 1}", disabled = false, mirror = ${JSON.stringify(mirror)} })`;
        };
        // Which monitors are on is saved by yunagi-display-scale, so it survives hotplug
        const keep = mode === "extend" ? mons
            : mode === "external" ? external
            : mode.startsWith("only:") ? mons.filter(m => m.name === mode.slice(5))
            : [];
        if (keep.length) {
            Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yunagi-display-scale", "--on", keep.map(m => m.name).join(",")]);
            return;
        }
        let lua = [];
        if (mode === "mirror")
            lua = [on(primary)].concat(mons.filter(m => m !== primary).map(m => on(m, primary.name)));
        if (lua.length)
            Quickshell.execDetached(["hyprctl", "eval", lua.join("; ")]);
    }

    Process {
        id: list
        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { win.monitors = JSON.parse(text); }
                catch (e) {}
            }
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            list.running = true;
        }
    }

    implicitWidth: 400
    implicitHeight: dispCol.implicitHeight + 40
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    PanelBackground {
        border.color: Colors.primary
    }

    Column {
        id: dispCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 8
        focus: true
        Keys.onUpPressed: win.sel = (win.sel + win.modes.length - 1) % Math.max(1, win.modes.length)
        Keys.onDownPressed: win.cycle()
        Keys.onReturnPressed: win.apply(win.modes[win.sel]?.id)
        Keys.onEnterPressed: win.apply(win.modes[win.sel]?.id)
        Keys.onEscapePressed: win.closeRequested()

        Text {
            text: win.swedishUi ? "skärmar" : "displays"
            color: Colors.primary
            font.family: "Hack Nerd Font"
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Repeater {
            model: win.modes

            Rectangle {
                required property var modelData
                required property int index
                readonly property bool sel: win.sel === index
                width: dispCol.width
                height: 52
                color: sel ? Colors.secondaryContainer : "transparent"
                border.color: sel ? Colors.primary : Colors.outlineVariant
                radius: 0
                border.width: 1

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    text: parent.modelData.label
                    color: parent.sel ? Colors.text : Colors.textDim
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 16
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Select only on real pointer movement, not when the menu appears under a still pointer
                    property point last: Qt.point(-1, -1)
                    onExited: last = Qt.point(-1, -1)
                    onPositionChanged: mouse => {
                        const p = mapToGlobal(mouse.x, mouse.y);
                        if (last.x >= 0 && (p.x !== last.x || p.y !== last.y)) win.sel = parent.index;
                        last = p;
                    }
                    onClicked: win.apply(parent.modelData.id)
                }
            }
        }
    }
}
