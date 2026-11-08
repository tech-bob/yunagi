// Preview of the SDDM theme without SDDM: /usr/lib/qt6/bin/qml sddm/preview/Preview.qml (password "test")
import QtQuick
import QtQuick.Window

Window {
    width: 1600
    height: 900
    visible: true
    title: "yunagi-sddm-preview"

    QtObject {
        id: sddm
        property bool canReboot: true
        property bool canPowerOff: true
        signal loginFailed
        function login(user, password, session) {
            console.log("login", user, session);
            if (password !== "test")
                loginFailed();
        }
        function reboot() { console.log("reboot"); }
        function powerOff() { console.log("powerOff"); }
    }

    QtObject {
        id: config
        property string background: "background.jpg"
    }

    ListModel {
        id: userModel
        property string lastUser: ""
        ListElement { name: "bob"; icon: "" }
    }

    ListModel {
        id: sessionModel
        property int lastIndex: -1
        ListElement { name: "Hyprland"; file: "/usr/share/wayland-sessions/hyprland.desktop" }
        ListElement { name: "Hyprland (uwsm-managed)"; file: "/usr/share/wayland-sessions/hyprland-uwsm.desktop" }
    }

    Loader {
        anchors.fill: parent
        source: "../yunagi/Main.qml"
    }
}
