import Quickshell
import Quickshell.Services.UPower
import Quickshell.Wayland
import QtQuick

// Battery state and power profiles.
Scope {
    id: root

    property bool open: false
    property var screen: null

    readonly property bool hasBat: UPower.displayDevice.isLaptopBattery && UPower.displayDevice.isPresent
    readonly property int batPct: {
        const p = UPower.displayDevice.percentage;
        return Math.round(p <= 1 ? p * 100 : p);
    }
    readonly property bool batCharging: UPower.displayDevice.state === UPowerDeviceState.Charging
    readonly property bool batFull: UPower.displayDevice.state === UPowerDeviceState.FullyCharged || root.batPct >= 99

    PanelWindow {
        id: batPanel
        visible: root.open
        implicitWidth: 360
        implicitHeight: batCol.implicitHeight + 24
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
            id: batCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "battery  ·  " + root.batPct + "%" + (root.batCharging ? "  ·  charging" : "")
                color: Colors.primary
                font.family: "Hack Nerd Font"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                text: "POWER PROFILE"
                color: Colors.tertiary
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Repeater {
                model: [
                    { label: "power-saver", value: PowerProfile.PowerSaver },
                    { label: "balanced", value: PowerProfile.Balanced },
                    { label: "performance", value: PowerProfile.Performance }
                ]

                Rectangle {
                    required property var modelData
                    width: parent.width
                    height: 34
                    color: PowerProfiles.profile === modelData.value ? Colors.secondaryContainer : "transparent"
                    border.color: PowerProfiles.profile === modelData.value ? Colors.primary : Colors.outlineVariant
                    radius: 0
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: PowerProfiles.profile === modelData.value ? Colors.primary : Colors.textDim
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PowerProfiles.profile = modelData.value
                    }
                }
            }
        }
    }
}
