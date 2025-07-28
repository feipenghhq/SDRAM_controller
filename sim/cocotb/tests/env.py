# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# Environment
# -------------------------------------------------------------------

import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from bus import *
import os

clk_freq = int(os.environ.get("FREQ", 50))
clk_period = round(1000.0 / clk_freq)
clk_period = round(clk_period, 2)

def load_mode_reg(dut, burst_len=0, burst_type=0, cas=2, write_burst_mode=0):
    dut.cfg_burst_length.value  = burst_len
    dut.cfg_burst_type.value    = burst_type
    dut.cfg_cas_latency.value   = cas
    dut.cfg_burst_mode.value    = write_burst_mode

async def init(dut, period = 10, debug=False):
    """
    Initialize the environment: setup clock, load the hack rom and reset the design
    """
    bus_init(dut)
    # start clock
    cocotb.start_soon(Clock(dut.clk, period, units = 'ns').start()) # clock
    # generate reset
    dut.rst_n.value = 0
    await Timer(period * 5, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    if not debug:
        dut.sdram_model.Debug.value = 0

step_val = 0
total_val = 0
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

    def report_progress(self, delta):
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
        percent = int((self.index + 1) * 100 / self.total)
        filled = int(self.bar_width * percent / 100)
        empty = self.bar_width - filled
        bar = "█" * filled + "░" * empty
        self.log.info(f"{self.prefix:<6} [{bar}] {percent:3d}%")
