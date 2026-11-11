import Quickshell
import Quickshell.Wayland
import QtQuick

// Right-click menu for system tray items, drawn in the panel style.
Scope {
    id: root

    property bool open: false
    property var screen: null
    property var item: null
    // Horizontal centre of the tray icon, in screen-local x
    property real anchorX: 0
    property var stack: []

    signal closeRequested()

    onOpenChanged: stack = []
    onItemChanged: stack = []

    QsMenuOpener {
        id: opener
        menu: root.stack.length > 0 ? root.stack[root.stack.length - 1] : (root.item ? root.item.menu : null)
    }

    PanelWindow {
        id: win
        visible: root.open && root.item !== null
        implicitWidth: 280
        implicitHeight: col.implicitHeight + 16
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        screen: root.screen

        anchors {
            top: true
            right: true
        }
        margins {
            top: 54
            right: root.screen ? Math.max(10, root.screen.width - root.anchorX - width / 2) : 10
        }

        PanelBackground {}

        Column {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            spacing: 2

            DevRow {
                visible: root.stack.length > 0
                icon: "󰁍"
                label: "Back"
                onPicked: root.stack = root.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Item {
                    id: entry
                    required property var modelData
                    width: col.width
                    height: modelData.isSeparator ? 9 : row.height

                    Divider {
                        visible: entry.modelData.isSeparator
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DevRow {
                        id: row
                        visible: !entry.modelData.isSeparator
                        opacity: entry.modelData.enabled ? 1 : 0.4
                        active: entry.modelData.buttonType !== QsMenuButtonType.None && entry.modelData.checkState === Qt.Checked
                        icon: entry.modelData.buttonType === QsMenuButtonType.CheckBox ? (active ? "󰄲" : "󰄱")
                            : entry.modelData.buttonType === QsMenuButtonType.RadioButton ? (active ? "󰐾" : "󰄯")
                            : ""
                        label: entry.modelData.text.replace(/_(?=\S)/, "")
                        detail: entry.modelData.hasChildren ? "󰅂" : ""
                        onPicked: {
                            const e = entry.modelData;
                            if (!e.enabled)
                                return;
                            if (e.hasChildren) {
                                root.stack = root.stack.concat([e]);
                                return;
                            }
                            e.triggered();
                            root.closeRequested();
                        }
                    }
                }
            }
        }
    }
}
