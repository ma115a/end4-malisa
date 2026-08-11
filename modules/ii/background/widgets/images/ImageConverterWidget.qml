pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "images"

    property list<var> formatOptions: [
        { displayName: "WEBP", icon: "motion_photos_on", value: "webp" },
        { displayName: "PNG",  icon: "image",            value: "png"  },
        { displayName: "JPG",  icon: "photo",            value: "jpg"  },
        { displayName: "AVIF", icon: "hd",               value: "avif" },
        { displayName: "GIF",  icon: "gif",              value: "gif"  },
        { displayName: "ICO",  icon: "crop_original",    value: "ico"  },
        { displayName: "BMP",  icon: "grid_on",          value: "bmp"  },
        { displayName: "TIFF", icon: "photo_library",    value: "tiff" },
        { displayName: "PDF",  icon: "picture_as_pdf",   value: "pdf"  },
    ]

    property list<var> scaleOptions: [
        { displayName: "Original (100%)", value: "100%" },
        { displayName: "75% Scale",       value: "75%"  },
        { displayName: "50% Scale",       value: "50%"  },
        { displayName: "1080p Max",       value: "1080p"},
        { displayName: "4K Max",          value: "4K"   }
    ]

    property string selectedFormat: "webp"
    property string selectedScale: "100%"
    property int selectedQuality: 85
    property bool pdfMerge: true
    property bool showSettings: false

    property string dropStatus: "idle"   // idle | hover | converting | done | error
    property string statusMessage: ""
    property string lastOutputPath: ""
    property string lastOutputDir: ""

    readonly property var acceptedExtensions: [
        "png","jpg","jpeg","webp","avif","bmp","gif","tiff","tif","ico","svg",
        "mp4","webm","mkv","mov","avi"
    ]

    readonly property bool isLossyFormat: ["jpg", "jpeg", "webp", "avif"].indexOf(root.selectedFormat) !== -1

    property var fileQueue: []
    property int queueTotal: 0
    property int queueDone: 0
    property var batchPaths: []

    implicitWidth:  280
    implicitHeight: root.showSettings ? 340 : 260

    Behavior on implicitHeight {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(root)
    }

    Process {
        id: converter
        property string inputPath: ""
        property string outputPath: ""
        onExited: (exitCode) => {
            root.queueDone++
            if (exitCode !== 0) {
                root.dropStatus = "error"
                root.statusMessage = "Failed: " + inputPath.replace(/.*\//, "")
                root.fileQueue = []
                root.queueTotal = 0
                root.queueDone = 0
                resetTimer.start()
                return
            }
            root.lastOutputPath = outputPath
            root.lastOutputDir = outputPath.substring(0, outputPath.lastIndexOf("/"))
            if (root.fileQueue.length > 0) {
                root.statusMessage = "Converting " + root.queueDone + " / " + root.queueTotal + "..."
                processNext()
            } else {
                root.dropStatus = "done"
                root.statusMessage = root.queueTotal === 1
                    ? "Saved: " + outputPath.replace(/.*\//, "")
                    : root.queueTotal + " files converted"
                root.queueTotal = 0
                root.queueDone = 0
                resetTimer.start()
            }
        }
    }

    Process {
        id: pdfMaker
        property string outputPath: ""
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root.lastOutputPath = outputPath
                root.lastOutputDir = outputPath.substring(0, outputPath.lastIndexOf("/"))
                root.dropStatus = "done"
                root.statusMessage = root.batchPaths.length === 1
                    ? "Saved: " + outputPath.replace(/.*\//, "")
                    : root.batchPaths.length + " pages → " + outputPath.replace(/.*\//, "")
            } else {
                root.dropStatus = "error"
                root.statusMessage = "PDF failed.\nIs ImageMagick installed?"
            }
            root.batchPaths = []
            resetTimer.start()
        }
    }

    Timer {
        id: resetTimer
        interval: 6000
        repeat: false
        onTriggered: {
            if (root.dropStatus === "done" || root.dropStatus === "error") {
                root.dropStatus = "idle"
            }
        }
    }

    function buildFfmpegCommand(input, output) {
        var args = ["ffmpeg", "-y", "-i", input]

        // Resolution scaling
        var vf = []
        if (root.selectedFormat === "ico") {
            vf.push("scale=32:32")
        } else if (root.selectedScale === "75%") {
            vf.push("scale=iw*0.75:-1")
        } else if (root.selectedScale === "50%") {
            vf.push("scale=iw*0.50:-1")
        } else if (root.selectedScale === "1080p") {
            vf.push("scale='min(1920,iw)':-1")
        } else if (root.selectedScale === "4K") {
            vf.push("scale='min(3840,iw)':-1")
        }

        if (vf.length > 0) {
            args.push("-vf")
            args.push(vf.join(","))
        }

        // Quality settings
        if (root.selectedFormat === "jpg" || root.selectedFormat === "jpeg") {
            var qval = Math.round(31 - (root.selectedQuality * 30 / 100))
            args.push("-q:v")
            args.push(Math.max(1, qval).toString())
        } else if (root.selectedFormat === "webp") {
            args.push("-q:v")
            args.push(root.selectedQuality.toString())
        } else if (root.selectedFormat === "avif") {
            var crf = Math.round(63 - (root.selectedQuality * 0.5))
            args.push("-crf")
            args.push(crf.toString())
        }

        args.push(output)
        return args
    }

    function processNext() {
        var next = root.fileQueue[0]
        root.fileQueue = root.fileQueue.slice(1)
        var out = next.replace(/\.[^/.]+$/, "") + "_converted." + root.selectedFormat
        converter.inputPath  = next
        converter.outputPath = out
        converter.command = buildFfmpegCommand(next, out)
        converter.running = true
    }

    function enqueueFiles(urls) {
        var valid = []
        for (var i = 0; i < urls.length; i++) {
            var cleanPath = urls[i].toString().replace(/^file:\/\//, "")
            cleanPath = decodeURIComponent(cleanPath)
            var ext = cleanPath.split(".").pop().toLowerCase()
            if (root.acceptedExtensions.indexOf(ext) !== -1)
                valid.push(cleanPath)
        }
        if (valid.length === 0) {
            root.dropStatus = "error"
            root.statusMessage = "No supported files dropped."
            resetTimer.start()
            return
        }

        resetTimer.stop()
        root.dropStatus = "converting"

        if (root.selectedFormat === "pdf" && root.pdfMerge && valid.length > 1) {
            root.batchPaths = valid
            root.statusMessage = "Merging " + valid.length + " images into PDF..."
            var outPdf = valid[0].replace(/\.[^/.]+$/, "") + "_merged.pdf"
            pdfMaker.outputPath = outPdf
            pdfMaker.command = ["convert"].concat(valid).concat([outPdf])
            pdfMaker.running = true
            return
        }

        root.fileQueue  = valid.slice(1)
        root.queueTotal = valid.length
        root.queueDone  = 0
        root.statusMessage = valid.length > 1 ? "Converting 0 / " + valid.length + "..." : "Converting..."

        var out = valid[0].replace(/\.[^/.]+$/, "") + "_converted." + root.selectedFormat
        converter.inputPath  = valid[0]
        converter.outputPath = out
        converter.command = buildFfmpegCommand(valid[0], out)
        converter.running = true
    }

    Rectangle {
        id: contentItem
        color: Appearance.colors.colPrimaryContainer
        radius: Appearance.rounding?.verylarge ?? 30
        anchors.fill: parent

        ColumnLayout {
            id: columnLayout
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8

            // Top bar: extensions & settings toggle
            RowLayout {
                Layout.fillWidth: true

                StyledText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnPrimaryContainer
                    opacity: 0.5
                    text: "PNG · JPG · WEBP · AVIF · ICO · PDF · GIF"
                    elide: Text.ElideRight
                }

                RippleButton {
                    implicitWidth: 30
                    implicitHeight: 30
                    padding: 0
                    topPadding: 0
                    bottomPadding: 0
                    leftPadding: 0
                    rightPadding: 0
                    buttonRadius: 15
                    colBackground: root.showSettings ? Appearance.colors.colSecondaryContainer : "transparent"
                    colBackgroundHover: Appearance.colors.colSurfaceContainerHigh
                    onClicked: root.showSettings = !root.showSettings

                    contentItem: Item {
                        anchors.fill: parent
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "tune"
                            iconSize: 18
                            color: root.showSettings ? Appearance.colors.colSecondary : Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }

            // Expandable settings drawer
            ColumnLayout {
                visible: root.showSettings
                Layout.fillWidth: true
                spacing: 6

                // Scale Selection
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: "Scale:"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: root.scaleOptions
                        colBackground: Appearance.colors.colSurfaceContainerLow
                        textRole: "displayName"
                        valueRole: "value"
                        currentIndex: {
                            for (var i = 0; i < model.length; i++) {
                                if (model[i].value === root.selectedScale) return i;
                            }
                            return 0;
                        }
                        onActivated: (index) => root.selectedScale = model[index].value
                    }
                }

                // Quality Slider (for lossy formats)
                RowLayout {
                    visible: root.isLossyFormat
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: "Quality:"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                    }

                    StyledSlider {
                        Layout.fillWidth: true
                        from: 10
                        to: 100
                        stepSize: 5
                        value: root.selectedQuality
                        onMoved: root.selectedQuality = Math.round(value)
                    }

                    StyledText {
                        text: root.selectedQuality + "%"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        font.weight: Font.Bold
                    }
                }

                // PDF Merge Mode (for PDF target)
                RowLayout {
                    visible: root.selectedFormat === "pdf"
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: "Merge multi-image to 1 PDF"
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.8
                    }

                    StyledSwitch {
                        checked: root.pdfMerge
                        onCheckedChanged: root.pdfMerge = checked
                    }
                }
            }

            // Drop zone
            Rectangle {
                id: dropZone
                Layout.fillWidth: true
                Layout.fillHeight: true
                implicitHeight: root.showSettings ? 110 : 144
                radius: Appearance.rounding.large
                color: {
                    switch (root.dropStatus) {
                        case "hover":      return Appearance.colors.colPrimaryContainer
                        case "converting": return Appearance.colors.colSecondaryContainer
                        case "done":       return Appearance.colors.colTertiaryContainer
                        case "error":      return Qt.rgba(
                                                Appearance.colors.colError.r,
                                                Appearance.colors.colError.g,
                                                Appearance.colors.colError.b, 0.15)
                        default:           return Appearance.colors.colSurfaceContainerLow 
                    }
                }
                border.color: {
                    switch (root.dropStatus) {
                        case "hover":      return Appearance.colors.colPrimary
                        case "converting": return Appearance.colors.colSecondary
                        case "done":       return Appearance.colors.colTertiary
                        case "error":      return Appearance.colors.colError
                        default:           return Appearance.colors.colOnPrimaryContainer
                    }
                }
                border.width: root.dropStatus === "hover" ? 2 : 1

                Behavior on color        { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                Behavior on border.color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                MaterialLoadingIndicator {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -12
                    visible: root.dropStatus === "converting"
                    loading: root.dropStatus === "converting"
                    colBg: Appearance.colors.colPrimary
                    colShape: Appearance.colors.colOnPrimary
                    implicitSize: 42
                }

                // Done State: Draggable Output Handle
                Item {
                    id: doneDragItem
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -12
                    width: 40
                    height: 40
                    visible: root.dropStatus === "done" && root.lastOutputPath !== ""

                    Drag.active: fileDragArea.drag.active
                    Drag.dragType: Drag.Automatic
                    Drag.mimeData: { "text/uri-list": "file://" + root.lastOutputPath }
                    Drag.supportedActions: Qt.CopyAction

                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: 32
                        fill: 1
                        color: Appearance.colors.colTertiary
                        text: "check_circle"
                    }

                    MouseArea {
                        id: fileDragArea
                        anchors.fill: parent
                        drag.target: parent
                        cursorShape: Qt.OpenHandCursor
                        onReleased: {
                            parent.x = 0
                            parent.y = 0
                        }
                    }
                }

                // Idle / Hover / Error Icon
                MaterialSymbol {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -12
                    visible: root.dropStatus !== "converting" && root.dropStatus !== "done"
                    iconSize: 32
                    color: {
                        switch (root.dropStatus) {
                            case "hover": return Appearance.colors.colPrimary
                            case "error": return Appearance.colors.colError
                            default:      return Appearance.colors.colOnLayer1
                        }
                    }
                    text: {
                        switch (root.dropStatus) {
                            case "hover": return "download"
                            case "error": return "error"
                            default:      return root.selectedFormat === "pdf" ? "picture_as_pdf" : "image"
                        }
                    }
                }

                // Text Status
                StyledText {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 20
                    horizontalAlignment: Text.AlignHCenter
                    font.pixelSize: Appearance.font.pixelSize.small
                    width: parent.width - 20
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    color: {
                        switch (root.dropStatus) {
                            case "hover":  return Appearance.colors.colPrimary
                            case "done":   return Appearance.colors.colTertiary
                            case "error":  return Appearance.colors.colError
                            default:       return Appearance.colors.colOnLayer1
                        }
                    }
                    opacity: root.dropStatus === "idle" ? 0.6 : 1.0
                    text: {
                        switch (root.dropStatus) {
                            case "idle":       return "Drop file(s) here to convert to ." + root.selectedFormat.toUpperCase()
                            case "hover":      return "Release to convert to ." + root.selectedFormat.toUpperCase()
                            case "converting": return root.statusMessage
                            case "done":       return root.statusMessage + "\n(Drag icon to copy file)"
                            case "error":      return root.statusMessage
                            default:           return ""
                        }
                    }
                }

                // Quick Action buttons on Done state (Copy & Open Folder)
                RowLayout {
                    visible: root.dropStatus === "done" && root.lastOutputPath !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 6
                    spacing: 8

                    RippleButton {
                        implicitHeight: 26
                        implicitWidth: 80
                        buttonRadius: 13
                        colBackground: Appearance.colors.colTertiaryContainer
                        onClicked: {
                            Quickshell.execDetached(["bash", "-c", "wl-copy -t image/png < '" + root.lastOutputPath + "' || wl-copy < '" + root.lastOutputPath + "'"])
                            root.statusMessage = "Copied to clipboard!"
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol { iconSize: 14; text: "content_copy"; color: Appearance.colors.colOnTertiaryContainer }
                            StyledText { text: "Copy"; font.pixelSize: 11; color: Appearance.colors.colOnTertiaryContainer }
                        }
                    }

                    RippleButton {
                        implicitHeight: 26
                        implicitWidth: 96
                        buttonRadius: 13
                        colBackground: Appearance.colors.colTertiaryContainer
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", root.lastOutputDir])
                        }
                        contentItem: RowLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            MaterialSymbol { iconSize: 14; text: "folder_open"; color: Appearance.colors.colOnTertiaryContainer }
                            StyledText { text: "Open Folder"; font.pixelSize: 11; color: Appearance.colors.colOnTertiaryContainer }
                        }
                    }
                }

                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onEntered: (drag) => {
                        drag.accept(Qt.CopyAction)
                        root.dropStatus = "hover"
                    }
                    onExited: {
                        if (root.dropStatus === "hover")
                            root.dropStatus = "idle"
                    }
                    onDropped: (drop) => {
                        if (drop.hasUrls && drop.urls.length > 0) {
                            root.enqueueFiles(drop.urls)
                        } else {
                            root.dropStatus = "error"
                            root.statusMessage = "Could not read file path."
                            resetTimer.start()
                        }
                    }
                }
            }

            // Target format row
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    Layout.leftMargin: 2
                    text: "Convert to:"
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnLayer1
                    opacity: 0.7
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    model: root.formatOptions
                    colBackground: Appearance.colors.colSurfaceContainerLow
                    colBackgroundHover: Appearance.colors.colSurfaceContainerLow
                    colBackgroundActive: Appearance.colors.colSurfaceContainerLow
                    textRole: "displayName"
                    valueRole: "value"
                    currentIndex: {
                        for (var i = 0; i < model.length; i++) {
                            if (model[i].value === root.selectedFormat) return i;
                        }
                        return 0;
                    }
                    onActivated: (index) => {
                        root.selectedFormat = model[index].value
                    }
                }
            }
        }
    }
}