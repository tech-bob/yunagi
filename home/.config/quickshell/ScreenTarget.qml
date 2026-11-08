import Quickshell
import Quickshell.Hyprland
import QtQuick

QtObject {
    property string name: ""

    // Keep a name, not a screen object: outputs can disappear during hotplug.
    readonly property var screen: {
        const screens = Quickshell.screens;
        const focused = Hyprland.focusedMonitor;
        return screens.find(sc => sc.name === name)
            || screens.find(sc => focused && sc.name === focused.name)
            || screens[0] || null;
    }

    function select(preferred) {
        name = preferred ? preferred.name : "";
        const selected = screen;
        name = selected ? selected.name : "";
        return selected;
    }
}
