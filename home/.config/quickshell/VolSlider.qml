import QtQuick

Item {
    id: sl
    property real value: 0
    property bool muted: false
    signal moved(real v)

    width: parent.width
    height: 22

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 0
        color: Colors.outlineVariant

        Rectangle {
            width: parent.width * Math.min(1, sl.value)
            height: parent.height
            radius: 0
            color: sl.muted ? Colors.outline : Colors.text
        }
    }

    Rectangle {
        x: (sl.width - width) * Math.min(1, sl.value)
        anchors.verticalCenter: parent.verticalCenter
        width: 14
        height: 14
        radius: 0
        color: sl.muted ? Colors.outline : Colors.text
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => sl.moved(mouse.x / width)
        onPositionChanged: mouse => { if (pressed) sl.moved(mouse.x / width); }
        onWheel: wheel => sl.moved(sl.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
