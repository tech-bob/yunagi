import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes

Scope {
    id: root

    property var screen: null
    property point position

    IpcHandler {
        target: "cursorlocator"

        function tap(x: int, y: int): void {
            if (!doubleTap.running) {
                doubleTap.start();
                return;
            }
            doubleTap.stop();

            const screen = Quickshell.screens.find(s => x >= s.x && x < s.x + s.width
                && y >= s.y && y < s.y + s.height);
            if (!screen)
                return;

            root.screen = screen;
            root.position = Qt.point(x - screen.x, y - screen.y);
            flash.restart();
        }
    }

    Timer {
        id: doubleTap
        interval: 360
    }

    PanelWindow {
        id: overlay
        screen: root.screen
        visible: flash.running && root.screen !== null
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "cursor-locator"
        mask: Region {}

        Shape {
            id: marker
            width: 40
            height: 56
            x: root.position.x - 2
            y: root.position.y - 2
            preferredRendererType: Shape.CurveRenderer

            transform: Scale {
                origin.x: 2
                origin.y: 2
                xScale: marker.x + marker.width > overlay.width ? -1 : 1
                yScale: marker.y + marker.height > overlay.height ? -1 : 1
            }

            ShapePath {
                fillColor: "#ffffff"
                strokeColor: "#24272b"
                strokeWidth: 2
                joinStyle: ShapePath.RoundJoin
                startX: 2
                startY: 2
                PathLine { x: 2; y: 45 }
                PathLine { x: 13; y: 34 }
                PathLine { x: 22; y: 53 }
                PathLine { x: 29; y: 50 }
                PathLine { x: 21; y: 31 }
                PathLine { x: 37; y: 31 }
                PathLine { x: 2; y: 2 }
            }

            SequentialAnimation {
                id: flash
                PropertyAction { target: marker; property: "opacity"; value: 1 }
                PauseAnimation { duration: 220 }
                NumberAnimation { target: marker; property: "opacity"; to: 0; duration: 300; easing.type: Easing.InQuad }
            }
        }
    }
}
