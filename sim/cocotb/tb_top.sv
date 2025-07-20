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

    // System Bus
    logic           bus_read;
    logic           bus_write;
    logic [AW-1:0]  bus_addr;
    logic           bus_burst;
    logic [2:0]     bus_burst_len;
    logic [DW-1:0]  bus_wdata;
    logic [1:0]     bus_byteenable;
    logic           bus_ready;
    logic           bus_rvalid;
    logic [DW-1:0]  bus_rdata;

    // SDRAM interface wires
    logic           sdram_cke;
    logic           sdram_cs_n;
    logic           sdram_ras_n;
    logic           sdram_cas_n;
    logic           sdram_we_n;
    logic [11:0]    sdram_addr;
    logic [1:0]     sdram_ba;
    logic [1:0]     sdram_dqm;
    wire  [15:0]    sdram_dq;


    sdram_MT48LC8M16A2 dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .bus_read           (bus_read),
        .bus_write          (bus_write),
        .bus_addr           (bus_addr),
        .bus_burst          (bus_burst),
        .bus_burst_len      (bus_burst_len),
        .bus_wdata          (bus_wdata),
        .bus_byteenable     (bus_byteenable),
        .bus_ready          (bus_ready),
        .bus_rvalid         (bus_rvalid),
        .bus_rdata          (bus_rdata),
        .cfg_burst_length   (cfg_burst_length),
        .cfg_burst_type     (cfg_burst_type),
        .cfg_cas_latency    (cfg_cas_latency),
        .cfg_burst_mode     (cfg_burst_mode),
        .sdram_cke          (sdram_cke),
        .sdram_cs_n         (sdram_cs_n),
        .sdram_ras_n        (sdram_ras_n),
        .sdram_cas_n        (sdram_cas_n),
        .sdram_we_n         (sdram_we_n),
        .sdram_addr         (sdram_addr),
        .sdram_ba           (sdram_ba),
        .sdram_dqm          (sdram_dqm),
        .sdram_dq           (sdram_dq)
    );

    // SDRAM Model (Micron MT48LC8M16A2 compatible)
    MT48LC8M16A2 sdram_model (
        .Dq     (sdram_dq),
        .Addr   (sdram_addr),
        .Ba     (sdram_ba),
        .Clk    (clk),
        .Cke    (sdram_cke),
        .Cs_n   (sdram_cs_n),
        .Ras_n  (sdram_ras_n),
        .Cas_n  (sdram_cas_n),
        .We_n   (sdram_we_n),
        .Dqm    (sdram_dqm)
    );

endmodule
