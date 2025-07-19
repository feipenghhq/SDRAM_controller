// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/16/2025
//
// -------------------------------------------------------------------
// SDRAM Controller
// -------------------------------------------------------------------

module sdram_controller #(
    // global parameter
    parameter AW = 16,          // AHB Bus Address width. Should match with SDRAM  data width
    parameter DW = 16,          // AHB Bus Data width
    parameter CLK_FREQ = 100,   // (MHz) clock frequency

    // sdram parameter
    parameter RAW = 12,         // Row address width
    parameter CAW = 8,          // Column address width

    // sdram timing parameter
    parameter tRAS = 50,        // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC  = 80,        // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD = 20,        // (ns) ACTIVE-to-READ or WRITE delay
    parameter tREF = 64,        // (ms) Refresh Period
    parameter tRFC = 60,        // (ns) AUTO REFRESH period
    parameter tRP  = 20,        // (ns) PRECHARGE command period
    parameter tRRD = 20,        // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter cMRD = 3,         // (cycle) LOAD MODE REGISTER command to ACTIVE or REFRESH command
    // TBD, FIXME
    parameter tDPL = 20,        // (ns) Data into precharge
    parameter tSRX = 10,        // (ns) Self refresh exit time

    // sdram initialization sequence
    parameter INIT_TIME = 200   // (us) initialization NOP time
) (
    input  logic            clk,
    input  logic            rst_n,

    // AHB-Lite Bus
    input  logic [AW-1:0]   haddr,
    input  logic [2:0]      hburst,
    input  logic            hmasterlock,
    input  logic [3:0]      hprot,
    input  logic [2:0]      hsize,
    input  logic [1:0]      htrans,
    input  logic [DW-1:0]   hwdata,
    input  logic            hwrite,

    // SDRAM Config
    input  logic [2:0]      cfg_burst_length,       // SDRAM Mode register: Burst Length
    input  logic            cfg_burst_type,         // SDRAM Mode register: Burst Type
    input  logic [2:0]      cfg_cas_latency,        // SDRAM Mode register: CAS Latency
    input  logic            cfg_write_burst_mode,   // SDRAM Mode register: Write Burst Mode

    // SDRAM interface
    output logic            sdram_cke,              // Clock Enable. CKE is high active.
    output logic            sdram_cs_n,             // Chip Select: CSn enables and disables command decoder.
    output logic            sdram_ras_n,            // Row Address Select.
    output logic            sdram_cas_n,            // Column Address Select.
    output logic            sdram_we_n,             // Write Enable.
    output logic [RAW-1:0]  sdram_addr,             // Address for row/column addressing.
    output logic [1:0]      sdram_ba,               // Bank Address. Fixed for 4 banks
    output logic [DW/8-1:0] sdram_dqm,              // Data Mask
    inout  logic [DW-1:0]   sdram_dq                // Data Input/Output bus.

);

/////////////////////////////////////////////////
// Local Parameter
/////////////////////////////////////////////////

// SDRAM Command
localparam CMD_DESL      = 4'b1111;                     // COMMAND INHIBIT, Device de-select
localparam CMD_NOP       = 4'b0111;                     // NO OPERATION
localparam CMD_ACTIVE    = 4'b0011;                     // BANK ACTIVE
localparam CMD_READ      = 4'b0101;                     // READ
localparam CMD_WRITE     = 4'b0100;                     // WRITE
localparam CMD_BST       = 4'b0110;                     // BURST TERMINATE
localparam CMD_PRECHARGE = 4'b0010;                     // PRECHARGE
localparam CMD_REFRESH   = 4'b0001;                     // AUTO REFRESH or SELF REFRESH
localparam CMD_LMR       = 4'b0000;                     // LOAD MODE REGISTER

// roundup division
`define ceil_div(a, b)  (a + b - 1) / b

// Calculate the SDRAM timing in terms of number of clock cycle
localparam cRAS = `ceil_div(tRAS * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE-to-PRECHARGE command
localparam cRC  = `ceil_div(tRC  * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE-to-ACTIVE command period
localparam cRCD = `ceil_div(tRCD * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE-to-READ or WRITE delay
localparam cRFC = `ceil_div(tRFC * CLK_FREQ, 1000);     // (CLK Cycle) AUTO REFRESH period
localparam cRP  = `ceil_div(tRP  * CLK_FREQ, 1000);     // (CLK Cycle) PRECHARGE command period
localparam cRRD = `ceil_div(tRRD * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE bank a to ACTIVE bank b command

// Initialization cycle and counter width
localparam INIT_NOP_CYCLE = 200 * CLK_FREQ;
localparam INIT_CNT_WIDTH = $clog2(INIT_NOP_CYCLE);

// Command counter width
localparam CMD_CNT_WIDTH = $clog2(cRC); // Row cycle time take the most count

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

// SDRAM Main Control State Machine
typedef enum logic [3:0] {
    RESET,              // Start up State
    INIT,               // SDRAM initialization
    MODE_REG_SET,       // Mode Register set
    IDLE,               // IDLE state (after bank have been pre-charged)
    ROW_ACTIVE,         // Active a row
    WRITE,              // Write without auto precharge
    WRITE_A,            // Write with auto precharge
    READ,               // Read without auto precharge
    READ_A,             // Read with auto precharge
    PRECHARGE           // Precharge the bank
} sdram_main_state_t;

// SDRAM Initialization State Machine
typedef enum logic [3:0] {
    INIT_IDLE,          // start up idle state
    INIT_WAIT,          // wait at least 100us
    INIT_PRECHARGE,     // precharge all the bank
    INIT_AUTO_REF0,     // First Auto refresh
    INIT_AUTO_REF1,     // Second Auto refresh
    INIT_SET_MODE_REG,  // Set mode register
    INIT_DONE           // Initialization done
} sdram_init_state_t;

/////////////////////////////////////////////////
// Signal Declaration
/////////////////////////////////////////////////

// ----------------------------------------------
// main state
// ----------------------------------------------

sdram_main_state_t          main_state, main_state_n;

logic                       main_state_is_reset;
logic                       main_state_is_init;
logic                       main_state_is_mode_reg_set;
logic                       main_state_is_idle;
logic                       main_state_is_row_active;
logic                       main_state_is_write;
logic                       main_state_is_write_a;
logic                       main_state_is_read;
logic                       main_state_is_read_a;
logic                       main_state_is_precharge;

logic                       arc_main_reset_2_init;

// ----------------------------------------------
// init state
// ----------------------------------------------
sdram_init_state_t          init_state, init_state_n;


// ----------------------------------------------
// Internal sdram control signal
// ----------------------------------------------
logic                       int_cke;
logic                       int_cs_n;
logic                       int_ras_n;
logic                       int_cas_n;
logic                       int_we_n;
logic [RAW-1:0]             int_addr;
logic [1:0]                 int_ba;
logic [DW/8-1:0]            int_dqm;
logic [DW-1:0]              int_dqo;
logic [DW-1:0]              sdram_dqo;          // registered version of int_dqp

// initialization/refresh counter
logic [INIT_CNT_WIDTH-1:0]  ir_cnt;
logic                       ir_cnt_zero;        // counter reach zero

// command period counter and state indicator
// a command is followed by the command itself and several NOP cmd for the wait state
logic [CMD_CNT_WIDTH-1:0]   cmd_cnt;
logic                       cmd_cpl;            // indicate that a cmd has been complete
logic                       cmd_is_precharge;
logic                       cmd_is_lmr;         // load mode register
logic                       cmd_is_refresh;

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

// ----------------------------------------------
// Main state machine
// ----------------------------------------------

// state assignment
assign main_state_is_reset        = (main_state == RESET);
assign main_state_is_init         = (main_state == INIT);
assign main_state_is_mode_reg_set = (main_state == MODE_REG_SET);
assign main_state_is_idle         = (main_state == IDLE);
assign main_state_is_row_active   = (main_state == ROW_ACTIVE);
assign main_state_is_write        = (main_state == WRITE);
assign main_state_is_write_a      = (main_state == WRITE_A);
assign main_state_is_read         = (main_state == READ);
assign main_state_is_read_a       = (main_state == READ_A);
assign main_state_is_precharge    = (main_state == PRECHARGE);

// state transaction arc

// Start SDRAM initialization sequence once coming out of reset
assign arc_main_reset_2_init = main_state_is_reset;

// state transition
always_ff @(posedge clk) begin
    if (!rst_n) begin
        main_state <= RESET;
    end
    else begin
        main_state <= main_state_n;
    end
end

always_comb begin
    case(1)
        arc_main_reset_2_init: main_state_n = INIT;
        default: main_state_n = main_state;
    endcase
end

// ----------------------------------------------
// Init state machine
// ----------------------------------------------

// state transition
always_ff @(posedge clk) begin
    if (!rst_n) begin
        init_state <= INIT_IDLE;
    end
    else begin
        init_state <= init_state_n;
    end
end

always_comb begin
    init_state_n = init_state;
    case(init_state)
        INIT_IDLE: begin
            if (arc_main_reset_2_init) init_state_n = INIT_WAIT;
        end
        INIT_WAIT: begin
            if (ir_cnt_zero) init_state_n = INIT_PRECHARGE;
        end
        INIT_PRECHARGE: begin
            if (cmd_cpl) init_state_n = INIT_AUTO_REF0;
        end
        INIT_AUTO_REF0: begin
            if (cmd_cpl) init_state_n = INIT_AUTO_REF1;
        end
        INIT_AUTO_REF1: begin
            if (cmd_cpl) init_state_n = INIT_SET_MODE_REG;
        end
        INIT_SET_MODE_REG: begin
            if (cmd_cpl) init_state_n = INIT_DONE;
        end
        INIT_DONE: begin
            init_state_n = INIT_DONE;
        end
        default: init_state_n = init_state;
    endcase
end

// ----------------------------------------------
// Init and refresh counter
// ----------------------------------------------
// To save register, we share the same counter for the initialization counter and refresh counter
always_ff @(posedge clk) begin
    if (!rst_n) begin
        ir_cnt <= 'b0;
    end
    else begin
        if (arc_main_reset_2_init)  ir_cnt <= INIT_NOP_CYCLE;
        else if (ir_cnt > 0)        ir_cnt <= ir_cnt - 1'b1;
    end
end

assign ir_cnt_zero = ir_cnt == 0;

// ----------------------------------------------
// cmd counter
// ----------------------------------------------
// A SDRAM command is usually the command itself followed by several NOP command to wait for the required time interval
// the cmd counter is used to count that and when it reach 0, it indicates a command has been fully completed.
always_ff @(posedge clk) begin
    if (!rst_n) begin
        cmd_cnt <= 'b0;
    end
    else begin
        case(1)
            cmd_is_precharge: cmd_cnt <= cRP [CMD_CNT_WIDTH-1:0];
            cmd_is_refresh:   cmd_cnt <= cRFC[CMD_CNT_WIDTH-1:0];
            cmd_is_lmr:       cmd_cnt <= cMRD[CMD_CNT_WIDTH-1:0];
            default: if (cmd_cnt > 0) cmd_cnt <= cmd_cnt - 1'b1;
        endcase
    end
end

assign cmd_cpl = cmd_cnt == 0;

// ----------------------------------------------
// SDRAM Output Logic
// ----------------------------------------------

// assign the control signal given a operation
`define cmd(op) {int_cs_n, int_ras_n, int_cas_n, int_we_n} = op

always_comb begin

    int_cke   = 'b1;    // default CLK = high
    int_cs_n  = 'b0;    // default NOP command
    int_ras_n = 'b1;
    int_cas_n = 'b1;
    int_we_n  = 'b1;
    int_addr  = 'b0;
    int_ba    = 'b0;
    int_dqm   = 'b0;
    int_dqo   = 'b0;

    cmd_is_precharge = 1'b0;
    cmd_is_refresh   = 1'b0;
    cmd_is_lmr       = 1'b0;

    // Note:
    //  1. To align the command with state, we use next state here as the case condition
    //  2. The command are send when we entering a specific state, else the NOP command is usually send to
    //     the wait time for the command to complete

    case(main_state_n)
        // Initialization Sequence
        INIT: begin
            case(init_state_n)
                INIT_WAIT: begin
                    `cmd(CMD_DESL);
                end
                INIT_PRECHARGE: begin
                    if (init_state == INIT_WAIT) begin
                        `cmd(CMD_PRECHARGE);
                        int_addr[10] = 1'b1;    // precharge all bank
                        cmd_is_precharge = 1'b1;
                    end
                end
                INIT_AUTO_REF0: begin
                    if (init_state == INIT_PRECHARGE) begin
                        `cmd(CMD_REFRESH);      // auto-refresh (cke=1)
                        cmd_is_refresh = 1'b1;
                    end
                end
                INIT_AUTO_REF1: begin
                    if (init_state == INIT_AUTO_REF0) begin
                        `cmd(CMD_REFRESH);      // auto-refresh (cke=1)
                        cmd_is_refresh = 1'b1;
                    end
                end
                INIT_SET_MODE_REG: begin
                    if (init_state == INIT_AUTO_REF1) begin
                        `cmd(CMD_LMR);
                        cmd_is_lmr = 1'b1;
                        int_addr[2:0] = cfg_burst_length;
                        int_addr[3]   = cfg_burst_type;
                        int_addr[6:4] = cfg_cas_latency;
                        int_addr[8:7] = 2'b0;
                        int_addr[9]   = cfg_write_burst_mode;
                        int_addr[RAW-1:10] = 'b0;
                    end
                end
                INIT_DONE: begin
                    `cmd(CMD_NOP);
                end
                default: `cmd(CMD_NOP);
            endcase
        end
    endcase
end

// Register the output
always_ff @(posedge clk) begin
    if (!rst_n) begin
        sdram_cke   <= 'b0;
        sdram_cs_n  <= 'b1;
        sdram_ras_n <= 'b1;
        sdram_cas_n <= 'b1;
        sdram_we_n  <= 'b1;
        sdram_addr  <= 'b0;
        sdram_ba    <= 'b0;
        sdram_dqm   <= 'b0;
        sdram_dqo   <= 'b0;
    end
    else begin
        sdram_cke   <= int_cke;
        sdram_cs_n  <= int_cs_n;
        sdram_ras_n <= int_ras_n;
        sdram_cas_n <= int_cas_n;
        sdram_we_n  <= int_we_n;
        sdram_addr  <= int_addr;
        sdram_ba    <= int_ba;
        sdram_dqm   <= int_dqm;
        sdram_dqo   <= int_dqo;
    end
end

assign sdram_dq = (sdram_we_n == 0) ? sdram_dqo : {DW{1'bz}};

endmodule

/*
always_ff @(posedge clk) begin
    if (!rst_n) begin
    end
    else begin
    end
end
*/
