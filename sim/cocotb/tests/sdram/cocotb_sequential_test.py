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

from utils import *
from Reporter import  Reporter

import random
import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def sequential_read_write(dut, start_addr=0, end_addr=0x1000):
    """
    Test sequential read and write. Will issue write first and then read from the location
    """

    # generate random  data
    num = int((end_addr - start_addr) / 2) # 16 bit data
    data = []
    for i in range(num):
        data.append(random.randint(0, 0xFFFF))
    dut._log.info(f"Running Sequential test. Start addr {hex(start_addr)}. End addr {hex(end_addr)}. Number of location: {num}")

    reporter = Reporter(dut._log, "Progress", 2*num)

    await init(dut)

    # sequential write
    for i in range(num):
        addr = start_addr + i * 2
        await single_write(dut, addr, data[i], 0x3)
        reporter.report_progress()

    # sequential read
    for i in range(num):
        addr = start_addr + i * 2
        read_resp = cocotb.start_soon(single_read_resp(dut))
        await single_read(dut, addr, 0x3)
        rdata = await read_resp
        assert rdata == data[i], dut._log.error(f'Addr: {hex(addr)}. Expected {hex(data[i])}. Actual {hex(rdata)}.')
        reporter.report_progress()
    await Timer(1, units='us')
    dut._log.info(f"Completed all the Operations!")
    await read_resp
