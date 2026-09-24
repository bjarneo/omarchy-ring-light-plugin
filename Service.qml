pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property bool active: false
  property int borderWidth: 64
  property int brightness: 100
  property int temperature: 6500

  // True keeps the light out of the bar's zone. False lets it cover the bar.
  property bool showBar: false

  // Persisted screen name. Empty means every screen.
  property string targetScreen: ""

  // True while a settings card is open. The light windows stay mapped then,
  // so turning the light on does not stack them above the card.
  property bool settingsOpen: false

  // Bar widget slot per screen, used to float the toggle on the overlay.
  property var iconAnchors: ({})

  signal settingsRequested(string screenName)
  signal widthNudged(string screenName, int delta)

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

  function boundedTemperature(value) {
    var number = Number(value)
    if (!isFinite(number)) return 6500
    return Math.max(1000, Math.min(12000, Math.round(number / 100) * 100))
  }

  function enabled(value) {
    return value === true || String(value) === "true"
  }

  function applySettings(width, level, screen, kelvin, barShown) {
    borderWidth = bounded(width, 16, 800, 64)
    brightness = bounded(level, 10, 100, 100)
    targetScreen = String(screen || "")
    temperature = boundedTemperature(kelvin)
    showBar = enabled(barShown)
  }

  function setBorderWidth(pixels) {
    borderWidth = bounded(pixels, 16, 800, borderWidth)
  }

  function setTemperature(kelvin) {
    temperature = boundedTemperature(kelvin)
  }

  function setShowBar(value) {
    showBar = enabled(value)
  }

  function setSettingsOpen(open) {
    settingsOpen = !!open
  }

  function setTargetScreen(name) {
    targetScreen = String(name || "")
  }

  function setIconAnchor(screenName, rect) {
    var name = String(screenName || "")
    if (!name || !rect) return
    var current = iconAnchors[name]
    if (current
      && current.x === rect.x
      && current.y === rect.y
      && current.width === rect.width
      && current.height === rect.height)
      return
    var next = {}
    for (var key in iconAnchors) next[key] = iconAnchors[key]
    next[name] = rect
    iconAnchors = next
  }

  function clearIconAnchor(screenName) {
    var name = String(screenName || "")
    var next = {}
    for (var key in iconAnchors) if (key !== name) next[key] = iconAnchors[key]
    iconAnchors = next
  }

  function handleIconPressed(screenName, button) {
    if (button === Qt.LeftButton) root.toggle()
    else if (button === Qt.RightButton) root.settingsRequested(String(screenName || ""))
  }

  function handleIconWheeled(screenName, delta) {
    root.widthNudged(String(screenName || ""), delta)
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
        temperature: root.temperature
        showBar: root.showBar
        held: root.settingsOpen
        iconAnchor: root.iconAnchors[String(modelData.name)] || null
        onIconPressed: function(button) { root.handleIconPressed(String(modelData.name), button) }
        onIconWheeled: function(delta) { root.handleIconWheeled(String(modelData.name), delta) }
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
        temperature: root.temperature,
        showBar: root.showBar,
        screen: root.effectiveScreen === "" ? "all" : root.effectiveScreen,
        targetScreen: root.targetScreen,
        screens: Quickshell.screens.map(function(screen) { return screen.name })
      })
    }
  }
}
