pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool supported: false
    property bool enabled: false
    property bool desiredEnabled: false
    property bool loading: statusProc.running || actionProc.running
    property string backend: "unsupported"
    property string battery: ""
    property string message: ""
    property int requestedStopThreshold: 90
    property int currentStopThreshold: -1

    function applyStatus(rawText) {
        const text = (rawText || "").trim();
        if (!text.length) {
            return;
        }

        try {
            const status = JSON.parse(text);
            root.available = !!status.available;
            root.supported = !!status.supported;
            root.enabled = !!status.enabled;
            root.desiredEnabled = !!status.desiredEnabled;
            root.backend = status.backend || "unsupported";
            root.battery = status.battery || "";
            root.message = status.message || "";
            root.requestedStopThreshold = status.requestedStopThreshold || 90;
            root.currentStopThreshold = status.currentStopThreshold ?? -1;
        } catch (error) {
            console.log("[ChargeLimit] Failed to parse status:", error);
        }
    }

    function refresh() {
        if (!statusProc.running) {
            statusProc.running = true;
        }
    }

    function toggle() {
        if (!root.supported) {
            Quickshell.execDetached([
                "notify-send",
                "Battery charge limit",
                root.message || `No supported battery-care backend was detected for ${root.requestedStopThreshold}% charging.`,
                "-a",
                "Shell",
                "--hint=int:transient:1",
            ]);
            root.refresh();
            return;
        }

        actionProc.command = [
            "systemctl",
            "start",
            root.enabled ? "x15-charge-limit-disable.service" : "x15-charge-limit-enable.service",
        ];
        actionProc.running = true;
    }

    Timer {
        id: refreshTimer
        interval: 700
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: statusProc
        running: true
        command: [ "x15-charge-limit-status" ]
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
    }

    Process {
        id: actionProc
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                Quickshell.execDetached([
                    "notify-send",
                    "Battery charge limit",
                    "Failed to update the charge limit. Check the system service or polkit rule.",
                    "-a",
                    "Shell",
                    "--hint=int:transient:1",
                ]);
            }

            refreshTimer.restart();
        }
    }
}
