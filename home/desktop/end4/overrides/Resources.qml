import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool alwaysShowAllResources: false
    implicitWidth: rowLayout.implicitWidth + rowLayout.anchors.leftMargin + rowLayout.anchors.rightMargin
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    RowLayout {
        id: rowLayout

        spacing: 0
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4

        Resource {
            iconName: "memory"
            percentage: ResourceUsage.memoryUsedPercentage
            warningThreshold: Config.options.bar.resources.memoryWarningThreshold
        }

        Resource {
            iconName: "swap_horiz"
            percentage: ResourceUsage.swapUsedPercentage
            shown: (Config.options.bar.resources.alwaysShowSwap && percentage > 0)
                || (MprisController.activePlayer?.trackTitle == null)
                || root.alwaysShowAllResources
            Layout.leftMargin: shown ? 6 : 0
            warningThreshold: Config.options.bar.resources.swapWarningThreshold
        }

        ColumnLayout {
            id: cpuColumn
            Layout.leftMargin: cpuResource.shown ? 6 : 0
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            visible: cpuResource.shown

            Resource {
                id: cpuResource
                iconName: "planner_review"
                percentage: ResourceUsage.cpuUsage
                shown: Config.options.bar.resources.alwaysShowCpu
                    || !(MprisController.activePlayer?.trackTitle?.length > 0)
                    || root.alwaysShowAllResources
                warningThreshold: Config.options.bar.resources.cpuWarningThreshold
                Layout.alignment: Qt.AlignHCenter
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                color: ResourceService.cpuTemperature >= 85
                    ? Appearance.colors.colError
                    : Appearance.colors.colOnLayer2
                font.pixelSize: Math.max(10, Appearance.font.pixelSize.small - 1)
                text: ResourceService.cpuTemperatureText
                visible: ResourceService.available
            }
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}
