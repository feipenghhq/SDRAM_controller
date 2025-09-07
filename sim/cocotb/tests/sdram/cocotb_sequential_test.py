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
from cocotb.regression import TestFactory

#@cocotb.test()
async def sequential_read_write(dut, start_addr=0, end_addr=0x1000):
    """
    Test sequential read and write. Will issue write first and then read from the location
    Read will be pipelined meaning a new read request will be continuously before the read data is returned
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
    read_resp_fork = cocotb.start_soon(read_resp(dut, num))
    for i in range(num):
        addr = start_addr + i * 2
        await single_read(dut, addr, 0x3)
        reporter.report_progress()

    rdata_list = await read_resp_fork
    for i in range(num):
        assert rdata_list[i] == data[i], dut._log.error(f'Addr: {hex(addr)}. Expected {hex(data[i])}. Actual {hex(rdata_list[i])}.')

    dut._log.info(f"Completed all the Operations!")

sequential_factory = TestFactory(sequential_read_write)
sequential_factory.add_option("start_addr", [0])
sequential_factory.add_option("end_addr",   [0x1000])
sequential_factory.generate_tests()