pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "local.ring-light"

  readonly property var ringLightService: {
    if (!bar || !bar.shell || typeof bar.shell.serviceFor !== "function") return null
    return bar.shell.serviceFor(root.moduleName)
  }

  readonly property bool lightActive: ringLightService ? ringLightService.active : false
  readonly property var configuredWidth: root.setting("borderWidth", 64)
  readonly property var configuredBrightness: root.setting("brightness", 100)
  readonly property string configuredScreen: String(root.setting("screen", ""))

  readonly property int minimumWidth: 16
  readonly property int maximumWidth: 200
  readonly property int widthStep: 8

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

  property bool popupOpen: false

  function boundedWidth(value) {
    var number = Number(value)
    if (!isFinite(number)) return 64
    return Math.max(root.minimumWidth, Math.min(root.maximumWidth, Math.round(number)))
  }

  function pushSettings() {
    if (ringLightService)
      ringLightService.applySettings(configuredWidth, configuredBrightness, configuredScreen)
  }

  // Live width with no persistence, so the border follows the slider.
  function previewWidth(pixels) {
    if (ringLightService) ringLightService.setBorderWidth(root.boundedWidth(pixels))
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

  Component.onCompleted: pushSettings()
  onRingLightServiceChanged: pushSettings()
  onConfiguredWidthChanged: pushSettings()
  onConfiguredBrightnessChanged: pushSettings()
  onConfiguredScreenChanged: pushSettings()

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
      + " · " + root.currentWidth + " px · Right-click to adjust"

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

  PopupCard {
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

      Row {
        id: header
        width: parent.width
        spacing: Style.space(6)

        Text {
          id: headerLabel
          textFormat: Text.PlainText
          text: "Border width"
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
          text: root.currentWidth + " px"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }
      }

      PanelSlider {
        width: parent.width
        bar: root.bar
        minimum: root.minimumWidth
        maximum: root.maximumWidth
        step: root.widthStep
        integer: true
        value: root.currentWidth
        onMoved: function(value) { root.previewWidth(value) }
        onReleased: function(value) { root.commitWidth(value) }
      }
    }
  }
}
