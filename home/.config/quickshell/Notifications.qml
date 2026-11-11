import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    required property bool dnd
    // Main monitor from yunagi-display-scale; empty means the focused one
    property string mainScreen: ""
    ScreenTarget { id: popupTarget }

    NotificationServer {
        id: notifs
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        onNotification: n => {
            if (notifs.trackedNotifications.values.length === 0)
                popupTarget.select(Quickshell.screens.find(sc => sc.name === root.mainScreen) ?? null);
            n.tracked = true;
        }
    }

    PanelWindow {
        visible: popupTarget.screen !== null && !root.dnd && notifs.trackedNotifications.values.length > 0
        screen: popupTarget.screen
        implicitWidth: 360 + 40
        implicitHeight: notifCol.implicitHeight + 40
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
        }
        margins {
            top: 40
        }

        Column {
            id: notifCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 8

            Repeater {
                model: notifs.trackedNotifications

                Item {
                    id: nBox
                    required property var modelData
                    readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                    width: notifCol.width
                    height: nText.implicitHeight + 24
                    opacity: 0
                    transform: Translate {
                        id: nSlide
                        y: -20
                    }
                    Component.onCompleted: nIn.start()

                    ParallelAnimation {
                        id: nIn
                        NumberAnimation {
                            target: nBox
                            property: "opacity"
                            to: 1
                            duration: 220
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                        }
                        NumberAnimation {
                            target: nSlide
                            property: "y"
                            to: 0
                            duration: 300
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: [0.2, 0, 0, 1, 1, 1]
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        offset: Qt.vector2d(0, 6)
                        radius: 0
                        blur: 24
                        color: Qt.rgba(0, 0, 0, 0.4)
                    }

                    PanelBackground {
                        border.color: nBox.critical ? "#f7768e" : Colors.outlineVariant
                    }

                    Timer {
                        running: !nBox.critical
                        interval: nBox.modelData.expireTimeout > 0 ? nBox.modelData.expireTimeout : 4000
                        onTriggered: nBox.modelData.expire()
                    }

                    IconImage {
                        id: nIcon
                        visible: source != ""
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.margins: 12
                        implicitSize: visible ? 28 : 0
                        source: nBox.modelData.image || (nBox.modelData.appIcon ? Quickshell.iconPath(nBox.modelData.appIcon, true) : "")
                    }

                    Column {
                        id: nText
                        anchors.left: nIcon.visible ? nIcon.right : parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 12
                        spacing: 2

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: nBox.modelData.summary || nBox.modelData.appName
                            color: Colors.text
                            font.family: "Noto Serif"
                            font.pixelSize: 17
                        }

                        Text {
                            visible: text !== ""
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 4
                            elide: Text.ElideRight
                            textFormat: Text.StyledText
                            text: nBox.modelData.body
                            color: Colors.textDim
                            font.pixelSize: 15
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            const a = nBox.modelData.actions;
                            if (mouse.button === Qt.LeftButton && a.length > 0)
                                a[0].invoke();
                            else
                                nBox.modelData.dismiss();
                        }
                    }
                }
            }
        }
    }
}
