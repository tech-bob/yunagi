import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Scope {
    id: root

    ScreenTarget { id: target }

    property var monitors: []
    property var clients: []
    property bool open: false
    property bool loading: false
    property string selectedWorkspace: ""
    readonly property var screen: target.screen
    readonly property var output: monitors.find(m => m.name === screen?.name) || monitors[0]
    onScreenChanged: open = false

    // Menu size, set in the settings menu (Settings → Menu size)
    readonly property real size: Number(sizeFile.text().trim()) || 1

    FileView {
        id: sizeFile
        path: Quickshell.env("HOME") + "/.local/state/yunagi/menu-size"
        watchChanges: true
        onFileChanged: reload()
    }

    // Workspaces in use: those with windows, and the active one. The key is the
    // workspace address from hyprctl, which hl.dsp.focus takes as is
    function workspaceKey(ws) {
        return String(ws.address ?? ws.id);
    }

    readonly property var workspaces: {
        const groups = new Map();
        const activeWs = output?.activeWorkspace;
        const active = activeWs ? workspaceKey(activeWs) : "";
        if (activeWs)
            groups.set(active, {id: activeWs.id, label: activeWs.id > 0 ? String(activeWs.id) : activeWs.name, windows: []});
        for (const client of clients) {
            const ws = client.workspace;
            if (!client.mapped || client.hidden || !ws || !client.at || !client.size || ws.type === "special")
                continue;
            const key = workspaceKey(ws);
            if (!groups.has(key))
                groups.set(key, {id: ws.id, label: ws.id > 0 ? String(ws.id) : ws.name, windows: []});
            groups.get(key).windows.push(client);
        }
        return Array.from(groups, ([key, group]) => ({
            key,
            id: group.id,
            label: group.label,
            windows: group.windows,
            active: key === active
        })).sort((a, b) => (a.id > 0 ? a.id : 1e9) - (b.id > 0 ? b.id : 1e9));
    }

    function bounds(windows) {
        const monitor = monitors.find(m => m.id === windows[0]?.monitor) || output;
        const {x, y, width, height, scale, transform} = monitor;
        const rotated = transform % 2 !== 0;
        const right = x + (rotated ? height : width) / scale;
        const bottom = y + (rotated ? width : height) / scale;
        return {
            x: Math.min(x, ...windows.map(w => w.at[0])),
            y: Math.min(y, ...windows.map(w => w.at[1])),
            right: Math.max(right, ...windows.map(w => w.at[0] + w.size[0])),
            bottom: Math.max(bottom, ...windows.map(w => w.at[1] + w.size[1]))
        };
    }

    function select(key) {
        const workspace = workspaces.find(ws => ws.key === key);
        if (!workspace)
            return;
        open = false;
        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${JSON.stringify(key)} })`);
    }

    function toggle() {
        if (open) {
            open = false;
            return;
        }
        if (loading || !target.select())
            return;
        loading = true;
        outputQuery.running = true;
    }

    function readList(text) {
        try {
            const list = JSON.parse(text);
            return Array.isArray(list) ? list : null;
        } catch (error) {
            console.warn("Could not read Hyprland state for the window map:", error);
            return null;
        }
    }

    function moveSelection(dx, dy) {
        const current = Math.max(0, workspaces.findIndex(ws => ws.key === selectedWorkspace));
        const next = current + dx + dy * grid.columns;
        const card = workspaceCards.itemAt(next);
        if (!card || (dx && Math.floor(current / grid.columns) !== Math.floor(next / grid.columns)))
            return;

        selectedWorkspace = card.modelData.key;
        scroll.contentY = Math.max(card.y + card.height - scroll.height, Math.min(scroll.contentY, card.y));
    }

    IpcHandler {
        target: "windowmap"
        function toggle(): void { root.toggle(); }
    }

    Process {
        id: outputQuery
        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.monitors = root.readList(text) || [];
                if (root.monitors.length > 0)
                    windowList.running = true;
                else
                    root.loading = false;
            }
        }
    }

    Process {
        id: windowList
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                const clients = root.readList(text);
                root.loading = false;
                if (!clients)
                    return;
                root.clients = clients;
                const active = root.workspaces.find(workspace => workspace.active);
                root.selectedWorkspace = active?.key || root.workspaces[0]?.key || "";
                scroll.contentY = 0;
                root.open = true;
            }
        }
    }

    PanelWindow {
        id: overlay
        visible: root.open && root.screen !== null
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "#b3000609"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "window-map"
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            focus: root.open
            Keys.onEscapePressed: root.open = false
            Keys.onLeftPressed: root.moveSelection(-1, 0)
            Keys.onRightPressed: root.moveSelection(1, 0)
            Keys.onUpPressed: root.moveSelection(0, -1)
            Keys.onDownPressed: root.moveSelection(0, 1)
            Keys.onReturnPressed: root.select(root.selectedWorkspace)
            Keys.onEnterPressed: root.select(root.selectedWorkspace)

            Rectangle {
                id: panel
                width: Math.min((parent.width - 48) / root.size, 1040)
                height: content.implicitHeight + 52
                anchors.centerIn: parent
                scale: root.size
                color: Colors.surfaceContainer
                border.color: Colors.outlineVariant
                radius: 20

                ColumnLayout {
                    id: content
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 26 }
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Workspaces"
                            font.pixelSize: 26
                            font.weight: Font.DemiBold
                            color: Colors.text
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            implicitWidth: 48
                            implicitHeight: 32
                            radius: 8
                            color: dismiss.containsMouse ? Colors.secondaryContainer : Colors.surfaceContainerHigh
                            border.color: Colors.outlineVariant

                            Text { anchors.centerIn: parent; text: "Esc"; color: Colors.textDim; font.pixelSize: 13 }
                            MouseArea {
                                id: dismiss
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.open = false
                            }
                        }
                    }

                    Flickable {
                        id: scroll
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(grid.implicitHeight, Math.max(0, overlay.height / root.size - 160))
                        contentHeight: grid.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        clip: true

                        GridLayout {
                            id: grid
                            width: scroll.width
                            columns: panel.width < 760 ? 2 : 3
                            columnSpacing: 14
                            rowSpacing: 14

                            Repeater {
                                id: workspaceCards
                                model: root.open ? root.workspaces : []

                                Rectangle {
                                    id: card
                                    required property var modelData
                                    readonly property bool selected: modelData.key === root.selectedWorkspace
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: Math.min(194, (width - 24) * 9 / 16 + 48)
                                    color: selected || pick.containsMouse ? Colors.secondaryContainer : Colors.surfaceContainerHigh
                                    radius: 12
                                    border.color: selected || pick.containsMouse || modelData.active ? Colors.primary : Colors.outlineVariant

                                    Text {
                                        anchors { left: parent.left; top: parent.top; margins: 12 }
                                        text: card.modelData.label
                                        textFormat: Text.PlainText
                                        color: card.modelData.active ? Colors.primary : Colors.text
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }

                                    Rectangle {
                                        id: map
                                        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 11; topMargin: 36 }
                                        color: Colors.surface
                                        radius: 7
                                        clip: true
                                        readonly property var bounds: root.bounds(card.modelData.windows)

                                        Text {
                                            visible: card.modelData.windows.length === 0
                                            anchors.centerIn: parent
                                            text: "Empty"
                                            color: Colors.textDim
                                            font.pixelSize: 12
                                        }

                                        Repeater {
                                            model: card.modelData.windows

                                            Rectangle {
                                                id: tile
                                                required property var modelData
                                                readonly property var app: DesktopEntries.heuristicLookup(modelData.class || modelData.initialClass || "")
                                                readonly property string appName: app?.name || modelData.class || "Window"
                                                readonly property real xScale: map.width / (map.bounds.right - map.bounds.x)
                                                readonly property real yScale: map.height / (map.bounds.bottom - map.bounds.y)
                                                x: (modelData.at[0] - map.bounds.x) * xScale + 2
                                                y: (modelData.at[1] - map.bounds.y) * yScale + 2
                                                width: Math.max(1, modelData.size[0] * xScale - 4)
                                                height: Math.max(1, modelData.size[1] * yScale - 4)
                                                z: modelData.floating ? 1 : 0
                                                radius: 6
                                                clip: true
                                                color: Colors.surfaceContainerHighest
                                                border.color: Colors.outlineVariant

                                                ColumnLayout {
                                                    width: Math.max(0, parent.width - 12)
                                                    anchors.centerIn: parent
                                                    spacing: 4

                                                    IconImage {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        implicitSize: 26
                                                        visible: tile.height >= 68 && tile.width >= 38
                                                        source: Quickshell.iconPath(tile.app?.icon || tile.modelData.class || "", "application-x-executable")
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: tile.appName
                                                        textFormat: Text.PlainText
                                                        elide: Text.ElideRight
                                                        font.pixelSize: 13
                                                        font.weight: Font.DemiBold
                                                        color: Colors.text
                                                    }

                                                    Text {
                                                        Layout.fillWidth: true
                                                        visible: tile.height >= 57 && tile.modelData.title !== tile.appName
                                                        horizontalAlignment: Text.AlignHCenter
                                                        text: tile.modelData.title || ""
                                                        textFormat: Text.PlainText
                                                        elide: Text.ElideRight
                                                        font.pixelSize: 11
                                                        color: Colors.textDim
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: pick
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.select(card.modelData.key)
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        text: "Click a workspace or use the arrow keys and Enter"
                        font.pixelSize: 13
                        color: Colors.textDim
                    }
                }
            }
        }
    }
}
