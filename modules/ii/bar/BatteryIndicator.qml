import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: Battery.systemAvailable && (percentage <= Config.options.battery.low / 100)

    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : layout.implicitWidth + 8
    implicitHeight: vertical ? layout.implicitHeight + 8 : Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    GridLayout {
        id: layout
        anchors.centerIn: parent
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: 4
        columnSpacing: 4

        // Main laptop battery
        BatteryGlyph {
            id: glyph
            visible: Battery.systemAvailable
            Layout.alignment: Qt.AlignCenter
            style: Config.options.bar.battery.style
            percentage: root.percentage
            isCharging: root.isCharging
            isLow: root.isLow
            showPercentage: Config.options.bar.battery.showPercentage
            showCharging: Config.options.bar.battery.showCharging
            vertical: root.vertical
            contentColor: root.contentColor
        }

        // Secondary Bluetooth battery
        Item {
            visible: Battery.showBluetoothBattery
            Layout.alignment: Qt.AlignCenter
            implicitWidth: root.vertical ? btBatteryProgress.implicitHeight : btBatteryProgress.implicitWidth
            implicitHeight: root.vertical ? btBatteryProgress.implicitWidth : btBatteryProgress.implicitHeight

            ClippedProgressBar {
                id: btBatteryProgress
                anchors.centerIn: parent
                value: Battery.bluetoothPercentage
                rotation: root.vertical ? -90 : 0
                highlightColor: Appearance.colors.colPrimary
                showTip: !Battery.systemAvailable
                Item {
                    anchors.centerIn: parent
                    width: btBatteryProgress.valueBarWidth
                    height: btBatteryProgress.valueBarHeight
                    RowLayout {
                        spacing: 0
                        anchors.centerIn: parent
                        rotation: root.vertical ? 90 : 0
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            text: Battery.bluetoothIcon
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            font: btBatteryProgress.font
                            text: btBatteryProgress.text
                            visible: !root.vertical
                        }
                    }
                }
            }
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
