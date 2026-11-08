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
    onOpenChanged: {
        pskFor = "";
        if (open)
            vpnList.running = true;
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
                const out = [];
                for (const line of text.split("\n")) {
                    const f = line.split(":");
                    if (f.length >= 3 && (f[0] === "wireguard" || f[0] === "vpn"))
                        out.push({ name: f.slice(2).join(":"), active: f[1] === "yes" });
                }
                root.vpns = out.sort((a, b) => a.name.localeCompare(b.name));
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
        implicitHeight: netHead.implicitHeight + Math.min(420, netList.implicitHeight) + 32 + 12
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

        Binding {
            target: root.wifiDev
            property: "scannerEnabled"
            value: root.open
            when: root.wifiDev !== null
        }

        PanelBackground {}

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
            anchors.bottom: parent.bottom
            anchors.topMargin: 12
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 16
            contentHeight: netList.implicitHeight
            clip: true

            Column {
                id: netList
                width: parent.width
                spacing: 2

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
                    visible: root.vpns.length > 0 && Networking.wifiEnabled
                    width: 1
                    height: 8
                }

                SectionHead {
                    visible: Networking.wifiEnabled
                    label: "NETWORKS"
                    value: root.wifiNets.length > 0 ? "" : "scanning…"
                }

                Repeater {
                    model: Networking.wifiEnabled ? root.wifiNets : []

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
    }
}
