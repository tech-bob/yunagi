import QtQuick
import QtQuick.Effects

Rectangle {
    id: root
    objectName: "yunagiLogin"
    width: 1920
    height: 1080
    color: "#0c1820"

    readonly property color text: "#f4f4f2"
    readonly property color textDim: "#b8c5d4"
    readonly property color cyan: "#7dd3fc"
    readonly property color lilac: "#a78bfa"
    readonly property color danger: "#f87171"
    // Sizes follow the screen height; the design is drawn at 1080 px
    readonly property real u: height / 1080

    property int sessionIndex: sessionModel.lastIndex
    property var sessions: []
    property var users: []
    property var icons: []
    property int userIndex: 0
    readonly property string userName: users.length > 0 ? users[userIndex] : userModel.lastUser
    readonly property string userIcon: icons.length > 0 ? icons[userIndex] : ""

    // Read users and sessions from the SDDM models
    Repeater {
        model: userModel
        Item {
            required property string name
            required property string icon
            Component.onCompleted: {
                root.users = root.users.concat([name]);
                root.icons = root.icons.concat([icon]);
                if (name === userModel.lastUser)
                    root.userIndex = root.users.length - 1;
            }
        }
    }

    Repeater {
        model: sessionModel
        Item {
            required property int index
            required property string name
            required property string file
            Component.onCompleted: {
                const s = root.sessions.slice();
                s[index] = name;
                root.sessions = s;
                if ((root.sessionIndex < 0 || root.sessionIndex >= sessionModel.rowCount()) && file.endsWith("hyprland.desktop"))
                    root.sessionIndex = index;
            }
        }
    }

    function login() {
        sddm.login(root.userName, password.text, root.sessionIndex);
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            password.text = "";
            fieldBox.failed = true;
            shake.start();
        }
    }

    property date now: new Date()
    Timer { interval: 1000; running: true; repeat: true; onTriggered: root.now = new Date() }

    // The same blurred canyon and translucent panel as the Glass lock screen.
    Image {
        anchors.fill: parent
        source: config.background || "background.jpg"
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 0.9 }
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.2667) }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 130 * root.u
        y: 66 * root.u
        spacing: 18 * root.u

        Repeater {
            model: [
                { label: "Restart", run: () => sddm.reboot(), ok: sddm.canReboot },
                { label: "Shut down", run: () => sddm.powerOff(), ok: sddm.canPowerOff }
            ]
            Row {
                required property var modelData
                required property int index
                visible: modelData.ok
                spacing: 18 * root.u
                Text {
                    visible: parent.index > 0
                    text: "·"
                    color: root.textDim
                    font.pixelSize: 17 * root.u
                }
                Text {
                    text: parent.modelData.label
                    color: powerHover.hovered ? root.text : root.textDim
                    font.pixelSize: 17 * root.u
                    HoverHandler { id: powerHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.parent.modelData.run()
                    }
                }
            }
        }
    }

    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        y: 220 * root.u
        width: 580 * root.u
        height: 600 * root.u
        radius: 28 * root.u
        color: Qt.rgba(13 / 255, 20 / 255, 32 / 255, 0.702)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.2078)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 143 * root.u - height / 2
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: "#f4f6fa"
            font.family: "Noto Sans"
            font.pixelSize: 85.33 * root.u
            font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 244 * root.u - height / 2
            text: Qt.formatDateTime(root.now, "dddd, d MMMM")
            color: root.textDim
            font.family: "Noto Sans"
            font.pixelSize: 22.67 * root.u
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 361 * root.u - height / 2
            text: root.userName + (root.users.length > 1 ? "  ▾" : "")
            color: "#e4eaf2"
            font.family: "Noto Sans"
            font.pixelSize: 22.67 * root.u
            MouseArea {
                anchors.fill: parent
                enabled: root.users.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.userIndex = (root.userIndex + 1) % root.users.length;
                    password.forceActiveFocus();
                }
            }
        }
        Rectangle {
            id: fieldBox
            objectName: "passwordField"
            property bool failed: false
            anchors.horizontalCenter: parent.horizontalCenter
            y: 414 * root.u
            width: 420 * root.u
            height: 64 * root.u
            radius: 14 * root.u
            color: Qt.rgba(7 / 255, 13 / 255, 22 / 255, 0.451)
            border.width: 1
            border.color: failed ? root.danger : password.activeFocus ? Qt.alpha(root.cyan, 0.65) : Qt.rgba(124 / 255, 154 / 255, 181 / 255, 0.3765)
            Behavior on border.color { ColorAnimation { duration: 150 } }
            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: -8; duration: 50 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 8; duration: 50 }
                NumberAnimation { target: fieldBox; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }
            Text {
                anchors.centerIn: parent
                visible: password.text === ""
                text: "Password"
                color: root.textDim
                font.family: "Noto Sans"
                font.pixelSize: 19 * root.u
            }
            TextInput {
                id: password
                objectName: "passwordInput"
                anchors.fill: parent
                anchors.leftMargin: 22 * root.u
                anchors.rightMargin: 56 * root.u
                verticalAlignment: TextInput.AlignVCenter
                horizontalAlignment: TextInput.AlignHCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: "#edf4fa"
                font.family: "Noto Sans"
                font.pixelSize: 19 * root.u
                focus: true
                clip: true
                onTextEdited: fieldBox.failed = false
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 20 * root.u
                anchors.verticalCenter: parent.verticalCenter
                text: "→"
                color: root.cyan
                font.pixelSize: 22 * root.u
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -10
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.login()
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 526 * root.u - height / 2
            text: (root.sessions[root.sessionIndex] || "Session") + (root.sessions.length > 1 ? "  ▾" : "")
            color: sessionHover.hovered ? root.text : root.textDim
            font.family: "Noto Sans"
            font.pixelSize: 20 * root.u
            HoverHandler { id: sessionHover }
            MouseArea {
                anchors.fill: parent
                enabled: root.sessions.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.sessionIndex = (root.sessionIndex + 1) % root.sessions.length;
                    password.forceActiveFocus();
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 565 * root.u
            visible: fieldBox.failed
            text: "Incorrect password"
            color: root.danger
            font.family: "Noto Sans"
            font.pixelSize: 17 * root.u
        }
    }
    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 926.5 * root.u
        width: 191 * root.u
        height: 57 * root.u
        source: "wordmark.png"
        fillMode: Image.PreserveAspectFit
    }
}
