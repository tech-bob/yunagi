import QtQuick

// A labelled one-line text field in the panels' style, with a hint while empty.
Column {
    property alias text: input.text
    property string label: ""
    property string hint: ""
    width: parent.width
    spacing: 3

    Text {
        visible: parent.label !== ""
        text: parent.label.toUpperCase()
        color: Colors.textDim
        font.family: "Hack Nerd Font"
        font.pixelSize: 11
        font.weight: Font.Bold
        font.letterSpacing: 1
    }

    Rectangle {
        width: parent.width
        height: 32
        color: Colors.surfaceContainerHigh
        border.color: input.activeFocus ? Colors.primary : Colors.outlineVariant
        border.width: 1

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            visible: input.text === ""
            elide: Text.ElideRight
            text: parent.parent.hint
            color: Colors.textDim
            font.family: "Hack Nerd Font"
            font.pixelSize: 12
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Colors.text
            selectionColor: Colors.secondaryContainer
            font.family: "Hack Nerd Font"
            font.pixelSize: 13
            clip: true
        }
    }
}
