import QtQuick

// Each agent's windows: use, pace and reset time. In the robot's panel and on the AI page.
Column {
    id: col
    spacing: 16

    Repeater {
        model: AiUsage.agents

        Column {
            id: agent
            required property var modelData
            width: col.width
            spacing: 8

            Item {
                width: parent.width
                height: name.implicitHeight

                Text {
                    id: name
                    text: agent.modelData.name
                    color: Colors.text
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 17
                    font.weight: Font.Bold
                }
                Text {
                    anchors.right: parent.right
                    anchors.baseline: name.baseline
                    text: agent.modelData.stale ? "not updated" : agent.modelData.plan || ""
                    color: agent.modelData.stale ? "#e0af68" : Colors.textDim
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 14
                    font.capitalization: agent.modelData.stale ? Font.MixedCase : Font.Capitalize
                }
            }

            Repeater {
                model: agent.modelData.limits || []

                Column {
                    id: lim
                    required property var modelData
                    readonly property real used: Math.max(0, Math.min(1, modelData.used))
                    width: agent.width
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 18

                        Text {
                            id: label
                            width: 80
                            anchors.verticalCenter: parent.verticalCenter
                            text: lim.modelData.label
                            color: Colors.textDim
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 14
                        }
                        // Bar of use; the thin mark is where use would be at an even pace
                        Rectangle {
                            id: track
                            anchors.left: label.right
                            anchors.right: pct.left
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 6
                            color: Colors.surfaceContainerHighest
                            Rectangle {
                                width: parent.width * lim.used
                                height: parent.height
                                color: AiUsage.color(lim.used)
                            }
                            Rectangle {
                                visible: lim.modelData.windowMins > 0
                                x: parent.width * AiUsage.gone(lim.modelData) - 1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: 12
                                color: Colors.text
                                opacity: 0.6
                            }
                        }
                        Text {
                            id: pct
                            width: 52
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: Math.round(lim.used * 100) + "%"
                            color: AiUsage.color(lim.used)
                            font.family: "Hack Nerd Font"
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        x: 80
                        text: "resets in " + AiUsage.until(lim.modelData.resetsAt) + "  ·  "
                            + Qt.formatDateTime(new Date(lim.modelData.resetsAt), "ddd HH:mm")
                            + (lim.used > AiUsage.gone(lim.modelData) + 0.05 ? "  ·  ahead" : "")
                        color: Colors.textDim
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
