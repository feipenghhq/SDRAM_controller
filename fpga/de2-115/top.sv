// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/20/2025
//
// -------------------------------------------------------------------
// Test SDRAM
// -------------------------------------------------------------------

module top
(
    input                   CLOCK_50,    // 50 MHz
    input                   KEY,         // Used as RESET, low active

    // SDRAM interface
    output logic            SDRAM_CLK,
    output logic            SDRAM_CKE,
    output logic            SDRAM_CS_N,
    output logic            SDRAM_RAS_N,
    output logic            SDRAM_CAS_N,
    output logic            SDRAM_WE_N,
    output logic [12:0]     SDRAM_ADDR,
    output logic [1:0]      SDRAM_BA,
    output logic [1:0]      SDRAM_DQM,
    inout  wire [15:0]      SDRAM_DQ
);

// System Bus
logic            bus_read;
logic            bus_write;
logic [22:0]     bus_addr;
logic            bus_burst;
logic [2:0]      bus_burst_len;
logic [15:0]     bus_wdata;
logic [1:0]      bus_byteenable;
logic            bus_ready;
logic            bus_rvalid;
logic [15:0]     bus_rdata;
// SDRAM Config
logic [2:0]      cfg_burst_length;
logic            cfg_burst_type;
logic [2:0]      cfg_cas_latency;
logic            cfg_burst_mode;

logic            clk;
logic            rst_n;

localparam CLK_FREQ = 130;

generate
if (CLK_FREQ == 25) begin
    pll_25 u_pll(
        .inclk0 (CLOCK_50),
        .c0     (clk),
        .c1     (SDRAM_CLK));
    assign cfg_cas_latency  = 3'd2;
end

if (CLK_FREQ == 50) begin
    pll_50 u_pll(
        .inclk0 (CLOCK_50),
        .c0     (clk),
        .c1     (SDRAM_CLK));
    assign cfg_cas_latency  = 3'd2;
end

if (CLK_FREQ == 100) begin
    pll_100 u_pll(
        .inclk0 (CLOCK_50),
        .c0     (clk),
        .c1     (SDRAM_CLK));
    assign cfg_cas_latency  = 3'd3;
end

if (CLK_FREQ == 130) begin
    pll_130 u_pll(
        .inclk0 (CLOCK_50),
        .c0     (clk),
        .c1     (SDRAM_CLK));
    assign cfg_cas_latency  = 3'd3;
end

endgenerate

assign cfg_burst_length = 3'd0;
assign cfg_burst_type   = 1'd0;
assign cfg_burst_mode   = 1'd0;

assign bus_burst = 'b0;
assign bus_burst_len = 'b0;
assign bus_byteenable = 2'b11;



assign rst_n = KEY;

// Instantiate SDRAM Controller
sdram_IS42S16320D #(.CLK_FREQ(CLK_FREQ))
u_sdram (
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
    .sdram_cke          (SDRAM_CKE),
    .sdram_cs_n         (SDRAM_CS_N),
    .sdram_ras_n        (SDRAM_RAS_N),
    .sdram_cas_n        (SDRAM_CAS_N),
    .sdram_we_n         (SDRAM_WE_N),
    .sdram_addr         (SDRAM_ADDR),
    .sdram_ba           (SDRAM_BA),
    .sdram_dqm          (SDRAM_DQM),
    .sdram_dq           (SDRAM_DQ)
);


vjtag_host #(.AW(23), .DW(16))
u_host (
    .clk       (clk),
    .rst_n     (rst_n),
    .rst_n_out (),
    .address   (bus_addr),
    .wvalid    (bus_write),
    .wdata     (bus_wdata),
    .wready    (bus_ready),
    .rvalid    (bus_read),
    .rready    (bus_ready),
    .rrvalid   (bus_rvalid),
    .rdata     (bus_rdata)
);

endmodule
