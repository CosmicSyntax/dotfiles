import QtQuick
import ".."

Rectangle {
    id: toggleRoot
    
    property string icon: ""
    property string title: ""
    property bool active: false
    property color activeColor: Theme.accent
    
    signal toggled()
    signal rightClicked()

    width: 115
    height: 75
    radius: 12
    color: active ? "#434c5e" : Theme.bgLight
    border.color: active ? activeColor : "transparent"
    border.width: 1

    Column { 
        anchors.centerIn: parent
        spacing: 4

        Text { 
            text: toggleRoot.icon
            color: toggleRoot.active ? toggleRoot.activeColor : "#d8dee9"
            font.pixelSize: 20
            font.family: Theme.fontFamily
            anchors.horizontalCenter: parent.horizontalCenter 
        }

        Text { 
            text: toggleRoot.title
            color: Theme.fgMain
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
            anchors.horizontalCenter: parent.horizontalCenter 
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                toggleRoot.rightClicked();
            } else {
                toggleRoot.toggled();
            }
        }
    }
}
