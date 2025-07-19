# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# Basic SDRAM test
# -------------------------------------------------------------------

import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.clock import Clock
from env import *

@cocotb.test()
async def test_init(dut):
    await init(dut)
    load_mode_reg(dut)
    await Timer(210, units='us')
