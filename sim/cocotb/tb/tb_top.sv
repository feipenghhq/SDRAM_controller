// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/18/2025
//
// -------------------------------------------------------------------
// Test bench top level
// -------------------------------------------------------------------


`timescale 1ns/1ps

`ifndef CLK_FREQ
`define CLK_FREQ 133
`endif

module tb_top;
    parameter DW = 16;
    parameter AW = 24;

    // Clock & reset
    logic          clk;
    logic          rst_n;

    // SDRAM config
    logic [2:0]     cfg_burst_length;
    logic           cfg_burst_type;
    logic [2:0]     cfg_cas_latency;
    logic           cfg_burst_mode;

    // System bus_req
    logic           bus_req_read;
    logic           bus_req_write;
    logic [AW-1:0]  bus_req_addr;
    logic           bus_req_burst;
    logic [2:0]     bus_req_burst_len;
    logic [DW-1:0]  bus_req_wdata;
    logic [1:0]     bus_req_byteenable;
    logic           bus_req_ready;
    logic           bus_rsp_valid;
    logic [DW-1:0]  bus_rsp_rdata;

    // SDRAM interface wires
    logic           sdram_clk;
    logic           sdram_cke;
    logic           sdram_cs_n;
    logic           sdram_ras_n;
    logic           sdram_cas_n;
    logic           sdram_we_n;
    logic [11:0]    sdram_addr;
    logic [1:0]     sdram_ba;
    logic [1:0]     sdram_dqm;
    wire  [15:0]    sdram_dq;

    localparam CLK_PERIOD = 1000 / `CLK_FREQ;
    localparam CLK_DELAY  = CLK_PERIOD - 1;

    always_comb sdram_clk <= #CLK_DELAY clk;

    sdram_MT48LC8M16A2 #(.CLK_FREQ(`CLK_FREQ))
    dut (
        .*
    );

    // SDRAM Model (Micron MT48LC8M16A2 compatible)
    MT48LC8M16A2 sdram_model (
        .Dq     (sdram_dq),
        .Addr   (sdram_addr),
        .Ba     (sdram_ba),
        .Clk    (sdram_clk),
        .Cke    (sdram_cke),
        .Cs_n   (sdram_cs_n),
        .Ras_n  (sdram_ras_n),
        .Cas_n  (sdram_cas_n),
        .We_n   (sdram_we_n),
        .Dqm    (sdram_dqm)
    );

endmodule
