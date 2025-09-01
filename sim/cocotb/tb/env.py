# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# Test environment
# -------------------------------------------------------------------

import os
import logging
import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock


def config_log():
    # Create a file handler
    file_handler = logging.FileHandler("cocotb.log")
    file_handler.setLevel(logging.INFO)

    # Format the logs
    formatter = logging.Formatter('%(asctime)s [%(levelname)s] %(message)s')
    file_handler.setFormatter(formatter)

    # Add handler to cocotb logger
    cocotb.log.addHandler(file_handler)
    cocotb.log.setLevel(logging.INFO)  # log all levels

config_log()

def get_clk_period():
    clk_freq = int(os.getenv('CLK_FREQ', 50))
    clk_period = round(1000.0 / clk_freq, 1)
    return clk_period

def load_config(dut, burst_len=0, burst_type=0, cas=2, write_burst_mode=0):
    """
    Load the config signal
    """
    clock_period = get_clk_period()
    if clock_period > 10:
        cas = 2
    else:
        cas = 3
    dut.cfg_burst_length.value  = burst_len
    dut.cfg_burst_type.value    = burst_type
    dut.cfg_cas_latency.value   = cas
    dut.cfg_burst_mode.value    = write_burst_mode

async def init_env(dut, period=None, sdram_debug=False):
    """
    Initialize the environment: setup clock, reset the design
    """
    # get the clock period
    if not period:
        period = get_clk_period()
    # start clock
    cocotb.start_soon(Clock(dut.clk, period, units = 'ns').start()) # clock
    dut._log.info(f"Clock period is {period}")
    # generate reset
    dut.rst_n.value = 0
    await Timer(period * 5, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    if not sdram_debug:
        dut.sdram_model.Debug.value = 0

async def init_sdram(dut, wait_time = 100):
    await Timer(wait_time, units='us')
    # wait additional 10 clock cycle just in case
    for _ in range(10):
        await RisingEdge(dut.clk)

