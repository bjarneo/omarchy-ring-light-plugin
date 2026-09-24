pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
  id: root

  required property var targetScreen
  property bool active: false
  property int borderWidth: 64
  property int brightness: 100
  property int temperature: 6500
  property bool showBar: false
  // Keeps the light window mapped while it is off, so a settings card that
  // opens afterwards stacks above it once the light turns on.
  property bool held: false
  property var iconAnchor: null

  signal iconPressed(int button)
  signal iconWheeled(int delta)

  // Keep the center open on small displays and after scale changes.
  readonly property int fadeWidth: Math.min(borderWidth, Math.floor(Math.min(light.width, light.height) / 2))

  // Tanner Helland's kelvin-to-RGB approximation, scaled by brightness.
  readonly property color lightColor: {
    var temp = Math.max(10, temperature / 100)
    var red
    var green
    var blue
    var level = brightness / 100

    if (temp <= 66) {
      red = 255
      green = 99.4708025861 * Math.log(temp) - 161.1195681661
    } else {
      red = 329.698727446 * Math.pow(temp - 60, -0.1332047592)
      green = 288.1221695283 * Math.pow(temp - 60, -0.0755148492)
    }

    if (temp >= 66) blue = 255
    else if (temp <= 19) blue = 0
    else blue = 138.5177312231 * Math.log(temp - 10) - 305.0447927307

    red = Math.max(0, Math.min(255, red)) / 255 * level
    green = Math.max(0, Math.min(255, green)) / 255 * level
    blue = Math.max(0, Math.min(255, blue)) / 255 * level
    return Qt.rgba(red, green, blue, 1)
  }

  readonly property int fallbackIconSize: 28
  readonly property bool hasIconAnchor: iconAnchor
    && iconAnchor.width > 0
    && iconAnchor.height > 0
  readonly property int floatingX: hasIconAnchor
    ? Math.round(iconAnchor.x)
    : Math.round(((targetScreen ? targetScreen.width : 0) - fallbackIconSize) / 2)
  readonly property int floatingY: hasIconAnchor
    ? Math.round(iconAnchor.y)
    : Math.round(Math.max(0, (fadeWidth - fallbackIconSize) / 2))
  readonly property int floatingW: hasIconAnchor ? Math.round(iconAnchor.width) : fallbackIconSize
  readonly property int floatingH: hasIconAnchor ? Math.round(iconAnchor.height) : fallbackIconSize

  // Two overlay surfaces stack in map order, so a full-screen light would
  // hide a separate icon window. When the light covers the whole screen the
  // icon lives inside it, where the screen coordinates also apply as is.
  readonly property bool iconInLight: !showBar || (targetScreen
    && light.width >= targetScreen.width
    && light.height >= targetScreen.height)

  // A dark chip keeps the glyph readable against any color temperature.
  component FloatingIcon: Item {
    id: icon

    signal pressed(int button)
    signal wheeled(int delta)

    Rectangle {
      anchors.centerIn: parent
      width: Math.max(22, Math.min(parent.width, parent.height) - 2)
      height: width
      radius: width / 2
      color: iconMouse.containsMouse ? Qt.rgba(0, 0, 0, 0.78) : Qt.rgba(0, 0, 0, 0.62)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.35)

      Rectangle {
        anchors.centerIn: parent
        width: 12
        height: 12
        radius: 6
        color: "transparent"
        border.width: 4
        border.color: "white"
      }
    }

    MouseArea {
      id: iconMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onPressed: function(mouse) { icon.pressed(mouse.button) }
      onWheel: function(wheel) { icon.wheeled(wheel.angleDelta.y) }
    }
  }

  component EdgeGradient: Rectangle {
    id: edge

    required property color lightColor
    property bool horizontal: false

    function shade(alpha) {
      return Qt.rgba(lightColor.r, lightColor.g, lightColor.b, alpha)
    }

    gradient: Gradient {
      orientation: edge.horizontal ? Gradient.Horizontal : Gradient.Vertical
      GradientStop { position: 0; color: edge.shade(1) }
      GradientStop { position: 0.25; color: edge.shade(0.85) }
      GradientStop { position: 0.5; color: edge.shade(0.5) }
      GradientStop { position: 0.75; color: edge.shade(0.15) }
      GradientStop { position: 1; color: edge.shade(0) }
    }
  }

  // Normal exclusion keeps the light out of the bar's reserved zone, so the
  // compositor stops the border at the bar on whichever edge it sits and
  // lets it reach the edge again when the bar is hidden. Ignore covers the
  // whole screen, bar included.
  PanelWindow {
    id: light

    screen: root.targetScreen
    visible: root.active || root.held
    color: "transparent"
    exclusionMode: root.showBar ? ExclusionMode.Normal : ExclusionMode.Ignore

    WlrLayershell.namespace: "omarchy-ring-light"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Only the icon captures input, and only when it is drawn here. The rest
    // stays click-through so the desktop and the bar keep working.
    mask: Region {
      x: root.active && root.iconInLight ? root.floatingX : 0
      y: root.active && root.iconInLight ? root.floatingY : 0
      width: root.active && root.iconInLight ? root.floatingW : 0
      height: root.active && root.iconInLight ? root.floatingH : 0
    }

    Item {
      anchors.fill: parent
      visible: root.active

      EdgeGradient {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: root.fadeWidth
        lightColor: root.lightColor
      }

      EdgeGradient {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
        height: root.fadeWidth
        rotation: 180
        lightColor: root.lightColor
      }

      EdgeGradient {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: root.fadeWidth
        horizontal: true
        lightColor: root.lightColor
      }

      EdgeGradient {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: root.fadeWidth
        horizontal: true
        rotation: 180
        lightColor: root.lightColor
      }

      FloatingIcon {
        visible: root.iconInLight
        x: root.floatingX
        y: root.floatingY
        width: root.floatingW
        height: root.floatingH
        onPressed: function(button) { root.iconPressed(button) }
        onWheeled: function(delta) { root.iconWheeled(delta) }
      }
    }
  }

  // When the light stops at the bar, the icon needs its own window to sit
  // over the bar icon, outside the lit area.
  PanelWindow {
    id: floatingWindow

    screen: root.targetScreen
    visible: root.active && !root.iconInLight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: root.floatingW
    implicitHeight: root.floatingH

    WlrLayershell.namespace: "omarchy-ring-light-toggle"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      left: true
    }

    margins {
      top: root.floatingY
      left: root.floatingX
    }

    FloatingIcon {
      anchors.fill: parent
      onPressed: function(button) { root.iconPressed(button) }
      onWheeled: function(delta) { root.iconWheeled(delta) }
    }
  }
}
