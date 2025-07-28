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

import random
import cocotb
from cocotb.triggers import FallingEdge, RisingEdge, Timer
from cocotb.regression import TestFactory
from cocotb.clock import Clock
from env import *
from bus import *

async def test_random_read_write(dut, num_op=10, num_seq=10):
    """
    Test Random read and write. Will issue write first and then read from the location

    Parameters:
    - num_op:  Number of operations to perform
    - num_seq: Number of random addr/data pairs
    """
    addr_data = []      # random address and data pair
    valid_idx = []      # List of index to addr_data. Indicate the location that has valid data
    test_sequence = []  # List of (op, addr_data_index), op: 0 - write, 1 - read
    read_cnt = 0

    # calculate cl from clock frequency
    cl = 3 if (clk_freq >= 100) else 2

    # generate random address and data
    for i in range(num_seq):
        addr_data.append((random.randint(0, 0xFFFFFF), random.randint(0, 0xFFFF)))

    # the first sequence must be a write
    idx = random.randint(0, num_seq-1)
    valid_idx.append(idx)
    test_sequence.append((0, idx))

    # generate the rest of sequence
    for i in range(num_op):
        op = random.choice([0,1])
        if op:  # for a read operation, we can only select from valid_idx
            idx = random.choice(valid_idx)
        else:   # for write, randomly select the index from num_seq and add it to valid_idx
            idx = random.randint(0, num_seq-1)
            if not idx in valid_idx:
                valid_idx.append(idx)
        test_sequence.append((op, idx))

    # create expected data for read response monitor
    expected = []
    for op, idx in test_sequence:
        if op:  # read
            _, data = addr_data[idx]
            expected.append(data)
            read_cnt += 1

    dut._log.info(f"Running Random test. Number of operation {hex(num_op)}. Number of location {hex(num_seq)}")
    reporter = Reporter(dut._log, "Progress", num_op)

    # cocotb test sequence
    rc = 0
    wc = 0
    load_mode_reg(dut, cas=cl)
    await init(dut, clk_period, False)
    read_monitor = cocotb.start_soon(bus_read_response(dut, expected))
    await Timer(101, units='us')
    for op, idx in test_sequence:
        if op:  # read
            addr, _ = addr_data[idx]
            await bus_read(dut, addr, 0x3)
            rc += 1
        else:   # write
            addr, data = addr_data[idx]
            await bus_write(dut, addr, data, 0x3)
            wc += 1
        reporter.report_progress(1)
    await Timer(1, units='us')
    dut._log.info(f"Completed all the Operations!")
    await read_monitor

factory = TestFactory(test_random_read_write)
factory.add_option("num_op", [1000])
factory.add_option("num_seq", [100])
factory.generate_tests()
