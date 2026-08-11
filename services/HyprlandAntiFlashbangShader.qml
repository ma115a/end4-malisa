pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.modules.common.models.hyprland

Singleton {
    id: root

    readonly property string shaderPath: Quickshell.shellPath("services/hyprlandAntiFlashbangShader/anti-flashbang.glsl")
    readonly property string weakShaderPath: Quickshell.shellPath("services/hyprlandAntiFlashbangShader/anti-flashbang-weak.glsl")
    property bool enabled: confOpt.value == shaderPath || weak
    property bool weak: confOpt.value == weakShaderPath

    function enable() { disable() }
    function enableWeak() { disable() }

    function disable() {
        HyprlandConfig.setMany({
            "decoration:screen_shader": "",
            "debug:damage_tracking": 2
        });
    }

    function toggle() { disable() }
    function cycle() { disable() }
    
    HyprlandConfigOption {
        id: confOpt
        key: "decoration:screen_shader"
    }
}