pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string dataPath: runtimeDir + "/x15-hwmon/hwmon.json"

    property bool available: false
    property double cpuTemperature: 0
    property double cpuLoad1: 0
    property double cpuFrequencyMHz: 0
    property double gpuTemperature: 0
    property double fanSpeed: 0
    property double lastUpdatedMs: 0

    readonly property string cpuTemperatureText: available && cpuTemperature > 0
        ? Math.round(cpuTemperature) + "°C"
        : "--"
    readonly property string cpuLoadText: available
        ? cpuLoad1.toFixed(2)
        : "--"
    readonly property string cpuFrequencyText: available && cpuFrequencyMHz > 0
        ? Math.round(cpuFrequencyMHz) + " MHz"
        : "--"
    readonly property string gpuTemperatureText: available && gpuTemperature > 0
        ? Math.round(gpuTemperature) + "°C"
        : "--"
    readonly property string fanSpeedText: available && fanSpeed > 0
        ? Math.round(fanSpeed) + " RPM"
        : "--"

    function updateAvailability() {
        available = lastUpdatedMs > 0 && (Date.now() - lastUpdatedMs) <= @staleAfterMs@
    }

    function reset() {
        cpuTemperature = 0
        cpuLoad1 = 0
        cpuFrequencyMHz = 0
        gpuTemperature = 0
        fanSpeed = 0
        lastUpdatedMs = 0
        available = false
    }

    function refresh() {
        const raw = dataFile.text()
        if (!raw || !raw.trim()) {
            reset()
            return
        }

        try {
            const data = JSON.parse(raw)
            const timestamp = data.timestamp ? Date.parse(data.timestamp) : Date.now()
            let firstFan = 0
            if (data.fans) {
                for (const fanName in data.fans) {
                    firstFan = Number(data.fans[fanName] || 0)
                    break
                }
            }

            cpuTemperature = Number(data.cpu?.temperature || 0)
            cpuLoad1 = Number(data.cpu?.load?.["1min"] || 0)
            cpuFrequencyMHz = Number(data.cpu?.frequency?.avg || 0)
            gpuTemperature = Number(data.gpu?.temperature || 0)
            fanSpeed = firstFan
            lastUpdatedMs = Number.isFinite(timestamp) ? timestamp : Date.now()
            updateAvailability()
        } catch (error) {
            console.log("ResourceService: failed to parse " + root.dataPath + ": " + error)
            reset()
        }
    }

    FileView {
        id: dataFile
        path: root.dataPath
        preload: true
        printErrors: false
        watchChanges: true

        onLoaded: root.refresh()
        onTextChanged: root.refresh()
        onFileChanged: reload()
        onLoadFailed: root.reset()
    }

    Timer {
        interval: @staleAfterMs@
        running: true
        repeat: true
        onTriggered: root.updateAvailability()
    }

    Component.onCompleted: dataFile.reload()
}
