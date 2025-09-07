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

from utils import *

import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def simple_write(dut):
    """
    Test Single Write request
    """
    addr = 0x1234
    data = 0x5678
    await init(dut, sdram_debug=True)
    await single_write(dut, addr, data, 0x3)
    await Timer(1, units='us')

@cocotb.test()
async def simple_read(dut):
    """
    Test read request
    """
    addr = 0xcafe
    data = 0xbeef
    await init(dut, sdram_debug=True)
    read_resp = cocotb.start_soon(single_read_resp(dut))
    await single_write(dut, addr, data, 0x3)
    await single_read(dut, addr, 0x3)
    rdata = await read_resp
    assert data == rdata
    await Timer(100, units='ns')