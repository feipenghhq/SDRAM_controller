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

    // Clock & reset
    logic clk;
    logic rst_n;

    // AHB-Lite signals
    logic [23:0] haddr;
    logic [2:0]  hburst;
    logic        hmasterlock;
    logic [3:0]  hprot;
    logic [2:0]  hsize;
    logic [1:0]  htrans;
    logic [15:0] hwdata;
    logic        hwrite;

    // SDRAM config
    logic [2:0]  cfg_burst_length;
    logic        cfg_burst_type;
    logic [2:0]  cfg_cas_latency;
    logic        cfg_burst_mode;

    // SDRAM interface wires
    wire         sdram_cke;
    wire         sdram_cs_n;
    wire         sdram_ras_n;
    wire         sdram_cas_n;
    wire         sdram_we_n;
    wire [11:0]  sdram_addr;
    wire [1:0]   sdram_ba;
    wire [1:0]   sdram_dqm;
    wire [15:0]  sdram_dq;


    sdram_MT48LC8M16A2 dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .haddr              (haddr),
        .hburst             (hburst),
        .hmasterlock        (hmasterlock),
        .hprot              (hprot),
        .hsize              (hsize),
        .htrans             (htrans),
        .hwdata             (hwdata),
        .hwrite             (hwrite),
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
