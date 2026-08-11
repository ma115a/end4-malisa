pragma Singleton

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * Samsung Quick Share / Android Nearby Share service for Quickshell
 */
Singleton {
    id: root

    property bool available: false
    property bool active: false
    property string binaryPath: "rquickshare-x"
    property string downloadsPath: `${Directories.home}/Downloads`

    function load() {
        checkAvailabilityProc.running = true
        checkActiveProc.running = true
    }

    function toggle() {
        if (!available) {
            Quickshell.execDetached(["notify-send", 
                Translation.tr("Quick Share"), 
                Translation.tr("rquickshare-x is not installed"),
                "-a", "Shell"
            ]);
            return;
        }

        if (active) {
            stop();
        } else {
            start();
        }
    }

    function start() {
        if (!available) return;
        Quickshell.execDetached(["bash", "-c", `${binaryPath} &`]);
        checkTimer.restart();
    }

    function stop() {
        Quickshell.execDetached(["pkill", "-f", "rquickshare-x"]);
        checkTimer.restart();
    }

    function openDownloads() {
        Quickshell.execDetached(["xdg-open", downloadsPath]);
    }

    function launchApp() {
        if (!available) return;
        Quickshell.execDetached([binaryPath]);
    }

    Timer {
        id: checkTimer
        interval: 1000
        repeat: false
        onTriggered: root.refresh()
    }

    Timer {
        interval: 4000
        repeat: true
        running: Config.ready
        onTriggered: root.refresh()
    }

    function refresh() {
        checkActiveProc.running = true
    }

    Process {
        id: checkAvailabilityProc
        running: true
        command: ["bash", "-c", "which rquickshare-x || (test -f ~/.local/bin/rquickshare-x && echo ~/.local/bin/rquickshare-x)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim();
                if (path.length > 0) {
                    root.available = true;
                    root.binaryPath = path;
                } else {
                    root.available = false;
                }
            }
        }
    }

    Process {
        id: checkActiveProc
        running: false
        command: ["pgrep", "-f", "rquickshare-x"]
        onExited: (exitCode, exitStatus) => {
            root.active = (exitCode === 0);
        }
    }
}
