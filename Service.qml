pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool active: false
  property int borderWidth: 64
  property int brightness: 100

  // Persisted screen name. Empty means every screen.
  property string targetScreen: ""

  // Empty lights every screen. A named screen that is gone falls back to the
  // first screen, so an unplugged monitor never leaves the light with no
  // target.
  readonly property string effectiveScreen: {
    if (root.targetScreen === "") return ""
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (String(screens[i].name) === root.targetScreen) return root.targetScreen
    }
    return screens.length > 0 ? String(screens[0].name) : ""
  }

  function bounded(value, minimum, maximum, fallback) {
    var number = Number(value)
    return isFinite(number) ? Math.max(minimum, Math.min(maximum, Math.round(number))) : fallback
  }

  function applySettings(width, level, screen) {
    borderWidth = bounded(width, 16, 200, 64)
    brightness = bounded(level, 10, 100, 100)
    targetScreen = String(screen || "")
  }

  function setBorderWidth(pixels) {
    borderWidth = bounded(pixels, 16, 200, borderWidth)
  }

  function setTargetScreen(name) {
    targetScreen = String(name || "")
  }

  function toggle() {
    active = !active
  }

  Instantiator {
    model: Quickshell.screens

    delegate: Component {
      RingLight {
        required property var modelData
        targetScreen: modelData
        active: root.active
          && (root.effectiveScreen === "" || String(modelData.name) === root.effectiveScreen)
        borderWidth: root.borderWidth
        brightness: root.brightness
      }
    }
  }

  IpcHandler {
    target: "ring-light"

    function toggle(): void {
      root.toggle()
    }

    function enable(): void {
      root.active = true
    }

    function disable(): void {
      root.active = false
    }

    function status(): string {
      return JSON.stringify({
        active: root.active,
        borderWidth: root.borderWidth,
        brightness: root.brightness,
        screen: root.effectiveScreen === "" ? "all" : root.effectiveScreen,
        targetScreen: root.targetScreen,
        screens: Quickshell.screens.map(function(screen) { return screen.name })
      })
    }
  }
}
