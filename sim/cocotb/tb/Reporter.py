# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/29/2025
#
# -------------------------------------------------------------------
# Reporter: report the test progress
# -------------------------------------------------------------------

class Reporter:

    def __init__(self, log, prefix, total, bar_width=20, step=10):
        """
        Parameters:
            log      -- cocotb logger (e.g., dut._log)
            prefix   -- "WRITE", "READ", etc.
            total    -- total count
            bar_width -- width of the visual bar (default 20)
            step     -- log every `step` percent
        """
        self.log = log
        self.prefix = prefix
        self.total = total
        self.bar_width = bar_width
        self.step = step
        assert total > 0
        self.index = 0
        self.step_val = 0
        self.step_thres = total * step / 100

    def report_progress(self, delta=1):
        """
        Logs a progress to the cocotb logger.

        Example output:
        WRITE [██████░░░░░░░░░░] 30%
        """

        self.step_val += delta
        self.index += delta
        if self.step_val < self.step_thres:
            return

        self.step_val = 0
        percent = int((self.index) * 100 / self.total)
        filled = int(self.bar_width * percent / 100)
        empty = self.bar_width - filled
        bar = "█" * filled + "░" * empty
        self.log.info(f"{self.prefix:<6} [{bar}] {percent:3d}%")
