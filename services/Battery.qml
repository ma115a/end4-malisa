pragma Singleton

import qs.services
import qs.modules.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick
import Quickshell.Io

Singleton {
    id: root
    readonly property bool systemAvailable: UPower.displayDevice.isLaptopBattery
    property var chargeState: UPower.displayDevice.state
    property bool isCharging: chargeState == UPowerDeviceState.Charging
    property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: Config.options.battery.automaticSuspend
    readonly property bool soundEnabled: Config.options.sounds.battery

    readonly property var bluetoothDevice: BluetoothStatus.firstDeviceWithBattery
    readonly property bool hasBluetoothBattery: BluetoothStatus.hasBatteryDevice
    readonly property bool showBluetoothDevice: Config.options.battery.showBluetoothDevice
    readonly property bool showBluetoothBattery: showBluetoothDevice && hasBluetoothBattery
    readonly property real bluetoothPercentage: bluetoothDevice?.battery ?? 0
    readonly property string bluetoothIcon: bluetoothDevice ? Icons.getBluetoothDeviceMaterialSymbol(bluetoothDevice.icon || "") : "bluetooth"

    property bool available: systemAvailable || showBluetoothBattery

    property bool isLow: systemAvailable && (percentage <= Config.options.battery.low / 100)
    property bool isCritical: systemAvailable && (percentage <= Config.options.battery.critical / 100)
    property bool isSuspending: systemAvailable && (percentage <= Config.options.battery.suspend / 100)
    property bool isFull: systemAvailable && (percentage >= Config.options.battery.full / 100)

    property bool isLowAndNotCharging: isLow && !isCharging
    property bool isCriticalAndNotCharging: isCritical && !isCharging
    property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && !isCharging
    property bool isFullAndCharging: isFull && isCharging

    property real energyRate: UPower.displayDevice.changeRate
    property real timeToEmpty: UPower.displayDevice.timeToEmpty
    property real timeToFull: UPower.displayDevice.timeToFull

    property real sysfsHealth: 0
    property int sysfsCycles: -1

    Process {
        id: sysfsHealthProc
        command: ["bash", "-c", "for bat in /sys/class/power_supply/BAT*; do if [ -f \"$bat/energy_full\" ] && [ -f \"$bat/energy_full_design\" ]; then ef=$(cat \"$bat/energy_full\"); efd=$(cat \"$bat/energy_full_design\"); if [ \"$efd\" -gt 0 ]; then echo $(( ef * 100 / efd )); break; fi; elif [ -f \"$bat/charge_full\" ] && [ -f \"$bat/charge_full_design\" ]; then cf=$(cat \"$bat/charge_full\"); cfd=$(cat \"$bat/charge_full_design\"); if [ \"$cfd\" -gt 0 ]; then echo $(( cf * 100 / cfd )); break; fi; fi; done"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                const val = parseFloat(data.trim());
                if (!isNaN(val) && val > 0) {
                    root.sysfsHealth = val;
                }
            }
        }
    }

    Process {
        id: sysfsCyclesProc
        command: ["bash", "-c", "for bat in /sys/class/power_supply/BAT*; do if [ -f \"$bat/cycle_count\" ]; then cc=$(cat \"$bat/cycle_count\"); if [ \"$cc\" -gt 0 ]; then echo \"$cc\"; break; fi; fi; done"]
        running: true
        stdout: SplitParser {
            onRead: (data) => {
                const val = parseInt(data.trim(), 10);
                if (!isNaN(val) && val > 0) {
                    root.sysfsCycles = val;
                }
            }
        }
    }

    property real health: {
        const devList = UPower.devices.values;
        for (let i = 0; i < devList.length; ++i) {
            const dev = devList[i];
            if (dev.isLaptopBattery) {
                if (dev.healthSupported && dev.healthPercentage > 0) {
                    const h = dev.healthPercentage;
                    return h < 1 ? h * 100 : h;
                }
                if (dev.capacity !== undefined && dev.capacity > 0) {
                    const cap = dev.capacity;
                    return cap < 1 ? cap * 100 : cap;
                }
            }
        }
        return root.sysfsHealth;
    }

    property int chargeCycles: {
        const devList = UPower.devices.values;
        for (let i = 0; i < devList.length; ++i) {
            const dev = devList[i];
            if (dev.isLaptopBattery && dev.chargeCycles !== undefined && dev.chargeCycles > 0) {
                return dev.chargeCycles;
            }
        }
        return root.sysfsCycles;
    }

    onIsLowAndNotChargingChanged: {
        if (!root.systemAvailable || !isLowAndNotCharging) return;
        Quickshell.execDetached([
            "notify-send", 
            Translation.tr("Low battery"), 
            Translation.tr("Consider plugging in your device"), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ])

        if (root.soundEnabled) Audio.playSystemSound("dialog-warning");
    }

    onIsCriticalAndNotChargingChanged: {
        if (!root.systemAvailable || !isCriticalAndNotCharging) return;
        Quickshell.execDetached([
            "notify-send", 
            Translation.tr("Critically low battery"), 
            Translation.tr("Please charge!\nAutomatic suspend triggers at %1%").arg(Config.options.battery.suspend), 
            "-u", "critical",
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playSystemSound("suspend-error");
    }

    onIsSuspendingAndNotChargingChanged: {
        if (root.systemAvailable && isSuspendingAndNotCharging) {
            Quickshell.execDetached(["bash", "-c", `systemctl suspend || loginctl suspend`]);
        }
    }

    onIsFullAndChargingChanged: {
        if (!root.systemAvailable || !isFullAndCharging) return;
        Quickshell.execDetached([
            "notify-send",
            Translation.tr("Battery full"),
            Translation.tr("Please unplug the charger"),
            "-a", "Shell",
            "--hint=int:transient:1",
        ]);

        if (root.soundEnabled) Audio.playSystemSound("complete");
    }

    onIsPluggedInChanged: {
        if (!root.systemAvailable || !root.soundEnabled) return;
        if (isPluggedIn) {
            Audio.playSystemSound("power-plug")
        } else {
            Audio.playSystemSound("power-unplug")
        }
    }
}
