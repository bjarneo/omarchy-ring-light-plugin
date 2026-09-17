pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: root

  required property var targetScreen
  property bool active: false
  property int borderWidth: 64
  property int brightness: 100

  // Keep the center open on small displays and after scale changes.
  readonly property int fadeWidth: Math.min(borderWidth, Math.floor(Math.min(width, height) / 4))

  screen: targetScreen
  visible: active
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore

  WlrLayershell.namespace: "omarchy-ring-light"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  // An empty input region lets all clicks and scroll events pass through.
  mask: Region {
    width: 0
    height: 0
  }

  component EdgeGradient: Rectangle {
    id: edge

    required property real lightLevel
    property bool horizontal: false

    function shade(alpha) {
      return Qt.rgba(lightLevel, lightLevel, lightLevel, alpha)
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

  EdgeGradient {
    anchors { top: parent.top; left: parent.left; right: parent.right }
    height: root.fadeWidth
    lightLevel: root.brightness / 100
  }

  EdgeGradient {
    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
    height: root.fadeWidth
    rotation: 180
    lightLevel: root.brightness / 100
  }

  EdgeGradient {
    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
    width: root.fadeWidth
    horizontal: true
    lightLevel: root.brightness / 100
  }

  EdgeGradient {
    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
    width: root.fadeWidth
    horizontal: true
    rotation: 180
    lightLevel: root.brightness / 100
  }
}
