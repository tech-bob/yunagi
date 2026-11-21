import Quickshell
import Quickshell.Wayland
import QtQuick

// AI usage under the robot: per agent each window's use, pace and reset time.
PanelWindow {
    id: win

    signal closeRequested()
    onVisibleChanged: if (visible) AiUsage.now = Date.now()

    implicitWidth: 460
    implicitHeight: col.implicitHeight + 28
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
    }
    margins {
        top: 54
    }

    PanelBackground {}

    // Esc closes it, as a click beside it does
    Item {
        focus: true
        Keys.onEscapePressed: win.closeRequested()
    }

    AiUsageList {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
    }
}
