import QtQuick
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "alec.break-reminder"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  readonly property var service: hostWidget ? hostWidget.service : null
  readonly property var state: hostWidget ? hostWidget.state : ({})
  property int workMinutes: 50
  property int breakMinutes: 5
  property int cycles: 4
  property string repeatMode: "continuous"
  property string feedback: ""
  component ActionButton: Button {
    foreground: root.barForeground
    accent: root.barForeground
    bordered: true
    focusable: true
    fontSize: Style.font.caption
  }
  function open() {
    var config = service ? service.state.config : ({})
    workMinutes = config.workMinutes || 50
    breakMinutes = config.breakMinutes || 5
    cycles = config.cycles || 4
    repeatMode = config.repeatMode || "continuous"
    feedback = ""
    controller.show()
  }
  function updateSetting(values) {
    var entry = Object.assign({}, root.settings, {id: root.moduleName, workMinutes: workMinutes, breakMinutes: breakMinutes, cycles: cycles, repeatMode: repeatMode}, values)
    if (root.bar?.shell?.updateEntryInline(root.moduleName, entry)) {
      workMinutes = entry.workMinutes
      breakMinutes = entry.breakMinutes
      cycles = entry.cycles
      repeatMode = entry.repeatMode
      root.hostWidget.settings = entry
      if (service) service.send("configure", entry)
      feedback = ""
    } else feedback = "Could not save settings. Please try again."
  }
  KeyboardPanel {
    id: popup
    anchorItem: root.anchorItem
    bar: root.bar
    owner: root.hostWidget
    open: root.opened
    focusTarget: content
    contentWidth: fittedContentWidth(Style.space(370))
    contentHeight: fittedContentHeight(column.implicitHeight)
    Flickable {
      id: content
      anchors.fill: parent
      clip: true
      contentWidth: width
      contentHeight: column.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      Keys.onEscapePressed: root.close()
      Column {
        id: column
        width: content.width
        spacing: Style.space(14)
        Text { text: "Break Reminder"; color: root.barForeground; font.family: Style.font.family; font.pixelSize: Style.font.body * 1.2 }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: !root.service?.ready ? "Timer unavailable" : root.hostWidget.phaseLabel + (root.state.paused ? " · Paused" : "") + (root.hostWidget.engaged ? "\n" + root.hostWidget.countdown + " remaining · " + root.hostWidget.cycleLabel : "")
          color: root.barForeground
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }
        Flow {
          width: parent.width
          spacing: Style.space(6)
          ActionButton {
            text: root.hostWidget?.running ? "Pause" : root.hostWidget?.engaged ? "Resume" : "Start"
            enabled: root.service?.ready ?? false
            onClicked: root.service.send("toggle")
          }
          ActionButton {
            text: "Start Break"
            visible: ["work", "waiting", "snooze"].indexOf(root.state.phase) !== -1
            onClicked: root.service.send("break")
          }
          ActionButton {
            text: "Remind in 5 min"
            visible: root.state.phase === "waiting" && !root.state.paused
            onClicked: root.service.send("snooze")
          }
          ActionButton { text: "End Session"; visible: root.hostWidget?.engaged ?? false; onClicked: root.service.send("end") }
        }
        Row {
          spacing: Style.space(16)
          NumberField { label: "Work (min)"; value: root.workMinutes; from: 1; to: 240; foreground: root.barForeground; accent: root.barForeground; onModified: function(v) { root.updateSetting({workMinutes: v}) } }
          NumberField { label: "Break (min)"; value: root.breakMinutes; from: 1; to: 120; foreground: root.barForeground; accent: root.barForeground; onModified: function(v) { root.updateSetting({breakMinutes: v}) } }
        }
        Flow {
          width: parent.width
          spacing: Style.space(6)
          ActionButton { text: "25 / 5"; onClicked: root.updateSetting({workMinutes: 25, breakMinutes: 5}) }
          ActionButton { text: "50 / 5"; onClicked: root.updateSetting({workMinutes: 50, breakMinutes: 5}) }
        }
        Text { text: "Repeat"; color: root.barForeground; font.family: Style.font.family; font.pixelSize: Style.font.body }
        Flow {
          width: parent.width
          spacing: Style.space(6)
          ActionButton { text: "Once"; selected: root.repeatMode === "once"; onClicked: root.updateSetting({repeatMode: "once"}) }
          ActionButton { text: "Fixed Cycles"; selected: root.repeatMode === "fixed"; onClicked: root.updateSetting({repeatMode: "fixed"}) }
          ActionButton { text: "Continuous"; selected: root.repeatMode === "continuous"; onClicked: root.updateSetting({repeatMode: "continuous"}) }
        }
        NumberField { visible: root.repeatMode === "fixed"; label: "Cycles"; value: root.cycles; from: 1; to: 99; foreground: root.barForeground; accent: root.barForeground; onModified: function(v) { root.updateSetting({cycles: v}) } }
        Text {
          width: parent.width
          wrapMode: Text.WordWrap
          text: "Settings save automatically. One cycle = work + break.\nDuration changes apply to the next interval. Repeat changes apply to the next session.\nSleep freezes all timers. Restarted timers restore paused."
          color: root.barForeground
          opacity: 0.65
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: root.feedback; visible: text !== ""; color: root.barForeground; font.pixelSize: Style.font.caption }
      }
    }
  }
}
