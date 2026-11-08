import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick

// Default sink and source, device lists and the audio panel.
Scope {
    id: root

    property bool open: false
    property var screen: null
    signal adjusted()

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property int volPct: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0
    readonly property bool volMuted: sink && sink.audio ? sink.audio.muted : false
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var mic: Pipewire.defaultAudioSource
    readonly property int micPct: mic && mic.audio ? Math.round(mic.audio.volume * 100) : 0
    readonly property bool micMuted: mic && mic.audio ? mic.audio.muted : false
    readonly property var mics: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && n.name.indexOf(".monitor") < 0)

    function setMic(v) {
        if (mic && mic.audio)
            mic.audio.volume = Math.max(0, Math.min(1, v));
    }
    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function devIcon(n) {
        const d = ((n.description || "") + " " + n.name).toLowerCase();
        if (/hdmi|displayport|monitor/.test(d))
            return "󰍹";
        if (/headset|headphone|cloud|usb|bluez/.test(d))
            return "󰋋";
        return "󰓃";
    }

    function setVol(v) {
        if (sink && sink.audio)
            sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    Connections {
        target: root.sink ? root.sink.audio : null
        function onVolumeChanged() {
            root.adjusted();
        }
        function onMutedChanged() {
            root.adjusted();
        }
    }

    PwObjectTracker {
        objects: root.sinks.concat(root.mics)
    }

    PanelWindow {
        id: volPanel
        visible: root.open
        implicitWidth: 380
        implicitHeight: volCol.implicitHeight + 32
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

        PwNodePeakMonitor {
            id: micPeak
            node: root.mic
            enabled: root.open
        }

        Column {
            id: volCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 16
            spacing: 12

            // Header: icon, title, mood, mute switch
            Item {
                width: parent.width
                height: 40

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.volMuted ? "󰝟" : "󰕾"
                        color: Colors.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 24
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: "Audio"
                            color: Colors.text
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 17
                            font.weight: Font.Bold
                        }

                        Text {
                            text: root.volMuted ? "SILENCE"
                                : root.volPct <= 25 ? "QUIET HOURS"
                                : root.volPct <= 55 ? "EASY LISTENING"
                                : root.volPct <= 85 ? "TURNED UP"
                                : "FULL BLAST"
                            color: Colors.primary
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 11
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 24
                    radius: 0
                    color: root.volMuted ? Colors.surfaceContainerHighest : Colors.primary

                    Rectangle {
                        x: root.volMuted ? 3 : parent.width - width - 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        radius: 0
                        color: root.volMuted ? Colors.textDim : Colors.surface
                        Behavior on x { NumberAnimation { duration: 120 } }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleMute()
                    }
                }
            }

            Divider {}

            SectionHead {
                label: "OUTPUT"
                value: root.volMuted ? "MUTED" : root.volPct + "%"
            }

            VolSlider {
                value: root.volPct / 100
                muted: root.volMuted
                onMoved: v => root.setVol(v)
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.sinks

                    DevRow {
                        required property var modelData
                        icon: root.devIcon(modelData)
                        label: modelData.nickname || modelData.description || modelData.name
                        active: root.sink === modelData
                        onPicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            Divider {}

            SectionHead {
                label: "INPUT"
                value: root.micMuted ? "MUTED" : root.micPct + "%"
            }

            VolSlider {
                value: root.micPct / 100
                muted: root.micMuted
                onMoved: v => root.setMic(v)
            }

            // Live mic level
            Rectangle {
                width: parent.width
                height: 4
                radius: 0
                color: Colors.outlineVariant

                Rectangle {
                    width: parent.width * Math.min(1, root.micMuted ? 0 : micPeak.peak)
                    height: parent.height
                    radius: 0
                    color: Colors.primary
                    Behavior on width { NumberAnimation { duration: 60 } }
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.mics

                    DevRow {
                        required property var modelData
                        icon: "󰍬"
                        label: modelData.nickname || modelData.description || modelData.name
                        active: root.mic === modelData
                        onPicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }
        }
    }
}
