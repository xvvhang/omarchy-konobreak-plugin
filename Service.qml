import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root
  property var shell: null
  property var state: ({phase: "idle", paused: false, remaining: 0, cycle: 0, mode: "continuous", total: 4, config: {workMinutes: 50, breakMinutes: 5, repeatMode: "continuous", cycles: 4}})
  readonly property bool ready: backend.running && receivedState
  property bool receivedState: false
  function send(action, settings) {
    if (ready) backend.write(JSON.stringify({action: action, settings: settings || {}}) + "\n")
  }
  Process {
    id: backend
    command: ["/usr/bin/python3", "-B", Qt.resolvedUrl("timer.py").toString().replace(/^file:\/\//, "")]
    running: true
    stdinEnabled: true
    stdout: SplitParser {
      onRead: function(line) {
        try { root.state = JSON.parse(line); root.receivedState = true }
        catch (error) { console.warn("Konobreak:", error) }
      }
    }
    onExited: function(code) { root.receivedState = false; console.warn("Konobreak backend stopped:", code) }
  }
  IpcHandler {
    target: "konochi.konobreak"
    function status(): string { return JSON.stringify(root.state) }
    function toggle(): void { root.send("toggle") }
    function startBreak(): void { root.send("break") }
    function snooze(): void { root.send("snooze") }
    function end(): void { root.send("end") }
  }
}
