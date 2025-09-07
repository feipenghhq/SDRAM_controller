// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/26/2025
//
// -------------------------------------------------------------------
// Functions:
//  - Generate SDRAM command to the SDRAM chip meeting required timing
//  - Keep track of the the timing requirement of the SDRAM chip
//  - Generate indicator to the above timing requirement
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
    output logic            cmd_ready,
    output logic            cmd_done,

    // signal to indicate if the timing is meet to perform the operation
    output logic            precharge_ready,
    output logic            active_ready,
    output logic            write_ready,

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
localparam MAX_CYCLE = `MAX4(cRAS, cRC, cRFC, 4); // 4 is for CL + 1 = (3+1) = 4 (assuming CL=3)
localparam CMD_CNT_WIDTH = $clog2(MAX_CYCLE+1);

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

logic                     cmd_fire;

// counter for command that might take more then one cycles
logic [CMD_CNT_WIDTH-1:0] cmd_cycle;
logic [CMD_CNT_WIDTH-1:0] cmd_cnt;
logic                     cmd_take_1cycle;

// counter for various sdram timing parameter
logic [CMD_CNT_WIDTH-1:0] cnt_RAS, cnt_RC, cnt_WR, cnt_RL;
logic                     meet_RAS, meet_RC, meet_WR, meet_RL;
logic [CMD_CNT_WIDTH-1:0] read_to_write_cycle;

logic                     cmd_is_active;
logic                     cmd_is_write;
logic                     cmd_is_read;

logic                     sdram_dq_out_en; // enable dq output
logic [DW-1:0]            sdram_dq_out;

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

assign cmd_fire = cmd_valid & cmd_ready;

// cmd counter is used to meet sdram timing for a command
// - auto_refresh (tRFC) / precharge (tRP) / active (tRCD):
//      * these commands may take more then 1 clock cycle depending on the clock frequency
// - write / read:
//      * these commands are considered to always take 1 clock cycle.
//      * Additional counters are used to meet other related timing including tRAS, tRC, tWR

always_comb begin
    cmd_cycle = 0;
    case(cmd_type)
        `CMD_PRECHARGE: cmd_cycle = cRP [CMD_CNT_WIDTH-1:0];
        `CMD_REFRESH:   cmd_cycle = cRFC[CMD_CNT_WIDTH-1:0];
        `CMD_LMR:       cmd_cycle = cMRD[CMD_CNT_WIDTH-1:0];
        `CMD_ACTIVE:    cmd_cycle = cRCD[CMD_CNT_WIDTH-1:0];
        `CMD_WRITE:     cmd_cycle = 'b1;    // write only takes 1 cycle
        `CMD_READ:      cmd_cycle = 'b1;    // read also takes 1 cycle
        `CMD_NOP:       cmd_cycle = 'b1;
        `CMD_DESL:      cmd_cycle = 'b1;
        default:        cmd_cycle = 'b1;
    endcase
end

always_ff @(posedge clk) begin
    if (!rst_n) cmd_cnt <= 'b0;
    else if (cmd_fire) cmd_cnt <= cmd_cycle - 1'b1 - 1'b1; // -1 to make it end with 0,
                                                           // then - 1 as the current cycle is counted as one cycle
    else if (cmd_cnt >0 ) cmd_cnt <= cmd_cnt - 1'b1;
end

always_ff @(posedge clk) begin
    if (!rst_n) begin
        cmd_ready <= 1'b0;
    end
    else begin
        // command can't complete in 1 cycle, de-assert cmd_ready in the next cycle
        if (cmd_fire & !cmd_take_1cycle) cmd_ready <= 1'b0;
        // re-assert cmd_ready after cmd is completed in the next cycle
        else if (cmd_done) cmd_ready <= 1'b1;
    end
end

assign cmd_take_1cycle = cmd_cycle == 1;

assign cmd_done = ( cmd_fire & cmd_take_1cycle) |           // for command takes 1 cycle, complete in the current cycle
                  (~cmd_fire & ~cmd_ready & cmd_cnt == 0);  // for command takes > 1 cycle, complete in last cycle
                                                            // ~cmd_ready indicate there are valid command in progress

// Additional counter to make sure the operation meet key sdram timing including:
// ACTIVE -> PRECHARGE:  tRAS
// ACTIVE -> ACTIVE:     tRC
// WRITE  -> PRECHARGE:  tWR
// READ   -> WRITE:      RL + additional 1 cycle

assign cmd_is_active = cmd_valid && cmd_type == `CMD_ACTIVE;
assign cmd_is_write = cmd_valid && cmd_type == `CMD_WRITE;
assign cmd_is_read = cmd_valid && cmd_type == `CMD_READ;

assign read_to_write_cycle = cfg_cas_latency + 1'b1;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        cnt_RAS <= 'b0;
        cnt_RC <= 'b0;
        cnt_WR <= 'b0;
        cnt_RL <= 'b0;
    end
    else begin
        if (cmd_is_active) cnt_RAS <= cRAS[CMD_CNT_WIDTH-1:0] - 1'b1;
        else if (cnt_RAS != 0) cnt_RAS <= cnt_RAS - 1'b1;

        if (cmd_is_active) cnt_RC <= cRC[CMD_CNT_WIDTH-1:0] - 1'b1;
        else if (cnt_RC != 0) cnt_RC <= cnt_RC - 1'b1;

        if (cmd_is_write) cnt_WR <= cWR[CMD_CNT_WIDTH-1:0] - 1'b1;
        else if (cnt_WR != 0) cnt_WR <= cnt_WR - 1'b1;

        if (cmd_is_read) cnt_RL <= read_to_write_cycle - 1'b1;
        else if (cnt_RL != 0) cnt_RL <= cnt_RL - 1'b1;
    end
end

assign meet_RAS = (cRAS == 1) ? 1'b1 : cnt_RAS == 0;
assign meet_RC = (cRC == 1) ? 1'b1 : cnt_RC == 0;
assign meet_WR = (cWR == 1) ? 1'b1 : cnt_WR == 0;
assign meet_RL = ((cfg_cas_latency + 1'b1) == 1) ? 1'b1 : cnt_RL == 0;

assign active_ready = meet_RC;
assign precharge_ready = meet_RAS & meet_WR;
assign write_ready = meet_RL;

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
