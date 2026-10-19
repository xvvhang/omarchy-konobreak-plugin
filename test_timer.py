import unittest
from timer import Timer, settings


class TimerTests(unittest.TestCase):
    def setUp(self):
        self.now = 0
        self.notices = []
        self.timer = Timer({"workMinutes": 1, "breakMinutes": 1, "repeatMode": "fixed", "cycles": 2},
                           clock=lambda: self.now, notify=lambda *args: self.notices.append(args))

    def advance(self, seconds):
        self.now += seconds
        self.timer.tick()

    def test_confirmation_and_completion(self):
        self.timer.command("toggle")
        self.advance(60)
        self.assertEqual(self.timer.phase, "waiting")
        self.advance(300)
        self.assertEqual(self.timer.phase, "waiting")
        self.assertEqual(len(self.notices), 1)
        self.timer.command("break")
        self.advance(60)
        self.assertEqual((self.timer.phase, self.timer.cycle), ("work", 2))
        self.advance(60)
        self.timer.command("break")
        self.advance(60)
        self.assertEqual(self.timer.phase, "complete")
        self.assertEqual(self.notices[-1][0], "Session Complete")
        self.advance(300)
        self.assertEqual(len(self.notices), 4)

    def test_pause_resume_and_snooze(self):
        self.timer.command("toggle")
        self.advance(20)
        self.timer.command("toggle")
        self.advance(100)
        self.assertEqual(self.timer.remaining, 40)
        self.timer.command("toggle")
        self.advance(40)
        self.timer.command("snooze")
        self.advance(100)
        self.timer.command("toggle")
        self.advance(400)
        self.assertEqual(self.timer.remaining, 200)
        self.timer.command("toggle")
        self.advance(200)
        self.assertEqual(self.timer.phase, "waiting")
        self.assertEqual(len(self.notices), 2)

    def test_settings_do_not_reset_interval_or_plan(self):
        self.timer.command("toggle")
        self.advance(10)
        self.timer.command("configure", {"workMinutes": 2, "breakMinutes": 2, "repeatMode": "once"})
        self.assertEqual(self.timer.remaining, 50)
        self.assertEqual(self.timer.mode, "fixed")
        self.timer.command("break")
        self.assertEqual(self.timer.remaining, 120)

    def test_restart_restores_paused(self):
        self.timer.command("toggle")
        self.advance(17)
        restored = Timer(clock=lambda: self.now)
        restored.restore(self.timer.snapshot())
        self.assertTrue(restored.paused)
        self.assertEqual(restored.remaining, 43)
        self.assertIsNone(restored.deadline)

    def test_sleep_is_excluded_by_clock(self):
        self.timer.command("toggle")
        self.advance(15)
        # CLOCK_MONOTONIC does not advance during Linux suspend.
        self.timer.tick()
        self.assertEqual(self.timer.remaining, 45)
        self.assertEqual(len(self.notices), 0)

    def test_validation(self):
        self.assertEqual(settings({"workMinutes": -1, "breakMinutes": "invalid", "cycles": 1000})["cycles"], 99)
        self.assertEqual(settings({"workMinutes": -1})["workMinutes"], 1)

    def test_once_finishes_after_break(self):
        self.timer.command("configure", {"workMinutes": 1, "breakMinutes": 1, "repeatMode": "once"})
        self.timer.command("toggle")
        self.advance(60)
        self.timer.command("break")
        self.advance(60)
        self.assertEqual(self.timer.phase, "complete")
        self.assertEqual(self.notices[-1][0], "Session Complete")

    def test_continuous_starts_next_work_interval(self):
        self.timer.command("configure", {"workMinutes": 1, "breakMinutes": 1, "repeatMode": "continuous"})
        self.timer.command("toggle")
        self.timer.command("break")
        self.advance(60)
        self.assertEqual((self.timer.phase, self.timer.cycle, self.timer.remaining), ("work", 2, 60))


if __name__ == "__main__":
    unittest.main()
