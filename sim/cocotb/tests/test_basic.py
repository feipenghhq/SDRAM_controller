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
from cocotb.triggers import Timer
from cocotb.regression import TestFactory
from env import *
from bus import *

#@cocotb.test()
async def test_write(dut):
    """
    Test Single Write request
    """
    load_mode_reg(dut)
    await init(dut, clk_period)
    await Timer(101, units='us')
    await bus_write(dut, 0x1111, 0x1234, 0x3)
    await Timer(1, units='us')

async def test_read(dut, cl=2):
    """
    Test read request
    """
    addr = 0xcafe
    data = 0xbeef
    load_mode_reg(dut, cas=cl)
    await init(dut, clk_period, True)
    read_monitor = cocotb.start_soon(bus_read_response(dut, [data]))
    await Timer(101, units='us')
    await bus_write(dut, addr, data, 0x3)
    await bus_read(dut, addr, 0x3)
    await Timer(1, units='us')
    await read_monitor
    await Timer(100, units='ns')


factory = TestFactory(test_read)
factory.add_option("cl", [2, 3])
factory.generate_tests()
