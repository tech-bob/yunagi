import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

// Bluetooth adapter, paired and nearby devices.
Scope {
    id: root

    property bool open: false
    property var screen: null
    property bool available: false
    // Address of the paired device whose action rows are shown (right click)
    property string menuFor: ""
    onOpenChanged: menuFor = ""

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

    // USB-dongle headsets (HeadsetControl); polled while the panel is open
    property var headsets: []

    Process {
        id: hsProc
        command: ["headsetcontrol", "-b", "-o", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.headsets = JSON.parse(text).devices.filter(d => d.battery && (d.battery.status === "BATTERY_AVAILABLE" || d.battery.status === "BATTERY_CHARGING"));
                } catch (e) {
                    root.headsets = [];
                }
            }
        }
    }

    Timer {
        interval: 60000
        running: root.open
        repeat: true
        triggeredOnStart: true
        onTriggered: hsProc.running = true
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
            // Wireless mice/keyboards on a USB receiver (UPower, e.g. Logitech HID++)
            readonly property var receiver: UPower.devices.values.filter(d => (d.type === UPowerDeviceType.Mouse || d.type === UPowerDeviceType.Keyboard) && d.isPresent && !d.nativePath.startsWith("/org/bluez"))
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

                    Column {
                        id: pRow
                        required property var modelData
                        readonly property bool menu: root.menuFor === modelData.address
                        width: parent.width
                        spacing: 2

                        DevRow {
                            icon: root.btIcon(pRow.modelData)
                            label: pRow.modelData.name || pRow.modelData.address
                            detail: pRow.modelData.state === BluetoothDeviceState.Connecting ? "…"
                                : pRow.modelData.connected && pRow.modelData.batteryAvailable ? Math.round(pRow.modelData.battery * 100) + "%"
                                : pRow.modelData.connected ? "connected" : ""
                            active: pRow.modelData.connected
                            onPicked: pRow.modelData.connected ? pRow.modelData.disconnect() : pRow.modelData.connect()
                            onRightPicked: root.menuFor = pRow.menu ? "" : pRow.modelData.address
                        }

                        Row {
                            visible: pRow.menu
                            width: parent.width
                            spacing: 6

                            DevRow {
                                width: (parent.width - 6) / 2
                                icon: pRow.modelData.connected ? "󰂲" : "󰂱"
                                label: pRow.modelData.connected ? "Disconnect" : "Connect"
                                accent: Colors.primary
                                active: true
                                onPicked: {
                                    pRow.modelData.connected ? pRow.modelData.disconnect() : pRow.modelData.connect();
                                    root.menuFor = "";
                                }
                            }

                            DevRow {
                                width: (parent.width - 6) / 2
                                icon: "󰆴"
                                label: "Forget"
                                accent: "#f7768e"
                                active: true
                                onPicked: {
                                    root.menuFor = "";
                                    pRow.modelData.forget();
                                }
                            }
                        }
                    }
                }
            }

            SectionHead {
                visible: btCol.receiver.length + root.headsets.length > 0
                label: "RECEIVER"
                value: ""
            }

            Column {
                visible: btCol.receiver.length + root.headsets.length > 0
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.headsets

                    DevRow {
                        required property var modelData
                        icon: "󰋋"
                        label: modelData.product
                        detail: modelData.battery.status === "BATTERY_CHARGING" ? "charging" : modelData.battery.level + "%"
                        active: true
                    }
                }

                Repeater {
                    model: btCol.receiver

                    DevRow {
                        required property var modelData
                        icon: modelData.type === UPowerDeviceType.Mouse ? "󰍽" : "󰌌"
                        label: modelData.model || "Receiver device"
                        detail: Math.round(modelData.percentage <= 1 ? modelData.percentage * 100 : modelData.percentage) + "%"
                        active: true
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
