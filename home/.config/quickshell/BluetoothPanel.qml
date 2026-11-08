import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Bluetooth adapter, paired and nearby devices.
Scope {
    id: root

    property bool open: false
    property var screen: null
    property bool available: false

    function btIcon(d) {
        const i = d.icon || "";
        if (/headset|headphone|audio-card/.test(i)) return "󰋋";
        if (/mouse/.test(i)) return "󰍽";
        if (/keyboard/.test(i)) return "󰌌";
        if (/phone/.test(i)) return "󰏲";
        if (/computer/.test(i)) return "󰌢";
        if (/gaming|joystick/.test(i)) return "󰊴";
        return "󰂯";
    }

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/bluetooth 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.available = text.trim() !== ""
        }
    }

    PanelWindow {
        id: btPanel
        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool btOn: adapter ? adapter.enabled : false
        readonly property var devs: adapter ? adapter.devices.values : []
        visible: root.open
        implicitWidth: 380
        implicitHeight: btCol.implicitHeight + 32
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
            target: btPanel.adapter
            property: "discovering"
            value: root.open && btPanel.btOn
            when: btPanel.adapter !== null
        }

        PanelBackground {}

        Column {
            id: btCol
            readonly property var paired: btPanel.devs.filter(d => d.paired || d.connected)
            readonly property var nearby: btPanel.devs.filter(d => !d.paired && !d.connected && d.name)
            readonly property int nConn: btPanel.devs.filter(d => d.connected).length
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            PanelHeader {
                icon: btPanel.btOn ? "󰂯" : "󰂲"
                title: "Bluetooth"
                mood: !btPanel.btOn ? "RADIO SILENCE"
                    : btCol.nConn > 0 ? (btCol.nConn === 1 ? "1 DEVICE LINKED" : btCol.nConn + " DEVICES LINKED")
                    : "LOOKING AROUND"
                on: btPanel.btOn
                onToggled: {
                    if (btPanel.adapter)
                        btPanel.adapter.enabled = !btPanel.adapter.enabled;
                    else
                        Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
                }
            }

            Divider { visible: btPanel.btOn }

            SectionHead {
                visible: btPanel.btOn && btCol.paired.length > 0
                label: "PAIRED"
                value: ""
            }

            Column {
                visible: btPanel.btOn
                width: parent.width
                spacing: 2

                Repeater {
                    model: btCol.paired

                    DevRow {
                        required property var modelData
                        icon: root.btIcon(modelData)
                        label: modelData.name || modelData.address
                        detail: modelData.state === BluetoothDeviceState.Connecting ? "…"
                            : modelData.connected && modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%"
                            : modelData.connected ? "connected" : ""
                        active: modelData.connected
                        onPicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                    }
                }
            }

            SectionHead {
                visible: btPanel.btOn
                label: "NEARBY"
                value: btCol.nearby.length > 0 ? "" : "scanning…"
            }

            Flickable {
                visible: btPanel.btOn && btCol.nearby.length > 0
                width: parent.width
                height: Math.min(nearCol.implicitHeight, 36 * 6)
                contentHeight: nearCol.implicitHeight
                clip: true

                Column {
                    id: nearCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: btCol.nearby

                        DevRow {
                            required property var modelData
                            icon: root.btIcon(modelData)
                            label: modelData.name
                            detail: modelData.pairing ? "pairing…" : ""
                            onPicked: {
                                modelData.trusted = true;
                                modelData.pair();
                            }
                        }
                    }
                }
            }
        }
    }
}
