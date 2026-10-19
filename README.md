# Konobreak

Part of **Konochi**, a personal Omarchy plugin series by Alec Xu.

An Omarchy shell plugin with a shared work/break timer across all monitors.

- Left-click: immediately open or close the settings and session controls panel.
- Right-click: toggle the saved Show Timer in Bar setting. Start, pause, and resume are also available in the panel.
- Working and break intervals use an `mm:ss` countdown, also available while paused when Show Timer in Bar is enabled.
- The bar uses a filled clock for work (`nf-md-clock`, U+F0954) and an outline clock for breaks and other states (`nf-md-clock_outline`, U+F0150). Pausing preserves the phase icon. Without a session, only the icon is shown; the countdown is hidden.
- Right-clicking the bar widget toggles the countdown display without affecting the timer; this option is not shown in the panel. Icon-only mode uses the native icon-slot width with symmetric padding. The open-panel underline follows the visible icon-and-timer content width.
- Hovering does not show a tooltip or open a panel.
- Work completion waits for **Start Break**. Dismissing a notification does not start a break.
- **Remind in 5 min** delays the break reminder without advancing the cycle.
- One cycle is one work interval plus one break. Repeat once, for a fixed number of cycles, or continuously.
- Linux's monotonic clock excludes suspend time, including during breaks and snoozes.
- Screen locking and display power-off do not pause timers.
- Settings save automatically on modification, inline in `~/.config/omarchy/shell.json`; no Save button is required.
- Runtime progress is checkpointed in `$XDG_CACHE_HOME/omarchy-break-reminder.json` (normally `~/.cache/`). A restarted service restores paused; at most five seconds of progress may be lost after abrupt termination.
- Duration changes apply to the next interval; repeat changes apply to the next session.
- The icon and countdown use the bar foreground, with full opacity while running and 0.45 opacity while paused or without a session, with no active accent color.

## Requirements

Omarchy shell, `/usr/bin/python3` (standard library only), and `notify-send` with action support.

## Commands

```sh
omarchy plugin enable konochi.konobreak
omarchy plugin disable konochi.konobreak
omarchy-shell konochi.konobreak status
omarchy-shell konochi.konobreak toggle
omarchy-shell konochi.konobreak startBreak
omarchy-shell konochi.konobreak snooze
omarchy-shell konochi.konobreak end
```

The service is kept loaded across widget hot reloads. Backend/service changes require a shell restart to take effect.

## Tests

```sh
/usr/bin/python3 -B -m unittest -v test_timer
```

## Install and remove

Requires Omarchy Quattro and the dependencies above. No privileged setup,
external service installation, or network access.

```sh
omarchy plugin add https://github.com/xvvhang/omarchy-konobreak-plugin --enable
omarchy plugin disable konochi.konobreak
omarchy plugin remove konochi.konobreak
```

Removal leaves the runtime checkpoint mentioned above. Back up unpushed changes
before removal. The plugin does not start a work session just by being installed.

## QML validation

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell ./*.qml
```

Use Qt 6's qmllint (the default executable may be Qt 5). MIT licensed; see LICENSE.
