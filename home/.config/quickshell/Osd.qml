import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects

// Volume and brightness popup on the focused output.
Scope {
    id: root

    property bool shown: false
    property bool ready: false
    property string icon: ""
    property int pct: 0
    ScreenTarget { id: target }
    readonly property var screen: target.screen
    onScreenChanged: if (!screen) shown = false

    function show(icon, pct) {
        if (!ready || !target.select())
            return;
        root.icon = icon;
        root.pct = pct;
        shown = true;
        hideTimer.restart();
    }

    function volume(pct, muted) {
        if (muted)
            show("󰝟", 0);
        else
            show(pct < 34 ? "󰕿" : (pct < 67 ? "󰖀" : "󰕾"), pct);
    }

    function brightness(pct) {
        show(pct < 34 ? "󰃞" : (pct < 67 ? "󰃟" : "󰃠"), pct);
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: root.shown = false
    }

    // Startup sets volume and brightness; stay quiet until it has settled.
    Timer {
        interval: 3000
        running: true
        onTriggered: root.ready = true
    }

    PanelWindow {
        visible: root.screen !== null && (root.shown || osdCard.opacity > 0)
        screen: root.screen
        implicitWidth: 320 + 48
        implicitHeight: 56 + 48
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        mask: Region {}

        anchors {
            bottom: true
        }
        margins {
            bottom: 56
        }

        RectangularShadow {
            anchors.fill: osdCard
            opacity: osdCard.opacity
            scale: osdCard.scale
            offset: Qt.vector2d(0, 8)
            radius: osdCard.radius
            blur: 32
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        PanelBackground {
            id: osdCard
            anchors.margins: 24
            opacity: root.shown ? 1 : 0
            scale: root.shown ? 1 : 0.94
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }

            Rectangle {
                id: osdChip
                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 38
                height: 38
                radius: 0
                color: Colors.secondaryContainer

                Text {
                    anchors.centerIn: parent
                    text: root.icon
                    color: Colors.primary
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 18
                }
            }

            Text {
                id: osdPctText
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                horizontalAlignment: Text.AlignRight
                text: root.pct
                color: Colors.text
                font.family: "Noto Serif"
                font.pixelSize: 17
            }

            Rectangle {
                anchors.left: osdChip.right
                anchors.leftMargin: 14
                anchors.right: osdPctText.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 6
                radius: 0
                color: Qt.alpha(Colors.outlineVariant, 0.7)

                Rectangle {
                    width: parent.width * Math.min(1, root.pct / 100)
                    height: parent.height
                    radius: 0
                    color: Colors.primary
                    Behavior on width {
                        SmoothedAnimation {
                            duration: 140
                            velocity: -1
                        }
                    }
                }
            }
        }
    }
}
