import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: calWin

    property date calMonth: new Date()
    signal closeRequested()

    onVisibleChanged: if (visible) calMonth = new Date()

    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        t.setDate(t.getDate() + 3 - (t.getDay() + 6) % 7);
        const w1 = new Date(t.getFullYear(), 0, 4);
        return 1 + Math.round(((t - w1) / 86400000 - 3 + (w1.getDay() + 6) % 7) / 7);
    }

    function calDays() {
        const first = new Date(calMonth.getFullYear(), calMonth.getMonth(), 1);
        const start = new Date(first);
        start.setDate(1 - (first.getDay() + 6) % 7);
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(start);
            d.setDate(start.getDate() + i);
            out.push(d);
        }
        return out;
    }

    function calStep(n) {
        calMonth = new Date(calMonth.getFullYear(), calMonth.getMonth() + n, 1);
    }

    // Calendar size factor
    readonly property real k: 1.4
    implicitWidth: 440 * calWin.k
    implicitHeight: calCol.implicitHeight + 28 * calWin.k
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: true
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
    }
    margins {
        top: 54
    }

    PanelBackground {
        radius: 16 * calWin.k
    }

    SystemClock {
        id: calClock
        precision: SystemClock.Minutes
    }

    Column {
        id: calCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14 * calWin.k
        spacing: 10 * calWin.k
        focus: true
        Keys.onLeftPressed: calWin.calStep(-1)
        Keys.onRightPressed: calWin.calStep(1)
        Keys.onUpPressed: calWin.calStep(-1)
        Keys.onDownPressed: calWin.calStep(1)
        Keys.onEscapePressed: calWin.closeRequested()

        Item {
            width: parent.width
            height: 30 * calWin.k

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "‹"
                color: Colors.textDim
                font.family: "Hack Nerd Font"
                font.pixelSize: 22 * calWin.k
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * calWin.k
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calWin.calStep(-1)
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.locale("en_US").monthName(calWin.calMonth.getMonth()) + " " + calWin.calMonth.getFullYear()
                color: Colors.primary
                font.family: "Hack Nerd Font"
                font.pixelSize: 17 * calWin.k
                font.weight: Font.DemiBold
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "›"
                color: Colors.textDim
                font.family: "Hack Nerd Font"
                font.pixelSize: 22 * calWin.k
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6 * calWin.k
                    cursorShape: Qt.PointingHandCursor
                    onClicked: calWin.calStep(1)
                }
            }
        }

        Grid {
            id: calGrid
            columns: 8
            width: parent.width
            readonly property real cell: width / 8

            Repeater {
                model: ["W", "Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                Text {
                    required property var modelData
                    width: calGrid.cell
                    height: 26 * calWin.k
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Colors.tertiary
                    font.family: "Hack Nerd Font"
                    font.pixelSize: 13 * calWin.k
                    font.weight: Font.Bold
                }
            }

            Repeater {
                model: {
                    const days = calWin.calDays();
                    const out = [];
                    for (let r = 0; r < 6; r++) {
                        out.push({ week: calWin.isoWeek(days[r * 7]) });
                        for (let c = 0; c < 7; c++)
                            out.push({ day: days[r * 7 + c] });
                    }
                    return out;
                }

                Rectangle {
                    required property var modelData
                    readonly property bool isWeek: modelData.week !== undefined
                    readonly property bool inMonth: !isWeek && modelData.day.getMonth() === calWin.calMonth.getMonth()
                    readonly property bool today: !isWeek && modelData.day.toDateString() === calClock.date.toDateString()
                    width: calGrid.cell
                    height: 36 * calWin.k
                    color: today ? Colors.primary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.isWeek ? parent.modelData.week : parent.modelData.day.getDate()
                        color: parent.today ? Colors.surface : (parent.isWeek ? Colors.outline : (parent.inMonth ? Colors.text : Colors.outlineVariant))
                        font.family: "Hack Nerd Font"
                        font.pixelSize: 15 * calWin.k
                        font.weight: parent.today ? Font.Bold : Font.Normal
                    }
                }
            }
        }

        Item {
            readonly property real yearPct: {
                const d = calClock.date;
                const y = d.getFullYear();
                const start = new Date(y, 0, 1);
                const days = (new Date(y + 1, 0, 1) - start) / 86400000;
                const done = Math.floor((new Date(y, d.getMonth(), d.getDate()) - start) / 86400000);
                return done / (days - 1);
            }
            width: parent.width
            height: 34 * calWin.k

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                text: calClock.date.getFullYear()
                color: Colors.outline
                font.family: "Hack Nerd Font"
                font.pixelSize: 13 * calWin.k
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                text: Math.round(parent.yearPct * 100) + "%"
                color: Colors.outline
                font.family: "Hack Nerd Font"
                font.pixelSize: 13 * calWin.k
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 6 * calWin.k
                color: Colors.surfaceContainerHigh

                Rectangle {
                    width: parent.width * parent.parent.yearPct
                    height: parent.height
                    color: Colors.primary
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => calWin.calStep(wheel.angleDelta.y > 0 ? -1 : 1)
    }
}
