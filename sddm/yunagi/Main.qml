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
    readonly property color danger: "#f87171"
    readonly property color amber: "#fbbf24"
    // Sizes follow the screen height; the design is drawn at 1080 px
    readonly property real u: height / 1080

    property int sessionIndex: sessionModel.lastIndex
    property var sessions: []
    property var users: []
    property var realNames: []
    property int userIndex: 0
    readonly property string userName: users.length > 0 ? users[userIndex] : userModel.lastUser
    readonly property string displayName: (realNames[userIndex] || "").split(",")[0] || userName

    // Read users and sessions from the SDDM models
    Repeater {
        model: userModel
        Item {
            required property string name
            required property string realName
            Component.onCompleted: {
                root.users = root.users.concat([name]);
                root.realNames = root.realNames.concat([realName]);
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

    // Greeting by time of day, the same lines as yunagi-greeting on the lock screen;
    // here the next line of the same part of the day comes every 3 minutes
    // The lines are also in bin/yunagi-greeting; change both.
    function greeting(name) {
        const hour = now.getHours();
        const day = now.getDay() || 7;
        let lines;
        if (hour >= 5 && hour < 11)
            lines = ["Good morning, %", "Morning, %", "Coffee first, %?", "Slow start, %?",
                     "Fresh day, %", "Up early, %?", "Easy does it, %"];
        else if (hour >= 11 && hour < 17)
            lines = ["Good afternoon, %", "Hey there, %", "Back at it, %", "Afternoon, %",
                     "Welcome back, %", "Short break, %?", "Where were we, %?"];
        else if (hour >= 17 && hour < 22)
            lines = ["Good evening, %", "Evening, %", "How was your day, %?", "Winding down, %?",
                     "One more thing, %?", "Feet up, %?", "Calm evening, %"];
        else
            lines = ["Night owl mode, %", "Still up, %?", "Late one, %?", "Quiet hours, %",
                     "Just one more, %?", "Moon's out, %", "The night is young, %"];
        if (day === 1 && hour < 12) lines.push("New week, %");
        if (day === 5 && hour >= 15 && hour < 17) lines.push("Almost Friday night, %");
        if (day === 5 && hour >= 17 && hour < 22)
            lines = ["Happy Friday, %", "Beer o'clock, %?", "Weekend mode, %", "Made it to Friday, %"];
        if (day >= 6) lines.push("Easy weekend, %?", "No rush today, %");
        const yday = Math.round((Date.UTC(now.getFullYear(), now.getMonth(), now.getDate())
                                 - Date.UTC(now.getFullYear(), 0, 0)) / 86400000);
        const safe = name.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const step = Math.floor((hour * 60 + now.getMinutes()) / 3);
        return lines[(yday * 480 + step) % lines.length]
            .replace("%", '<font color="' + root.cyan + '">' + safe + "</font>");
    }

    // Background from theme.conf (or theme.conf.user): a blurred photo, or a video played as is
    readonly property string background: config.background || "background.jpg"
    readonly property bool video: /\.(mp4|webm|mkv|mov)$/i.test(background)
    Loader {
        id: videoLoader
        anchors.fill: parent
        active: root.video
        source: "VideoBackground.qml"
        onLoaded: item.source = Qt.resolvedUrl(root.background)
    }
    Image {
        anchors.fill: parent
        visible: !root.video || videoLoader.status === Loader.Error
        source: root.video ? "background.jpg" : root.background
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 0.9 }
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.2667) }

    // Session, top left; click to switch
    Text {
        x: 130 * root.u
        y: 66 * root.u
        text: (root.sessions[root.sessionIndex] || "Session") + (root.sessions.length > 1 ? "  ▾" : "")
        color: sessionHover.hovered ? root.text : root.textDim
        font.family: "Noto Sans"
        font.pixelSize: 17 * root.u
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

    // Restart and shut down, top right
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

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 300 * root.u - height / 2
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: "#f4f6fa"
        font.family: "Noto Sans"
        font.pixelSize: 85.33 * root.u
        font.weight: Font.Light
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 390 * root.u - height / 2
        text: Qt.locale("en_GB").toString(root.now, "dddd, d MMMM")
        color: root.textDim
        font.family: "Noto Sans"
        font.pixelSize: 22.67 * root.u
    }

    // Greeting in the middle, or at greetingY from theme.conf; click to switch user when there are several.
    // A new line fades out the old one and fades in.
    readonly property string greetingText: greeting(displayName) + (users.length > 1 ? "  ▾" : "")
    onGreetingTextChanged: greetingLabel.text === "" ? greetingLabel.text = greetingText : greetingFade.restart()
    SequentialAnimation {
        id: greetingFade
        NumberAnimation { target: greetingLabel; property: "opacity"; to: 0; duration: 600; easing.type: Easing.InOutSine }
        ScriptAction { script: greetingLabel.text = root.greetingText }
        NumberAnimation { target: greetingLabel; property: "opacity"; to: 1; duration: 600; easing.type: Easing.InOutSine }
    }
    Text {
        id: greetingLabel
        Component.onCompleted: text = root.greetingText
        anchors.horizontalCenter: parent.horizontalCenter
        y: (Number(config.greetingY) || 540) * root.u - height / 2
        textFormat: Text.StyledText
        color: "#e8eef5"
        font.family: "Noto Serif"
        font.weight: Font.Light
        font.pixelSize: 34.67 * root.u
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

    // Caps Lock warning under the password field
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 904 * root.u - height / 2
        visible: keyboard.capsLock
        text: "Caps Lock is on"
        color: root.amber
        font.family: "Noto Sans"
        font.pixelSize: 17 * root.u
    }

    Rectangle {
        id: fieldBox
        objectName: "passwordField"
        property bool failed: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: 850 * root.u - height / 2
        width: 420 * root.u
        height: 64 * root.u
        color: Qt.rgba(7 / 255, 13 / 255, 22 / 255, 0.451)
        border.width: 1
        border.color: failed ? root.danger : keyboard.capsLock ? Qt.alpha(root.amber, 0.8) : password.activeFocus ? Qt.alpha(root.cyan, 0.65) : Qt.rgba(124 / 255, 154 / 255, 181 / 255, 0.3765)
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
            text: fieldBox.failed ? "Incorrect password" : "Password for " + root.userName
            color: fieldBox.failed ? root.danger : root.textDim
            font.family: "Noto Sans"
            font.pixelSize: 19 * root.u
        }
        TextInput {
            id: password
            objectName: "passwordInput"
            anchors.fill: parent
            anchors.leftMargin: 22 * root.u
            anchors.rightMargin: 22 * root.u
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
    }

    // The wordmark breathes slowly
    Image {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 955 * root.u - height / 2
        width: 191 * root.u
        height: 57 * root.u
        source: "wordmark.png"
        fillMode: Image.PreserveAspectFit
        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { from: 1; to: 0.35; duration: 2400; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.35; to: 1; duration: 2400; easing.type: Easing.InOutSine }
        }
    }
}
