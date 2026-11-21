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
    // AI page: state from yunagi-ai, the item being worked on and its progress
    property var aiStatus: ({})
    property string aiName: "ai"
    property string aiBusy: ""
    // SSH page: the agent and the keys, from yunagi-ssh
    property var sshStatus: ({})
    onSshStatusChanged: if (page === "ssh") Qt.callLater(() => selected = firstRow())
    property bool sshBusy: false

    function sshRefresh() {
        if (!sshStatusProc.running) sshStatusProc.running = true;
    }
    // Adding or making a key, or turning the agent on, happens in a terminal
    function sshRun(row) {
        if (sshBusy) return;
        sshBusy = true;
        sshProc.command = ["kitty", "--class", "bar-tui", "-o", "confirm_os_window_close=0", "-e",
                           Quickshell.env("HOME") + "/.local/bin/yunagi-ssh", "do"].concat(row.sshDo);
        sshProc.running = true;
        open = false;
    }

    // Keybinds page: rows from hyprctl binds -j, read when the page opens
    property var keybinds: []
    readonly property string title: ({
        root: "Yunagi", prefs: "Settings", screen: "Screen", lock: "Lock screen", config: "Config", look: "About mark",
        keyboard: "Keyboard", mouse: "Mouse & touchpad", git: "Git", system: "System", ai: "AI", aiusage: "Usage", keybinds: "Keybinds", ssh: "SSH",
        choice: optionTitle, input: optionTitle, lookcolour: lookTitle
    })[page] || ""
    // [label, value] lists for the choice page
    readonly property var minuteOptions: [1, 2, 5, 10, 15, 30, 60].map(n => [n + (n === 1 ? " minute" : " minutes"), n * 60])
    readonly property var startOptions: ["17:00", "18:00", "19:00", "20:00", "21:00", "22:00"].map(t => [t, t])
    readonly property var tempOptions: [[ "Warm · 2500 K", 2500], ["2750 K", 2750], ["3000 K", 3000], ["3500 K", 3500], ["Mild · 4500 K", 4500]]
    readonly property var layoutOptions: [["Swedish", "se"], ["English (US)", "us"], ["English (UK)", "gb"], ["Norwegian", "no"],
                                          ["Danish", "dk"], ["Finnish", "fi"], ["German", "de"], ["French", "fr"], ["Spanish", "es"]]
    readonly property var rateOptions: [["Slow · 20/s", 20], ["Normal · 25/s", 25], ["Fast · 35/s", 35], ["Faster · 50/s", 50]]
    // Pictures in ~/Pictures/wallpapers, by file name
    readonly property var lockBackgroundOptions: (settings.lock_backgrounds || []).map(f =>
        [f.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ").replace(/^./, c => c.toUpperCase()), f])
    readonly property var lockBlurOptions: [["Off", 0], ["Light", 1], ["Medium", 2], ["Strong", 3]]
    readonly property var menuSizeOptions: [["Small · 80 %", 0.8], ["90 %", 0.9], ["Normal · 100 %", 1]]
    // Menu size from yunagi-settings; the launcher reads the same file
    readonly property real menuSize: Number(menuSizeFile.text().trim()) || 1
    readonly property var delayOptions: [["Short · 250 ms", 250], ["400 ms", 400], ["Long · 600 ms", 600]]
    // Slider being dragged: its key and value until release
    property string dragKey: ""
    property real dragValue: 0
    onSettingsChanged: dragKey = ""
    readonly property var entries: {
        if (page === "root") return [
            { label: "Apps", detail: "Find and launch applications", icon: "\uf00a", target: "launcher" },
            { label: "Packages", detail: "Search, install and remove software", icon: "\uf187", packages: true },
            { label: "AI", detail: "Agents, desktop apps and the shared terminal", icon: "\uee0d", page: "ai" },
            { label: "Settings", detail: "Screen, input, git and SSH", icon: "\uf1de", page: "prefs" },
            { label: "System", detail: "Devices, this computer and config files", icon: "\uf013", page: "system" }
        ];
        if (page === "prefs") return [
            { head: "Screen" },
            { label: "Screen", detail: "Screensaver and night light", icon: "\uf108", page: "screen" },
            { label: "Lock screen", detail: "Locking, background, blur and greeting", icon: "\uf023", page: "lock" },
            { label: "Menu size", detail: "This menu and the app launcher; the bar keeps its size", icon: "\uf065",
              key: "menu_size", kind: "choice", options: menuSizeOptions, value: optionLabel(menuSizeOptions, settings.menu_size) },
            { label: "About mark", detail: "Mark and colours in System information", icon: "\udb80\udfd8", page: "look" },
            { head: "Input" },
            { label: "Keyboard", detail: "Layout and key repeat", icon: "\uf11c", page: "keyboard" },
            { label: "Mouse & touchpad", detail: "Speed, scrolling and tapping", icon: "\uf245", page: "mouse" },
            { label: "Keybinds", detail: "Every shortcut · Super+K", icon: "\udb80\udf0c", page: "keybinds" },
            { head: "Accounts" },
            { label: "Git", detail: "Name and email for commits", icon: "\uf1d3", page: "git" },
            { label: "SSH", detail: "The SSH agent and new keys", icon: "\uf084", page: "ssh" }
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
            { label: "Neovim", icon: "\ue62b", file: ".config/nvim/init.lua" },
            { label: "Firewall", detail: "nftables; asks for your password", icon: "\uf132", system: "/etc/nftables.conf" }
        ];
        if (page === "screen") return [
            { label: "Screensaver", key: "screensaver_enabled", kind: "toggle", value: settings.screensaver_enabled ? "On" : "Off" },
            { label: "Start after", key: "screensaver_seconds", kind: "choice", options: minuteOptions, value: minutes(settings.screensaver_seconds), disabled: !settings.screensaver_enabled },
            { label: "Night light in the evening", detail: (settings.night_start || "20:00") + " to 07:00; Super+T switches it by hand", key: "night_auto", kind: "toggle", value: settings.night_auto ? "On" : "Off" },
            { label: "Night light from", key: "night_start", kind: "choice", options: startOptions, value: settings.night_start || "—", disabled: !settings.night_auto },
            { label: "Night light temperature", key: "night_temperature", kind: "choice", options: tempOptions, value: settings.night_temperature ? settings.night_temperature + " K" : "—" },
            { label: "Preview screensaver", icon: "\uf04b", preview: true }
        ];
        if (page === "lock") return [
            { label: "Lock after", key: "lock_seconds", kind: "choice", options: minuteOptions, value: minutes(settings.lock_seconds) },
            { label: "Turn screens off on lock", key: "screen_off_on_lock", kind: "toggle", value: settings.screen_off_on_lock ? "On" : "Off" },
            { label: "Background", detail: "Pictures in ~/Pictures/wallpapers", key: "lock_background", kind: "choice", options: lockBackgroundOptions,
              value: optionLabel(lockBackgroundOptions, settings.lock_background) },
            { label: "Blur", key: "lock_blur", kind: "choice", options: lockBlurOptions, value: optionLabel(lockBlurOptions, settings.lock_blur) },
            { label: "Your name", detail: "In the greeting; empty uses " + Quickshell.env("USER"), key: "display_name", kind: "text", value: settings.display_name || "—" }
        ];
        if (page === "keyboard") return [
            { label: "Layout", key: "kb_layout", kind: "choice", options: layoutOptions, value: optionLabel(layoutOptions, settings.kb_layout) },
            { label: "Repeat rate", key: "repeat_rate", kind: "choice", options: rateOptions, value: optionLabel(rateOptions, settings.repeat_rate) },
            { label: "Repeat delay", key: "repeat_delay", kind: "choice", options: delayOptions, value: optionLabel(delayOptions, settings.repeat_delay) }
        ];
        if (page === "mouse") return [
            { label: "Pointer speed", detail: "0 is Hyprland's default", key: "sensitivity", kind: "slider", min: -1, max: 1, num: settings.sensitivity ?? 0 },
            { label: "Natural scrolling", detail: "Touchpad", key: "natural_scroll", kind: "toggle", value: settings.natural_scroll ? "On" : "Off" },
            { label: "Tap to click", detail: "Touchpad", key: "tap_to_click", kind: "toggle", value: settings.tap_to_click ? "On" : "Off" }
        ];
        if (page === "git") return [
            { label: "Name", key: "git_name", kind: "text", value: settings.git_name || "—" },
            { label: "Email", key: "git_email", kind: "text", value: settings.git_email || "—" }
        ];
        if (page === "input") return [];
        if (page === "keybinds") return keybinds;
        if (page === "ssh") return [
            sshStatus.agent
                ? { label: "SSH agent", detail: "On: keys you add with ssh-add are kept", icon: "\uf011", value: "Turn off", sshDo: ["disable"] }
                : { label: "SSH agent", detail: "Off: keys are asked for every time", icon: "\uf011", value: "Turn on", sshDo: ["enable"] },
            { label: "New key", detail: "ed25519, shows the public key for GitHub and servers", icon: "\uf067", sshDo: ["new"] }
        ];
        if (page === "aiusage") return [];
        if (page === "ai") {
            const account = aiStatus.account || "";
            const self = !!aiStatus.self;
            // Enter opens a terminal that does the job; ready rows have nothing to do
            const state = { install: "Install", setup: "Set up", ready: "Ready" };
            const stateIcon = { ready: "\uf00c", install: "\uf019", setup: "\uf019" };
            const item = (key, label, detail) => ({
                label: label, aiItem: key, detail: detail,
                icon: aiBusy === key ? "\uf110" : stateIcon[aiStatus[key]] || "\uf105",
                value: aiBusy === key ? "…" : state[aiStatus[key]] || "—",
                disabled: aiBusy !== "" && aiBusy !== key
            });
            const rows = [
                { head: "Agents · " + (self ? account + " (you)" : account || aiName) },
                item("claude", "Claude Code"), item("codex", "Codex"), item("grok", "Grok CLI"),
                { head: "Usage" },
                aiStatus.usage === "ready" ? { label: "Usage", icon: "\udb81\udea9", page: "aiusage" } : item("usage", "Usage")
            ];
            if (self) return rows;
            return rows.concat([
                { head: "Apps" },
                item("grokbot", "Grok Bot"), item("hermes", "Hermes", "Never starts by itself"),
                { head: "Account" },
                account ? { label: account, detail: "No sudo · Enter sets the password for su", icon: "\uf007",
                            aiItem: "password", value: aiBusy === "password" ? "…" : undefined, disabled: aiBusy !== "" }
                        : { label: aiName, detail: "Created on the first set-up · Enter renames", icon: "\uf007",
                            key: "ai_name", kind: "text", aiAccount: true },
                item("tmux", "Shared terminal", "tmuxdela lets it watch, tmuxdelaw lets it type")
            ]);
        }

        // Lock backgrounds show a thumbnail of the picture
        if (page === "choice") return optionList.map(o => ({
            label: o[0], choice: o[1], value: String(settings[optionKey]) === String(o[1]) ? "Current" : "",
            picture: optionKey === "lock_background" ? "file://" + Quickshell.env("HOME") + "/Pictures/wallpapers/" + o[1] : ""
        }));
        const current = markChoice.text().trim() || "diamant-solnedgang";
        // [label, file key]
        // The other candidates stay in branding/ and mark/, out of the menu
        if (page === "look") return [["Diamond", "diamant"], ["Labyrinth", "labyrint"]].map(m => ({
            label: m[0], look: m[1], value: current.startsWith(m[1] + "-") ? "Current" : ""
        }));
        if (page === "lookcolour") return [["Aurora", "aurora"], ["Sunset", "solnedgang"], ["Ocean", "hav"], ["Neon", "neon"],
                                           ["Candy", "godis"], ["Ice", "is"]]
            .map(c => {
                const mark = lookMark + "-" + c[1];
                return { label: c[0], mark: mark, value: mark === current ? "Current" : "" };
            });
        return [
            { head: "Devices" },
            { label: "Audio", detail: "Volume, outputs and inputs", icon: "\uf028", target: "audio", center: true },
            { label: "Display", detail: "Brightness and screens", icon: "\uf108", target: "brightness", center: true },
            { label: "Bluetooth", detail: "Devices and pairing", icon: "\uf293", target: "bt", center: true },
            { label: "Network", detail: "Connections: Wi-Fi, wired, VPN, IP and DNS", icon: "\uf1eb", run: ["nm-connection-editor"] },
            { head: "This computer" },
            { label: "System information", detail: "Hardware", icon: "\uf05a", target: "info" },
            { label: "Config", detail: "Edit configuration files", icon: "\uf121", page: "config" }
        ];
    }
    readonly property var shown: page === "input" ? [] : entries.filter(row => row.head ? query.trim() === ""
                                                                         : row.label.toLowerCase().includes(query.trim().toLowerCase()))
    // Section heads are skipped by the selection
    onShownChanged: if (shown[selected]?.head || shown[selected]?.info) selected = nextRow(selected, 1)
    function firstRow() {
        return shown[0]?.head || shown[0]?.info ? nextRow(0, 1) : 0;
    }
    function nextRow(from, dir) {
        const n = shown.length;
        for (let i = from, k = 0; k < n; k++) {
            i = (i + dir + n) % n;
            if (!shown[i].head && !shown[i].info) return i;
        }
        return from;
    }

    function optionLabel(list, v) {
        const o = list.find(o => String(o[1]) === String(v));
        return o ? o[0].split(" · ")[0] : (v === undefined ? "—" : String(v));
    }

    function saveInput() {
        const text = search.text.trim();
        if (optionKey === "ai_name") aiName = text || "ai";
        else request(["set", optionKey, text]);
        navigate(optionReturn);
    }

    function aiRefresh() {
        if (!aiStatusProc.running) aiStatusProc.running = true;
    }

    // A terminal sets the item up (sudo, sign-in links and codes happen there); the page
    // reads the states again when it closes
    function aiRun(row) {
        if (aiBusy !== "" || (row.aiItem !== "password" && aiStatus[row.aiItem] === "ready")) return;
        aiBusy = row.aiItem;
        error = "";
        aiProc.command = ["kitty", "--class", "bar-tui", "-o", "confirm_os_window_close=0", "-e",
                          "/usr/local/bin/yunagi-ai", "do", row.aiItem, aiStatus.account || aiName];
        aiProc.running = true;
        open = false;
    }

    function signed(v) {
        return (v > 0 ? "+" : "") + v.toFixed(1);
    }

    // Slider value to a step of 0.1 within the row's range, then saved
    function setSlider(row, v) {
        v = Math.max(row.min, Math.min(row.max, Math.round(v * 10) / 10));
        if (v !== row.num) request(["set", row.key, String(v)]);
    }

    function minutes(seconds) {
        return seconds ? Math.round(seconds / 60) + " min" : "—";
    }

    function navigate(next) {
        page = next;
        dragKey = "";
        pointer = Qt.point(-1, -1);
        query = "";
        search.text = "";
        selected = firstRow();
        error = "";
        search.forceActiveFocus();
    }

    function toggle() {
        if (open) { open = false; return; }
        if (!popupTarget.select())
            return;
        // Back to the AI page while something is in progress there
        navigate(aiBusy ? "ai" : "root");
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
        if (!row || row.head || row.info || row.disabled || backend.running) return;
        if (row.page) { navigate(row.page); if (row.page === "ai") aiRefresh(); if (row.page === "aiusage") AiUsage.now = Date.now(); if (row.page === "keybinds") kbProc.running = true; if (row.page === "ssh") sshRefresh(); return; }
        if (row.sshDo) { sshRun(row); return; }
        if (row.aiItem) { aiRun(row); return; }
        if (row.aiAccount && !row.kind) return;
        if (row.kind === "slider") return;
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
            if (row.kind === "text") search.text = row.aiAccount ? aiName : settings[row.key] || "";
        } else if (row.choice !== undefined) {
            request(["set", optionKey, String(row.choice)]);
            navigate(optionReturn);
        } else {
            open = false;
            if (row.preview) Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yunagi-screensaver"]);
            // System file: edited as root, then the firewall reloads; an error stays on screen
            else if (row.system) Quickshell.execDetached(["kitty", "-e", "sh", "-c",
                'SUDO_EDITOR=nvim sudoedit "$1" && sudo systemctl restart nftables || { echo; read -r -p "Press Return to close" _; }', "sh", row.system]);
            else if (row.file) Quickshell.execDetached(["kitty", "-e", "nvim", Quickshell.env("HOME") + "/" + row.file]);
            else if (row.run) Quickshell.execDetached(row.run);
            else if (row.packages) Quickshell.execDetached(["kitty", "--class", "yunagi-pkg", "-o", "confirm_os_window_close=0", "-o", "window_padding_width=0", "-e", "yunagi-pkg"]);
            else Quickshell.execDetached(["qs", "ipc", "call", row.target, row.center ? "center" : "toggle"]);
        }
    }

    function back() {
        if (page === "root") open = false;
        else navigate(page === "choice" || page === "input" ? optionReturn : page === "lookcolour" ? "look"
                      : page === "config" ? "system"
                      : page === "aiusage" ? "ai"
                      : ["screen", "lock", "keyboard", "mouse", "git", "look", "keybinds", "ssh"].includes(page) ? "prefs" : "root");
    }

    FileView {
        id: menuSizeFile
        path: Quickshell.env("HOME") + "/.local/state/yunagi/menu-size"
        watchChanges: true
        onFileChanged: reload()
    }

    FileView {
        id: markChoice
        path: Quickshell.env("HOME") + "/.local/state/yunagi/about-mark"
        watchChanges: true
        onFileChanged: reload()
    }

    Process {
        id: aiStatusProc
        command: ["/usr/local/bin/yunagi-ai", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.aiStatus = JSON.parse(text); }
                catch (e) { root.error = "Could not read the AI status."; }
            }
        }
    }

    Process {
        id: sshStatusProc
        command: [Quickshell.env("HOME") + "/.local/bin/yunagi-ssh", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.sshStatus = JSON.parse(text); }
                catch (e) { root.error = "Could not read the SSH keys."; }
            }
        }
    }

    Process {
        id: sshProc
        onExited: { root.sshBusy = false; root.sshRefresh(); }
    }

    Process {
        id: aiProc
        onExited: { root.aiBusy = ""; root.aiRefresh(); }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle(); }
        // Opens the menu on a page, e.g. "ai"
        function page(name: string): void {
            if (!root.open) { root.toggle(); if (!root.open) return; }
            root.navigate(name);
            if (name === "ai") root.aiRefresh();
            if (name === "keybinds") kbProc.running = true;
            if (name === "ssh") root.sshRefresh();
        }
        function keybinds(): void {
            if (root.open && root.page === "keybinds") { root.open = false; return; }
            if (!root.open) { root.toggle(); if (!root.open) return; }
            root.navigate("keybinds");
            kbProc.running = true;
        }
    }

    // "Super + Shift + F"; the workspace binds 1–10 fold into one row each
    function combo(b) {
        const mods = [[64, "Super"], [4, "Ctrl"], [8, "Alt"], [1, "Shift"]].filter(m => b.modmask & m[0]).map(m => m[1]);
        const keys = { "mouse:272": "Left drag", "mouse:273": "Right drag", mouse_down: "Scroll down", mouse_up: "Scroll up",
                       Return: "Enter", Space: "Space", Page_Up: "Page Up", left: "←", right: "→", up: "↑", down: "↓", less: "<",
                       PRINT: "Print", XF86Display: "Display key", XF86AudioRaiseVolume: "Volume up key", XF86AudioLowerVolume: "Volume down key",
                       XF86AudioMute: "Mute key", XF86AudioMicMute: "Mic mute key", XF86MonBrightnessUp: "Brightness up key",
                       XF86MonBrightnessDown: "Brightness down key" };
        return mods.concat([keys[b.key] || (b.key.length === 1 ? b.key.toUpperCase() : b.key)]).join(" + ");
    }
    function keybindRows(binds) {
        const rows = [], folded = {};
        for (const b of binds) {
            if (!b.description || b.submap) continue;
            const m = b.description.match(/^(.*workspace) (\d+)(.*)$/i);
            if (m && /^[0-9]$/.test(b.key)) {
                const label = m[1] + " 1–10" + m[3];
                if (folded[label]) continue;
                folded[label] = true;
                rows.push({ label: label, value: combo(b).replace(/ \+ [0-9]$/, " + 1…0"), info: true });
            } else rows.push({ label: b.description, value: combo(b), info: true });
        }
        return rows;
    }

    Process {
        id: kbProc
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.keybinds = root.keybindRows(JSON.parse(text)); }
                catch (e) { root.error = "Could not read the keybinds."; }
            }
        }
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
            scale: root.menuSize
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
                    // The Yunagi mark on the first page, a back arrow below it
                    Item {
                        width: 26
                        height: 26
                        Image {
                            visible: root.page === "root"
                            anchors.fill: parent
                            sourceSize: Qt.size(52, 52)
                            source: Qt.resolvedUrl("mark/diamant.svg")
                        }
                        Text {
                            visible: root.page !== "root"
                            anchors.fill: parent
                            text: "\uf104"
                            color: Colors.primary
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 20
                            verticalAlignment: Text.AlignVCenter
                        }
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
                // Close, as in the app launcher
                Text {
                    parent: card
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 24
                    anchors.topMargin: 26
                    text: "\uf00d"
                    color: closeHover.hovered ? Colors.primary : Colors.textDim
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 18
                    HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.open = false }
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
                        onTextChanged: { root.query = text; root.selected = root.firstRow(); }
                        Keys.onPressed: event => {
                            if (root.page === "input" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) root.saveInput();
                            else if (event.key === Qt.Key_Escape) root.back();
                            else if (event.key === Qt.Key_Backspace && text === "") root.back();
                            else if (root.page === "keybinds" && (event.key === Qt.Key_Down || event.key === Qt.Key_Up))
                                rowsView.contentY = Math.max(0, Math.min(rowsView.contentHeight - rowsView.height,
                                                                          rowsView.contentY + (event.key === Qt.Key_Down ? 76 : -76)));
                            else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                                root.selected = root.nextRow(root.selected, 1);
                            else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                                root.selected = root.nextRow(root.selected, -1);
                            else if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right) && root.shown[root.selected]?.kind === "slider") {
                                const row = root.shown[root.selected];
                                root.setSlider(row, row.num + (event.key === Qt.Key_Right ? 0.1 : -0.1));
                            }
                            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                                root.activate(root.shown[root.selected]);
                            else return;
                            event.accepted = true;
                        }
                    }
                }

                Flickable {
                    id: rowsView
                    width: parent.width
                    height: Math.min(rows.implicitHeight, (root.screen ? root.screen.height : 1080) - 300)
                    contentHeight: rows.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    Connections {
                        target: root
                        function onPageChanged() { rowsView.contentY = 0; }
                    }

                Column {
                    id: rows
                    width: parent.width
                    spacing: 4
                    AiUsageList {
                        visible: root.page === "aiusage"
                        width: parent.width
                        topPadding: 6
                        bottomPadding: 6
                    }
                    Repeater {
                        model: root.shown
                        Rectangle {
                            id: entry
                            required property var modelData
                            required property int index
                            readonly property bool current: root.selected === index && !modelData.info && !modelData.head
                            width: content.width
                            height: modelData.head ? (index === 0 ? 22 : 34) : modelData.picture ? 74 : modelData.info && !modelData.detail ? 34 : modelData.detail ? 64 : 48
                            radius: 9
                            color: current ? Qt.alpha(Colors.primary, 0.1) : "transparent"
                            border.width: current ? 1 : 0
                            border.color: Qt.alpha(Colors.primary, 0.55)
                            opacity: modelData.disabled ? 0.4 : 1

                            Text {
                                visible: !!entry.modelData.head
                                x: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                text: (entry.modelData.head || "").toUpperCase()
                                color: Colors.textDim
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                            Image {
                                visible: !!entry.modelData.picture
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 96
                                height: 54
                                source: entry.modelData.picture || ""
                                sourceSize: Qt.size(192, 108)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                clip: true
                            }
                            Text {
                                visible: !entry.modelData.head && !entry.modelData.picture
                                x: 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.icon || (entry.modelData.info ? "" : "\uf105")
                                color: entry.current ? Colors.primary : Colors.textDim
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 16
                            }
                            Column {
                                visible: !entry.modelData.head
                                x: entry.modelData.picture ? 124 : entry.modelData.info && !entry.modelData.icon ? 14 : 44
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    text: entry.modelData.label || ""
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
                                visible: !entry.modelData.head
                                anchors.right: parent.right
                                anchors.rightMargin: entry.modelData.kind === "slider" ? 204 : 14
                                anchors.verticalCenter: parent.verticalCenter
                                text: entry.modelData.kind === "slider"
                                    ? root.signed(root.dragKey === entry.modelData.key ? root.dragValue : entry.modelData.num)
                                    : entry.modelData.value !== undefined ? entry.modelData.value : "›"
                                color: entry.current || entry.modelData.value === "On" || entry.modelData.value === "Ready" ? Colors.primary : Colors.textDim
                                font.family: "sans-serif"
                                font.pixelSize: 14
                            }
                            MouseArea {
                                enabled: !entry.modelData.head && !entry.modelData.info
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
                            // Drag or click to set; ← → on the keyboard step by 0.1
                            Item {
                                id: slider
                                visible: entry.modelData.kind === "slider"
                                readonly property var row: entry.modelData
                                readonly property real at: row.kind === "slider"
                                    ? ((root.dragKey === row.key ? root.dragValue : row.num) - row.min) / (row.max - row.min) : 0
                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 180
                                height: 22
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    color: Colors.outlineVariant
                                    Rectangle {
                                        width: parent.width * slider.at
                                        height: parent.height
                                        color: entry.current ? Colors.primary : Colors.text
                                    }
                                }
                                // Mark at the default (0)
                                Rectangle {
                                    visible: slider.row.min < 0
                                    x: slider.width * (0 - slider.row.min) / (slider.row.max - slider.row.min) - 1
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 2
                                    height: 10
                                    color: Colors.textDim
                                }
                                Rectangle {
                                    x: (slider.width - width) * slider.at
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    color: entry.current ? Colors.primary : Colors.text
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    function valueAt(x) {
                                        const r = slider.row;
                                        const v = r.min + Math.max(0, Math.min(1, (x - 6) / slider.width)) * (r.max - r.min);
                                        return Math.round(v * 10) / 10;
                                    }
                                    onPressed: mouse => { root.selected = entry.index; root.dragKey = slider.row.key; root.dragValue = valueAt(mouse.x); }
                                    onPositionChanged: mouse => { if (pressed) root.dragValue = valueAt(mouse.x); }
                                    // The dragged value stays shown until the saved settings come back
                                    onReleased: {
                                        if (root.dragValue === slider.row.num) root.dragKey = "";
                                        else root.setSlider(slider.row, root.dragValue);
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        visible: root.shown.length === 0 && root.page !== "aiusage"
                        text: "No matching settings"
                        color: Colors.textDim
                        font.pixelSize: 14
                        height: 48
                        verticalAlignment: Text.AlignVCenter
                    }
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
                Item {
                    width: parent.width
                    height: footer.implicitHeight
                Text {
                    id: footer
                    text: backend.running ? "Loading…"
                        : root.page === "input" ? "Enter save   ·   Esc back"
                        : ["screen", "lock", "keyboard", "mouse", "git"].includes(root.page) ? "Changes are saved immediately"
                        : root.page === "keybinds" ? "Type to search   ·   ↑ ↓ scroll   ·   Esc back"
                        : root.page === "ai" ? "Enter opens a terminal for it   ·   Esc back"
                        : root.page === "aiusage" ? "Updates every 5 minutes   ·   Esc back"
                        : root.page === "ssh" ? "Enter opens a terminal for it   ·   Esc back"
                        : "↑ ↓ navigate   ·   Enter select   ·   Esc back"
                    color: Colors.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 12
                }
                // Power menu, as in the app launcher
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uf011"
                    color: powerHover.hovered ? Colors.primary : Colors.textDim
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 18
                    HoverHandler { id: powerHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            root.open = false;
                            Quickshell.execDetached(["qs", "ipc", "call", "power", "toggle"]);
                        }
                    }
                }
                }
            }
        }
    }
}
