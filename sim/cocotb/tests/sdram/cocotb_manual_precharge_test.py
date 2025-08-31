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

from utils import *

import cocotb
from cocotb.triggers import Timer

def addr_gen(bank, row, col, raw=12, caw=10):
    """
    Generate address given bank, row, and col
    Assuming:
        - row address width: 12
        - col address width: 10
    """
    return ((bank << (raw + caw)) | (row << caw) | col)

@cocotb.test()
async def write(dut, num=4):
    """
    test write request targeting different bank to trigger precharge
    """
    stimulus = []
    for i in range(1, num+1):
        addr = addr_gen(i-1, 0x100 * i, 0x10 * i)
        data = 0x1111 * i
        stimulus.append((addr, data))

    await init(dut)
    for addr, data in stimulus:
        await single_write(dut, addr, data, 0x3)
    await Timer(1, units='us')

@cocotb.test()
async def read(dut, num=4, debug=True):
    """
    test read request targeting different bank to trigger precharge
    """
    stimulus = []
    for i in range(1, num+1):
        addr = addr_gen(i-1, 0x100 * i, 0x10 * i)
        data = 0x1111 * i
        stimulus.append((addr, data))

    await init(dut)
    for addr, data in stimulus:
        await single_write(dut, addr, data, 0x3)
    for addr, data in stimulus:
        read_resp = cocotb.start_soon(single_read_resp(dut))
        await single_read(dut, addr, 0x3)
        rdata = await read_resp
        assert rdata == data
    await Timer(1, units='us')
