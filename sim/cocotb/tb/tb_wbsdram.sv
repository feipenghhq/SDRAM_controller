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

module tb_wbsdram;
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

    // Wishbone bus
    logic [DW-1:0]   wb_dat_i;
    logic [DW-1:0]   wb_dat_o;
    logic            wb_cyc_i;
    logic            wb_stb_i;
    logic            wb_we_i;
    logic [AW-1:0]   wb_adr_i;
    logic [DW/8-1:0] wb_sel_i;
    logic            wb_ack_o;
    logic            wb_stall_o;

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

    wbsdram #(.CLK_FREQ(`CLK_FREQ))
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
