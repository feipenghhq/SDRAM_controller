// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 09/07/2025
//
// -------------------------------------------------------------------
// Test bench top level
// -------------------------------------------------------------------


`timescale 1ns/1ps

module tb_sdram_test;
    parameter DW = 16;
    parameter AW = 24;
    parameter ADDR_LO = 0;         // starting address
    parameter ADDR_HI = 1 << 24;   // ending address
    parameter CLK_FREQ = 50;

    // Clock & reset
    logic          clk;
    logic          rst_n;

    // SDRAM config
    logic [2:0]     cfg_burst_length;
    logic           cfg_burst_type;
    logic [2:0]     cfg_cas_latency;
    logic           cfg_burst_mode;

    logic           complete;
    logic           error;

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

    localparam CLK_PERIOD = 1000 / CLK_FREQ;
    localparam CLK_DELAY  = CLK_PERIOD - 1;

    always_comb sdram_clk <= #CLK_DELAY clk;

    sdram_test #(
        .CLK_FREQ(CLK_FREQ),
        .AW(AW),
        .DW(DW),
        .ADDR_LO(ADDR_LO),
        .ADDR_HI(ADDR_HI)
    )
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
