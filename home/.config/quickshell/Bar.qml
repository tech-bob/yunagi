import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts

Scope {
    id: root

    property string activePanel: ""
    property var trayItem: null
    property real trayX: 0

    function closeAll() {
        activePanel = "";
    }

    function showPanel(panel, screen) {
        closeAll();
        if (!popupTarget.select(screen))
            return;
        activePanel = panel;
    }

    function togglePanel(panel, screen) {
        if (activePanel === panel)
            closeAll();
        else
            showPanel(panel, screen);
    }

    function toggleRecording(screen) {
        if (capture.recording)
            capture.stop();
        else
            togglePanel("record", screen);
    }

    readonly property var marks: ["diamant", "labyrint", "briljant", "oktaeder", "kristall", "prisma", "spiral"]
    property int markIdx: 0
    property bool stayAwake: false
    property bool night: false
    property bool dnd: false

    function nightToggle() {
        night = !night;
        // Night temperature from hyprsunset.conf (set in the settings menu)
        Quickshell.execDetached(["sh", "-c", night
            ? 't=$(grep -o "temperature = [0-9]*" "$HOME/.config/hypr/hyprsunset.conf" | grep -o "[0-9]*$"); hyprctl hyprsunset temperature "${t:-2750}"'
            : "hyprctl hyprsunset identity"]);
    }

    Process {
        command: ["hyprctl", "hyprsunset", "temperature"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.night = parseInt(text) < 6000
        }
    }

    IpcHandler {
        target: "night"
        function toggle(): void {
            root.nightToggle();
        }
    }

    IpcHandler {
        target: "record"
        function toggle(): void {
            root.toggleRecording();
        }
        // Sent by yunagi-screenrecord.
        function started(): void {
            capture.started();
        }
        function stopped(): void {
            capture.recording = false;
        }
    }

    ScreenTarget { id: popupTarget }
    readonly property var popScreen: popupTarget.screen
    onPopScreenChanged: if (!popScreen) closeAll()

    function classIcon(cls) {
        if (!cls)
            return "";
        const e = DesktopEntries.heuristicLookup(cls);
        const p = Quickshell.iconPath(e && e.icon ? e.icon : cls, true);
        return p || Quickshell.iconPath("application-x-executable", true);
    }

    function wsById(id) {
        const vals = Hyprland.workspaces.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].id === id)
                return vals[i];
        }
        return null;
    }

    IpcHandler {
        target: "network"
        function toggle(): void {
            root.togglePanel("network");
        }
    }

    IpcHandler {
        target: "audio"
        function toggle(): void {
            root.togglePanel("audio");
        }
    }

    IpcHandler {
        target: "display"
        function toggle(): void {
            if (root.activePanel === "display") {
                displays.cycle();
                return;
            }
            root.showPanel("display");
        }
    }

    IpcHandler {
        target: "brightness"
        function up(): void {
            brightness.key(true);
        }
        function down(): void {
            brightness.key(false);
        }
        function toggle(): void {
            root.togglePanel("brightness");
        }
    }

    IpcHandler {
        target: "bt"
        function toggle(): void {
            root.togglePanel("bt");
        }
        function show(): void {
            root.showPanel("bt");
        }
        function hide(): void {
            if (root.activePanel === "bt")
                root.closeAll();
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            IdleInhibitor {
                window: bar
                enabled: root.stayAwake
            }

            anchors {
                top: true
                left: true
                right: true
            }
            margins {
                top: 10
                left: 10
                right: 10
            }
            implicitHeight: 36
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: 0
                color: Qt.alpha(Colors.surface, 0.65)
            }

            Item {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 10

                Row {
                    id: leftRow
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    // Yunagi mark: left click opens the Yunagi menu, right click cycles the mark candidates
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28
                        height: 28
                        sourceSize: Qt.size(56, 56)
                        source: Qt.resolvedUrl("mark/" + root.marks[root.markIdx] + ".svg")

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton)
                                    root.markIdx = (root.markIdx + 1) % root.marks.length;
                                else
                                    Quickshell.execDetached(["qs", "ipc", "call", "settings", "toggle"]);
                            }
                        }
                    }

                    Repeater {
                        model: {
                            const ids = [1, 2, 3, 4, 5];
                            const vals = Hyprland.workspaces.values;
                            for (let i = 0; i < vals.length; i++)
                                if (vals[i].id > 0 && !ids.includes(vals[i].id))
                                    ids.push(vals[i].id);
                            return ids.sort((a, b) => a - b);
                        }

                        Item {
                            required property int modelData
                            readonly property int wsId: modelData
                            readonly property var ws: root.wsById(wsId)
                            readonly property bool focused: ws ? ws.focused : false
                            readonly property bool used: ws ? ws.toplevels.values.length > 0 : false

                            height: 30
                            width: 18

                            Text {
                                anchors.centerIn: parent
                                visible: !focused
                                text: wsId
                                color: used ? Colors.text : Colors.textDim
                                opacity: used ? 1 : 0.4
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 13
                                font.weight: used ? Font.Bold : Font.Normal
                            }

                            // Windows open: a short line in the accent colour under the number
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                visible: used && !focused
                                width: 10
                                height: 2
                                color: Colors.primary
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                visible: focused
                                width: 12
                                height: 12
                                radius: 0
                                color: Colors.primary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (ws)
                                        ws.activate();
                                    else
                                        Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsId + " })");
                                }
                            }
                        }
                    }
                }

                // Hidden toggles left of the clock: shown on hover, active ones always
                Item {
                    id: togArea
                    anchors.right: clockText.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: togRow.implicitWidth + 16
                    height: parent.height

                    HoverHandler {
                        id: togHover
                    }

                    Row {
                        id: togRow
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Repeater {
                            model: [
                                { id: "cap", icon: "󰹑", tip: "Screenshot" },
                                { id: "rec", icon: "󰻂", tip: "Screen recording" },
                                { id: "awake", icon: "󰅶", tip: "Stay awake" },
                                { id: "night", icon: "󰖔", tip: "Night light" },
                                { id: "dnd", icon: "󰂛", tip: "Silence notifications" }
                            ]

                            Text {
                                id: togIcon
                                required property var modelData
                                readonly property bool active: modelData.id === "rec" ? capture.recording
                                    : modelData.id === "awake" ? root.stayAwake
                                    : modelData.id === "night" ? root.night
                                    : modelData.id === "dnd" ? root.dnd
                                    : root.activePanel === "capture"
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: active || togHover.hovered ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                text: modelData.id === "rec" && capture.recording
                                    ? "󰻂 " + Math.floor(capture.recSecs / 60) + ":" + String(capture.recSecs % 60).padStart(2, "0")
                                    : modelData.icon
                                color: modelData.id === "rec" && capture.recording ? "#f7768e" : (active ? Colors.primary : Colors.textDim)
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 17
                                font.weight: Font.Bold

                                PopupWindow {
                                    visible: togMouse.containsMouse
                                    anchor.item: togIcon
                                    anchor.edges: Edges.Bottom
                                    anchor.gravity: Edges.Bottom
                                    implicitWidth: tipText.implicitWidth + 24
                                    implicitHeight: tipText.implicitHeight + 14 + 12
                                    color: "transparent"
                                    mask: Region {}

                                    // Top 12 px stay empty so the cursor does not cover the text
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        height: parent.height - 12
                                        radius: 0
                                        color: Qt.alpha(Colors.surface, 0.96)
                                        border.color: Colors.primary
                                        border.width: 1

                                        Text {
                                            id: tipText
                                            anchors.centerIn: parent
                                            text: togIcon.modelData.id === "rec" && capture.recording ? "Stop recording" : togIcon.modelData.tip
                                            color: Colors.text
                                            font.family: "Hack Nerd Font"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }

                                MouseArea {
                                    id: togMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        const id = parent.modelData.id;
                                        if (id === "awake")
                                            root.stayAwake = !root.stayAwake;
                                        else if (id === "night")
                                            root.nightToggle();
                                        else if (id === "dnd")
                                            root.dnd = !root.dnd;
                                        else if (id === "rec")
                                            root.toggleRecording(bar.screen);
                                        else
                                            root.togglePanel("capture", bar.screen);
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    id: clockText
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(clock.date, "hh:mm AP")
                    color: Colors.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 17
                    font.weight: Font.DemiBold

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePanel("calendar", bar.screen)
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Repeater {
                        model: SystemTray.items

                        IconImage {
                            id: trayIcon
                            required property var modelData
                            implicitSize: 18
                            source: modelData.icon
                            anchors.verticalCenter: parent.verticalCenter

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    const it = trayIcon.modelData;
                                    if (mouse.button === Qt.MiddleButton)
                                        it.secondaryActivate();
                                    else if (mouse.button === Qt.RightButton || it.onlyMenu) {
                                        if (it.hasMenu) {
                                            root.trayItem = it;
                                            root.trayX = trayIcon.mapToItem(null, trayIcon.width / 2, 0).x;
                                            root.togglePanel("tray", bar.screen);
                                        }
                                    } else
                                        it.activate();
                                }
                            }
                        }
                    }

                    Text {
                        text: {
                            let icon = "󰤫";
                            if (network.wiredDev && network.wiredDev.connected)
                                icon = "󰈀";
                            else if (!Networking.wifiEnabled)
                                icon = "󰤮";
                            else if (network.wifiActive)
                                icon = network.wifiIcon(network.wifiActive.signalStrength) + " " + network.wifiActive.name;
                            const up = network.vpns.filter(v => v.active).map(v => v.name);
                            return up.length > 0 ? icon + "  󰖂 " + up.join(", ") : icon;
                        }
                        color: root.activePanel === "network" ? Colors.primary : Colors.textDim
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("network", bar.screen)
                        }
                    }

                    Text {
                        visible: bluetooth.available
                        text: {
                            const a = Bluetooth.defaultAdapter;
                            if (!a || !a.enabled)
                                return "󰂲";
                            return "󰂯";
                        }
                        color: root.activePanel === "bt" ? Colors.primary : Colors.textDim
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 18
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("bt", bar.screen)
                        }
                    }

                    Text {
                        text: {
                            if (audio.volMuted)
                                return "󰝟 muted";
                            const icon = audio.volPct < 34 ? "󰕿" : (audio.volPct < 67 ? "󰖀" : "󰕾");
                            return icon + " " + audio.volPct + "%";
                        }
                        color: root.activePanel === "audio" ? Colors.primary : Colors.textDim
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    audio.toggleMute();
                                    return;
                                }
                                root.togglePanel("audio", bar.screen);
                            }
                            onWheel: wheel => audio.setVol(audio.volPct / 100 + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                        }
                    }

                    Text {
                        text: "󰍹"
                        color: root.activePanel === "brightness" ? Colors.primary : Colors.textDim
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("brightness", bar.screen)
                            onWheel: wheel => brightness.step(bar.screen.name, wheel.angleDelta.y > 0)
                        }
                    }

                    Text {
                        visible: battery.hasBat
                        text: {
                            let icon = "󰁹";
                            if (battery.batCharging && !battery.batFull)
                                icon = "󰂄";
                            else if (battery.batPct <= 20)
                                icon = "󰁻";
                            else if (battery.batPct <= 40)
                                icon = "󰁾";
                            else if (battery.batPct <= 70)
                                icon = "󰂀";
                            if (battery.batFull)
                                return icon;
                            return icon + " " + battery.batPct + "%";
                        }
                        color: (battery.batPct < 20 && !battery.batCharging && !battery.batFull) ? "#f7768e" : "#9ece6a"
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 15
                        anchors.verticalCenter: parent.verticalCenter

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.togglePanel("battery", bar.screen)
                        }
                    }
                }
            }

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.activePanel !== ""
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Top

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            margins {
                top: 52
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                onPressed: root.closeAll()
            }
        }
    }

    NetworkPanel {
        id: network
        open: root.activePanel === "network"
        screen: root.popScreen
    }

    BluetoothPanel {
        id: bluetooth
        open: root.activePanel === "bt"
        screen: root.popScreen
    }

    TrayMenu {
        open: root.activePanel === "tray"
        screen: root.popScreen
        item: root.trayItem
        anchorX: root.trayX
        onCloseRequested: root.closeAll()
    }

    AudioPanel {
        id: audio
        open: root.activePanel === "audio"
        screen: root.popScreen
        onAdjusted: osd.volume(audio.volPct, audio.volMuted)
    }

    BatteryPanel {
        id: battery
        open: root.activePanel === "battery"
        screen: root.popScreen
    }

    CapturePanel {
        id: capture
        captureOpen: root.activePanel === "capture"
        recordOpen: root.activePanel === "record"
        screen: root.popScreen
        onCloseRequested: root.closeAll()
    }

    // Notifications.qml owns the server and popups; the bar controls Do Not Disturb.
    Notifications {
        dnd: root.dnd
    }

    Calendar {
        visible: root.activePanel === "calendar"
        screen: root.popScreen
        onCloseRequested: root.closeAll()
    }

    Displays {
        id: displays
        visible: root.activePanel === "display"
        screen: root.popScreen
        onCloseRequested: root.closeAll()
    }

    Brightness {
        id: brightness
        open: root.activePanel === "brightness"
        screen: root.popScreen
        onAdjusted: pct => osd.brightness(pct)
    }

    Osd {
        id: osd
    }
}
