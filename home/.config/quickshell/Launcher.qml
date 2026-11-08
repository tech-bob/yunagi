import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    property bool open: false
    ScreenTarget { id: popupTarget }
    readonly property var screen: popupTarget.screen
    property string query: ""

    readonly property var apps: {
        const q = query.trim().toLowerCase();
        const all = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        if (q === "")
            return all.slice().sort((a, b) => a.name.localeCompare(b.name));
        const score = a => {
            const n = a.name.toLowerCase();
            if (n.startsWith(q))
                return 0;
            if (n.includes(q))
                return 1;
            const extra = [a.genericName, a.comment].concat(a.keywords).join(" ").toLowerCase();
            return extra.includes(q) ? 2 : -1;
        };
        return all.map(a => ({ a: a, s: score(a) }))
            .filter(x => x.s >= 0)
            .sort((x, y) => x.s - y.s || x.a.name.localeCompare(y.a.name))
            .map(x => x.a);
    }

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        if (!popupTarget.select())
            return;
        query = "";
        open = true;
    }

    function launch(app) {
        if (!app)
            return;
        open = false;
        app.execute();
    }

    IpcHandler {
        target: "launcher"
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
        WlrLayershell.namespace: "launcher"

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
            readonly property int cols: 4
            readonly property int tile: 132
            width: cols * tile + (cols - 1) * 10 + 40
            height: 92 + Math.min(2, Math.ceil(grid.count / cols)) * (tile + 10)
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
                    anchors.right: glyph.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Search"
                    color: Colors.textDim
                    font.family: "Noto Serif"
                    font.pixelSize: 20
                }

                Text {
                    id: glyph
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
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
                        grid.currentIndex = 0;
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
                            root.launch(root.apps[grid.currentIndex]);
                        else if (event.key === Qt.Key_Right || event.key === Qt.Key_Tab)
                            grid.moveCurrentIndexRight();
                        else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab)
                            grid.moveCurrentIndexLeft();
                        else if (event.key === Qt.Key_Down)
                            grid.moveCurrentIndexDown();
                        else if (event.key === Qt.Key_Up)
                            grid.moveCurrentIndexUp();
                        else
                            return;
                        event.accepted = true;
                    }
                }
            }

            GridView {
                id: grid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: field.bottom
                anchors.bottom: parent.bottom
                anchors.margins: 20
                anchors.topMargin: 10
                anchors.rightMargin: 10
                cellWidth: box.tile + 10
                cellHeight: box.tile + 10
                clip: true
                model: root.apps
                highlightMoveDuration: 0
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool current: GridView.isCurrentItem
                    width: box.tile
                    height: box.tile
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

                    IconImage {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 14
                        implicitSize: 34
                        source: Quickshell.iconPath(modelData.icon, "application-x-executable")
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        text: modelData.name
                        elide: Text.ElideRight
                        color: Colors.text
                        font.family: "Noto Serif"
                        font.pixelSize: 15
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.launch(modelData)
                    }
                }
            }
        }
    }
}
