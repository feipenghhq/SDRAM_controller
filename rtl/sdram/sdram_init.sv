// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/26/2025
//
// -------------------------------------------------------------------
// SDRAM initialization control
// -------------------------------------------------------------------

`include "sdram_inc.svh"

module sdram_init #(
    parameter CLK_FREQ = 50,    // (MHz) clock frequency
    parameter AW       = 12     // SDRAM Address width
) (
    input  logic            clk,
    input  logic            rst_n,

    // SDRAM Config
    input  logic [2:0]      cfg_burst_length,   // SDRAM Mode register: Burst Length
    input  logic            cfg_burst_type,     // SDRAM Mode register: Burst Type
    input  logic [2:0]      cfg_cas_latency,    // SDRAM Mode register: CAS Latency
    input  logic            cfg_burst_mode,     // SDRAM Mode register: Write Burst Mode

    // Init Control
    output logic            init_valid,         // Initialization command valid
    output logic [3:0]      init_cmd,           // Initialization command type
    output logic [AW-1:0]   init_addr,          // Initialization command address
    input  logic            cmd_done,           // Command completion flag
    input  logic            cmd_wip,            // Command in progress

    output logic            init_done           // Initialization process done
);

/////////////////////////////////////////////////
// Local Parameter
/////////////////////////////////////////////////
// Initialization cycle and counter width
localparam TIME      = 100;        // (us) initialization NOP time
localparam NOP_CYCLE = TIME * CLK_FREQ;
localparam CNT_WIDTH = $clog2(NOP_CYCLE);

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

// SDRAM Initialization State Machine
typedef enum logic [3:0] {
    IDLE,          // start up idle state
    WAIT,          // wait at least 100us
    PRECHARGE,     // precharge all the bank
    AUTO_REF0,     // First Auto refresh
    AUTO_REF1,     // Second Auto refresh
    SET_MODE_REG,  // Set mode register`
    DONE           // Initialization done
} init_state_t;

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

init_state_t init_state, init_state_next;
logic [CNT_WIDTH-1:0] init_cnt;
logic wait_done;

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

// state transition
always_ff @(posedge clk) begin
    if (!rst_n) begin
        init_state <= IDLE;
    end
    else begin
        init_state <= init_state_next;
    end
end

always_comb begin
    init_state_next = init_state;
    case(init_state)
        IDLE: begin
            init_state_next = WAIT;
        end
        WAIT: begin
            if (wait_done) init_state_next = PRECHARGE;
        end
        PRECHARGE: begin
            if (cmd_done) init_state_next = AUTO_REF0;
        end
        AUTO_REF0: begin
            if (cmd_done) init_state_next = AUTO_REF1;
        end
        AUTO_REF1: begin
            if (cmd_done) init_state_next = SET_MODE_REG;
        end
        SET_MODE_REG: begin
            if (cmd_done) init_state_next = DONE;
        end
        DONE: begin
            init_state_next = DONE;
        end
        default: init_state_next = init_state;
    endcase
end

// init counter
always_ff @(posedge clk) begin
    if (!rst_n) begin
        init_cnt <= NOP_CYCLE;
    end
    else begin
        if (init_cnt > 0) init_cnt <= init_cnt - 1'b1;
    end
end

assign wait_done = init_cnt == 0;

// output function logic
always_comb begin

    init_valid = ~cmd_wip;      // default init_valid to 1
    init_cmd   = `CMD_NOP;
    init_addr  = 'b0;
    init_done  = 1'b0;

    case(init_state_next)
        IDLE: begin
            init_cmd = `CMD_DESL;
        end
        WAIT: begin
            init_cmd = `CMD_DESL;
        end
        PRECHARGE: begin
            init_cmd = `CMD_PRECHARGE;
            init_addr[10] = 1'b1;
        end
        AUTO_REF0: begin
            init_cmd = `CMD_REFRESH;
        end
        AUTO_REF1: begin
            init_cmd = `CMD_REFRESH;
        end
        SET_MODE_REG: begin
            init_cmd = `CMD_LMR;
            init_addr[2:0] = cfg_burst_length;
            init_addr[3]   = cfg_burst_type;
            init_addr[6:4] = cfg_cas_latency;
            init_addr[9]   = cfg_burst_mode;
        end
        DONE: begin
            init_done  = 1'b1;
            init_valid = 1'b0;
        end
    endcase
end

endmodule
