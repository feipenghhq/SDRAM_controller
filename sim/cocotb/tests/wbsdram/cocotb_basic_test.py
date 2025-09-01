# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/10/2025
#
# -------------------------------------------------------------------
# Basic wbsdram test
# -------------------------------------------------------------------

from utils import *
from WbHostBFM import WbHostBFM

import cocotb
from cocotb.triggers import Timer


@cocotb.test()
async def write(dut):
    """
    Test Single Write request
    """
    addr = 0x1234
    data = 0x5678
    bus = WbHostBFM(dut)
    await init(dut, sdram_debug=True)
    await bus.single_write(addr, data, 0x3)
    await Timer(100, units='ns')

@cocotb.test()
async def read(dut):
    """
    Test read request
    """
    addr = 0xcafe
    data = 0xbeef
    bus = WbHostBFM(dut)
    await init(dut, sdram_debug=True)
    await bus.single_write(addr, data, 0x3, True)
    rdata = await bus.single_read(addr, 0x3, True)
    assert rdata == data
    await Timer(100, units='ns')
