import QtQuick

Item {
    id: ph
    property string icon: ""
    property string title: ""
    property string mood: ""
    property bool on: false
    property bool hasSwitch: true
    signal toggled()
    width: parent.width
    height: 40

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ph.icon
            color: Colors.text
            font.family: "Hack Nerd Font"
            font.pixelSize: 24
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
                text: ph.title
                color: Colors.text
                font.family: "Hack Nerd Font"
                font.pixelSize: 17
                font.weight: Font.Bold
            }

            Text {
                text: ph.mood
                color: Colors.primary
                font.family: "Hack Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }
        }
    }

    ToggleSwitch {
        visible: ph.hasSwitch
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        on: ph.on
        onToggled: ph.toggled()
    }
}
