import QtQuick

Rectangle {
    id: dr
    property string icon: ""
    property string label: ""
    property bool active: false
    property string detail: ""
    // Set for rows whose active state should stand out (VPN, Wi-Fi).
    property color accent: "transparent"
    readonly property bool accented: active && accent.a > 0
    readonly property color fg: accented ? accent : (active ? Colors.text : Colors.textDim)
    signal picked()

    width: parent.width
    height: 34
    radius: 0
    color: accented ? Qt.alpha(accent, 0.16) : active ? Colors.surfaceContainerHighest : (drMouse.containsMouse ? Colors.surfaceContainerHigh : "transparent")
    border.color: accented ? accent : "transparent"
    border.width: 1

    Text {
        id: drDetail
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 10
        text: dr.detail
        color: dr.accented ? dr.accent : Colors.textDim
        font.family: "Hack Nerd Font"
        font.pixelSize: 12
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: drDetail.left
        anchors.rightMargin: 8
        spacing: 12

        Text {
            text: dr.icon
            color: dr.fg
            font.family: "Hack Nerd Font"
            font.pixelSize: 15
        }

        Text {
            width: parent.width - 30
            elide: Text.ElideRight
            text: dr.label
            color: dr.fg
            font.family: "Hack Nerd Font"
            font.pixelSize: 14
            font.weight: dr.active ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: drMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dr.picked()
    }
}
