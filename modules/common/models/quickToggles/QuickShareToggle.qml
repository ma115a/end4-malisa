import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Quickshell
import Quickshell.Io

QuickToggleModel {
    id: root
    name: Translation.tr("Quick Share")
    statusText: QuickShare.active ? Translation.tr("Active") : Translation.tr("Off")
    tooltipText: Translation.tr("Samsung Quick Share / Nearby Share | Click to toggle, Right-click to open Downloads")
    icon: QuickShare.active ? "share" : "share"

    available: QuickShare.available
    toggled: QuickShare.active

    mainAction: () => {
        QuickShare.toggle()
    }

    altAction: () => {
        QuickShare.openDownloads()
    }
}
