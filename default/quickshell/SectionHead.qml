import QtQuick

Item {
    property string label: ""
    property string value: ""
    width: parent.width
    height: 18

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: parent.label
        color: Colors.textDim
        font.family: "Hack Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Bold
        font.letterSpacing: 1
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: parent.value
        color: Colors.textDim
        font.family: "Hack Nerd Font"
        font.pixelSize: 12
        font.weight: Font.Bold
    }
}
