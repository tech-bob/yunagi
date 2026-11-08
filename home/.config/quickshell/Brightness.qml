import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Brightness (backlight or DDC), GTK text size and monitor scale.
Scope {
    id: root

    property bool open: false
    property var screen: null
    signal adjusted(int pct)

    property string dev: ""
    readonly property bool hasBacklight: dev !== ""
    readonly property int backlightPct: hasBacklight ? Math.round(parseInt(briFile.text()) * 100 / parseInt(briMax.text())) : 0
    onBacklightPctChanged: if (hasBacklight) adjusted(backlightPct)

    property var ddcBus: ({})
    property var ddcVal: ({})
    property var ddcPending: ({})

    property real textFactor: 1.0
    property var monScale: ({})
    readonly property var textSteps: [9, 10, 11, 12, 13, 14, 16]
    readonly property var scaleSteps: [1, 1.25, 1.6, 2, 3, 4]

    onOpenChanged: if (open) {
        if (!ddcList.running)
            ddcList.running = true;
        dispRead.running = true;
    }

    function backlight(name) {
        return hasBacklight && Outputs.isInternal(name);
    }

    function has(name) {
        return backlight(name) || ddcBus[name] !== undefined;
    }

    function get(name) {
        return backlight(name) ? backlightPct : (ddcVal[name] ?? 0);
    }

    function run(args) {
        briProc.command = ["brightnessctl", "-d", dev, "-n2"].concat(args);
        briProc.running = true;
    }

    function set(name, pct) {
        if (!has(name))
            return;
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        if (backlight(name)) {
            run(["set", pct + "%"]);
            return;
        }
        const v = Object.assign({}, ddcVal);
        v[name] = pct;
        ddcVal = v;
        adjusted(pct);
        const p = Object.assign({}, ddcPending);
        p[name] = pct;
        ddcPending = p;
        ddcTimer.restart();
    }

    function step(name, up) {
        if (backlight(name))
            run(["set", up ? "5%+" : "5%-"]);
        else
            set(name, get(name) + (up ? 5 : -5));
    }

    // Brightness keys: the laptop backlight in 2% steps.
    function key(up) {
        if (!hasBacklight)
            return;
        const pct = Math.max(1, Math.min(100, backlightPct + (up ? 2 : -2)));
        adjusted(pct);
        run(["set", pct + "%"]);
    }

    function setTextPt(pt) {
        textFactor = pt / 11;
        Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "text-scaling-factor", String(textFactor)]);
    }

    function setScale(name, s) {
        const m = Object.assign({}, monScale);
        m[name] = s;
        monScale = m;
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yunagi-display-scale", name, String(s)]);
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.dev = text.trim()
        }
    }

    FileView {
        id: briFile
        path: root.hasBacklight ? "/sys/class/backlight/" + root.dev + "/brightness" : ""
    }

    FileView {
        id: briMax
        path: root.hasBacklight ? "/sys/class/backlight/" + root.dev + "/max_brightness" : ""
    }

    // sysfs sends no change events; poll so hardware keys and other tools show up.
    Timer {
        interval: 250
        running: root.hasBacklight
        repeat: true
        onTriggered: briFile.reload()
    }

    Process {
        id: briProc
        onExited: briFile.reload()
    }

    Process {
        id: ddcList
        running: true
        command: [Quickshell.env("HOME") + "/.local/bin/yunagi-ddc-list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const bus = {};
                const val = {};
                for (const line of text.split("\n")) {
                    const f = line.trim().split(/\s+/);
                    if (f.length >= 4) {
                        bus[f[0]] = f[1];
                        val[f[0]] = Math.round(parseInt(f[2]) * 100 / parseInt(f[3]));
                    }
                }
                root.ddcBus = bus;
                root.ddcVal = Object.assign(val, root.ddcPending);
            }
        }
    }

    Timer {
        id: ddcTimer
        interval: 300
        onTriggered: {
            for (const name in root.ddcPending)
                Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yunagi-ddc-set", root.ddcBus[name], String(root.ddcPending[name])]);
            root.ddcPending = {};
        }
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!ddcList.running)
                ddcList.running = true;
        }
    }

    Process {
        id: dispRead
        command: ["sh", "-c", "gsettings get org.gnome.desktop.interface text-scaling-factor; hyprctl monitors -j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const nl = text.indexOf("\n");
                root.textFactor = parseFloat(text.slice(0, nl)) || 1.0;
                const m = {};
                for (const mon of JSON.parse(text.slice(nl + 1)))
                    m[mon.name] = mon.scale;
                root.monScale = m;
            }
        }
    }

    PanelWindow {
        visible: root.open
        implicitWidth: 380
        implicitHeight: briCol.implicitHeight + 32
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        screen: root.screen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 54
            right: 10
        }

        PanelBackground {}

        Column {
            id: briCol
            readonly property string mon: root.screen ? root.screen.name : ""
            readonly property bool hasBri: root.has(mon)
            readonly property int bri: root.get(mon)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // Header
            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰍹"
                        color: Colors.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 24
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Display"
                            color: Colors.text
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }

                        Text {
                            text: !briCol.hasBri ? "LOOKING SHARP"
                                : briCol.bri <= 20 ? "NIGHT OWL"
                                : briCol.bri <= 50 ? "SOFT GLOW"
                                : briCol.bri <= 80 ? "DAYLIGHT"
                                : "SUN BLAST"
                            color: Colors.primary
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: briCol.mon
                    color: Colors.textDim
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 12
                    font.weight: Font.Bold
                }
            }

            Divider {}

            SectionHead {
                visible: briCol.hasBri
                label: "BRIGHTNESS"
                value: briCol.bri + "%"
            }

            VolSlider {
                visible: briCol.hasBri
                value: briCol.bri / 100
                onMoved: v => root.set(briCol.mon, v * 100)
            }

            Divider { visible: briCol.hasBri }

            SectionHead {
                label: "TEXT SIZE"
                value: Math.round(root.textFactor * 11) + "pt"
            }

            // Stepped slider over textSteps
            Item {
                id: ts
                readonly property int idx: {
                    const pt = Math.round(root.textFactor * 11);
                    let best = 0;
                    for (let i = 0; i < root.textSteps.length; i++)
                        if (Math.abs(root.textSteps[i] - pt) < Math.abs(root.textSteps[best] - pt))
                            best = i;
                    return best;
                }
                width: parent.width
                height: 22

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    Repeater {
                        model: root.textSteps.length - 1

                        Rectangle {
                            required property int index
                            width: (ts.width - 4 * (root.textSteps.length - 2)) / (root.textSteps.length - 1)
                            height: 4
                            radius: 0
                            color: index < ts.idx ? Colors.text : Colors.outlineVariant
                        }
                    }
                }

                Rectangle {
                    x: (ts.width - width) * ts.idx / (root.textSteps.length - 1)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14
                    height: 14
                    radius: 0
                    color: Colors.text
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function pick(x) {
                        const i = Math.max(0, Math.min(root.textSteps.length - 1, Math.round(x / width * (root.textSteps.length - 1))));
                        if (i !== ts.idx)
                            root.setTextPt(root.textSteps[i]);
                    }
                    onPressed: mouse => pick(mouse.x)
                    onPositionChanged: mouse => { if (pressed) pick(mouse.x); }
                }
            }

            Divider {}

            SectionHead {
                label: "SCALE"
                value: ""
            }

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: root.scaleSteps

                    Rectangle {
                        required property var modelData
                        readonly property bool on: Math.abs((root.monScale[briCol.mon] ?? 1) - modelData) < 0.01
                        width: (briCol.width - 6 * (root.scaleSteps.length - 1)) / root.scaleSteps.length
                        height: 32
                        radius: 0
                        color: on ? Colors.surfaceContainerHighest : (scMouse.containsMouse ? Colors.surfaceContainerHigh : "transparent")
                        border.color: on ? Colors.primary : Colors.outlineVariant
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: modelData + "x"
                            color: parent.on ? Colors.text : Colors.textDim
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }

                        MouseArea {
                            id: scMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!parent.on) root.setScale(briCol.mon, modelData)
                        }
                    }
                }
            }
        }
    }
}
