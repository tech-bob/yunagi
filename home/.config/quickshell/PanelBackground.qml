import QtQuick

Rectangle {
    anchors.fill: parent
    radius: 0
    border.color: Colors.outlineVariant
    border.width: 1
    gradient: Gradient {
        GradientStop { position: 0; color: Qt.alpha(Colors.surface, 0.94) }
        GradientStop { position: 1; color: Qt.alpha(Colors.surfaceContainerHigh, 0.94) }
    }
}
