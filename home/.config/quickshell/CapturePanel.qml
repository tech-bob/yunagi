import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Screenshots and screen recording: the capture panel and the recording picker.
Scope {
    id: root

    property bool captureOpen: false
    property bool recordOpen: false
    property var screen: null
    signal closeRequested()
    onRecordOpenChanged: if (recordOpen) recPickSel = 0

    property bool recording: false
    property int recSecs: 0
    property string recAudio: "none"
    property int recPickSel: 0
    readonly property var recPicks: [
        { label: "With no audio", audio: "none" },
        { label: "With desktop audio", audio: "desktop" },
        { label: "With desktop + microphone audio", audio: "mic" }
    ]

    function recPick(i) {
        recAudio = recPicks[i].audio;
        recStart(false);
    }

    function started() {
        recSecs = 0;
        recording = true;
    }

    function stop() {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/yunagi-screenrecord", "--stop"]);
    }

    function capRun(args) {
        closeRequested();
        Quickshell.execDetached(args);
    }

    function recStart(region) {
        const a = [Quickshell.env("HOME") + "/.local/bin/yunagi-screenrecord"];
        if (region)
            a.push("--region");
        if (root.recAudio !== "none")
            a.push("--desktop");
        if (root.recAudio === "mic")
            a.push("--mic");
        root.capRun(a);
    }

    // Startup check only; yunagi-screenrecord reports start and stop over IPC.
    Process {
        running: true
        command: ["pgrep", "-f", "^gpu-screen-recorder"]
        onExited: code => root.recording = code === 0
    }

    Timer {
        interval: 1000
        running: root.recording
        repeat: true
        onTriggered: root.recSecs++
    }

    // Screen recording picker (Omarchy style)
    PanelWindow {
        visible: root.recordOpen
        implicitWidth: 420
        implicitHeight: recCol.implicitHeight + 28
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        screen: root.screen

        Rectangle {
            anchors.fill: parent
            border.color: Colors.text
            border.width: 2
            color: Qt.alpha(Colors.surface, 0.96)
        }

        Column {
            id: recCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 4
            focus: root.recordOpen
            Keys.onUpPressed: root.recPickSel = (root.recPickSel + root.recPicks.length - 1) % root.recPicks.length
            Keys.onDownPressed: root.recPickSel = (root.recPickSel + 1) % root.recPicks.length
            Keys.onReturnPressed: root.recPick(root.recPickSel)
            Keys.onEnterPressed: root.recPick(root.recPickSel)
            Keys.onEscapePressed: root.closeRequested()

            Text {
                text: "Screenrecord…"
                color: Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 14
                bottomPadding: 6
            }

            Repeater {
                model: root.recPicks

                Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool sel: root.recPickSel === index
                    width: recCol.width
                    height: 34
                    color: sel ? Colors.surfaceContainerHighest : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        text: "󰕧  " + parent.modelData.label
                        color: parent.sel ? Colors.primary : Colors.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        // Select only on real pointer movement, not when the menu appears under a still pointer
                        property point last: Qt.point(-1, -1)
                        onExited: last = Qt.point(-1, -1)
                        onPositionChanged: mouse => {
                            const p = mapToGlobal(mouse.x, mouse.y);
                            if (last.x >= 0 && (p.x !== last.x || p.y !== last.y)) root.recPickSel = parent.index;
                            last = p;
                        }
                        onClicked: root.recPick(parent.index)
                    }
                }
            }
        }
    }

    PanelWindow {
        visible: root.captureOpen
        implicitWidth: 380
        implicitHeight: capCol.implicitHeight + 20
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: true
        WlrLayershell.layer: WlrLayer.Overlay
        screen: root.screen

        anchors {
            top: true
        }
        margins {
            top: 54
        }

        PanelBackground {}

        Column {
            id: capCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "capture"
                color: Colors.primary
                font.family: "Hack Nerd Font"
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                text: "SCREENSHOT"
                color: Colors.tertiary
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Row {
                width: parent.width
                spacing: 6

                CapButton {
                    width: (parent.width - 6) / 2
                    label: "󰍹  screen"
                    onClicked: root.capRun(["sh", "-c", "sleep 0.3; $HOME/.local/bin/yunagi-screenshot output"])
                }
                CapButton {
                    width: (parent.width - 6) / 2
                    label: "󰩭  region"
                    onClicked: root.capRun([Quickshell.env("HOME") + "/.local/bin/yunagi-screenshot", "region"])
                }
            }

            Text {
                text: "RECORD"
                color: Colors.tertiary
                font.family: "Hack Nerd Font"
                font.pixelSize: 13
                font.weight: Font.Bold
            }

            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: [
                        { label: "󰝟  none", value: "none" },
                        { label: "󰕾  audio", value: "desktop" },
                        { label: "󰍬  audio+mic", value: "mic" }
                    ]

                    CapButton {
                        required property var modelData
                        width: (parent.width - 12) / 3
                        label: modelData.label
                        on: root.recAudio === modelData.value
                        onClicked: root.recAudio = modelData.value
                    }
                }
            }

            Row {
                width: parent.width
                spacing: 6

                CapButton {
                    width: (parent.width - 6) / 2
                    label: "󰻂  screen"
                    onClicked: root.recStart(false)
                }
                CapButton {
                    width: (parent.width - 6) / 2
                    label: "󰻂  region"
                    onClicked: root.recStart(true)
                }
            }
        }
    }
}
