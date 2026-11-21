import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import QtQuick

// The password prompt (polkit agent), drawn as a card like the menu, over everything.
Scope {
    id: root

    readonly property var flow: agent.flow
    ScreenTarget { id: target }

    PolkitAgent {
        id: agent
        onIsActiveChanged: if (isActive) target.select()
    }

    function submit() {
        if (!flow || !flow.isResponseRequired) return;
        flow.submit(field.text);
        field.text = "";
    }

    function cancel() {
        if (flow) flow.cancelAuthenticationRequest();
    }

    PanelWindow {
        visible: agent.isActive && target.screen !== null
        screen: target.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: agent.isActive ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        WlrLayershell.namespace: "yunagi-polkit"
        anchors { top: true; bottom: true; left: true; right: true }

        // Everything else dims while the password is asked for
        Rectangle {
            anchors.fill: parent
            color: Qt.alpha("#000000", 0.45)
        }

        Rectangle {
            id: card
            width: Math.min(480, parent.width - 48)
            height: col.implicitHeight + 48
            anchors.centerIn: parent
            color: Qt.alpha(Colors.surface, 0.98)
            radius: 18
            border.width: 1
            border.color: Colors.outlineVariant

            Column {
                id: col
                x: 24
                y: 24
                width: parent.width - 48
                spacing: 14

                Row {
                    spacing: 10
                    Image {
                        width: 26
                        height: 26
                        anchors.verticalCenter: parent.verticalCenter
                        sourceSize: Qt.size(52, 52)
                        source: Qt.resolvedUrl("mark/diamant.svg")
                    }
                    Text {
                        text: "Password"
                        color: Colors.text
                        font.family: "Noto Serif"
                        font.pixelSize: 23
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.message : ""
                    color: Colors.text
                    font.family: "sans-serif"
                    font.pixelSize: 14
                }

                Text {
                    visible: text !== ""
                    width: parent.width
                    elide: Text.ElideRight
                    text: root.flow && root.flow.selectedIdentity && root.flow.selectedIdentity.displayName
                        ? "As " + root.flow.selectedIdentity.displayName : ""
                    color: Colors.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 12
                }

                Rectangle {
                    width: parent.width
                    height: 42
                    radius: 9
                    color: Colors.surfaceContainer
                    border.width: 1
                    border.color: field.activeFocus ? Qt.alpha(Colors.primary, 0.55) : "transparent"

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: root.flow && !root.flow.isResponseRequired ? "Checking…"
                            : (root.flow && root.flow.inputPrompt ? root.flow.inputPrompt.replace(/:\s*$/, "") : "Password") + "…"
                        color: Colors.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 14
                    }
                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.margins: 12
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Colors.text
                        selectionColor: Colors.secondaryContainer
                        font.family: "sans-serif"
                        font.pixelSize: 14
                        clip: true
                        focus: agent.isActive
                        enabled: root.flow ? root.flow.isResponseRequired : false
                        onVisibleChanged: if (visible) forceActiveFocus()
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                }

                // A wrong password, or what polkit says on the way
                Text {
                    visible: text !== ""
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.supplementaryMessage : ""
                    color: root.flow && root.flow.supplementaryIsError ? "#f7768e" : Colors.textDim
                    font.family: "sans-serif"
                    font.pixelSize: 13
                }

                Rectangle { width: parent.width; height: 1; color: Qt.alpha(Colors.outlineVariant, 0.6) }

                Item {
                    width: parent.width
                    height: 34

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Enter confirm   ·   Esc cancel"
                        color: Colors.textDim
                        font.family: "sans-serif"
                        font.pixelSize: 12
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        Repeater {
                            model: ["Cancel", "Confirm"]
                            Rectangle {
                                required property string modelData
                                readonly property bool primary: modelData === "Confirm"
                                width: 92
                                height: 34
                                radius: 9
                                color: primary ? Colors.primary : "transparent"
                                border.width: 1
                                border.color: primary ? Colors.primary : Colors.outlineVariant
                                Text {
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    color: parent.primary ? Colors.surface : Colors.textDim
                                    font.family: "sans-serif"
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.primary ? root.submit() : root.cancel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
