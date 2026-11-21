import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Wayland
import QtQuick

// Wi-Fi, wired and VPN state, and the network panel.
Scope {
    id: root

    property bool open: false
    property var screen: null
    signal closeRequested()
    // Opened from the menu: in the middle of the screen; from the bar: under its icon
    property bool centered: false
    onOpenChanged: {
        pskFor = "";
        editName = "";
        if (open)
            vpnList.running = true;
    }

    // The connections you are on (wired, Wi-Fi): IPv4 and DNS edited in the panel
    property var conns: []
    property string editName: ""
    property var edit: ({})

    function editToggle(name) {
        editName = editName === name ? "" : name;
        edit = {};
        if (editName) {
            connInfo.command = ["nmcli", "-t", "-g", "ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS",
                                "connection", "show", name];
            connInfo.running = true;
        }
    }

    // What NetworkManager would refuse, said before the panel closes; "" when fine
    function editProblem(manual, addr, gw, dns) {
        const ip = v => /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.test(v) && v.split(".").every(n => Number(n) <= 255);
        if (manual) {
            const [a, prefix] = addr.split("/");
            if (!ip(a || "") || !(Number(prefix) >= 1 && Number(prefix) <= 32))
                return "Manual needs an address with its prefix, e.g. 192.168.1.50/24.";
            if (gw && !ip(gw))
                return "The gateway is not an IPv4 address.";
        }
        for (const d of dns.split(/[ ,]+/).filter(x => x))
            if (!ip(d) && !/^[0-9a-fA-F:]*:[0-9a-fA-F:]*$/.test(d))
                return d + " is not a DNS server address.";
        return "";
    }

    // Saving asks for the admin's password; the panel closes so the dialog can be used
    function editApply(name, manual, addr, gw, dns) {
        closeRequested();
        Quickshell.execDetached(["sh", "-c", 'name=$1 addr=$3 gw=$4 dns=$5
if [ "$2" = manual ]; then set -- ipv4.method manual ipv4.addresses "$addr" ipv4.gateway "$gw"
else set -- ipv4.method auto ipv4.addresses "" ipv4.gateway ""; fi
if [ -n "$dns" ]; then set -- "$@" ipv4.dns "$dns" ipv4.ignore-auto-dns yes
else set -- "$@" ipv4.dns "" ipv4.ignore-auto-dns no; fi
if out=$(nmcli connection modify "$name" "$@" 2>&1) && out=$(nmcli connection up "$name" 2>&1)
then notify-send -a Yunagi "$name" "Network settings applied."
else notify-send -a Yunagi "$name" "$out"; fi', "sh", name, manual ? "manual" : "auto", addr, gw, dns]);
    }

    property string pskFor: ""
    property var vpns: []
    readonly property bool vpnUp: vpns.some(v => v.active)
    readonly property color connectedColor: "#9ece6a"

    function vpnToggle(v) {
        vpnCmd.command = ["nmcli", "connection", v.active ? "down" : "up", "id", v.name];
        vpnCmd.running = true;
    }

    readonly property var wifiDev: {
        const d = Networking.devices.values;
        for (let i = 0; i < d.length; i++)
            if (d[i].type === DeviceType.Wifi)
                return d[i];
        return null;
    }
    readonly property var wiredDev: {
        const d = Networking.devices.values;
        for (let i = 0; i < d.length; i++)
            if (d[i].type === DeviceType.Wired)
                return d[i];
        return null;
    }
    readonly property var wifiNets: {
        if (!wifiDev)
            return [];
        return wifiDev.networks.values.slice().sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength));
    }
    readonly property var wifiActive: {
        for (let i = 0; i < wifiNets.length; i++)
            if (wifiNets[i].connected)
                return wifiNets[i];
        return null;
    }

    function pct(v) {
        return Math.round(v <= 1 ? v * 100 : v);
    }

    function wifiIcon(v) {
        const p = pct(v);
        if (p >= 80)
            return "󰤨";
        if (p >= 60)
            return "󰤥";
        if (p >= 40)
            return "󰤢";
        if (p >= 20)
            return "󰤟";
        return "󰤯";
    }

    Process {
        id: vpnList
        running: true
        command: ["nmcli", "-t", "-e", "no", "-f", "TYPE,ACTIVE,NAME", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [], on = [];
                for (const line of text.split("\n")) {
                    const f = line.split(":");
                    if (f.length < 3)
                        continue;
                    const name = f.slice(2).join(":");
                    if (f[0] === "wireguard" || f[0] === "vpn")
                        out.push({ name: name, active: f[1] === "yes" });
                    else if (f[1] === "yes" && (f[0] === "802-3-ethernet" || f[0] === "802-11-wireless"))
                        on.push({ name: name, wired: f[0] === "802-3-ethernet" });
                }
                root.vpns = out.sort((a, b) => a.name.localeCompare(b.name));
                root.conns = on;
            }
        }
    }

    Process {
        id: disconnectCmd
        onExited: vpnList.running = true
    }

    Process {
        id: connInfo
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.split("\n");
                root.edit = { method: v[0], addresses: v[1], gateway: v[2], dns: v[3],
                              nowAddress: v[4], nowGateway: v[5], nowDns: (v[6] || "").replace(/ \| /g, ", ") };
            }
        }
    }

    Process {
        id: vpnCmd
        onExited: vpnList.running = true
    }

    // NetworkManager reports changes; re-list VPNs only then.
    Process {
        id: nmMonitor
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: vpnDebounce.restart()
        }
        onExited: nmRestart.start()
    }

    Timer {
        id: vpnDebounce
        interval: 300
        onTriggered: vpnList.running = true
    }

    Timer {
        id: nmRestart
        interval: 5000
        onTriggered: {
            nmMonitor.running = true;
            vpnList.running = true;
        }
    }

    PanelWindow {
        id: netPanel
        readonly property bool wired: root.wiredDev && root.wiredDev.connected
        visible: root.open
        implicitWidth: 380
        implicitHeight: netHead.implicitHeight + Math.min(420, netList.implicitHeight) + 32 + 12 + more.height + 10
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.layer: WlrLayer.Overlay
        screen: root.screen

        anchors {
            top: true
            right: !root.centered
        }
        margins {
            top: root.centered ? Math.max(54, ((root.screen ? root.screen.height : 1080) - implicitHeight) / 2) : 54
            right: 10
        }

        Binding {
            target: root.wifiDev
            property: "scannerEnabled"
            value: root.open
            when: root.wifiDev !== null
        }

        PanelBackground {}

        // Esc closes it, as a click beside it does
        Item {
            focus: true
            Keys.onEscapePressed: root.closeRequested()
        }

        Column {
            id: netHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            PanelHeader {
                icon: netPanel.wired ? "󰈀" : (!Networking.wifiEnabled ? "󰤮" : (root.wifiActive ? root.wifiIcon(root.wifiActive.signalStrength) : "󰤯"))
                title: netPanel.wired ? "Network" : "Wi-Fi"
                mood: netPanel.wired ? "PLUGGED IN"
                    : !Networking.wifiEnabled ? "OFF THE GRID"
                    : root.wifiActive ? root.wifiActive.name.toUpperCase()
                    : "SEARCHING"
                on: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }

            Divider {}
        }

        Flickable {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: netHead.bottom
            anchors.bottom: more.top
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 10
            contentHeight: netList.implicitHeight
            clip: true

            Column {
                id: netList
                width: parent.width
                spacing: 2

                SectionHead {
                    visible: root.conns.length > 0
                    label: "CONNECTED"
                    value: ""
                }

                Repeater {
                    model: root.conns

                    Column {
                        id: conn
                        required property var modelData
                        readonly property bool editing: root.editName === modelData.name
                        property bool manual: false
                        property string problem: ""
                        width: netList.width
                        spacing: 6

                        // The network you are on, green as in the list; a click opens IP and DNS
                        DevRow {
                            readonly property var net: !conn.modelData.wired && root.wifiActive && root.wifiActive.name === conn.modelData.name ? root.wifiActive : null
                            icon: conn.modelData.wired ? "󰈀" : root.wifiIcon(net ? net.signalStrength : 1)
                            label: conn.modelData.name
                            detail: (net && net.security !== WifiSecurityType.Open ? "󰌾 " : "") + (net ? root.pct(net.signalStrength) + "%" : conn.modelData.wired ? "wired" : "")
                                + "  " + (conn.editing ? "󰅀" : "󰅂")
                            active: true
                            accent: root.connectedColor
                            onPicked: root.editToggle(conn.modelData.name)
                        }

                        // Filled in when nmcli answers; Auto shows what DHCP gave
                        Connections {
                            target: root
                            function onEditChanged() {
                                conn.problem = "";
                                if (!conn.editing || root.edit.method === undefined)
                                    return;
                                conn.manual = root.edit.method === "manual";
                                addr.text = root.edit.addresses || "";
                                gw.text = root.edit.gateway || "";
                                dns.text = root.edit.dns || "";
                            }
                        }

                        Column {
                            visible: conn.editing && root.edit.method !== undefined
                            width: parent.width
                            spacing: 6

                            Text {
                                text: "IPV4"
                                color: Colors.textDim
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 11
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }

                            Row {
                                spacing: 6
                                Repeater {
                                    model: [["Auto (DHCP)", false], ["Manual", true]]
                                    Rectangle {
                                        required property var modelData
                                        readonly property bool on: conn.manual === modelData[1]
                                        width: 120
                                        height: 30
                                        color: on ? Colors.secondaryContainer : "transparent"
                                        border.color: on ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData[0]
                                            color: parent.on ? Colors.primary : Colors.textDim
                                            font.family: "Hack Nerd Font"
                                            font.pixelSize: 13
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: conn.manual = modelData[1]
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: !conn.manual
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: "Now " + (root.edit.nowAddress || "—") + (root.edit.nowGateway ? " via " + root.edit.nowGateway : "")
                                color: Colors.textDim
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 12
                            }

                            NetField { id: addr; visible: conn.manual; label: "Address"; hint: "with prefix, e.g. 192.168.1.50/24" }
                            NetField { id: gw; visible: conn.manual; label: "Gateway"; hint: "e.g. 192.168.1.1" }
                            Text {
                                visible: conn.problem !== ""
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: conn.problem
                                color: "#f7768e"
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 12
                            }

                            NetField { id: dns; label: "DNS"; hint: "empty: automatic" + (root.edit.nowDns ? " (now " + root.edit.nowDns + ")" : "") + ", or e.g. 1.1.1.1, 9.9.9.9" }

                            Row {
                                spacing: 6
                                Repeater {
                                    model: ["Apply", "Cancel", "Disconnect"]
                                    Rectangle {
                                        required property string modelData
                                        readonly property bool primary: modelData === "Apply"
                                        width: 90
                                        height: 30
                                        color: primary ? Colors.primary : "transparent"
                                        border.color: primary ? Colors.primary : Colors.outlineVariant
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.modelData
                                            color: parent.primary ? Colors.surface : Colors.textDim
                                            font.family: "Hack Nerd Font"
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (parent.modelData === "Disconnect") {
                                                    root.editName = "";
                                                    disconnectCmd.command = ["nmcli", "connection", "down", "id", conn.modelData.name];
                                                    disconnectCmd.running = true;
                                                    return;
                                                }
                                                if (!parent.primary) {
                                                    root.editToggle(conn.modelData.name);
                                                    return;
                                                }
                                                conn.problem = root.editProblem(conn.manual, addr.text.trim(), gw.text.trim(), dns.text.trim());
                                                if (conn.problem === "")
                                                    root.editApply(conn.modelData.name, conn.manual, addr.text.trim(), gw.text.trim(), dns.text.trim());
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    visible: root.conns.length > 0
                    width: 1
                    height: 8
                }

                SectionHead {
                    visible: root.vpns.length > 0
                    label: "VPN"
                    value: ""
                }

                Repeater {
                    model: root.vpns

                    DevRow {
                        required property var modelData
                        icon: "󰖂"
                        label: modelData.name
                        detail: modelData.active ? "on" : ""
                        active: modelData.active
                        accent: root.connectedColor
                        onPicked: root.vpnToggle(modelData)
                    }
                }

                Item {
                    visible: root.vpns.length > 0 && Networking.wifiEnabled && root.wifiDev !== null
                    width: 1
                    height: 8
                }

                SectionHead {
                    visible: Networking.wifiEnabled && root.wifiDev !== null
                    label: "NETWORKS"
                    value: root.wifiNets.length > 0 ? "" : "scanning…"
                }

                Repeater {
                    model: Networking.wifiEnabled ? root.wifiNets.filter(n => !n.connected) : []

                    Column {
                        id: netRow
                        required property var modelData
                        width: netList.width
                        spacing: 4

                        DevRow {
                            icon: root.wifiIcon(netRow.modelData.signalStrength)
                            label: netRow.modelData.name + (netRow.modelData.stateChanging ? "  …" : "")
                            detail: (netRow.modelData.security !== WifiSecurityType.Open ? "󰌾 " : "") + root.pct(netRow.modelData.signalStrength) + "%"
                            active: netRow.modelData.connected
                            accent: root.connectedColor
                            onPicked: {
                                const n = netRow.modelData;
                                if (n.connected)
                                    n.disconnect();
                                else if (n.known || n.security === WifiSecurityType.Open)
                                    n.connect();
                                else
                                    root.pskFor = root.pskFor === n.name ? "" : n.name;
                            }
                        }

                        Rectangle {
                            visible: root.pskFor === netRow.modelData.name
                            width: parent.width
                            height: 34
                            radius: 0
                            color: Colors.surfaceContainerHigh
                            border.color: Colors.primary
                            border.width: 1

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                visible: psk.text === ""
                                text: "Password"
                                color: Colors.textDim
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 14
                            }

                            TextInput {
                                id: psk
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Colors.text
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 14
                                focus: parent.visible
                                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                                onAccepted: {
                                    netRow.modelData.connectWithPsk(text);
                                    text = "";
                                    root.pskFor = "";
                                }
                                Keys.onEscapePressed: root.pskFor = ""
                            }
                        }
                    }
                }
            }
        }

        // Everything else (static IP, DNS, VLAN, bridges) in NetworkManager's editor
        DevRow {
            id: more
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 16
            icon: "\uf013"
            label: "More settings…"
            onPicked: {
                root.closeRequested();
                Quickshell.execDetached(["nm-connection-editor"]);
            }
        }
    }
}
