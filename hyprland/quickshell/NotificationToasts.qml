import QtQuick
import Quickshell

PanelWindow {
    id: toastWindow

    required property var rootState
    required property var toastModel

    anchors {
        top: true
        right: true
    }
    margins {
        top: 54
        right: 20
    }

    implicitWidth: 360
    implicitHeight: toastCol.implicitHeight + 10
    color: "transparent"

    visible: toastModel.count > 0 && !rootState.dndEnabled

    Column {
        id: toastCol
        spacing: 10
        width: parent.width

        Repeater {
            model: toastModel

            delegate: Rectangle {
                id: toastCard

                required property int index
                required property var model

                width: toastCol.width
                height: contentCol.implicitHeight + 24
                radius: 12
                color: "#2e3440"
                border.color: Qt.rgba(0.50, 0.63, 0.75, 0.4)
                border.width: 1

                // Timeout comes from the notification itself now; 0 means
                // "never expire" (critical urgency).
                Timer {
                    interval: toastCard.model.timeoutMs
                    running: toastCard.model.timeoutMs > 0
                    onTriggered: toastWindow.rootState.dismissToast(toastCard.model.notifId)
                }

                Row {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12

                    Rectangle {
                        width: 36
                        height: 36
                        radius: 8
                        color: "#3b4252"
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            anchors.centerIn: parent
                            text: "󰂚"
                            color: "#81a1c1"
                            font.pixelSize: 18
                            font.family: "GoogleSansCode Nerd Font"
                        }
                    }

                    Column {
                        id: contentCol
                        width: parent.width - 48
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3

                        Text {
                            text: toastCard.model.summary || ""
                            color: "#eceff4"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "GoogleSansCode Nerd Font"
                            // Apps send markup regardless of advertised caps.
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: toastCard.model.body || ""
                            color: "#d8dee9"
                            font.pixelSize: 12
                            font.family: "GoogleSansCode Nerd Font"
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            width: parent.width
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toastWindow.rootState.executeToastAction(toastCard.model.notifId)
                }
            }
        }
    }
}
