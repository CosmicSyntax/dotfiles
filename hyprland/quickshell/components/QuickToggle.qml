import QtQuick

Rectangle {
    id: toggleRoot
    
    property string icon: ""
    property string title: ""
    property bool active: false
    property color activeColor: "#81a1c1"
    
    signal toggled()
    signal rightClicked()

    width: 115
    height: 75
    radius: 12
    color: active ? "#434c5e" : "#3b4252"
    border.color: active ? activeColor : "transparent"
    border.width: 1

    Column { 
        anchors.centerIn: parent
        spacing: 4

        Text { 
            text: toggleRoot.icon
            color: toggleRoot.active ? toggleRoot.activeColor : "#d8dee9"
            font.pixelSize: 20
            font.family: "GoogleSansCode Nerd Font"
            anchors.horizontalCenter: parent.horizontalCenter 
        }

        Text { 
            text: toggleRoot.title
            color: "#eceff4"
            font.pixelSize: 13
            font.bold: true
            font.family: "GoogleSansCode Nerd Font"
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
