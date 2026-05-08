import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    readonly property var hoverWindow: root.hoverTarget?.QsWindow?.window
    default property Item contentItem
    property real popupBackgroundMargin: 0

    active: hoverTarget && hoverTarget.containsMouse

    function mappedHoverTargetPoint(x, y) {
        if (!root.hoverTarget || !root.hoverTarget.window)
            return Qt.point(0, 0);

        return root.hoverTarget.mapToItem(null, x, y);
    }

    function clampMargin(value, availableSpace) {
        const safeValue = isFinite(value) ? value : 0;
        if (!availableSpace || availableSpace <= 0)
            return Math.max(0, safeValue);

        return Math.min(Math.max(0, safeValue), Math.max(0, availableSpace));
    }

    component: PanelWindow {
        id: popupWindow
        color: "transparent"
        screen: root.hoverWindow?.screen

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            left: {
                if (!Config.options.bar.vertical) {
                    const targetPoint = root.mappedHoverTargetPoint(
                        (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
                    );
                    const screenWidth = popupWindow.screen?.width ?? root.hoverWindow?.width ?? 0;
                    return root.clampMargin(targetPoint.x, screenWidth - popupWindow.implicitWidth);
                }
                return Appearance.sizes.verticalBarWidth
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                const targetPoint = root.mappedHoverTargetPoint(
                    (root.hoverTarget.height - popupBackground.implicitHeight) / 2, 0
                );
                const screenHeight = popupWindow.screen?.height ?? root.hoverWindow?.height ?? 0;
                return root.clampMargin(targetPoint.y, screenHeight - popupWindow.implicitHeight);
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.elevationMargin + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            color: Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.small
            children: [root.contentItem]

            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }
}
