// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/26/2025
//
// -------------------------------------------------------------------
// Generate SDRAM command to the SDRAM chip meeting required timing
// -------------------------------------------------------------------

`include "sdram_inc.svh"

module sdram_cmd #(
    parameter CLK_FREQ  = 100,      // (MHz) clock frequency
    parameter RAW       = 12,       // SDRAM Address width
    parameter DW        = 16,       // SDRAM data width
    parameter tRAS      = 37,       // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC       = 60,       // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD      = 15,       // (ns) ACTIVE-to-READ or WRITE delay
    parameter tRFC      = 66,       // (ns) AUTO REFRESH period
    parameter tRP       = 15,       // (ns) PRECHARGE command period
    parameter tRRD      = 14,       // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter tWR       = 15,       // (ns) WRITE recovery time (WRITE completion to PRECHARGE period)
    parameter tREF      = 64        // (ms) Refresh Period
) (
    input  logic            clk,
    input  logic            rst_n,

    // Command Input/Output
    input  logic            cmd_valid,
    input  logic [3:0]      cmd_type,
    input  logic [RAW-1:0]  cmd_addr,
    input  logic [DW-1:0]   cmd_data,
    input  logic [1:0]      cmd_ba,
    input  logic [DW/8-1:0] cmd_dqm,
    output logic            cmd_wip,
    output logic            cmd_done,
    output logic            cmd_early_done,

    input  logic [2:0]      cfg_cas_latency,

    // SDRAM interface
    output logic            sdram_cke,          // Clock Enable.
    output logic            sdram_cs_n,         // Chip Select.
    output logic            sdram_ras_n,        // Row Address Select.
    output logic            sdram_cas_n,        // Column Address Select.
    output logic            sdram_we_n,         // Write Enable.
    output logic [RAW-1:0]  sdram_addr,         // Address.
    output logic [1:0]      sdram_ba,           // Bank.
    output logic [DW/8-1:0] sdram_dqm,          // Data Mask
    inout  wire  [DW-1:0]   sdram_dq            // Data Input/Output bus.
);

/////////////////////////////////////////////////
// Local Parameter
/////////////////////////////////////////////////
// Calculate the SDRAM timing in clock cycle
localparam cRAS = `SDRAM_CEIL_DIV(tRAS * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE-to-PRECHARGE command
localparam cRC  = `SDRAM_CEIL_DIV(tRC  * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE-to-ACTIVE command period
localparam cRCD = `SDRAM_CEIL_DIV(tRCD * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE-to-READ or WRITE delay
localparam cRFC = `SDRAM_CEIL_DIV(tRFC * CLK_FREQ, 1000);   // (CLK Cycle) AUTO REFRESH period
localparam cRP  = `SDRAM_CEIL_DIV(tRP  * CLK_FREQ, 1000);   // (CLK Cycle) PRECHARGE command period
localparam cRRD = `SDRAM_CEIL_DIV(tRRD * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE bank a to ACTIVE bank b command
localparam cWR  = `SDRAM_CEIL_DIV(tWR  * CLK_FREQ, 1000);   // (CLK Cycle) WRITE recovery time (WRITE completion to PRECHARGE period)
localparam cMRD = 3;                                        // (cycle) LOAD MODE REGISTER cycle. JEDEC specify 3 clocks.

// Command counter width
localparam CMD_CNT_WIDTH = 4;

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

typedef enum logic [3:0] {
    IDLE,          // IDLE state, no command to send.
    CMD,           // Send the command to the SDRAM chip.
    WAIT           // Wait for the command timing.
} cmd_state_t;

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

cmd_state_t cmd_state, cmd_state_next;
logic                     new_cmd;
logic [CMD_CNT_WIDTH-1:0] cmd_cnt;

logic                     sdram_dq_out_en; // enable dq output
logic [DW-1:0]            sdram_dq_out;

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

always_ff @(posedge clk) begin
    if (!rst_n) begin
        cmd_cnt <= 'b0;
    end
    else begin
        // load the counter when a new command is issue. otherwise decrease the counter till it reach 0.
        if (cmd_valid) begin
            case(cmd_type)
                `CMD_PRECHARGE: cmd_cnt <= cRP [CMD_CNT_WIDTH-1:0] - 1'b1;
                `CMD_REFRESH:   cmd_cnt <= cRFC[CMD_CNT_WIDTH-1:0] - 1'b1;
                `CMD_LMR:       cmd_cnt <= cMRD[CMD_CNT_WIDTH-1:0] - 1'b1;
                `CMD_ACTIVE:    cmd_cnt <= cRCD[CMD_CNT_WIDTH-1:0] - 1'b1;
                `CMD_WRITE:     cmd_cnt <= cWR [CMD_CNT_WIDTH-1:0] - 1'b1;
                `CMD_READ:      cmd_cnt <= cfg_cas_latency + 1'b1;
            endcase
        end
        else if (cmd_cnt > 0) cmd_cnt <= cmd_cnt - 1'b1;
    end
end

assign cmd_done = cmd_cnt == 0;
assign cmd_early_done = cmd_cnt == 1;
assign cmd_wip  = !cmd_done;

// Register the SDRAM output
always_ff @(posedge clk) begin
    if (!rst_n) begin
        sdram_cke       <= 'b0;
        sdram_cs_n      <= 'b1;
        sdram_ras_n     <= 'b1;
        sdram_cas_n     <= 'b1;
        sdram_we_n      <= 'b1;
        sdram_addr      <= 'b0;
        sdram_ba        <= 'b0;
        sdram_dqm       <= 'b0;
        sdram_dq_out    <= 'b0;
        sdram_dq_out_en <= 'b0;
    end
    else begin
        if (cmd_valid) begin
            sdram_cke       <= 1'b1;
            sdram_cs_n      <= cmd_type[3];
            sdram_ras_n     <= cmd_type[2];
            sdram_cas_n     <= cmd_type[1];
            sdram_we_n      <= cmd_type[0];
            sdram_addr      <= cmd_addr;
            sdram_ba        <= cmd_ba;
            sdram_dqm       <= cmd_dqm;
            sdram_dq_out    <= cmd_data;
            sdram_dq_out_en <= (cmd_type == `CMD_WRITE);
        end
        else begin
            sdram_cke       <= 1'b1;
            sdram_cs_n      <= 1'b1;
            sdram_ras_n     <= 1'b1;
            sdram_cas_n     <= 1'b1;
            sdram_we_n      <= 1'b1;
            sdram_addr      <= 'b0;
            sdram_ba        <= 'b0;
            sdram_dqm       <= 'b0;
            sdram_dq_out    <= 'b0;
            sdram_dq_out_en <= 'b0;

        end
    end
end

assign sdram_dq = sdram_dq_out_en ? sdram_dq_out : {DW{1'bz}};

/////////////////////////////////////////////////
// SIMULATION
/////////////////////////////////////////////////

`ifdef SIMULATION

// Display SDRAM parameter
initial begin
    #10;
    $display("%m: ---------------------------------------");
    $display("%m: SDRAM Timing (in ns):");
    $display("%m: CLK_FREQ = %4d.   # Clock Frequency",         CLK_FREQ);
    $display("%m:       CL = %4d.   # CAS Latency",             cfg_cas_latency);
    $display("%m:     tRAS = %4d.   # ACTIVE to PRECHARGE",     tRAS);
    $display("%m:     tRC  = %4d.   # ACTIVE to ACTIVE",        tRC);
    $display("%m:     tRCD = %4d.   # ACTIVE to READ/WRITE",    tRCD);
    $display("%m:     tRFC = %4d.   # REFRESH to ACTIVE",       tRFC);
    $display("%m:     tRP  = %4d.   # RECHARGE command period", tRP);
    $display("%m:     tWR  = %4d.   # WRITE recover time",      tWR);
    $display("%m:     tRRD = %4d.   # ACTIVE bank a to ACTIVE bank b", tRRD);
    $display("%m: SDRAM Timing (in clock cycle):");
    $display("%m:     cRAS = %4d.   # ACTIVE to PRECHARGE",     cRAS);
    $display("%m:     cRC  = %4d.   # ACTIVE to ACTIVE",        cRC);
    $display("%m:     cRCD = %4d.   # ACTIVE to READ/WRITE",    cRCD);
    $display("%m:     cRFC = %4d.   # REFRESH to ACTIVE",       cRFC);
    $display("%m:     cRP  = %4d.   # RECHARGE command period", cRP);
    $display("%m:     cWR  = %4d.   # WRITE recover time",      cWR);
    $display("%m:     cRRD = %4d.   # ACTIVE bank a to ACTIVE bank b", cRRD);
    $display("%m: ---------------------------------------");
end

`endif

endmodule
