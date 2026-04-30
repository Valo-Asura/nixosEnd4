// ═══════════════════════════════════════════════════════════════════════════════
// Quickshell Resource Monitor Widget
// ═══════════════════════════════════════════════════════════════════════════════
// Real-time system monitoring widget for X15 optimized NixOS configuration
// Displays CPU temperature, usage, memory, GPU stats, and fan speeds
// ═══════════════════════════════════════════════════════════════════════════════

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
    id: resourceWidget
    
    // Configuration
    property int updateInterval: 2000  // ms
    property bool showGpu: true
    property bool showFan: true
    property string tempUnit: "°C"
    
    // Data properties
    property real cpuTemp: 0
    property real cpuUsage: 0
    property real cpuFreq: 0
    property real memUsed: 0
    property real memTotal: 1
    property real gpuTemp: 0
    property int fanSpeed: 0
    property string loadAvg: "0.00"
    
    // Thresholds for color coding
    property int tempWarning: 75
    property int tempCritical: 85
    property int memWarning: 85
    
    // Data source paths
    property string dataPath: "/run/user/1000/x15-hwmon/hwmon.json"
    
    // ───────────────────────────────────────────────────────────────────────────
    // DATA SOURCES
    // ───────────────────────────────────────────────────────────────────────────
    
    Process {
        id: hwmonProcess
        command: ["cat", dataPath]
        running: true
        
        stdout: SplitParser {
            onRead: data => {
                try {
                    var json = JSON.parse(data)
                    updateMetrics(json)
                } catch (e) {
                    console.log("Failed to parse hwmon data:", e)
                    fallbackRead()
                }
            }
        }
        
        onExited: {
            // Fallback if daemon not running
            fallbackRead()
        }
    }
    
    // Fallback: read directly from /sys
    function fallbackRead() {
        cpuTempFallback.running = true
        cpuUsageFallback.running = true
        memFallback.running = true
        if (showGpu) gpuFallback.running = true
        if (showFan) fanFallback.running = true
    }
    
    // Fallback processes for direct /sys access
    Process {
        id: cpuTempFallback
        command: ["bash", "-c", 
            "cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1 | awk '{print $1/1000}'"]
        stdout: SplitParser {
            onRead: data => cpuTemp = parseFloat(data) || 0
        }
    }
    
    Process {
        id: cpuUsageFallback
        command: ["bash", "-c",
            "top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1"]
        stdout: SplitParser {
            onRead: data => cpuUsage = parseFloat(data) || 0
        }
    }
    
    Process {
        id: memFallback
        command: ["bash", "-c",
            "free -m | awk 'NR==2{printf \"%.1f,%.1f\", $3,$2}'"]
        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(",")
                if (parts.length === 2) {
                    memUsed = parseFloat(parts[0]) || 0
                    memTotal = parseFloat(parts[1]) || 1
                }
            }
        }
    }
    
    Process {
        id: gpuFallback
        command: ["nvidia-smi", "--query-gpu=temperature.gpu", "--format=csv,noheader"]
        stdout: SplitParser {
            onRead: data => gpuTemp = parseInt(data) || 0
        }
    }
    
    Process {
        id: fanFallback
        command: ["bash", "-c",
            "cat /sys/class/hwmon/hwmon*/fan1_input 2>/dev/null | head -1"]
        stdout: SplitParser {
            onRead: data => fanSpeed = parseInt(data) || 0
        }
    }
    
    // ───────────────────────────────────────────────────────────────────────────
    // UPDATE TIMER
    // ───────────────────────────────────────────────────────────────────────────
    
    Timer {
        interval: updateInterval
        running: true
        repeat: true
        onTriggered: {
            hwmonProcess.running = true
        }
    }
    
    // ───────────────────────────────────────────────────────────────────────────
    // HELPER FUNCTIONS
    // ───────────────────────────────────────────────────────────────────────────
    
    function updateMetrics(json) {
        if (json.cpu && json.cpu.temperature) {
            cpuTemp = json.cpu.temperature
        }
        if (json.cpu && json.cpu.frequency && json.cpu.frequency.avg) {
            cpuFreq = json.cpu.frequency.avg
        }
        if (json.cpu && json.cpu.load) {
            cpuUsage = Math.min(json.cpu.load["1min"] * 100 / 12, 100)  // 12 cores
            loadAvg = json.cpu.load["1min"].toFixed(2)
        }
        if (json.memory) {
            memUsed = json.memory.used || 0
            memTotal = json.memory.total || 1
        }
        if (json.gpu && json.gpu.temperature) {
            gpuTemp = json.gpu.temperature
        }
        if (json.fans) {
            // Get first fan speed
            var firstFan = Object.values(json.fans)[0]
            fanSpeed = firstFan || 0
        }
    }
    
    function formatBytes(mib) {
        if (mib > 1024) {
            return (mib / 1024).toFixed(1) + " GB"
        }
        return Math.round(mib) + " MB"
    }
    
    function getTempColor(temp) {
        if (temp >= tempCritical) return "#ff5555"
        if (temp >= tempWarning) return "#ffaa55"
        return "#55ff55"
    }
    
    function getMemColor() {
        var pct = (memUsed / memTotal) * 100
        if (pct >= memWarning) return "#ff5555"
        if (pct >= 70) return "#ffaa55"
        return "#55ff55"
    }
    
    // ───────────────────────────────────────────────────────────────────────────
    // UI LAYOUT
    // ───────────────────────────────────────────────────────────────────────────
    
    RowLayout {
        anchors.fill: parent
        spacing: 8
        
        // CPU Temperature
        ResourceItem {
            icon: "thermostat"
            value: Math.round(cpuTemp) + tempUnit
            color: getTempColor(cpuTemp)
            tooltip: "CPU Temperature: " + cpuTemp.toFixed(1) + tempUnit
        }
        
        // CPU Usage Bar
        ResourceBar {
            width: 60
            value: cpuUsage / 100
            color: cpuUsage > 80 ? "#ff5555" : (cpuUsage > 50 ? "#ffaa55" : "#55ff55")
            tooltip: "CPU Usage: " + cpuUsage.toFixed(1) + "% | Load: " + loadAvg
        }
        
        // Memory
        ResourceItem {
            icon: "memory"
            value: formatBytes(memUsed)
            color: getMemColor()
            tooltip: "Memory: " + formatBytes(memUsed) + " / " + formatBytes(memTotal)
        }
        
        // GPU Temperature (if available)
        ResourceItem {
            visible: showGpu && gpuTemp > 0
            icon: "memory"  // Using memory icon for GPU
            value: Math.round(gpuTemp) + tempUnit
            color: getTempColor(gpuTemp)
            tooltip: "GPU Temperature: " + gpuTemp.toFixed(1) + tempUnit
        }
        
        // Fan Speed
        ResourceItem {
            visible: showFan && fanSpeed > 0
            icon: "toys_fan"
            value: Math.round(fanSpeed / 100) + "00"
            color: fanSpeed > 4000 ? "#ff5555" : (fanSpeed > 2500 ? "#ffaa55" : "#55ff55")
            tooltip: "Fan Speed: " + fanSpeed + " RPM"
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

component ResourceItem: Row {
    property string icon: "info"
    property string value: "0"
    property color color: "#ffffff"
    property string tooltip: ""
    
    spacing: 4
    
    MaterialIcon {
        icon: parent.icon
        iconColor: parent.color
        size: 16
    }
    
    Text {
        text: parent.value
        color: parent.color
        font.pixelSize: 12
        font.family: "JetBrainsMono Nerd Font Mono"
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        ToolTip.text: parent.tooltip
        ToolTip.visible: containsMouse
        ToolTip.delay: 500
    }
}

component ResourceBar: Rectangle {
    property real value: 0  // 0.0 to 1.0
    property color barColor: "#55ff55"
    property string tooltip: ""
    
    height: 16
    radius: 2
    color: "#2a2a2a"
    border.width: 1
    border.color: "#404040"
    
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.min(Math.max(parent.value, 0), 1)
        radius: 2
        color: parent.barColor
        
        Behavior on width {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        ToolTip.text: parent.tooltip
        ToolTip.visible: containsMouse
        ToolTip.delay: 500
    }
}

component MaterialIcon: Text {
    property string icon: "info"
    property color iconColor: "#ffffff"
    property int size: 16
    
    // FontAwesome 6 Free icons (using Unicode)
    text: {
        var icons = {
            "thermostat": "\uf2c7",     // fa-temperature-high
            "memory": "\uf538",         // fa-microchip
            "toys_fan": "\uf863",       // fa-fan
            "speed": "\uf135",          // fa-rocket
            "info": "\uf129"            // fa-info
        }
        return icons[icon] || icons["info"]
    }
    
    color: parent.iconColor
    font.family: "Font Awesome 6 Free"
    font.weight: Font.Bold
    font.pixelSize: size
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
