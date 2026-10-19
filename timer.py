"""Single timer backend. Linux CLOCK_MONOTONIC excludes system suspend time."""
import json
import math
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time

PLUGIN_ID = "konochi.konopause"


def read_config():
    shell = json.loads((Path.home() / ".config/omarchy/shell.json").read_text())
    for section in shell.get("bar", {}).get("layout", {}).values():
        for entry in section:
            if isinstance(entry, dict) and entry.get("id") == PLUGIN_ID:
                return settings(entry)
    return None


def settings(values):
    def bounded(key, default, maximum):
        try:
            return max(1, min(maximum, int(values.get(key, default))))
        except (ValueError, TypeError, OverflowError):
            return default
    mode = values.get("repeatMode", "continuous")
    return dict(workMinutes=bounded("workMinutes", 50, 240),
                breakMinutes=bounded("breakMinutes", 5, 120),
                cycles=bounded("cycles", 4, 99),
                repeatMode=mode if mode in ("once", "fixed", "continuous") else "continuous")


class Timer:
    def __init__(self, config=None, clock=time.monotonic, notify=None):
        self.config = settings(config or {})
        self.clock = clock
        self.notify = notify or (lambda *args: None)
        self.phase = "idle"
        self.paused = False
        self.remaining = 0.0
        self.deadline = None
        self.cycle = 0
        self.mode = "continuous"
        self.total = 4
        self.generation = 0

    def snapshot(self):
        return dict(phase=self.phase, paused=self.paused,
                    remaining=math.ceil(max(0, self.remaining)), cycle=self.cycle,
                    mode=self.mode, total=self.total, config=self.config)

    def restore(self, saved):
        if saved.get("phase") not in ("work", "waiting", "break", "snooze"):
            return
        self.phase = saved["phase"]
        self.remaining = max(0, min(14400, float(saved.get("remaining", 0))))
        self.cycle = max(1, min(99, int(saved.get("cycle", 1))))
        self.mode = saved.get("mode", "continuous")
        self.total = max(1, min(99, int(saved.get("total", 4))))
        self.paused = True

    def interval(self, phase, seconds):
        self.generation += 1
        self.phase = phase
        self.remaining = seconds
        self.deadline = None if self.paused else self.clock() + seconds

    def tick(self):
        if self.deadline is None or self.paused:
            return
        self.remaining = max(0, self.deadline - self.clock())
        if self.remaining > 0:
            return
        if self.phase in ("work", "snooze"):
            self.interval("waiting", 0)
            self.deadline = None
            self.notify("Time for a Break",
                        f"Step away from your computer for {self.config['breakMinutes']} minutes.",
                        self.generation)
        elif self.phase == "break":
            if self.mode == "once" or (self.mode == "fixed" and self.cycle >= self.total):
                count = self.cycle
                self.generation += 1
                self.deadline = None
                self.remaining = 0
                self.paused = False
                self.phase = "complete"
                self.notify("Session Complete", f"You completed {count} work-and-break cycle{'s' if count != 1 else ''}.", None)
            else:
                self.cycle += 1
                self.interval("work", self.config["workMinutes"] * 60)
                self.notify("Break Complete", f"Your next {self.config['workMinutes']}-minute work interval is starting.", None)

    def command(self, action, values=None):
        self.tick()
        if action == "configure":
            self.config = settings(values or {})
        elif action == "toggle":
            if self.phase in ("idle", "complete"):
                self.cycle = 1
                self.mode = self.config["repeatMode"]
                self.total = self.config["cycles"]
                self.paused = False
                self.interval("work", self.config["workMinutes"] * 60)
            elif self.paused:
                self.paused = False
                if self.phase != "waiting":
                    self.deadline = self.clock() + self.remaining
            else:
                self.paused = True
                self.deadline = None
        elif action == "break" and self.phase in ("work", "waiting", "snooze"):
            self.paused = False
            self.interval("break", self.config["breakMinutes"] * 60)
        elif action == "snooze" and self.phase == "waiting" and not self.paused:
            self.interval("snooze", 300)
        elif action == "end":
            self.generation += 1
            self.phase = "idle"
            self.paused = False
            self.remaining = 0
            self.deadline = None
            self.cycle = 0


def main():
    commands = queue.Queue()
    children = []
    state_path = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "omarchy-break-reminder.json"

    def notify(title, body, generation):
        def worker():
            args = ["notify-send", "-a", "Konopause", "-t", "15000"]
            if generation is not None:
                args += ["-A", "break=Start Break", "-A", "snooze=Remind in 5 min"]
            try:
                children[:] = [child for child in children if child.poll() is None]
                proc = subprocess.Popen(args + [title, body], stdout=subprocess.PIPE, text=True)
                children.append(proc)
                output, _ = proc.communicate(timeout=120)
                action = output.strip()
                if generation is not None and action in ("break", "snooze"):
                    commands.put(dict(action=action, generation=generation))
            except (OSError, subprocess.TimeoutExpired):
                if 'proc' in locals() and proc.poll() is None:
                    proc.terminate()
        threading.Thread(target=worker, daemon=True).start()

    try:
        config = read_config()
    except (OSError, ValueError, TypeError):
        config = None
    timer = Timer(config, notify=notify)
    try:
        timer.restore(json.loads(state_path.read_text()))
    except (OSError, ValueError, TypeError):
        pass

    def reader():
        for line in sys.stdin:
            try:
                commands.put(json.loads(line))
            except ValueError:
                pass
        commands.put(dict(action="quit"))
    threading.Thread(target=reader, daemon=True).start()
    previous = None
    last_save = 0
    last_config_check = 0
    try:
        while True:
            try:
                message = commands.get(timeout=0.2)
                if message.get("action") == "quit":
                    break
                if "generation" not in message or (message["generation"] == timer.generation and not timer.paused):
                    timer.command(message.get("action"), message.get("settings"))
            except queue.Empty:
                pass
            if time.monotonic() - last_config_check >= 1:
                try:
                    config = read_config()
                    if config is not None and config != timer.config:
                        timer.command("configure", config)
                except (OSError, ValueError, TypeError):
                    pass
                last_config_check = time.monotonic()
            timer.tick()
            snapshot = timer.snapshot()
            if snapshot != previous:
                print(json.dumps(snapshot), flush=True)
                significant = previous is None or any(snapshot[k] != previous[k] for k in ("phase", "paused", "config", "cycle"))
                if significant or time.monotonic() - last_save >= 5:
                    temporary = state_path.with_suffix(".tmp")
                    temporary.write_text(json.dumps(snapshot))
                    temporary.replace(state_path)
                    last_save = time.monotonic()
                previous = snapshot
    finally:
        state_path.write_text(json.dumps(timer.snapshot()))
        for proc in children:
            if proc.poll() is None:
                proc.terminate()


if __name__ == "__main__":
    main()
