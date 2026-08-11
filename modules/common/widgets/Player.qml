pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Item {
    id: root
    required property MprisPlayer player
    property var artUrl: player?.trackArtUrl ?? ""
    property string trackTitle: player?.trackTitle ?? ""
    property string trackArtist: player?.trackArtist ?? ""
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5((artUrl && artUrl.length > 0) ? artUrl : (trackTitle + trackArtist))
    property string artFilePath: `${artDownloadLocation}/${artFileName}`
    property color artDominantColor: ColorUtils.mix(
        (colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary),
        Appearance.colors.colPrimaryContainer,
        0.8) || Appearance.m3colors.m3secondaryContainer
    property bool downloaded: false
    property list<real> visualizerPoints: []
    property real maxVisualizerValue: 1000
    property int visualizerSmoothing: 2
    property real radius
    property bool showLyrics: false

    property string displayedArtFilePath: {
        if (root.artUrl && root.artUrl.length > 0 && root.artUrl.startsWith("file://")) return root.artUrl
        if (!root.downloaded) return ""
        return Qt.resolvedUrl(artFilePath)
    }

    property QtObject blendedColors: AdaptedMaterialScheme {
        color: artDominantColor
    }

    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    Component.onCompleted: updateArt()
    onArtFilePathChanged: updateArt()
    onTrackTitleChanged: updateArt()

    function updateArt() {
        if ((!root.artUrl || root.artUrl.length === 0) && (!root.trackTitle || root.trackTitle.length === 0)) {
            root.artDominantColor = Appearance.m3colors.m3secondaryContainer
            root.downloaded = false
            return
        }

        coverArtDownloader.playerName = root.player?.dbusName ?? root.player?.busName ?? ""
        coverArtDownloader.targetFile = root.artUrl ?? ""
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process {
        id: coverArtDownloader
        property string playerName: ""
        property string targetFile: root.artUrl ?? ""
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `
            target="${targetFile}"
            path="${artFilePath}"
            player="${playerName}"
            
            xesamUrl=$(playerctl -p "$player" metadata xesam:url 2>/dev/null || playerctl metadata xesam:url 2>/dev/null)

            if [[ "$xesamUrl" =~ (v=|youtu\.be/|embed/)([a-zA-Z0-9_-]{11}) ]]; then
                target="https://i.ytimg.com/vi/\${BASH_REMATCH[2]}/hqdefault.jpg"
            elif [ -z "$target" ] || [ "$target" = "undefined" ]; then
                target="$xesamUrl"
            fi

            if [[ "$target" =~ (v=|youtu\.be/|embed/)([a-zA-Z0-9_-]{11}) ]]; then
                target="https://i.ytimg.com/vi/\${BASH_REMATCH[2]}/hqdefault.jpg"
            fi

            if [ -n "$target" ] && [ "$target" != "undefined" ]; then
                if [[ "$target" == file://* ]]; then
                    srcPath="\${target#file://}"
                    if [ -f "$srcPath" ]; then
                        if file "$srcPath" | grep -q "WebP"; then
                            ffmpeg -y -i "$srcPath" "$path" 2>/dev/null || convert "$srcPath" "$path" 2>/dev/null || cp "$srcPath" "$path"
                        else
                            cp "$srcPath" "$path"
                        fi
                    fi
                else
                    curl -sSL -A 'Mozilla/5.0 (X11; Linux x86_64)' "$target" -o "$path" || rm -f "$path"
                fi
            fi
        `]
        onExited: (exitCode, exitStatus) => {
            root.downloaded = true
        }
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    StyledRectangularShadow {
        target: background
    }

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        color: ColorUtils.applyAlpha(blendedColors.colLayer0, 1)
        radius: root.radius

        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            sourceSize.width: background.width
            sourceSize.height: background.height
            fillMode: Image.PreserveAspectCrop
            cache: false
            antialiasing: true
            asynchronous: true

            layer.enabled: true
            layer.effect: StyledBlurEffect {
                source: blurredArt
            }

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(blendedColors.colLayer0, 0.3)
                radius: root.radius
            }
        }

        WaveVisualizer {
            id: visualizerCanvas
            anchors.fill: parent
            live: root.player?.isPlaying
            points: root.visualizerPoints
            maxVisualizerValue: root.maxVisualizerValue
            smoothing: root.visualizerSmoothing
            color: blendedColors.colPrimary
        }

        Loader {
            id: layoutLoader
            anchors.fill: parent

            sourceComponent: root.showLyrics ? lyricsComponent : controlsComponent

            Component {
                id: controlsComponent
                PlayerControls {
                    player: root.player
                    blendedColors: root.blendedColors
                    displayedArtFilePath: root.displayedArtFilePath
                    radius: root.radius
                    onToggleLyrics: root.showLyrics = !root.showLyrics
                }
            }

            Component {
                id: lyricsComponent
                PlayerControlsLyrics {
                    player: root.player
                    blendedColors: root.blendedColors
                    displayedArtFilePath: root.displayedArtFilePath
                    radius: root.radius
                    artDominantColor: root.artDominantColor
                    onToggleLyrics: root.showLyrics = !root.showLyrics
                }
            }
        }
    }
}
