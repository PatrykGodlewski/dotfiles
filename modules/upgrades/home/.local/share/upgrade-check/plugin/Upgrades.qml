import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Pending upgrades (Omarchy, pacman, AUR, mise), fed by `upgrade-check`.
// left = update · right = not now (hide until something new) · middle = re-check
BarWidget {
  id: root
  moduleName: "local.upgrades"

  property int count: 0
  property bool dismissed: false
  property string details: ""

  // Tooltips are Omarchy-owned text sinks; keep package names from reading as markup.
  function plain(s) { return String(s).replace(/[<>&]/g, "") }

  function refresh() { if (!statusProc.running) statusProc.running = true }
  function recheck() { if (!checkProc.running) checkProc.running = true }

  function run(args) {
    Quickshell.execDetached(["upgrade-check"].concat(args))
  }

  visible: count > 0 && !dismissed
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  ShellIpc {
    target: "local.upgrades"
    function refresh(): void { root.broadcast("refresh") }
  }

  Process {
    id: statusProc
    command: ["upgrade-check", "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var s = JSON.parse(String(text || "{}"))
          root.count = s.count || 0
          root.dismissed = !!s.dismissed
          var groups = {}
          var items = (s.items || []).slice(0, 200)
          for (var i = 0; i < items.length; i++) {
            var src = root.plain(items[i].label || items[i].source || "").slice(0, 30)
            groups[src] = (groups[src] || []).concat(root.plain(items[i].name || "").slice(0, 60))
          }
          var lines = []
          for (var k in groups) {
            var names = groups[k]
            lines.push(k + " (" + names.length + "): " + names.slice(0, 6).join(", ") + (names.length > 6 ? ", …" : ""))
          }
          root.details = lines.join("\n")
        } catch (e) {
          root.count = 0
        }
      }
    }
  }

  // Full check (network). Notifies only when the pending set is new.
  Process {
    id: checkProc
    command: ["upgrade-check", "check", "--notify"]
    onExited: root.refresh()
  }

  Timer { // pick up state written by the boot / update hooks
    interval: 2000
    running: true
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    interval: 21600000 // 6h
    running: true
    repeat: true
    onTriggered: root.recheck()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰏔" // nf-md-package_up
    slotSize: Style.bar.statusSlot
    tooltipText: root.count + " upgrade" + (root.count === 1 ? "" : "s") + " pending\n"
      + root.details
      + "\n\nClick: update · Right-click: not now · Middle: re-check"
    onPressed: function(btn) {
      if (btn === Qt.RightButton) root.run(["dismiss"])
      else if (btn === Qt.MiddleButton) root.recheck()
      else root.run(["update"])
    }
  }
}
