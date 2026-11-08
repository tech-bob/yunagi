import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Scope {
    id: root

    property bool open: false
    ScreenTarget { id: popupTarget }
    readonly property var screen: popupTarget.screen
    property string page: "root"
    property string query: ""
    property int selected: 0
    property var settings: ({})
    property string error: ""
    property string optionKey: ""
    property string optionTitle: ""
    property var optionList: []
    // Last pointer position; rows moving under a still pointer must not steal the selection
    property point pointer: Qt.point(-1, -1)
    property string optionReturn: "root"
    property string lookMark: ""
    property string lookTitle: ""
    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/yunagi-settings"
    readonly property string title: ({
        root: "Settings", screen: "Screen & lock", devices: "Devices", config: "Config", look: "About mark",
        keyboard: "Keyboard", mouse: "Mouse & touchpad", git: "Git", system: "System",
        choice: optionTitle, input: optionTitle, lookcolour: lookTitle
    })[page] || ""
    // [label, value] lists for the choice page
    readonly property var minuteOptions: [1, 2, 5, 10, 15, 30, 60].map(n => [n + (n === 1 ? " minute" : " minutes"), n * 60])
    readonly property var tempOptions: [[ "Warm · 2500 K", 2500], ["2750 K", 2750], ["3000 K", 3000], ["3500 K", 3500], ["Mild · 4500 K", 4500]]
    readonly property var layoutOptions: [["Swedish", "se"], ["English (US)", "us"], ["English (UK)", "gb"], ["Norwegian", "no"],
                                          ["Danish", "dk"], ["Finnish", "fi"], ["German", "de"], ["French", "fr"], ["Spanish", "es"]]
    readonly property var rateOptions: [["Slow · 20/s", 20], ["Normal · 25/s", 25], ["Fast · 35/s", 35], ["Faster · 50/s", 50]]
    readonly property var delayOptions: [["Short · 250 ms", 250], ["400 ms", 400], ["Long · 600 ms", 600]]
    readonly property var sensOptions: [["Slowest", -0.6], ["Slow", -0.3], ["Normal", 0], ["Fast", 0.2], ["Faster", 0.4], ["Fastest", 0.7]]
    readonly property var entries: {
        if (page === "root") return [
            { label: "Apps", detail: "Find and launch applications", icon: "\uf00a", target: "launcher" },
            { label: "Packages", detail: "Search, install and remove software", icon: "\uf187", packages: true },
            { label: "Screen & lock", detail: "Screensaver, idle time and locking", icon: "\uf023", page: "screen" },
            { label: "Devices", detail: "Audio, displays and connections", icon: "\uf108", page: "devices" },
            { label: "System", detail: "Lock, power and system information", icon: "\uf013", page: "system" },
            { label: "Git", detail: "Name and email for commits", icon: "\uf1d3", page: "git" },
            { label: "Config", detail: "Edit configuration files", icon: "\uf121", page: "config" }
        ];
        if (page === "config") return [
            { label: "Git", icon: "\uf1d3", file: ".gitconfig" },
            { label: "Hyprland", icon: "\uf2d2", file: ".config/hypr/hyprland.lua" },
            { label: "Hypridle", icon: "\uf186", file: ".config/hypr/hypridle.conf" },
            { label: "Hyprlock", icon: "\uf023", file: ".config/hypr/hyprlock.conf" },
            { label: "Hyprpaper", icon: "\uf03e", file: ".config/hypr/hyprpaper.conf" },
            { label: "Hyprsunset", icon: "\uf043", file: ".config/hypr/hyprsunset.conf" },
            { label: "Kitty", icon: "\uf120", file: ".config/kitty/kitty.conf" },
            { label: "Fish", icon: "\uf489", file: ".config/fish/config.fish" },
            { label: "Neovim", icon: "\ue62b", file: ".config/nvim/init.lua" }
        ];
        if (page === "screen") return [
            { label: "Screensaver", key: "screensaver_enabled", kind: "toggle", value: settings.screensaver_enabled ? "On" : "Off" },
            { label: "Start after", key: "screensaver_seconds", kind: "choice", options: minuteOptions, value: minutes(settings.screensaver_seconds), disabled: !settings.screensaver_enabled },
            { label: "Lock after", key: "lock_seconds", kind: "choice", options: minuteOptions, value: minutes(settings.lock_seconds) },
            { label: "Turn screens off on lock", key: "screen_off_on_lock", kind: "toggle", value: settings.screen_off_on_lock ? "On" : "Off" },
            { label: "Night light in the evening", detail: "20:00 to 07:00; Super+T switches it by hand", key: "night_auto", kind: "toggle", value: settings.night_auto ? "On" : "Off" },
            { label: "Night light temperature", key: "night_temperature", kind: "choice", options: tempOptions, value: settings.night_temperature ? settings.night_temperature + " K" : "—" },
            { label: "Preview screensaver", icon: "\uf04b", preview: true }
        ];
        if (page === "keyboard") return [
            { label: "Layout", key: "kb_layout", kind: "choice", options: layoutOptions, value: optionLabel(layoutOptions, settings.kb_layout) },
            { label: "Repeat rate", key: "repeat_rate", kind: "choice", options: rateOptions, value: optionLabel(rateOptions, settings.repeat_rate) },
            { label: "Repeat delay", key: "repeat_delay", kind: "choice", options: delayOptions, value: optionLabel(delayOptions, settings.repeat_delay) }
        ];
        if (page === "mouse") return [
            { label: "Pointer speed", key: "sensitivity", kind: "choice", options: sensOptions, value: optionLabel(sensOptions, settings.sensitivity) },
            { label: "Natural scrolling", detail: "Touchpad", key: "natural_scroll", kind: "toggle", value: settings.natural_scroll ? "On" : "Off" },
            { label: "Tap to click", detail: "Touchpad", key: "tap_to_click", kind: "toggle", value: settings.tap_to_click ? "On" : "Off" }
        ];
        if (page === "git") return [
            { label: "Name", key: "git_name", kind: "text", value: settings.git_name || "—" },
            { label: "Email", key: "git_email", kind: "text", value: settings.git_email || "—" }
        ];
        if (page === "input") return [];
        if (page === "devices") return [
            { label: "Audio", icon: "\uf028", target: "audio" },
            { label: "Display", icon: "\uf108", target: "brightness" },
            { label: "Bluetooth", icon: "\uf293", target: "bt" },
            { label: "Network", icon: "\uf1eb", target: "network" },
            { label: "Keyboard", icon: "\uf11c", page: "keyboard" },
            { label: "Mouse & touchpad", icon: "\uf245", page: "mouse" }
        ];
        if (page === "choice") return optionList.map(o => ({
            label: o[0], choice: o[1], value: String(settings[optionKey]) === String(o[1]) ? "Current" : ""
        }));
        const current = markChoice.text().trim() || "diamant-solnedgang";
        // [label, file key]
        if (page === "look") return [["Diamond", "diamant"], ["Labyrinth", "labyrint"], ["Brilliant", "briljant"],
                                     ["Octahedron", "oktaeder"], ["Crystal", "kristall"], ["Prism", "prisma"], ["Spiral", "spiral"]].map(m => ({
            label: m[0], look: m[1], value: current.startsWith(m[1] + "-") ? "Current" : ""
        }));
        if (page === "lookcolour") return [["Aurora", "aurora"], ["Sunset", "solnedgang"], ["Ocean", "hav"], ["Neon", "neon"],
                                           ["Candy", "godis"], ["Ice", "is"]]
            .concat(lookMark === "briljant" || lookMark === "prisma" || lookMark === "spiral" ? [["Original", "original"]] : []).map(c => {
                const mark = lookMark + "-" + c[1];
                return { label: c[0], mark: mark, value: mark === current ? "Current" : "" };
            });
        return [
            { label: "Lock now", icon: "\uf023", lock: true },
            { label: "Power menu", icon: "\uf011", target: "power" },
            { label: "System information", icon: "\uf05a", target: "info" },
            { label: "About mark", detail: "Mark and colours in System information", icon: "\uf53f", page: "look" }
        ];
    }
    readonly property var shown: page === "input" ? [] : entries.filter(row => row.label.toLowerCase().includes(query.trim().toLowerCase()))

    function optionLabel(list, v) {
        const o = list.find(o => String(o[1]) === String(v));
        return o ? o[0].split(" · ")[0] : (v === undefined ? "—" : String(v));
    }

    function saveInput() {
        request(["set", optionKey, search.text.trim()]);
        navigate(optionReturn);
    }

    function minutes(seconds) {
        return seconds ? Math.round(seconds / 60) + " min" : "—";
    }

    function navigate(next) {
        page = next;
        pointer = Qt.point(-1, -1);
        query = "";
        search.text = "";
        selected = 0;
        error = "";
        search.forceActiveFocus();
    }

    function toggle() {
        if (open) { open = false; return; }
        if (!popupTarget.select())
            return;
        navigate("root");
        open = true;
        request(["get"]);
        search.forceActiveFocus();
    }

    function request(args) {
        if (backend.running) return;
        error = "";
        backend.command = [helper].concat(args);
        backend.running = true;
    }

    function activate(row) {
        if (!row || row.disabled || backend.running) return;
        if (row.page) { navigate(row.page); return; }
        if (row.look) { lookMark = row.look; lookTitle = row.label; navigate("lookcolour"); return; }
        if (row.mark) {
            Quickshell.execDetached(["sh", "-c", 'mkdir -p "$HOME/.local/state/yunagi" && printf %s "$1" > "$HOME/.local/state/yunagi/about-mark"', "sh", row.mark]);
            open = false;
            Quickshell.execDetached(["qs", "ipc", "call", "info", "toggle"]);
            return;
        }
        if (row.kind === "toggle") {
            request(["set", row.key, String(!settings[row.key])]);
        } else if (row.kind === "choice" || row.kind === "text") {
            optionKey = row.key;
            optionTitle = row.label;
            optionList = row.options || [];
            optionReturn = page;
            navigate(row.kind === "choice" ? "choice" : "input");
            if (row.kind === "text") search.text = settings[row.key] || "";
        } else if (row.choice !== undefined) {
            request(["set", optionKey, String(row.choice)]);
            navigate(optionReturn);
        } else {
            open = false;
            if (row.preview) Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yunagi-screensaver"]);
            else if (row.lock) Quickshell.execDetached(["hyprlock"]);
            else if (row.file) Quickshell.execDetached(["kitty", "-e", "nvim", Quickshell.env("HOME") + "/" + row.file]);
            else if (row.packages) Quickshell.execDetached(["kitty", "--class", "yunagi-pkg", "-o", "confirm_os_window_close=0", "-e", "yunagi-pkg"]);
            else Quickshell.execDetached(["qs", "ipc", "call", row.target, "toggle"]);
        }
    }

    function back() {
        if (page === "root") open = false;
        else navigate(page === "choice" || page === "input" ? optionReturn : page === "lookcolour" ? "look"
                      : page === "look" ? "system" : page === "keyboard" || page === "mouse" ? "devices" : "root");
    }

    FileView {
        id: markChoice
        path: Quickshell.env("HOME") + "/.local/state/yunagi/about-mark"
        watchChanges: true
        onFileChanged: reload()
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle(); }
    }

    Process {
        id: backend
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim()) {
                    try { root.settings = JSON.parse(text); }
                    catch (e) { root.error = "Could not read settings."; }
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) root.error = text.trim()
        }
    }

    PanelWindow {
        visible: root.screen !== null && root.open
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "yunagi-settings"
        anchors { top: true; bottom: true; left: true; right: true }

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: card
            width: Math.min(560, parent.width - 48)
            height: content.height + 48
            anchors.centerIn: parent
            color: Qt.alpha(Colors.surface, 0.98)
            radius: 18
            border.width: 1
            border.color: Colors.outlineVariant

            MouseArea { anchors.fill: parent }

            Column {
                id: content
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 14

                Row {
                    width: parent.width
                    spacing: 10
                    Text {
                        text: root.page === "root" ? "\uf013" : "\uf104"
                        color: Colors.primary
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 20
                        width: 24
                        height: 26
                        verticalAlignment: Text.AlignVCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.back()
                        }
                    }
                    Text {
                        text: root.title
                        color: Colors.text
                        font.family: "Noto Serif"
                        font.pixelSize: 23
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 9
                    color: Colors.surfaceContainer
                    Text {
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.page === "input" ? root.optionTitle + "…" : "Search settings…"
                        color: Colors.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 14
                        visible: search.text === ""
                    }
                    TextInput {
                        id: search
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        color: Colors.text
                        selectionColor: Colors.secondaryContainer
                        font.family: "sans-serif"
                        font.pixelSize: 14
                        clip: true
                        focus: true
                        onTextChanged: { root.query = text; root.selected = 0; }
                        Keys.onPressed: event => {
                            if (root.page === "input" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) root.saveInput();
                            else if (event.key === Qt.Key_Escape) root.back();
                            else if (event.key === Qt.Key_Backspace && text === "") root.back();
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                                root.selected = (root.selected + 1) % Math.max(1, root.shown.length);
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                                root.selected = (root.selected + root.shown.length - 1) % Math.max(1, root.shown.length);
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                root.activate(root.shown[root.selected]);
                            else return;
                            event.accepted = true;
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: root.shown
                        Rectangle {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool current: root.selected === index
                            width: content.width
                            height: modelData.detail ? 64 : 48
                            radius: 9
                            color: current ? Qt.alpha(Colors.primary, 0.1) : "transparent"
                            border.width: current ? 1 : 0
                            border.color: Qt.alpha(Colors.primary, 0.55)
                            opacity: modelData.disabled ? 0.4 : 1

                            Text {
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.icon || "\uf105"
                                color: entry.current ? Colors.primary : Colors.textDim
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 16
                            }
                            Column {
                                x: 44
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    text: entry.modelData.label
                                    color: Colors.text
                                    font.family: "sans-serif"
                                    font.pixelSize: 15
                                }
                                Text {
                                    visible: !!entry.modelData.detail
                                    text: entry.modelData.detail || ""
                                    color: Colors.textDim
                                    font.family: "sans-serif"
                                    font.pixelSize: 12
                                }
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.value !== undefined ? entry.modelData.value : "›"
                                color: entry.current || entry.modelData.value === "On" ? Colors.primary : Colors.textDim
                                font.family: "sans-serif"
                                font.pixelSize: 14
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: entry.modelData.disabled ? Qt.ArrowCursor : Qt.PointingHandCursor
                                onPositionChanged: mouse => {
                                    const p = mapToGlobal(mouse.x, mouse.y);
                                    if (root.pointer.x >= 0 && (p.x !== root.pointer.x || p.y !== root.pointer.y))
                                        root.selected = entry.index;
                                    root.pointer = p;
                                }
                                onClicked: root.activate(entry.modelData)
                            }
                        }
                    }
                    Text {
                        visible: root.shown.length === 0
                        text: "No matching settings"
                        color: Colors.textDim
                        font.pixelSize: 14
                        height: 48
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    width: parent.width
                    visible: root.error !== ""
                    text: root.error
                    color: "#f87171"
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
                Rectangle { width: parent.width; height: 1; color: Qt.alpha(Colors.outlineVariant, 0.6) }
                Text {
                    text: backend.running ? "Loading…"
                        : root.page === "input" ? "Enter save   ·   Esc back"
                        : ["screen", "keyboard", "mouse", "git"].includes(root.page) ? "Changes are saved immediately"
                        : "↑ ↓ navigate   ·   Enter select   ·   Esc back"
                    color: Colors.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 12
                }
            }
        }
    }
}
