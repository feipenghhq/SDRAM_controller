# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# Bus BFM
# -------------------------------------------------------------------

from cocotb.triggers import FallingEdge, RisingEdge

def bus_init(dut):
    """
    Initialize the bus
    """
    dut.bus_read.value      = 0
    dut.bus_write.value     = 0
    dut.bus_addr.value      = 0
    dut.bus_burst.value     = 0
    dut.bus_burst_len.value = 0
    dut.bus_wdata.value     = 0
    dut.bus_byteenable.value = 0

async def bus_write(
    dut,
    addr: int,
    data: int,
    byte_en: int = 2,
):
    """
    Issue a single-beat write transaction.

    Parameters:
    - dut: The DUT handle
    - addr: Write address (int)
    - data: Write data (int)
    - byte_en: Byte enable
    """
    await FallingEdge(dut.clk)
    # Address phase
    dut.bus_write.value      = 1
    dut.bus_addr.value       = addr
    dut.bus_wdata.value      = data
    dut.bus_byteenable.value = byte_en

    await RisingEdge(dut.clk)
    # Wait for slave to be ready (optional depending on DUT)
    while not dut.bus_ready.value:
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    # Drive idle values after write address phase
    dut.bus_write.value      = 0
    dut.bus_addr.value       = 0
    dut.bus_wdata.value      = 0
    dut.bus_byteenable.value = 0

async def bus_read(
    dut,
    addr: int,
    byte_en: int = 2,
):
    """
    Issue a single-beat read request. (Request only. Does not receive the read data)

    Parameters:
    - dut: The DUT handle
    - addr: Read address (int)
    - byte_en: Byte enable
    """
    await FallingEdge(dut.clk)
    # Address phase
    dut.bus_read.value       = 1
    dut.bus_addr.value       = addr
    dut.bus_byteenable.value = byte_en

    await RisingEdge(dut.clk)
    # Wait for slave to be ready (optional depending on DUT)
    while not dut.bus_ready.value:
        await RisingEdge(dut.clk)

    await FallingEdge(dut.clk)
    # Drive idle values after write address phase
    dut.bus_read.value       = 0
    dut.bus_addr.value       = 0
    dut.bus_byteenable.value = 0

async def bus_read_response(dut, expected=None, debug=False):
    """
    Monitor the bus and receive read data

    Parameters:
    - dut: The DUT handle
    - expected: List of expected data
    """
    i = 0
    if expected:
        for exp_data in expected:
            await RisingEdge(dut.bus_rvalid)
            await FallingEdge(dut.clk)
            data = dut.bus_rdata.value.integer
            assert data == exp_data, dut._log.error(f"[BUS READ] Wrong read data. Expected: {exp_data}. Actual: {data}")
            i += 1
            if debug:
                dut._log.info(f"[BUS READ] Read data count: {i}")
        dut._log.info(f"[BUS READ] Read all expected data!!!")
        return
    else:
        await RisingEdge(dut.bus_rvalid)
        await FallingEdge(dut.clk)
        return dut.bus_rdata.value
