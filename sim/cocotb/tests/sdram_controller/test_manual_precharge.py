# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/27/2025
#
# -------------------------------------------------------------------
# Basic SDRAM controller with manual precharge
# -------------------------------------------------------------------

import cocotb
from cocotb.triggers import Timer
from cocotb.regression import TestFactory

import sys
sys.path.append('../../tb')

from env import *
from bus import *

def addr_gen(bank, row, col, raw=12, caw=10):
    """
    Generate address given bank, row, and col
    Assuming:
        - row address width: 12
        - col address width: 10
    """
    return ((bank << (raw + caw)) | (row << caw) | col)


async def test_write(dut, cl=2, num=4, debug=True):
    """
    test single write request
    """
    stimulus = []
    for i in range(1, num+1):
        addr = addr_gen(i-1, 0x100 * i, 0x10 * i)
        data = 0x1111 * i
        stimulus.append((addr, data))

    load_config(dut, cas=cl)
    await init(dut, clk_period, debug)
    await Timer(101, units='us')

    for addr, data in stimulus:
        await single_write(dut, addr, data, 0x3)
    await Timer(1, units='us')

wr_factory = TestFactory(test_write)
wr_factory.add_option("cl", [2, 3])
wr_factory.generate_tests()

async def test_read(dut, cl=2, num=4, debug=True):
    """
    test single write request
    """
    stimulus = []
    for i in range(1, num+1):
        addr = addr_gen(i-1, 0x100 * i, 0x10 * i)
        data = 0x1111 * i
        stimulus.append((addr, data))

    load_config(dut, cas=cl)
    await init(dut, clk_period, debug)
    await Timer(101, units='us')

    for addr, data in stimulus:
        await single_write(dut, addr, data, 0x3)
    for addr, data in stimulus:
        read_monitor = cocotb.start_soon(single_read_resp(dut))
        await single_read(dut, addr, 0x3)
        rdata = await read_monitor
        assert rdata == data

    await read_monitor
    await Timer(1, units='us')


rd_factory = TestFactory(test_read)
rd_factory.add_option("cl", [2, 3])
rd_factory.generate_tests()
