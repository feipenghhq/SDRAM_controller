# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/17/2025
#
# -------------------------------------------------------------------
# Pipelined SDRAM access test
# -------------------------------------------------------------------

from utils import *

import random
import cocotb
from cocotb.triggers import Timer

async def write2write(dut, addr0, addr1):
    """
    Test write followed by another write
    """
    await init(dut, sdram_debug=True)
    data0 = random.randint(0, 1 << 15)
    await single_write(dut, addr0, data0, 0x3)
    data1 = random.randint(0, 1 << 15)
    await single_write(dut, addr1, data1, 0x3)
    await Timer(1, units='us')

async def write2read(dut, addr0, addr1):
    """
    Test write followed by a read
    """
    await init(dut, sdram_debug=True)
    data0 = random.randint(0, 1 << 15)
    data1 = random.randint(0, 1 << 15)
    await single_write(dut, addr1, data1, 0x3)
    await single_write(dut, addr0, data0, 0x3)
    await single_read(dut, addr1, 0x3)
    rdata = await single_read_resp(dut)
    assert data1 == rdata
    await Timer(1, units='us')

@cocotb.test()
async def w2w_sr(dut):
    """Write 2 write with same row"""
    await write2write(dut, 0x100, 0x200)

@cocotb.test()
async def w2w_dr(dut):
    """Write 2 write with diff row"""
    await write2write(dut, 0x100, 0x1000)

@cocotb.test()
async def w2r_sr(dut):
    """Write 2 read with same row"""
    await write2read(dut, 0x100, 0x200)

@cocotb.test()
async def w2r_dr(dut):
    """Write 2 read with different row"""
    await write2read(dut, 0x100, 0x1000)
