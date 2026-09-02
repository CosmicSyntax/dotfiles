import QtQuick
import Quickshell
import Quickshell.Hyprland

PanelWindow {
	id: topBarRoot

	required property var rootState
	required property var screenState

	anchors {
		top: true
		left: true
		right: true
	}
	margins {
		top: 10
		left: 10
		right: 10
	}

	implicitHeight: 35
	color: "transparent"
	exclusiveZone: 40

	Rectangle {
		anchors.fill: parent
		color: "#2e3440"
		radius: 10
		border.color: Qt.rgba(0.50, 0.63, 0.75, 0.3)
		border.width: 0

		// LEFT: Hyprland Workspaces
		Row {
			anchors {
				left: parent.left
				leftMargin: 18
				verticalCenter: parent.verticalCenter
			}
			spacing: 10

			Repeater {
				model: [1, 2, 3, 4, 5]
				delegate: Rectangle {
					required property int modelData

					readonly property bool isFocused: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData
					readonly property bool exists: {
						for (let i = 0; i < Hyprland.workspaces.values.length; i++) {
							if (Hyprland.workspaces.values[i].id === modelData) return true;
						}
						return false;
					}

					width: isFocused ? 20 : 8
					height: 8
					radius: 4
					color: isFocused ? "#81a1c1" : (exists ? "#d8dee9" : "#4c566a")

					Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
					Behavior on color { ColorAnimation { duration: 180 } }

					MouseArea {
						anchors.fill: parent
						anchors.margins: -4
						cursorShape: Qt.PointingHandCursor
						onClicked: Hyprland.dispatch(`workspace ${modelData}`)
					}
				}
			}
		}

		// CENTER: Clock
		Text {
			id: clockText
			anchors.centerIn: parent
			color: "#eceff4"
			font.pixelSize: 15
			font.bold: true
			font.family: "GoogleSansM Nerd Font"
			text: Qt.formatDateTime(clock.date, "hh:mm | ddd, MMM d")

			SystemClock {
				id: clock
				precision: SystemClock.Minutes
			}
		}

		// RIGHT: Status Modules
		Row {
			anchors {
				right: parent.right
				rightMargin: 10
				verticalCenter: parent.verticalCenter
			}
			spacing: 15

			// DND Indicator
			Text {
				visible: rootState.dndEnabled
				text: "󰂛"
				color: "#ebcb8b"
				font.pixelSize: 14
				font.family: "GoogleSansM Nerd Font"
				anchors.verticalCenter: parent.verticalCenter
			}

			// Volume
			MouseArea {
				width: volText.implicitWidth
				height: parent.height
				cursorShape: Qt.PointingHandCursor
				onClicked: rootState.toggleMute()
				anchors.verticalCenter: parent.verticalCenter

				Text {
					id: volText
					anchors.centerIn: parent
					text: `${rootState.volumeMuted ? "󰝟" : "󰕾"} ${Math.round(rootState.volumeLevel * 100)}%`
					color: rootState.volumeMuted ? "#4c566a" : "#eceff4"
					font.pixelSize: 14
					font.family: "GoogleSansM Nerd Font"
				}
			}

			// Wi-Fi
			Row {
				spacing: 6
				anchors.verticalCenter: parent.verticalCenter

				Text {
					text: rootState.wifiIcon
					color: rootState.wifiEnabled ? "#eceff4" : "#4c566a"
					font.pixelSize: 14
					font.family: "GoogleSansM Nerd Font"
					anchors.verticalCenter: parent.verticalCenter
				}

				Text {
					visible: rootState.wifiEnabled && rootState.wifiSsid !== ""
					text: `${rootState.wifiSsid} ${rootState.wifiSignal}%`
					color: "#eceff4"
					font.pixelSize: 13
					font.family: "GoogleSansM Nerd Font"
					anchors.verticalCenter: parent.verticalCenter
				}
			}

			// Battery
			Text {
				text: `${rootState.batteryIcon} ${rootState.batteryPercentage}%`
				color: rootState.batteryPercentage <= 20 && !rootState.batteryCharging ? "#bf616a" : (rootState.batteryCharging ? "#a3be8c" : "#eceff4")
				font.pixelSize: 14
				font.family: "GoogleSansM Nerd Font"
				anchors.verticalCenter: parent.verticalCenter
			}

			// Dropdown Button
			Rectangle {
				width: 26
				height: 26
				radius: 13
				color: screenState.showControlCenter || toggleArea.containsMouse ? "#434c5e" : "transparent"
				anchors.verticalCenter: parent.verticalCenter

				Text {
					anchors.centerIn: parent
					text: screenState.showControlCenter ? "󰅖" : "󰍜"
					color: "#81a1c1"
					font.pixelSize: 18
					font.family: "GoogleSansM Nerd Font"
				}

				MouseArea {
					id: toggleArea
					anchors.fill: parent
					hoverEnabled: true
					cursorShape: Qt.PointingHandCursor
					onClicked: screenState.showControlCenter = !screenState.showControlCenter
				}
			}
		}
	}
}
