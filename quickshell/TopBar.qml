import QtQuick
import Quickshell

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
		color: Theme.bgDark
		radius: 8
		border.color: Qt.rgba(0.50, 0.63, 0.75, 0.3)
		border.width: 0

		// LEFT: Niri Workspaces
		Row {
			anchors {
				left: parent.left
				leftMargin: 18
				verticalCenter: parent.verticalCenter
			}
			spacing: 15

			Repeater {
				model: niri.workspaces

				Rectangle {
					visible: index < 11
					width: 10
					height: 10
					radius: 10
					color: model.isActive ? Theme.accent : "#d8dee9"
					MouseArea {
						anchors.fill: parent
						cursorShape: Qt.PointingHandCursor
						onClicked: niri.focusWorkspaceById(model.id)
					}
				}
			}

		}

		// CENTER: Clock
		Text {
			id: clockText
			anchors.centerIn: parent
			color: Theme.fgMain
			font.pixelSize: 15
			font.bold: true
			font.family: Theme.fontFamily
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
				font.family: Theme.fontFamily
				anchors.verticalCenter: parent.verticalCenter
			}

			// Caffeine Indicator
			Text {
				visible: rootState.caffeineEnabled
				text: "󰅶"
				color: "#ebcb8b"
				font.pixelSize: 14
				font.family: Theme.fontFamily
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
					color: rootState.volumeMuted ? "#4c566a" : Theme.fgMain
					font.pixelSize: 14
					font.family: Theme.fontFamily
				}
			}

			// Wi-Fi
			Row {
				spacing: 6
				anchors.verticalCenter: parent.verticalCenter

				Text {
					text: rootState.wifiIcon
					color: rootState.wifiEnabled ? Theme.fgMain : "#4c566a"
					font.pixelSize: 14
					font.family: Theme.fontFamily
					anchors.verticalCenter: parent.verticalCenter
				}

				Text {
					visible: rootState.wifiEnabled && rootState.wifiSsid !== ""
					text: `${rootState.wifiSsid} ${rootState.wifiSignal}%`
					color: Theme.fgMain
					font.pixelSize: 13
					font.family: Theme.fontFamily
					anchors.verticalCenter: parent.verticalCenter
				}
			}

			// Battery
			Text {
				text: `${rootState.batteryIcon} ${rootState.batteryPercentage}%`
				color: rootState.batteryPercentage <= 20 && !rootState.batteryCharging ? "#bf616a" : (rootState.batteryCharging ? "#a3be8c" : Theme.fgMain)
				font.pixelSize: 14
				font.family: Theme.fontFamily
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
					color: Theme.accent
					font.pixelSize: 18
					font.family: Theme.fontFamily
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
