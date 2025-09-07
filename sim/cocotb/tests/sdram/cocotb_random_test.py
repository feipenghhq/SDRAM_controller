# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# Random Read/Write test
# -------------------------------------------------------------------

from utils import *
from Reporter import Reporter

import random
import cocotb
from cocotb.triggers import Timer
from cocotb.regression import TestFactory

#@cocotb.test()
async def random_read_write(dut, num_op=1000, num_seq=100):
    """
    Test Random read and write. Will issue write first and then read from the location

    Parameters:
    - num_op:  Number of operations to perform
    - num_seq: Number of random addr/data pairs
    """
    stimulus  = []  # List of (addr, data) pair
    valid_idx = []  # List of index to stimulus. Indicate the location that has valid data
    op_seq    = []  # List of (op, stimulus_index), op: 0 - write, 1 - read
    read_cnt  = 0

    # generate random stimulus
    for i in range(num_seq):
        stimulus.append((random.randint(0, 0xFFFFFF), random.randint(0, 0xFFFF)))

    # generate sequence of operation
    # the first sequence must be a write
    idx = random.randint(0, num_seq-1)
    valid_idx.append(idx)
    op_seq.append((0, idx))
    # generate the rest of sequence
    for i in range(num_op-1):
        op = random.choice([0,1])
        if op:  # for a read operation, we can only select from valid_idx
            idx = random.choice(valid_idx)
        else:   # for write, randomly select the index from num_seq and add it to valid_idx
            idx = random.randint(0, num_seq-1)
            if not idx in valid_idx:
                valid_idx.append(idx)
        op_seq.append((op, idx))

    dut._log.info(f"Running Random test. Number of operation {hex(num_op)}. Number of location {hex(num_seq)}")
    reporter = Reporter(dut._log, "Progress", num_op)

    await init(dut)
    for op, idx in op_seq:
        if op == 1:  # read
            addr, data = stimulus[idx]
            read_resp = cocotb.start_soon(single_read_resp(dut))
            await single_read(dut, addr, 0x3)
            rdata = await read_resp
            assert rdata == data
        else:   # write
            addr, data = stimulus[idx]
            await single_write(dut, addr, data, 0x3)
        reporter.report_progress()
    await Timer(1, units='us')
    dut._log.info(f"Completed all the Operations!")
    await read_resp

random_factory = TestFactory(random_read_write)
random_factory.add_option("num_op", [1000])
random_factory.add_option("num_seq", [100])
random_factory.generate_tests()