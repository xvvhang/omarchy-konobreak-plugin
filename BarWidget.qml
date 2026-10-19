import QtQuick
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "konochi.konopause"
  readonly property var service: bar?.shell?.serviceFor(moduleName)
  readonly property var state: service ? service.state : ({phase: "idle", paused: false, remaining: 0})
  readonly property bool engaged: state.phase !== "idle" && state.phase !== "complete"
  readonly property bool running: engaged && !state.paused
  readonly property bool timerVisible: engaged && setting("showTimer", true) !== false
  readonly property string countdown: {
    if (!engaged) return ""
    var seconds = Math.max(0, state.remaining || 0)
    return String(Math.floor(seconds / 60)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
  }
  readonly property string phaseLabel: state.phase === "work" ? "Working" : state.phase === "break" ? "Taking a Break" : state.phase === "waiting" ? "Time for a Break" : state.phase === "snooze" ? "Konopause Snoozed" : state.phase === "complete" ? "Session Complete" : "Ready to Start"
  readonly property string cycleLabel: !engaged ? "" : state.mode === "continuous" ? "Cycle " + state.cycle : "Cycle " + state.cycle + " of " + (state.mode === "once" ? 1 : state.total)
  readonly property bool opened: panel.opened
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing
  readonly property real openPanelIndicatorWidth: display.implicitWidth
  readonly property real openPanelIndicatorHeight: display.implicitHeight
  function open() { panel.open() }
  function close() { panel.close() }
  function closeForPopoutSwitch() { panel.closeForPopoutSwitch() }
  function toggleTimer() {
    var entry = Object.assign({}, root.settings, {id: moduleName, showTimer: setting("showTimer", true) === false})
    if (bar?.shell?.updateEntryInline(moduleName, entry)) root.settings = entry
  }
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    useActiveColor: false
    dimmed: !root.running
    labelVisible: false
    hasVisualContent: true
    // Match adjacent native icon slots, with equal padding on both sides.
    fixedWidth: root.vertical ? -1 : display.implicitWidth + Math.max(0, Style.bar.iconSlot - Style.bar.iconCanvas)
    fixedHeight: root.vertical ? display.implicitHeight + Style.space(12) : -1
    tooltipText: ""
    onPressed: function(b) {
      if (b === Qt.LeftButton) panel.toggle()
      else if (b === Qt.RightButton) root.toggleTimer()
    }
    Grid {
      id: display
      anchors.centerIn: parent
      columns: root.vertical || !root.timerVisible ? 1 : 2
      verticalItemAlignment: Grid.AlignVCenter
      spacing: root.timerVisible ? Style.space(6) : 0
      Item {
        width: Style.bar.iconCanvas
        height: width
        OpticalGlyph {
          anchors.fill: parent
          // nf-md-clock (U+F0954) / nf-md-clock_outline (U+F0150).
          text: String.fromCodePoint(root.state.phase === "work" ? 0xf0954 : 0xf0150)
          color: button.foreground
          fontFamily: button.fontFamily
          fontSize: Style.bar.iconFont
        }
      }
      Text {
        visible: root.timerVisible
        text: root.countdown
        color: button.foreground
        font.family: "monospace"
        font.pixelSize: Style.font.body
      }
    }
  }
  BreakPanel {
    id: panel
    bar: root.bar
    settings: root.settings
    anchorItem: button
    hostWidget: root
  }
}
