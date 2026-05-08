import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "memory"
                label: "RAM"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.memoryUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.memoryFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.memoryTotal)
                }
            }
        }

        Column {
            visible: ResourceUsage.swapTotal > 0
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "swap_horiz"
                label: "Swap"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "clock_loader_60"
                    label: Translation.tr("Used:")
                    value: root.formatKB(ResourceUsage.swapUsed)
                }
                StyledPopupValueRow {
                    icon: "check_circle"
                    label: Translation.tr("Free:")
                    value: root.formatKB(ResourceUsage.swapFree)
                }
                StyledPopupValueRow {
                    icon: "empty_dashboard"
                    label: Translation.tr("Total:")
                    value: root.formatKB(ResourceUsage.swapTotal)
                }
            }
        }

        Column {
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "planner_review"
                label: "CPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "bolt"
                    label: Translation.tr("Usage:")
                    value: Math.round(ResourceUsage.cpuUsage * 100) + "%"
                }
                StyledPopupValueRow {
                    icon: "device_thermostat"
                    label: Translation.tr("Temp:")
                    value: ResourceService.cpuTemperatureText
                }
                StyledPopupValueRow {
                    icon: "memory"
                    label: Translation.tr("Freq:")
                    value: ResourceService.cpuFrequencyText
                }
            }
        }

        Column {
            visible: true && ResourceService.gpuTemperature > 0
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "videogame_asset"
                label: "GPU"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "device_thermostat"
                    label: Translation.tr("Temp:")
                    value: ResourceService.gpuTemperatureText
                }
            }
        }

        Column {
            visible: true && ResourceService.fanSpeed > 0
            anchors.top: parent.top
            spacing: 8

            StyledPopupHeaderRow {
                icon: "air"
                label: "Fan"
            }
            Column {
                spacing: 4
                StyledPopupValueRow {
                    icon: "air"
                    label: Translation.tr("Speed:")
                    value: ResourceService.fanSpeedText
                }
            }
        }
    }
}
