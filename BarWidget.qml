pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "bjarneo.ring-light"

  readonly property var ringLightService: {
    if (!bar || !bar.shell || typeof bar.shell.serviceFor !== "function") return null
    return bar.shell.serviceFor(root.moduleName)
  }

  readonly property bool lightActive: ringLightService ? ringLightService.active : false
  readonly property var configuredWidth: root.setting("borderWidth", 64)
  readonly property var configuredBrightness: root.setting("brightness", 100)
  readonly property var configuredTemperature: root.setting("temperature", 6500)
  readonly property string configuredScreen: String(root.setting("screen", ""))

  readonly property int minimumWidth: 16
  readonly property int maximumWidth: 200
  readonly property int widthStep: 8
  readonly property int minimumTemperature: 1000
  readonly property int maximumTemperature: 12000
  readonly property int temperatureStep: 100

  readonly property var screenOptions: {
    var options = [{ value: "", label: "All screens" }]
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      var name = String(screens[i].name)
      if (name) options.push({ value: name, label: name })
    }
    return options
  }

  readonly property bool multipleScreens: Quickshell.screens.length > 1

  // The screen the light shows on, empty for all screens. A stale name falls
  // back to the first screen, matching the service.
  readonly property string currentScreen: ringLightService
    ? ringLightService.effectiveScreen
    : root.configuredScreen

  readonly property string currentScreenLabel: root.currentScreen === ""
    ? "All screens"
    : root.currentScreen

  // The service holds the width while the user drags. The persisted setting
  // is the fallback before the service loads.
  readonly property int currentWidth: ringLightService
    ? ringLightService.borderWidth
    : root.boundedWidth(configuredWidth)

  readonly property int currentTemperature: ringLightService
    ? ringLightService.temperature
    : root.boundedTemperature(configuredTemperature)

  readonly property var widgetWindow: root.QsWindow ? root.QsWindow.window : null
  readonly property var widgetScreen: widgetWindow ? widgetWindow.screen : null

  TransformWatcher {
    id: iconWatcher
    a: widgetWindow ? widgetWindow.contentItem : null
    b: root
  }

  // Screen-relative slot of this bar icon. TransformWatcher keeps the
  // overlay copy aligned when the bar moves or widgets reorder.
  readonly property var iconScreenRect: {
    iconWatcher.transform
    if (!widgetWindow || !widgetWindow.contentItem || !widgetScreen) return null
    if (root.width <= 0 || root.height <= 0) return null
    var pos = root.mapToItem(widgetWindow.contentItem, 0, 0)
    var x = pos.x
    var y = pos.y
    var barPos = root.bar ? root.bar.position : "top"
    if (barPos === "bottom") y += widgetScreen.height - widgetWindow.height
    else if (barPos === "right") x += widgetScreen.width - widgetWindow.width
    return {
      x: Math.round(x),
      y: Math.round(y),
      width: Math.round(root.width),
      height: Math.round(root.height),
      screen: String(widgetScreen.name)
    }
  }

  property bool popupOpen: false

  function onThisScreen(screenName) {
    return widgetScreen && String(widgetScreen.name) === String(screenName)
  }

  function reportIconAnchor() {
    if (!ringLightService || typeof ringLightService.setIconAnchor !== "function") return
    if (!iconScreenRect) return
    ringLightService.setIconAnchor(iconScreenRect.screen, iconScreenRect)
  }

  function boundedWidth(value) {
    var number = Number(value)
    if (!isFinite(number)) return 64
    return Math.max(root.minimumWidth, Math.min(root.maximumWidth, Math.round(number)))
  }

  function boundedTemperature(value) {
    var number = Number(value)
    if (!isFinite(number)) return 6500
    return Math.max(root.minimumTemperature, Math.min(root.maximumTemperature, Math.round(number / root.temperatureStep) * root.temperatureStep))
  }

  function pushSettings() {
    if (ringLightService)
      ringLightService.applySettings(configuredWidth, configuredBrightness, configuredScreen, configuredTemperature)
  }

  // Live width with no persistence, so the border follows the slider.
  function previewWidth(pixels) {
    if (ringLightService) ringLightService.setBorderWidth(root.boundedWidth(pixels))
  }

  function previewTemperature(kelvin) {
    if (ringLightService) ringLightService.setTemperature(root.boundedTemperature(kelvin))
  }

  // Apply the value locally first, then persist it through shell.json. The
  // returned config patches widget settings in place, so the popup stays open.
  function commitSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var current in root.settings) if (current !== "id") entry[current] = root.settings[current]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function commitWidth(pixels) {
    var width = root.boundedWidth(pixels)
    root.previewWidth(width)
    root.commitSetting("borderWidth", width)
  }

  function commitTemperature(kelvin) {
    var temperature = root.boundedTemperature(kelvin)
    root.previewTemperature(temperature)
    root.commitSetting("temperature", temperature)
  }

  function commitScreen(name) {
    var screenName = String(name || "")
    if (root.ringLightService) root.ringLightService.setTargetScreen(screenName)
    root.commitSetting("screen", screenName)
  }

  // Panel shape: the bar routes shell.summon/toggle to widgets that expose
  // open, close, and opened.
  function open() { root.popupOpen = true }
  function close() { root.popupOpen = false }
  readonly property bool opened: root.popupOpen

  // An open card must not sit under the hover tooltip, which covers the
  // width row; this also covers opens that do not come from a click.
  onPopupOpenChanged: if (root.popupOpen) button.hideOwnTooltip()

  Component.onCompleted: {
    pushSettings()
    reportIconAnchor()
  }
  Component.onDestruction: {
    if (ringLightService && iconScreenRect && typeof ringLightService.clearIconAnchor === "function")
      ringLightService.clearIconAnchor(iconScreenRect.screen)
  }
  onRingLightServiceChanged: {
    pushSettings()
    reportIconAnchor()
  }
  onIconScreenRectChanged: reportIconAnchor()
  onConfiguredWidthChanged: pushSettings()
  onConfiguredBrightnessChanged: pushSettings()
  onConfiguredTemperatureChanged: pushSettings()
  onConfiguredScreenChanged: pushSettings()

  Connections {
    target: ringLightService

    function onSettingsRequested(screenName) {
      if (!root.onThisScreen(screenName)) return
      root.popupOpen = !root.popupOpen
    }

    function onWidthNudged(screenName, delta) {
      if (delta === 0 || !root.onThisScreen(screenName)) return
      root.previewWidth(root.currentWidth + (delta > 0 ? root.widthStep : -root.widthStep))
      widthCommitTimer.restart()
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: root.lightActive
    interactive: root.ringLightService !== null
    tooltipText: (root.lightActive ? "Ring light on" : "Ring light off")
      + (root.multipleScreens ? " · " + root.currentScreenLabel : "")
      + " · " + root.currentWidth + " px · " + root.currentTemperature + " K · Right-click to adjust"

    iconComponent: Component {
      // The icon canvas stretches its loaded root item to the slot size, so
      // the drawn ring sits inside an unsized wrapper at its own size.
      Item {
        Rectangle {
          anchors.centerIn: parent
          width: 12
          height: 12
          radius: 6
          color: "transparent"
          border.width: root.lightActive ? 4 : 2
          border.color: button.foreground
        }
      }
    }

    onPressed: function(mouseButton) {
      if (!root.ringLightService) return
      if (mouseButton === Qt.LeftButton) root.ringLightService.toggle()
      else if (mouseButton === Qt.RightButton) root.popupOpen = !root.popupOpen
    }

    onWheelMoved: function(delta) {
      if (delta === 0) return
      root.previewWidth(root.currentWidth + (delta > 0 ? root.widthStep : -root.widthStep))
      widthCommitTimer.restart()
    }
  }

  // Wheel notches coalesce into one shell.json write.
  Timer {
    id: widthCommitTimer
    interval: 500
    onTriggered: root.commitWidth(root.currentWidth)
  }

  component SliderRow: Column {
    id: row

    required property string label
    required property string displayValue
    required property real minimum
    required property real maximum
    required property real step
    required property real value

    signal preview(real value)
    signal commit(real value)

    width: parent.width
    spacing: Style.space(8)

    Row {
      id: header
      width: parent.width
      spacing: Style.space(6)

      Text {
        id: headerLabel
        textFormat: Text.PlainText
        text: row.label
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
      }

      Item {
        width: Math.max(0, header.width - headerLabel.implicitWidth - headerValue.implicitWidth - header.spacing * 2)
        height: 1
      }

      Text {
        id: headerValue
        textFormat: Text.PlainText
        text: row.displayValue
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    PanelSlider {
      width: parent.width
      bar: root.bar
      minimum: row.minimum
      maximum: row.maximum
      step: row.step
      integer: true
      value: row.value
      onMoved: function(value) { row.preview(value) }
      onReleased: function(value) { row.commit(value) }
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(240))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(8)

      Dropdown {
        id: screenSelect
        width: parent.width
        visible: root.multipleScreens
        label: "Screen"
        options: root.screenOptions
        value: root.currentScreen
        foreground: root.bar.foreground
        fontFamily: root.bar.fontFamily
        onChanged: function(value) { root.commitScreen(value) }
      }

      SliderRow {
        label: "Border width"
        displayValue: root.currentWidth + " px"
        minimum: root.minimumWidth
        maximum: root.maximumWidth
        step: root.widthStep
        value: root.currentWidth
        onPreview: function(value) { root.previewWidth(value) }
        onCommit: function(value) { root.commitWidth(value) }
      }

      SliderRow {
        label: "Temperature"
        displayValue: root.currentTemperature + " K"
        minimum: root.minimumTemperature
        maximum: root.maximumTemperature
        step: root.temperatureStep
        value: root.currentTemperature
        onPreview: function(value) { root.previewTemperature(value) }
        onCommit: function(value) { root.commitTemperature(value) }
      }
    }
  }
}
