import QtQuick

Rectangle {
    id: cb
    property string label
    property bool on: false
    signal clicked
    height: 34
    color: on ? Colors.secondaryContainer : (cbMouse.containsMouse ? Colors.surfaceContainerHigh : "transparent")
    border.color: on ? Colors.primary : Colors.outlineVariant
    radius: 0
    border.width: 1

    Text {
        anchors.centerIn: parent
        text: cb.label
        color: cb.on ? Colors.primary : Colors.textDim
        font.family: "Hack Nerd Font"
        font.pixelSize: 15
    }

    MouseArea {
        id: cbMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cb.clicked()
    }
}
