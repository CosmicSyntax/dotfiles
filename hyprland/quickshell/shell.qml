import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import "."

Scope {
    id: root

    // UI States
    property bool showControlCenter: false
    property bool animVisible: false

    // Wi-Fi State
    property bool wifiEnabled: true
    property string wifiSsid: ""
    property int wifiSignal: 0
    property string wifiIcon: "󰤨"

    // Toggle State
    property bool bluetoothEnabled: false
    property bool dndEnabled: false

    // Brightness (no native service; driven by brightnessctl)
    property real brightnessLevel: 1.00

    // ----------------------------------------------------
    // AUDIO (Pipewire)
    // ----------------------------------------------------
    // audio properties are only valid on bound nodes.
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
    readonly property bool batteryCharging:
        battery?.state === UPowerDeviceState.Charging
        || battery?.state === UPowerDeviceState.PendingCharge
    readonly property bool batteryFull: battery?.state === UPowerDeviceState.FullyCharged
    readonly property string batteryIcon: {
        if (root.batteryCharging) return "󰂄";
        let pct = root.batteryPercentage;
        if (pct >= 95) return "󰁹";
        if (pct >= 90) return "󰂂";
        if (pct >= 80) return "󰂁";
        if (pct >= 70) return "󰂀";
        if (pct >= 60) return "󰁿";
        if (pct >= 50) return "󰁾";
        if (pct >= 40) return "󰁽";
        if (pct >= 30) return "󰁼";
        if (pct >= 20) return "󰁻";
        if (pct >= 10) return "󰁺";
        return "󰂃";
    }
    // ----------------------------------------------------
    // POWER PROFILE (PowerProfiles)
    // ----------------------------------------------------
    // ControlCenter still speaks in the string ids it always did.
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
    // WI-FI
    // ----------------------------------------------------
    function updateWifiIcon() {
        if (!root.wifiEnabled) {
            root.wifiIcon = "󰖪";
        } else if (root.wifiSsid === "" || root.wifiSignal === 0) {
            root.wifiIcon = "󰤭";
        } else if (root.wifiSignal >= 75) {
            root.wifiIcon = "󰤨";
        } else if (root.wifiSignal >= 50) {
            root.wifiIcon = "󰤥";
        } else if (root.wifiSignal >= 25) {
            root.wifiIcon = "󰤢";
        } else {
            root.wifiIcon = "󰤟";
        }
    }

    Process {
        id: getWifiProc
        running: true
        command: [
            "sh", "-c",
            "if [ \"$(nmcli radio wifi 2>/dev/null)\" != 'enabled' ]; then " +
            "  echo 'disabled::0'; " +
            "else " +
            "  DEV_LINE=$(nmcli -t -f DEVICE,TYPE,STATE,CONNECTION dev 2>/dev/null | awk -F: '$2==\"wifi\" && $3==\"connected\" {print $1 \":\" $4; exit}'); " +
            "  if [ -n \"$DEV_LINE\" ]; then " +
            "    IFACE=$(echo \"$DEV_LINE\" | cut -d: -f1); " +
            "    SSID=$(echo \"$DEV_LINE\" | cut -d: -f2-); " +
            "    SIG=$(awk -v dev=\"$IFACE:\" '$1==dev {sub(/\\./, \"\", $3); print int($3 * 100 / 70)}' /proc/net/wireless 2>/dev/null); " +
            "    [ -z \"$SIG\" ] && SIG=80; " +
            "    echo \"connected:${SSID}:${SIG}\"; " +
            "  else " +
            "    echo 'disconnected::0'; " +
            "  fi; " +
            "fi"
        ]
        stdout: SplitParser {
            onRead: data => {
                let line = data.trim();
                if (!line) return;
                let parts = line.split(":");
                let status = parts[0] || "";

                if (status === "disabled") {
                    root.wifiEnabled = false;
                    root.wifiSsid = "";
                    root.wifiSignal = 0;
                } else if (status === "connected" && parts.length >= 3) {
                    root.wifiEnabled = true;
                    root.wifiSignal = parseInt(parts[parts.length - 1]) || 80;
                    root.wifiSsid = parts.slice(1, parts.length - 1).join(":");
                } else {
                    root.wifiEnabled = true;
                    root.wifiSsid = "";
                    root.wifiSignal = 0;
                }
                root.updateWifiIcon();
            }
        }
    }

    // One long-lived process instead of a poll: nmcli emits a line whenever
    // radio, device or connection state changes. Signal strength still needs
    // sampling, which the slow timer below handles.
    Process {
        id: nmMonitorProc
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: _ => {
                getWifiProc.running = false;
                getWifiProc.running = true;
            }
        }
    }

    function toggleWifi() {
        root.wifiEnabled = !root.wifiEnabled;
        actionProc.exec(["nmcli", "radio", "wifi", root.wifiEnabled ? "on" : "off"]);
    }

    // ----------------------------------------------------
    // BRIGHTNESS / BLUETOOTH (still shelling out)
    // ----------------------------------------------------
    Process {
        id: getBrightProc
        running: true
        command: ["sh", "-c", "brightnessctl -m | cut -d, -f4 | tr -d '%'"]
        stdout: SplitParser {
            onRead: data => {
                let val = parseFloat(data.trim());
                if (!isNaN(val)) root.brightnessLevel = Math.min(Math.max(val / 100.0, 0.05), 1.0);
            }
        }
    }

    Process { id: setBrightProc }
    function setBrightness(val) {
        root.brightnessLevel = Math.min(Math.max(val, 0.05), 1.0);
        setBrightProc.exec(["brightnessctl", "set", `${Math.round(root.brightnessLevel * 100)}%`]);
    }

    Process {
        id: getBtProc
        running: true
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: SplitParser {
            onRead: data => root.bluetoothEnabled = (data.trim() === "on")
        }
    }

    function toggleBluetooth() {
        root.bluetoothEnabled = !root.bluetoothEnabled;
        actionProc.exec(["bluetoothctl", "power", root.bluetoothEnabled ? "on" : "off"]);
    }

    // Only brightness, bluetooth and wifi signal strength still need sampling.
    // Everything else is now event driven.
    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            getBrightProc.running = false; getBrightProc.running = true;
            getBtProc.running = false;     getBtProc.running = true;
            getWifiProc.running = false;   getWifiProc.running = true;
        }
    }

    // ----------------------------------------------------
    // EXTERNAL SETTINGS APPS
    // ----------------------------------------------------
    Process { id: actionProc }
    Process { id: appLaunchProc }

	function runSystemCommand(cmd) {
        actionProc.exec(["sh", "-c", cmd]);
    }

    function openWifiSettings() {
        appLaunchProc.exec(["sh", "-c", "nm-connection-editor || foot -e nmtui"]);
    }

    function openBluetoothSettings() {
        appLaunchProc.exec(["sh", "-c", "blueman-manager || blueberry || foot -e bluetoothctl"]);
    }

    function openAudioSettings() {
        appLaunchProc.exec(["sh", "-c", "pavucontrol || helvum || foot -e alsamixer"]);
    }

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

            // Without this the Notification object (and its actions) is
            // discarded as soon as this handler returns.
            notif.tracked = true;

            let summaryText = notif.summary ? notif.summary.toString() : "Notification";
            let bodyText = notif.body ? notif.body.toString() : "";
            let timeStr = Qt.formatTime(new Date(), "hh:mm");
            let nId = notif.id;
            let dEntry = notif.desktopEntry ? notif.desktopEntry.toString() : "";

            // expireTimeout is in seconds; <= 0 means "server decides".
            // Critical notifications are not supposed to auto-expire.
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

    // Look up a live Notification by the id we stored in the models.
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

    // Notifications are now tracked, so the sending app can close them out
    // from under us (Slack does this when you read the message elsewhere).
    // Drop the corresponding rows so the UI doesn't show stale entries.
    Connections {
        target: notifServer.trackedNotifications

        function onObjectRemovedPost(object, index) {
            root.removeFromModel(notifHistoryModel, object.id);
            root.removeFromModel(activeToastModel, object.id);
        }
    }

    // Universal Click Handler
    function triggerAction(nId, appName) {
        let actionFired = false;
        let n = root.findNotification(nId);

        // 1. D-Bus action invocation.
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

        // 2. Fallback: ask Hyprland to focus the window directly.
        // Hyprland's regex is case sensitive, so match case-insensitively
        // rather than lowercasing the desktop entry name.
        if (!actionFired && appName && appName !== "") {
            let cleanName = appName.replace(".desktop", "");
            appLaunchProc.exec([
                "hyprctl", "dispatch", "focuswindow", `class:(?i)${cleanName}`
            ]);
        }
    }

    // Clicking a toast and clicking a history row do the same thing, so both
    // go through here by id. No index bookkeeping to get out of sync.
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
        root.showControlCenter = false;
    }

    // Toast timeout: drops the popup only, the entry stays in history.
    function dismissToast(nId) {
        root.removeFromModel(activeToastModel, nId);
    }

    // X button in Control Center: closes the notification for real.
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
    TopBar {
        id: topBar
        rootState: root
    }

    PanelWindow {
        id: dismissBackdrop
        visible: root.animVisible
        color: "transparent"
        anchors { top: true; bottom: true; left: true; right: true; }
        MouseArea {
            anchors.fill: parent
            onClicked: root.showControlCenter = false
        }
    }

    ControlCenter {
        id: controlCenter
        rootState: root
        topBarWindow: topBar
        historyModel: notifHistoryModel
    }

    NotificationToasts {
        id: notificationToasts
        rootState: root
        toastModel: activeToastModel
    }
}
