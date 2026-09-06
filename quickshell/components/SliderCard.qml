import QtQuick
import ".."

Rectangle {
    id: sliderRoot

    property string icon: ""
    property color iconColor: Theme.accent
    property string title: ""
    property real value: 0.0

    signal valueChangedByUser(real newValue)
    signal rightClicked()

    width: 240
    height: 75
    radius: 12
    color: Theme.bgLight

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: sliderRoot.rightClicked()
    }

    Text {
        text: sliderRoot.icon
        color: sliderRoot.iconColor
        font.pixelSize: 22
        font.family: Theme.fontFamily
        anchors.left: parent.left
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 52
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Text {
            text: sliderRoot.title
            color: Theme.fgMain
            font.pixelSize: 13
            font.bold: true
            font.family: Theme.fontFamily
        }

        Rectangle {
            id: track
            width: 165
            height: 8
            radius: 4
            color: "#4c566a"

            Rectangle {
                width: parent.width * sliderRoot.value
                height: parent.height
                radius: 4
                color: sliderRoot.iconColor
            }

            MouseArea {
                id: hitArea
                anchors.fill: parent
                anchors.margins: -hitArea.hitMargin
                acceptedButtons: Qt.LeftButton | Qt.RightButton

                // The hit area is grown by hitMargin on every side, so its
                // origin sits that far left of the track. mouse.x must be
                // shifted back or every value is skewed by 6/165 (~3.6%).
                readonly property int hitMargin: 6

                function fraction(x) {
                    return Math.min(Math.max((x - hitArea.hitMargin) / track.width, 0.0), 1.0);
                }

                onPositionChanged: mouse => {
                    if (pressed && (mouse.buttons & Qt.LeftButton)) {
                        sliderRoot.valueChangedByUser(hitArea.fraction(mouse.x));
                    }
                }
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        sliderRoot.rightClicked();
                    } else {
                        sliderRoot.valueChangedByUser(hitArea.fraction(mouse.x));
                    }
                }
            }
        }
    }

    Text {
        text: `${Math.round(sliderRoot.value * 100)}%`
        color: "#d8dee9"
        font.pixelSize: 12
        anchors.right: parent.right
        anchors.rightMargin: 15
        anchors.top: parent.top
        anchors.topMargin: 15
        font.family: Theme.fontFamily
    }
}
