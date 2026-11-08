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
    property string query: ""
    property var entries: []

    readonly property var shown: {
        const q = query.trim().toLowerCase();
        return q === "" ? entries : entries.filter(e => e.text.toLowerCase().includes(q));
    }

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        if (!popupTarget.select())
            return;
        query = "";
        list.currentIndex = 0;
        load.running = true;
        open = true;
    }

    function pick(e) {
        if (!e)
            return;
        open = false;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "sh", e.line]);
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void {
            root.toggle();
        }
    }

    Process {
        id: load
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l !== "").map(l => {
                    const tab = l.indexOf("\t");
                    const t = l.slice(tab + 1);
                    return { line: l, text: t, image: t.startsWith("[[ binary data") };
                });
            }
        }
    }

    PanelWindow {
        visible: root.screen !== null && (root.open || box.opacity > 0)
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "clipboard"

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
            width: 640
            height: 92 + Math.max(1, Math.min(8, list.count)) * 48
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            radius: 16
            border.color: Colors.outlineVariant
            border.width: 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0.92) }
                GradientStop { position: 0.75; color: Qt.alpha(Colors.surfaceContainer, 0.92) }
                GradientStop { position: 1; color: Qt.alpha(Colors.surfaceContainerHigh, 0.92) }
            }
            opacity: root.open ? 1 : 0
            scale: root.open ? 1 : 0.96
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
            Behavior on height {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
            }

            Item {
                id: field
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 20
                height: 42

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Clipboard"
                    color: Colors.textDim
                    font.family: "Noto Serif"
                    font.pixelSize: 20
                }

                Text {
                    id: glyph
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Colors.primary
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 18
                }

                TextInput {
                    id: input
                    anchors.left: parent.left
                    anchors.right: glyph.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.query
                    onTextEdited: {
                        root.query = text;
                        list.currentIndex = 0;
                    }
                    color: Colors.text
                    selectionColor: Colors.secondaryContainer
                    font.family: "Noto Serif"
                    font.pixelSize: 20
                    focus: root.open
                    clip: true

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape)
                            root.open = false;
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                            root.pick(root.shown[list.currentIndex]);
                        else if (event.key === Qt.Key_Down || event.key === Qt.Key_Tab)
                            list.incrementCurrentIndex();
                        else if (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab)
                            list.decrementCurrentIndex();
                        else
                            return;
                        event.accepted = true;
                    }
                }
            }

            Text {
                anchors.centerIn: list
                visible: list.count === 0
                text: root.entries.length === 0 ? "History is empty" : "No matches"
                color: Colors.textDim
                font.family: "Noto Serif"
                font.pixelSize: 15
            }

            ListView {
                id: list
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: field.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 20
                anchors.topMargin: 10
                spacing: 6
                clip: true
                model: root.shown
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    readonly property bool current: ListView.isCurrentItem
                    width: list.width
                    height: 42
                    radius: 12
                    color: current ? Colors.secondaryContainer : (hover.hovered ? Colors.surfaceContainerHighest : Qt.alpha(Colors.surfaceContainerHigh, 0.7))
                    border.color: current ? Colors.primary : Colors.outlineVariant
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    HoverHandler {
                        id: hover
                    }

                    Text {
                        id: kind
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        text: entry.modelData.image ? "\uf03e" : "\uf0c5"
                        color: Colors.primary
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.left: kind.right
                        anchors.right: parent.right
                        anchors.leftMargin: 10
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        text: entry.modelData.text.replace(/\s+/g, " ")
                        elide: Text.ElideRight
                        color: Colors.text
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.pick(entry.modelData)
                    }
                }
            }
        }
    }
}
