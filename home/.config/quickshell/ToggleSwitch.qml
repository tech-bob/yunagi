import QtQuick

Rectangle {
    id: tsw
    property bool on: false
    signal toggled()
    width: 44
    height: 24
    radius: 0
    color: on ? Colors.primary : Colors.surfaceContainerHighest

    Rectangle {
        x: tsw.on ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: 0
        color: tsw.on ? Colors.surface : Colors.textDim
        Behavior on x { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: tsw.toggled()
    }
}
