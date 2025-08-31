# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/18/2025
#
# -------------------------------------------------------------------
# BFM for the Generic system bus used in sdram_controller
# -------------------------------------------------------------------

from cocotb.triggers import FallingEdge, RisingEdge, ReadWrite

def init_bus(dut):
    """
    Initialize the bus
    """
    dut.req_valid.value      = 0
    dut.req_write.value      = 0
    dut.req_addr.value       = 0
    dut.req_wdata.value      = 0
    dut.req_byteenable.value = 0

async def single_write(
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
    # Address phase
    await ReadWrite()
    dut.req_valid.value      = 1
    dut.req_write.value      = 1
    dut.req_addr.value       = addr
    dut.req_wdata.value      = data
    dut.req_byteenable.value = byte_en
    # Wait for the ready
    while not dut.req_ready.value:
        await RisingEdge(dut.clk)
        await ReadWrite()

    # Drive idle values after write request accepted
    await RisingEdge(dut.clk)
    await ReadWrite()
    dut.req_valid.value      = 0
    dut.req_write.value      = 0
    dut.req_addr.value       = 0
    dut.req_wdata.value      = 0
    dut.req_byteenable.value = 0

async def single_read(
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
    # Address phase
    dut.req_valid.value      = 1
    dut.req_write.value      = 0
    dut.req_addr.value       = addr
    dut.req_byteenable.value = byte_en

    # Wait for the ready
    while not dut.req_ready.value:
        await RisingEdge(dut.clk)
        await ReadWrite()

    # Drive idle values after read request is accepted
    await RisingEdge(dut.clk)
    await ReadWrite()
    dut.req_valid.value      = 0
    dut.req_addr.value       = 0
    dut.req_byteenable.value = 0

async def single_read_resp(dut):
    """
    Receive one read data

    Parameters:
    - dut: The DUT handle
    """
    await RisingEdge(dut.clk)
    await ReadWrite()
    # Wait for the rvalid
    while not dut.rsp_valid.value:
        await RisingEdge(dut.clk)
        await ReadWrite()
    try:
        data = dut.rsp_rdata.value.integer
    except ValueError as e:
        data = 0
        dut.rsp_rdata._log.error(str(e))
        await RisingEdge(dut.clk)
        raise e
    return data

