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
logic            bus_req_read;
logic            bus_req_write;
logic [22:0]     bus_req_addr;
logic            bus_req_burst;
logic [2:0]      bus_req_burst_len;
logic [15:0]     bus_req_wdata;
logic [1:0]      bus_req_byteenable;
logic            bus_req_ready;
logic            bus_rsp_valid;
logic [15:0]     bus_rsp_rdata;
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

assign bus_req_burst = 'b0;
assign bus_req_burst_len = 'b0;
assign bus_req_byteenable = 2'b11;

assign rst_n = KEY;

// Instantiate SDRAM Controller
sdram_IS42S16320D #(.CLK_FREQ(CLK_FREQ))
u_sdram (
    .sdram_cke          (SDRAM_CKE),
    .sdram_cs_n         (SDRAM_CS_N),
    .sdram_ras_n        (SDRAM_RAS_N),
    .sdram_cas_n        (SDRAM_CAS_N),
    .sdram_we_n         (SDRAM_WE_N),
    .sdram_addr         (SDRAM_ADDR),
    .sdram_ba           (SDRAM_BA),
    .sdram_dqm          (SDRAM_DQM),
    .sdram_dq           (SDRAM_DQ),
    .bus_req_addr       (bus_req_addr),
    .*
);


vjtag_host #(.AW(23), .DW(16))
u_host (
    .clk       (clk),
    .rst_n     (rst_n),
    .rst_n_out (),
    .address   (bus_req_addr),
    .wvalid    (bus_req_write),
    .wdata     (bus_req_wdata),
    .wready    (bus_req_ready),
    .rvalid    (bus_req_read),
    .rready    (bus_req_ready),
    .rrvalid   (bus_rsp_valid),
    .rdata     (bus_rsp_rdata)
);

endmodule
