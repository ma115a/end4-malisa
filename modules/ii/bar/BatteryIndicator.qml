import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool vertical: false
    property bool borderless: Config.options.bar.borderless
    property bool isMaterial: Config.options.bar.cornerStyle === 3
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: Battery.systemAvailable && (percentage <= Config.options.battery.low / 100)
    readonly property bool showSecondaryBt: Battery.showBluetoothBattery && Battery.systemAvailable

    implicitWidth: vertical
        ? Appearance.sizes.verticalBarWidth
        : (38 + (showSecondaryBt ? 38 : 0))
    implicitHeight: vertical
        ? (38 + (showSecondaryBt ? 38 : 0))
        : Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    Loader {
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colLayout : rowLayout
    }

    Component {
        id: rowLayout
        RowLayout {
            spacing: 4
            anchors.centerIn: parent

            // Main Laptop Battery
            ClippedProgressBar {
                id: batteryProgress
                visible: Battery.systemAvailable
                value: root.percentage
                highlightColor: (root.isLow && !root.isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnSecondaryContainer
                Item {
                    anchors.centerIn: parent
                    width: batteryProgress.valueBarWidth
                    height: batteryProgress.valueBarHeight
                    RowLayout {
                        spacing: 0
                        anchors.centerIn: parent
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.topMargin: 2
                            Layout.leftMargin: -2
                            Layout.rightMargin: -2
                            fill: 1
                            text: "bolt"
                            iconSize: Appearance.font.pixelSize.smaller
                            visible: root.isCharging && root.percentage < 1
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignVCenter
                            Layout.topMargin: 2
                            font: batteryProgress.font
                            text: batteryProgress.text
                        }
                    }
                }
            }

            // Secondary Bluetooth Battery
            ClippedProgressBar {
                id: btBatteryProgress
                visible: Battery.showBluetoothBattery
                value: Battery.bluetoothPercentage
                highlightColor: Appearance.colors.colPrimary
                showTip: !Battery.systemAvailable
                Item {
                    anchors.centerIn: parent
                    width: btBatteryProgress.valueBarWidth
                    height: btBatteryProgress.valueBarHeight
                    RowLayout {
                        spacing: 0
                        anchors.centerIn: parent
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
                        }
                    }
                }
            }
        }
    }

    Component {
        id: colLayout
        ColumnLayout {
            spacing: 4
            anchors.centerIn: parent

            // Main Laptop Battery
            ClippedProgressBar {
                id: batteryProgressVert
                visible: Battery.systemAvailable
                value: root.percentage
                rotation: -90
                highlightColor: (root.isLow && !root.isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnSecondaryContainer
                Item {
                    anchors.centerIn: parent
                    width: batteryProgressVert.valueBarWidth
                    height: batteryProgressVert.valueBarHeight
                    ColumnLayout {
                        rotation: 90
                        spacing: -7
                        anchors.centerIn: parent
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            fill: 1
                            text: "bolt"
                            Layout.topMargin: 4
                            iconSize: Appearance.font.pixelSize.smaller
                            visible: root.isCharging && root.percentage < 1
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: root.isCharging ? 2 : 4
                            font: batteryProgressVert.font
                            text: root.percentage * 100 
                            visible: root.percentage < 1
                        }
                    }
                }
            }

            // Secondary Bluetooth Battery
            ClippedProgressBar {
                id: btBatteryProgressVert
                visible: Battery.showBluetoothBattery
                value: Battery.bluetoothPercentage
                rotation: -90
                highlightColor: Appearance.colors.colPrimary
                showTip: !Battery.systemAvailable
                Item {
                    anchors.centerIn: parent
                    width: btBatteryProgressVert.valueBarWidth
                    height: btBatteryProgressVert.valueBarHeight
                    ColumnLayout {
                        rotation: 90
                        spacing: -7
                        anchors.centerIn: parent
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: Battery.bluetoothIcon
                            iconSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            font: btBatteryProgressVert.font
                            text: btBatteryProgressVert.text
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