import QtQuick
import QtQuick.Controls
import Quickshell
import "components"

PopupWindow {
    id: ccWindow
         
    required property var rootState
    required property var topBarWindow
    required property var historyModel
    required property var screenState
    
    anchor.window: topBarWindow
    anchor.rect.x: topBarWindow.width - implicitWidth
    anchor.rect.y: topBarWindow.height + 10
         
    implicitWidth: 650
    implicitHeight: 630
    visible: screenState.animVisible
    color: "transparent"
    
    Rectangle {
        id: popupContainer
        anchors.fill: parent
        color: "#2e3440"
        radius: 16
        border.color: Qt.rgba(0.50, 0.63, 0.75, 0.3)
        border.width: 1
        opacity: 0.0
        y: -15
        
        ParallelAnimation {
            id: enterAnim
            NumberAnimation { target: popupContainer; property: "opacity"; to: 1.0; duration: 160; easing.type: Easing.OutCubic }
            NumberAnimation { target: popupContainer; property: "y"; to: 0; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        }
        
        ParallelAnimation {
            id: exitAnim
            NumberAnimation { target: popupContainer; property: "opacity"; to: 0.0; duration: 140; easing.type: Easing.InQuad }
            NumberAnimation { target: popupContainer; property: "y"; to: -15; duration: 140; easing.type: Easing.InQuad }
            onFinished: screenState.animVisible = false
        }
        
        Connections {
            target: screenState
            function onShowControlCenterChanged() {
                if (screenState.showControlCenter) {
                    screenState.animVisible = true;
                    enterAnim.restart();
                } else {
                    exitAnim.restart();
                }
            }
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14
            
            Column {
                spacing: 4
                Text { text: "Control Center"; color: "#eceff4"; font.pixelSize: 18; font.bold: true; font.family: "GoogleSansM Nerd Font" }
                Text { text: "Focused system controls"; color: "#d8dee9"; font.pixelSize: 13; font.family: "GoogleSansM Nerd Font" }
            }
                         
            Row {
                spacing: 15
                                 
                Column {
                    spacing: 15
                                         
                    SliderCard {
                        icon: rootState.volumeMuted ? "󰝟" : (rootState.volumeLevel < 0.5 ? "󰖀" : "󰕾")
                        iconColor: "#81a1c1"
                        title: "Output volume"
                        value: rootState.volumeLevel
                        onValueChangedByUser: val => rootState.setVolume(val)
                        onRightClicked: rootState.openAudioSettings()
                    }
                    
                    SliderCard {
                        visible: ccWindow.topBarWindow && ccWindow.topBarWindow.screen 
                                 ? ccWindow.topBarWindow.screen.name.startsWith("eDP") 
                                 : false
                        icon: "󰃠"
                        iconColor: "#b48ead"
                        title: "Display brightness"
                        value: rootState.brightnessLevel
                        onValueChangedByUser: val => rootState.setBrightness(val)
                    }
                }
                
                Grid {
                    columns: 3
                    spacing: 10
                                         
                    QuickToggle {
                        icon: rootState.wifiIcon
                        title: rootState.wifiSsid !== "" ? (rootState.wifiSsid.length > 8 ? rootState.wifiSsid.substring(0, 7) + "…" : rootState.wifiSsid) : "Wi-Fi"
                        active: rootState.wifiEnabled
                        onToggled: rootState.toggleWifi()
                        onRightClicked: rootState.openWifiSettings()
                    }
                    
                    QuickToggle {
                        icon: rootState.bluetoothEnabled ? "󰂯" : "󰂲"
                        title: "Bluetooth"
                        active: rootState.bluetoothEnabled
                        onToggled: rootState.toggleBluetooth()
                        onRightClicked: rootState.openBluetoothSettings()
                    }
                    
                    QuickToggle {
                        icon: rootState.micMuted ? "󰍭" : "󰍬"
                        title: rootState.micMuted ? "Muted" : "Mic On"
                        active: rootState.micMuted
                        activeColor: "#bf616a"
                        onToggled: rootState.toggleMic()
                    }
                    
                    QuickToggle {
                        icon: rootState.dndEnabled ? "󰂛" : "󰂚"
                        title: "DND"
                        active: rootState.dndEnabled
                        activeColor: "#ebcb8b"
                        onToggled: rootState.dndEnabled = !rootState.dndEnabled
                    }
                    
                    QuickToggle {
                        icon: "󰃟"
                        title: "Night Shift"
                        active: rootState.nightShiftEnabled
                        activeColor: "#ebcb8b"
                        onToggled: rootState.toggleNightShift()
                    }
                    
                    QuickToggle {
                        icon: rootState.caffeineEnabled ? "󰅶" : "󰾫"
                        title: "Caffeine"
                        active: rootState.caffeineEnabled
                        activeColor: "#ebcb8b"
                        onToggled: rootState.toggleCaffeine()
                    }
                }
            }
            
            Row {
                spacing: 15
                                 
                Repeater {
                    model: [
                        { id: "power-saver", name: "  Power saver" },
                        { id: "balanced",    name: "󰾆  Balanced" },
                        { id: "performance", name: "󰓅  Performance" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        
                        width: 195
                        height: 40
                        radius: 10
                        color: rootState.activeProfile === modelData.id ? "#81a1c1" : "transparent"
                        border.color: rootState.activeProfile === modelData.id ? "#81a1c1" : "#4c566a"
                        border.width: 1
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.name
                            color: rootState.activeProfile === modelData.id ? "#2e3440" : "#d8dee9"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "GoogleSansM Nerd Font"
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: rootState.setPowerProfile(modelData.id)
                        }
                    }
                }
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(0.50, 0.63, 0.75, 0.2)
            }
            
            Item {
                width: parent.width
                height: 20
                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: `Notifications (${ccWindow.historyModel.count})`
                    color: "#eceff4"
                    font.pixelSize: 14
                    font.bold: true
                    font.family: "GoogleSansM Nerd Font"
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: ccWindow.historyModel.count > 0
                    text: "Clear All"
                    color: "#81a1c1"
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "GoogleSansM Nerd Font"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootState.clearAllNotifications()
                    }
                }
            }
            
            ListView {
                id: historyListView
                width: parent.width
                height: 190
                clip: true
                spacing: 8
                model: ccWindow.historyModel
                delegate: Rectangle {
                    width: historyListView.width
                    height: 52
                    radius: 10
                    color: "#3b4252"
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            rootState.executeNotification(model.notifId);
                            screenState.showControlCenter = false;
                        }
                    }
                    Row {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Text {
                            text: "󰂚"
                            color: "#81a1c1"
                            font.pixelSize: 16
                            font.family: "GoogleSansM Nerd Font"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            width: parent.width - 70
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Row {
                                spacing: 8
                                Text {
                                    text: model.summary || ""
                                    textFormat: Text.PlainText
                                    color: "#eceff4"
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.family: "GoogleSansM Nerd Font"
                                    elide: Text.ElideRight
                                    width: 370
                                }
                                Text {
                                    text: model.time || ""
                                    color: "#4c566a"
                                    font.pixelSize: 10
                                    font.family: "GoogleSansM Nerd Font"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                text: model.body || ""
                                textFormat: Text.PlainText
                                color: "#d8dee9"
                                font.pixelSize: 11
                                font.family: "GoogleSansM Nerd Font"
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                        Text {
                            text: "󰅖"
                            color: "#4c566a"
                            font.pixelSize: 14
                            font.family: "GoogleSansM Nerd Font"
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                propagateComposedEvents: false
                                onClicked: mouse => {
                                    mouse.accepted = true;
                                    rootState.removeNotification(model.notifId);
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: ccWindow.historyModel.count === 0
                    anchors.centerIn: parent
                    text: "No notifications"
                    color: "#4c566a"
                    font.pixelSize: 13
                    font.family: "GoogleSansM Nerd Font"
                }
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: Qt.rgba(0.50, 0.63, 0.75, 0.2)
            }
            
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 35
                Repeater {
                    model: [
                        { icon: "󰌾", action: "pidof hyprlock || hyprlock", color: "#eceff4" },
                        { icon: "󰤄", action: "systemctl suspend", color: "#eceff4" },
                        { icon: "󰍃", action: "uwsm stop", color: "#eceff4" },
                        { icon: "󰜉", action: "systemctl reboot", color: "#eceff4" },
                        { icon: "󰐥", action: "systemctl poweroff", color: "#bf616a" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 44
                        height: 44
                        radius: 22
                        color: hoverArea.containsMouse ? "#434c5e" : "transparent"
                                                 
                        Behavior on color { ColorAnimation { duration: 150 } }
                        
                        Text {
                            anchors.centerIn: parent
                            text: modelData.icon
                            color: modelData.color
                            font.pixelSize: 22
                            font.family: "GoogleSansM Nerd Font"
                        }
                        
                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                screenState.showControlCenter = false;
                                rootState.runSystemCommand(modelData.action);
                            }
                        }
                    }
                }
            }
        }
    }
}
