# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: Wishbone IP
# Author: Heqing Huang
# Date Created: 08/04/2025
#
# -------------------------------------------------------------------
# Wishbone Bus Host BFM
# Support Wishbone B4 Pipeline Interface
# -------------------------------------------------------------------

from cocotb.triggers import RisingEdge, ReadWrite, ReadOnly

class WbHostBFM:

    def __init__(self, dut, AW=24, DW=16, default=True):

        """
            Parameters:
            - dut: cocotb  dut
            - AW (int): Address width, default is 32 bits.
            - DW (int): Data width, default is 32 bits.
            - default (bool): Connect the BFM to RTL using default wb signal name
        """
        self.dut = dut
        self.AW = AW
        self.DW = DW
        self.clk = dut.clk
        self.ram = {}
        if default:
            self.connect_default()
            self.init()

    def connect(self, wb_cyc_i, wb_stb_i, wb_we_i, wb_adr_i, wb_dat_o, wb_dat_i, wb_ack_o, wb_stall_o,
                      wb_sel_i = None):
        """
        Connect wishbone device BFM to RTL. Assuming RTL interface naming as wb_xxx_i/o
        The WbHostBFM is acting as a Wishbone Host so:
            - dut.wb_xxx_o is connected to self.wb_xxx_i
            - dut.wb_xxx_i is connected to self.wb_xxx_o
        """
        # Inputs to the BFM (from DUT outputs)
        self.wb_cyc_o    = wb_cyc_i
        self.wb_stb_o    = wb_stb_i
        self.wb_we_o     = wb_we_i
        self.wb_adr_o    = wb_adr_i
        self.wb_dat_i    = wb_dat_o
        self.wb_dat_o    = wb_dat_i
        self.wb_ack_i    = wb_ack_o
        self.wb_stall_i  = wb_stall_o
        # optional signal
        self.wb_sel_o    = wb_sel_i

    def connect_default(self):
        """
        Connect wishbone device BFM to RTL using default signal name
        """
        self.connect(self.dut.wb_cyc_i, self.dut.wb_stb_i, self.dut.wb_we_i, self.dut.wb_adr_i,
                     self.dut.wb_dat_o, self.dut.wb_dat_i, self.dut.wb_ack_o, self.dut.wb_stall_o)
        self.wb_sel_o = getattr(self.dut, 'wb_sel_i', None)

    def init(self):
        """
        Initialize the signal
        """
        self.wb_cyc_o.value = 0
        self.wb_stb_o.value = 0
        self.wb_we_o.value = 0
        self.wb_adr_o.value = 0
        self.wb_dat_o.value = 0

    async def single_write(self, addr, data, byte_enable=None, info=False):
        """
        Send a SINGLE pipelined write request
        """
        await ReadWrite()
        if info:
            self.dut._log.info(f"[WB Host BFM] Single write request. Address: {hex(addr)}. Write data: {hex(data)}")
        # assert request
        self.wb_cyc_o.value = 1
        self.wb_stb_o.value = 1
        self.wb_we_o.value = 1
        self.wb_adr_o.value = addr
        self.wb_dat_o.value = data
        if byte_enable:
            self.wb_sel_o.value = byte_enable
        # wait for stall
        await ReadOnly()
        while(self.wb_stall_i.value == 1):
            await RisingEdge(self.clk)
            await ReadWrite()
        # request is taken, de-assert request and check for ack
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_stb_o.value = 0
        self.wb_we_o.value = 0
        self.wb_adr_o.value = 0
        self.wb_dat_o.value = 0
        if byte_enable:
            self.wb_sel_o.value = 0
        assert self.wb_ack_i.value == 1, self.dut._log.error("[WB Host BFM] ack should be at high")
        # de-assert cyc
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_cyc_o.value = 0

    async def single_read(self, addr, byte_enable=None, info=False):
        """
        Send a SINGLE pipelined read request
        """
        await ReadWrite()
        if info:
            self.dut._log.info(f"[WB Host BFM] Single read request. Address: {hex(addr)}")
        # assert request
        self.wb_cyc_o.value = 1
        self.wb_stb_o.value = 1
        self.wb_we_o.value = 0
        self.wb_adr_o.value = addr
        if byte_enable:
            self.wb_sel_o.value = byte_enable
        # wait for stall
        await ReadOnly()
        while(self.wb_stall_i.value == 1):
            await RisingEdge(self.clk)
            await ReadWrite()
        # request is taken, de-assert request and grab the data
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_stb_o.value = 0
        self.wb_we_o.value = 0
        self.wb_adr_o.value = 0
        self.wb_dat_o.value = 0
        assert self.wb_ack_i.value == 1, self.dut._log.error("[WB Host BFM] ack should be at high")
        data = self.wb_dat_i.value.integer
        if info:
            self.dut._log.info(f"[WB Host BFM] Read Complete. Data: {hex(data)}")
        # de-assert cyc
        await RisingEdge(self.clk)
        await ReadWrite()
        self.wb_cyc_o.value = 0
        return data
