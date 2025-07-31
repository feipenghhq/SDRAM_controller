# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# Sequential read write
# -------------------------------------------------------------------

import os
import random
import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.regression import TestFactory
from cocotb.clock import Clock
from env import *
from bus import *

async def test_sequential_read_write(dut, start_addr=0, end_addr=0x1000):
    """
    Test sequential read and write. Will issue write first and then read from the location
    """

    # calculate cl from clock frequency
    cl = 3 if (clk_freq >= 100) else 2
    # assuming 16 bit data
    num = int((end_addr - start_addr) / 2)
    # generate random  data
    data = []
    for i in range(num):
        data.append(random.randint(0, 0xFFFF))
    dut._log.info(f"Running Sequential test. Start addr {hex(start_addr)}. End addr {hex(end_addr)}. Number of location: {num}")
    reporter = Reporter(dut._log, "Progress", 2*num)
    # cocotb test sequence
    load_mode_reg(dut, cas=cl)
    await init(dut, clk_period, False)
    read_monitor = cocotb.start_soon(bus_read_response(dut, data))
    await Timer(101, units='us')
    for i in range(num):
        addr = start_addr + i * 2
        await bus_write(dut, addr, data[i], 0x3)
        reporter.report_progress(1)
    for i in range(num):
        addr = start_addr + i * 2
        await bus_read(dut, addr, 0x3)
        reporter.report_progress(1)
    await Timer(1, units='us')
    dut._log.info(f"Completed all the Operations!")
    await read_monitor

factory = TestFactory(test_sequential_read_write)
factory.add_option("start_addr", [0])
factory.add_option("end_addr", [100])
factory.generate_tests()
