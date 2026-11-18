import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Pending upgrades, as reported by `upgrade-check` (all logic lives there;
// this widget only displays its state and forwards clicks).
// left = show the notification · right = not now · middle = check now
BarWidget {
  id: root
  moduleName: "local.upgrades"

  readonly property string tool: "upgrade-check"
  readonly property int checkEverySeconds: 6 * 3600
  readonly property int maxTooltipLines: 12

  property int count: 0
  property bool dismissed: false
  property var lines: []

  // Tooltips are Omarchy-owned text sinks; keep package names from reading as markup.
  function plain(value) { return String(value).replace(/[<>&]/g, "").slice(0, 200) }

  function refresh() { if (!statusProc.running) statusProc.running = true }

  function check(force) {
    if (checkProc.running) return
    checkProc.command = force
      ? [tool, "check", "--notify"]
      : [tool, "check", "--notify", "--max-age", String(checkEverySeconds)]
    checkProc.running = true
  }

  function run(command) { Quickshell.execDetached([tool, command]) }

  function applyStatus(json) {
    try {
      var s = JSON.parse(json || "{}")
      count = s.count || 0
      dismissed = !!s.dismissed
      lines = (s.lines || []).slice(0, maxTooltipLines).map(plain)
    } catch (e) {
      console.warn("local.upgrades: bad status from " + tool + ": " + e)
      count = 0
    }
  }

  visible: count > 0 && !dismissed
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  // `upgrade-check` calls this after every state change.
  ShellIpc {
    target: "local.upgrades"
    function refresh(): void { root.broadcast("refresh") }
  }

  Process {
    id: statusProc
    command: [root.tool, "status"]
    stdout: StdioCollector { onStreamFinished: root.applyStatus(String(text || "")) }
  }

  // Network check; the tool serialises concurrent runs and toasts only for a new set.
  Process {
    id: checkProc
    onExited: root.refresh()
  }

  // Cheap poll: the tool skips the real check until the last one is older than
  // checkEverySeconds, so this also catches up soon after a suspend.
  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.check(false)
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏔"
    slotSize: Style.bar.statusSlot
    labelText: root.count > 0 ? String(root.count) : ""
    tooltipText: root.count + (root.count === 1 ? " upgrade" : " upgrades") + " pending\n"
      + root.lines.join("\n")
      + "\n\nClick: details · Right-click: not now · Middle-click: check now"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.run("dismiss")
      else if (mouseButton === Qt.MiddleButton) root.check(true)
      else root.run("notify")
    }
  }
}
