# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/10/2025
#
# -------------------------------------------------------------------
# Basic wbsdram
# -------------------------------------------------------------------

import cocotb
from cocotb.triggers import Timer
from cocotb.regression import TestFactory

import sys
sys.path.append('../../tb')

from env import *
from WbHostBFM import *

#@cocotb.test()
async def test_write(dut):
    """
    Test Single Write request
    """
    addr = 0x1234
    data = 0x5678
    load_config(dut)
    bus = await init(dut, clk_period, True, 'wishbone')
    await Timer(90, units='us')
    await RisingEdge(dut.clk)
    await bus.single_write(addr, data, 0x3)
    await Timer(1, units='us')

@cocotb.test()
async def test_read(dut, cl=2):
    """
    Test read request
    """
    addr = 0xcafe
    data = 0xbeef
    load_config(dut, cas=cl)
    bus = await init(dut, clk_period, True, 'wishbone')
    await Timer(90, units='us')
    await RisingEdge(dut.clk)
    await bus.single_write(addr, data, 0x3, True)
    rdata = await bus.single_read(addr, 0x3, True)
    assert rdata == data
    await Timer(100, units='ns')

factory = TestFactory(test_read)
factory.add_option("cl", [2, 3])
#factory.generate_tests()
