import QtQuick
import QtQml
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Networking
import "."

Scope {
    id: root

    // Initialize states on startup
    Component.onCompleted: {
        updateBrightness();
        // Wi-Fi updates natively now, so we only manually poll Bluetooth/Brightness on startup
        updateBluetooth();
    }

    // Toggle State
    property bool bluetoothEnabled: false
    property bool dndEnabled: false

    // Brightness State
    property real brightnessLevel: 1.00

    // Night Shift State
    property bool nightShiftEnabled: false

    // Caffeine Mode State
    property bool caffeineEnabled: false

    // ----------------------------------------------------
    // AUDIO (Pipewire)
    // ----------------------------------------------------
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property real volumeLevel: sink?.audio?.volume ?? 0.0
    readonly property bool volumeMuted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    function setVolume(val) {
        if (!sink?.ready || !sink.audio) return;
        sink.audio.muted = false;
        sink.audio.volume = Math.min(Math.max(val, 0.0), 1.0);
    }

    function toggleMute() {
        if (sink?.ready && sink.audio) sink.audio.muted = !sink.audio.muted;
    }

    function toggleMic() {
        if (source?.ready && source.audio) source.audio.muted = !source.audio.muted;
    }

    // ----------------------------------------------------
    // BATTERY (UPower)
    // ----------------------------------------------------
    readonly property UPowerDevice battery: UPower.displayDevice ?? (UPower.devices.values.length > 0 ? UPower.devices.values[0] : null)
    readonly property int batteryPercentage: {
        let p = battery?.percentage ?? 1.0;
        return Math.round(p <= 1.0 ? p * 100 : p);
    }
    
    readonly property bool batteryCharging: battery?.state === UPowerDeviceState.Charging || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool batteryFull: battery?.state === UPowerDeviceState.FullyCharged
    
    readonly property string batteryIcon: {
        if (root.batteryCharging) return "󰂄"
        let pct = root.batteryPercentage;
        if (pct >= 95) return "󰁹"
        if (pct >= 90) return "󰂂"
        if (pct >= 80) return "󰂁"
        if (pct >= 70) return "󰂀"
        if (pct >= 60) return "󰁿"
        if (pct >= 50) return "󰁾"
        if (pct >= 40) return "󰁽"
        if (pct >= 30) return "󰁼"
        if (pct >= 20) return "󰁻"
        if (pct >= 10) return "󰁺"
        return "󰂃"
    }

    // ----------------------------------------------------
    // POWER PROFILE (PowerProfiles)
    // ----------------------------------------------------
    readonly property string activeProfile: {
        switch (PowerProfiles.profile) {
            case PowerProfile.PowerSaver:  return "power-saver";
            case PowerProfile.Performance: return "performance";
            default:                       return "balanced";
        }
    }

    function setPowerProfile(profile) {
        switch (profile) {
            case "power-saver": PowerProfiles.profile = PowerProfile.PowerSaver; break;
            case "performance": PowerProfiles.profile = PowerProfile.Performance; break;
            default:            PowerProfiles.profile = PowerProfile.Balanced; break;
        }
    }

    // ----------------------------------------------------
    // NIGHT SHIFT (hyprsunset)
    // ----------------------------------------------------
    Process {
        id: getNightShiftProc
        stdout: SplitParser {
			onRead: data => root.nightShiftEnabled = (data.trim() === "on");
        }
    }

    function updateNightShift() {
        getNightShiftProc.exec(["sh", "-c", "hyprctl hyprsunset temperature 2>/dev/null | awk '$1 < 6000 {found=1} END {exit !found}' && echo on || echo off"]);
    }

    function toggleNightShift() {
        let targetState = !root.nightShiftEnabled;
        root.nightShiftEnabled = targetState;
        if (targetState) {
            runSystemCommand("hyprctl hyprsunset temperature 4500");
        } else {
            runSystemCommand("hyprctl hyprsunset temperature 6000 && hyprctl hyprsunset identity");
            //runSystemCommand("hyprctl hyprsunset identity");
        }
    }

    // ----------------------------------------------------
    // CAFFEINE MODE (systemd-inhibit)
    // ----------------------------------------------------
    function toggleCaffeine() {
        caffeineEnabled = !caffeineEnabled;
        if (caffeineEnabled) {
            runSystemCommand("systemd-inhibit --what=idle --why='User requested caffeine' sleep infinity &");
        } else {
            runSystemCommand("pkill -f 'systemd-inhibit.*sleep infinity'");
        }
    }

    // ----------------------------------------------------
    // WI-FI (Event-driven via Native Quickshell.Networking)
    // ----------------------------------------------------
    property var wifiAdapter: {
        let devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++) {
            if (devs[i].type === DeviceType.Wifi) return devs[i];
        }
        return null;
    }

    property var activeWifiConnection: {
        if (!wifiAdapter) return null;
        let nets = wifiAdapter.networks.values;
        for (let i = 0; i < nets.length; i++) {
            if (nets[i].connected) return nets[i];
        }
        return null;
    }

    property bool wifiEnabled: Networking.wifiEnabled
    property string wifiSsid: activeWifiConnection ? activeWifiConnection.name : ""
    property int wifiSignal: activeWifiConnection ? Math.round(activeWifiConnection.signalStrength * 100) : 0
    property string wifiIcon: "󰖪"

    onWifiEnabledChanged: updateWifiIcon()
    onWifiSsidChanged: updateWifiIcon()
    onWifiSignalChanged: updateWifiIcon()

    function updateWifiIcon() {
        if (!root.wifiEnabled) {
            root.wifiIcon = "󰖪" 
        } else if (root.wifiSsid === "" || root.wifiSignal === 0) {
            root.wifiIcon = "󰤯" 
        } else if (root.wifiSignal >= 75) {
            root.wifiIcon = "󰤨"
        } else if (root.wifiSignal >= 50) {
            root.wifiIcon = "󰤥"
        } else if (root.wifiSignal >= 25) {
            root.wifiIcon = "󰤢"
        } else {
            root.wifiIcon = "󰤟"
        }
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ----------------------------------------------------
    // BRIGHTNESS (Event-driven via udevadm monitor)
    // ----------------------------------------------------
    Process {
        id: getBrightProc
        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split(',');
                if (parts.length >= 4) {
                    let val = parseFloat(parts[3].replace('%', ''));
                    if (!isNaN(val)) root.brightnessLevel = Math.min(Math.max(val / 100.0, 0.05), 1.0);
                }
            }
        }
    }

    Process {
        id: brightMonitorProc
        running: true
        command: ["stdbuf", "-oL", "udevadm", "monitor", "--subsystem-match=backlight"]
        stdout: SplitParser {
            onRead: _ => { root.updateBrightness(); }
        }
    }

    function updateBrightness() {
        getBrightProc.exec(["brightnessctl", "-m"]);
    }

    Process { id: setBrightProc }
    
    function setBrightness(val) {
        root.brightnessLevel = Math.min(Math.max(val, 0.05), 1.0);
        // setBrightProc.exec(["brightnessctl", "set", `${Math.round(root.brightnessLevel * 100)}%`]);
		setBrightProc.exec(["brightnessctl", "-d", "intel_backlight", "set", `${Math.round(root.brightnessLevel * 100)}%`]);
    }

    // ----------------------------------------------------
    // BLUETOOTH (Event-driven via bluetoothctl monitor)
    // ----------------------------------------------------
    Process {
        id: getBtProc
        stdout: SplitParser {
            onRead: data => {
                root.bluetoothEnabled = data.trim().includes("Powered: yes");
            }
        }
    }

    Process {
        id: btMonitorProc
        running: true
        command: ["bluetoothctl", "monitor"]
        stdout: SplitParser {
            onRead: _ => { updateBluetooth(); }
        }
    }
         
    function updateBluetooth() {
        getBtProc.exec(["bluetoothctl", "show"]);
    }

    function toggleBluetooth() {
        root.bluetoothEnabled = !root.bluetoothEnabled;
        actionProc.exec(["bluetoothctl", "power", root.bluetoothEnabled ? "on" : "off"]);
    }

    // ----------------------------------------------------
    // EXTERNAL SETTINGS APPS
    // ----------------------------------------------------
    Process { id: actionProc }
    Process { id: appLaunchProc }
    
    function runSystemCommand(cmd) { actionProc.exec(["sh", "-c", cmd]); }
    function openWifiSettings() { appLaunchProc.exec(["sh", "-c", "nm-connection-editor || foot -e nmtui"]); }
    function openBluetoothSettings() { appLaunchProc.exec(["sh", "-c", "blueman-manager || blueberry || foot -e bluetoothctl"]); }
    function openAudioSettings() { appLaunchProc.exec(["sh", "-c", "pavucontrol || helvum || foot -e alsamixer"]); }

    // ----------------------------------------------------
    // NOTIFICATION SERVER & MODELS
    // ----------------------------------------------------
    ListModel { id: notifHistoryModel }
    ListModel { id: activeToastModel }
    
    readonly property int defaultToastTimeout: 5000
    
    NotificationServer {
        id: notifServer
        actionsSupported: true
        imageSupported: true
        onNotification: notif => {
            if (!notif) return;
            notif.tracked = true;
            let summaryText = notif.summary ? notif.summary.toString() : "Notification";
            let bodyText = notif.body ? notif.body.toString() : "";
            let timeStr = Qt.formatTime(new Date(), "hh:mm");
            let nId = notif.id;
            let dEntry = notif.desktopEntry ? notif.desktopEntry.toString() : "";
            let timeoutMs = root.defaultToastTimeout;
            
            if (notif.urgency === NotificationUrgency.Critical) {
                timeoutMs = 0;
            } else if (notif.expireTimeout > 0) {
                timeoutMs = notif.expireTimeout * 1000;
            }
            
            notifHistoryModel.insert(0, {
                "notifId": nId,
                "summary": summaryText,
                "body": bodyText,
                "time": timeStr,
                "appName": dEntry
            });
            
            if (!root.dndEnabled) {
                activeToastModel.insert(0, {
                    "notifId": nId,
                    "summary": summaryText,
                    "body": bodyText,
                    "appName": dEntry,
                    "timeoutMs": timeoutMs
                });
            }
        }
    }

    function findNotification(nId) {
        let tracked = notifServer.trackedNotifications.values;
        for (let i = 0; i < tracked.length; i++) {
            if (tracked[i].id == nId) return tracked[i];
        }
        return null;
    }

    function removeFromModel(model, nId) {
        for (let i = 0; i < model.count; i++) {
            if (model.get(i).notifId == nId) {
                model.remove(i);
                return;
            }
        }
    }

    Connections {
        target: notifServer.trackedNotifications
        function onObjectRemovedPost(object, index) {
            root.removeFromModel(notifHistoryModel, object.id);
            root.removeFromModel(activeToastModel, object.id);
        }
    }

    function triggerAction(nId, appName) {
        let actionFired = false;
        let n = root.findNotification(nId);
        if (n) {
            let chosen = null;
            for (let j = 0; j < n.actions.length; j++) {
                if (n.actions[j].identifier === "default") {
                    chosen = n.actions[j];
                    break;
                }
            }
            if (!chosen && n.actions.length > 0) chosen = n.actions[0];
            if (chosen) {
                chosen.invoke();
                actionFired = true;
            } else {
                n.dismiss();
            }
        }
        
        if (!actionFired && appName && appName !== "") {
            let cleanName = appName.replace(".desktop", "");
            appLaunchProc.exec([
                "hyprctl", "dispatch", "focuswindow", `class:(?i)${cleanName}`
            ]);
        }
    }

    function activateNotification(nId) {
        let appName = "";
        for (let i = 0; i < notifHistoryModel.count; i++) {
            if (notifHistoryModel.get(i).notifId == nId) {
                appName = notifHistoryModel.get(i).appName;
                break;
            }
        }
        root.removeFromModel(activeToastModel, nId);
        root.removeFromModel(notifHistoryModel, nId);
        root.triggerAction(nId, appName);
    }

    function executeToastAction(nId) {
        root.activateNotification(nId);
    }

    function executeNotification(nId) {
        root.activateNotification(nId);
    }

    function dismissToast(nId) {
        root.removeFromModel(activeToastModel, nId);
    }

    function removeNotification(nId) {
        let n = root.findNotification(nId);
        if (n) n.dismiss();
        root.removeFromModel(notifHistoryModel, nId);
        root.removeFromModel(activeToastModel, nId);
    }

    function clearAllNotifications() {
        for (let i = 0; i < notifHistoryModel.count; i++) {
            let n = root.findNotification(notifHistoryModel.get(i).notifId);
            if (n) n.dismiss();
        }
        notifHistoryModel.clear();
        activeToastModel.clear();
    }

    // ----------------------------------------------------
    // WINDOW INSTANCES
    // ----------------------------------------------------
    Instantiator {
        model: Quickshell.screens
        delegate: Scope {
            id: screenScope
            required property var modelData
            
            property bool showControlCenter: false
            property bool animVisible: false 
            
            onShowControlCenterChanged: {
                if (showControlCenter) {
                    root.updateNightShift();
                }
            }
            
            TopBar {
                id: topBar
                rootState: root
                screenState: screenScope
                screen: modelData
            }
            
            PanelWindow {
                id: dismissBackdrop
                screen: modelData
                visible: screenScope.animVisible
                color: "transparent"
                anchors { top: true; bottom: true; left: true; right: true; }
                MouseArea {
                    anchors.fill: parent
                    onClicked: screenScope.showControlCenter = false
                }
            }
            
            ControlCenter {
                id: controlCenter
                rootState: root
                screenState: screenScope
                topBarWindow: topBar
                historyModel: notifHistoryModel
            }
            
            NotificationToasts {
                id: notificationToasts
                rootState: root
                toastModel: activeToastModel
                screen: modelData
            }
        }
    }
}
