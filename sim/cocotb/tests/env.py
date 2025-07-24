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
