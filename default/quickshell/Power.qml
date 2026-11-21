import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    property bool open: false
    ScreenTarget { id: popupTarget }
    readonly property var screen: popupTarget.screen
    property int sel: 0

    readonly property var actions: [
        { icon: "\uf023", label: "Lock", cmd: ["hyprlock"] },
        { icon: "\udb80\udf43", label: "Log out", cmd: ["sh", "-c", "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"] },
        { icon: "\udb81\udc53", label: "Restart", cmd: ["systemctl", "reboot"] },
        { icon: "\uf011", label: "Shut down", cmd: ["systemctl", "poweroff"] }
    ]

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        if (!popupTarget.select())
            return;
        sel = 0;
        open = true;
    }

    function run(i) {
        open = false;
        Quickshell.execDetached(actions[i].cmd);
    }

    IpcHandler {
        target: "power"
        function toggle(): void {
            root.toggle();
        }
    }

    PanelWindow {
        visible: root.screen !== null && (root.open || box.opacity > 0)
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "power"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: root.open = false
        }

        RectangularShadow {
            anchors.fill: box
            opacity: box.opacity
            scale: box.scale
            offset: Qt.vector2d(0, 12)
            radius: box.radius
            blur: 48
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Rectangle {
            id: box
            width: row.implicitWidth + 56
            height: row.implicitHeight + 56
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            radius: 24
            border.color: Colors.outlineVariant
            border.width: 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0.95) }
                GradientStop { position: 1; color: Qt.alpha(Colors.surfaceContainerHigh, 0.95) }
            }
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
            focus: root.open
            Behavior on opacity {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape)
                    root.open = false;
                else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                    root.sel = (root.sel + 1) % root.actions.length;
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                    root.sel = (root.sel + root.actions.length - 1) % root.actions.length;
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.run(root.sel);
                else
                    return;
                event.accepted = true;
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Row {
                id: row
                anchors.centerIn: parent
                spacing: 20

                Repeater {
                    model: root.actions

                    Column {
                        id: item
                        required property var modelData
                        required property int index
                        readonly property bool current: root.sel === index
                        spacing: 10

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 72
                            height: 72
                            radius: 36
                            color: item.current ? Colors.secondaryContainer : Qt.alpha(Colors.surfaceContainerHighest, 0.6)
                            border.color: item.current ? Colors.primary : Colors.outlineVariant
                            border.width: 1
                            scale: item.current ? 1.06 : 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: item.modelData.icon
                                color: item.current ? Colors.primary : Colors.text
                                font.family: "Hack Nerd Font"
                                font.pixelSize: 28
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
                                    if (last.x >= 0 && (p.x !== last.x || p.y !== last.y)) root.sel = item.index;
                                    last = p;
                                }
                                onClicked: root.run(item.index)
                            }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: item.modelData.label
                            color: item.current ? Colors.text : Colors.textDim
                            font.family: "Noto Serif"
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
