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
//
// Supported SDRAM Features:
//     1. Single Read/Write access with Auto-precharge
//
// SDRAM Controller Features:
//     1. bus input and output are registered for better timing
//
// -------------------------------------------------------------------


module sdram_controller #(
    parameter CLK_FREQ = 100,   // (MHz) clock frequency
    parameter AW = 24,          // Bus Address width. Should match with SDRAM size
    parameter DW = 16,          // Bus Data width
    // SDRAM Size
    parameter RAW = 12,         // SDRAM Address width
    parameter CAW = 9,          // SDRAM Column address width
    // SDRAM timing parameter
    parameter tRAS = 42,        // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC  = 60,        // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD = 18,        // (ns) ACTIVE-to-READ or WRITE delay
    parameter tRFC = 60,        // (ns) AUTO REFRESH period
    parameter tRP  = 18,        // (ns) PRECHARGE command period
    parameter tRRD = 20,        // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter tWR  = 20,        // (ns) WRITE recovery time (WRITE completion to PRECHARGE period)
    parameter tREF = 64         // (ms) Refresh Period
) (
    input  logic            clk,
    input  logic            rst_n,

    // System Bus
    input  logic            bus_read,               // read request
    input  logic            bus_write,              // write request
    input  logic [AW-1:0]   bus_addr,               // address
    input  logic            bus_burst,              // indicate burst transfer
    input  logic [2:0]      bus_burst_len,          // Burst length
    input  logic [DW-1:0]   bus_wdata,              // write data
    input  logic [DW/8-1:0] bus_byteenable,         // byte enable
    output logic            bus_ready,              // ready
    output logic            bus_rvalid,             // read data valid
    output logic [DW-1:0]   bus_rdata,              // read data

    // SDRAM Config
    input  logic [2:0]      cfg_burst_length,       // SDRAM Mode register: Burst Length
    input  logic            cfg_burst_type,         // SDRAM Mode register: Burst Type
    input  logic [2:0]      cfg_cas_latency,        // SDRAM Mode register: CAS Latency
    input  logic            cfg_burst_mode,         // SDRAM Mode register: Write Burst Mode

    // SDRAM interface
    output logic            sdram_cke,              // Clock Enable.
    output logic            sdram_cs_n,             // Chip Select.
    output logic            sdram_ras_n,            // Row Address Select.
    output logic            sdram_cas_n,            // Column Address Select.
    output logic            sdram_we_n,             // Write Enable.
    output logic [RAW-1:0]  sdram_addr,             // Address.
    output logic [1:0]      sdram_ba,               // Bank.
    output logic [DW/8-1:0] sdram_dqm,              // Data Mask
    inout  wire  [DW-1:0]   sdram_dq                // Data Input/Output bus.

);

/////////////////////////////////////////////////
// SDRAM Parameter
/////////////////////////////////////////////////

// Other SDRAM parameter
parameter cMRD = 3;             // (cycle) LOAD MODE REGISTER command to ACTIVE or REFRESH command. JEDEC specify 3 clocks.
parameter INIT_TIME = 100;      // (us) initialization NOP time
parameter ROW_COUNT = 2**RAW;   // SDRAM row count

/////////////////////////////////////////////////
// Local Parameter
/////////////////////////////////////////////////

// Calculate the SDRAM timing in terms of number of clock cycle
localparam cRAS = ceil_div(tRAS * CLK_FREQ, 1000);      // (CLK Cycle) ACTIVE-to-PRECHARGE command
localparam cRC  = ceil_div(tRC  * CLK_FREQ, 1000);      // (CLK Cycle) ACTIVE-to-ACTIVE command period
localparam cRCD = ceil_div(tRCD * CLK_FREQ, 1000);      // (CLK Cycle) ACTIVE-to-READ or WRITE delay
localparam cRFC = ceil_div(tRFC * CLK_FREQ, 1000);      // (CLK Cycle) AUTO REFRESH period
localparam cRP  = ceil_div(tRP  * CLK_FREQ, 1000);      // (CLK Cycle) PRECHARGE command period
localparam cRRD = ceil_div(tRRD * CLK_FREQ, 1000);      // (CLK Cycle) ACTIVE bank a to ACTIVE bank b command
localparam cWR  = ceil_div(tWR  * CLK_FREQ, 1000);      // (CLK Cycle) WRITE recovery time (WRITE completion to PRECHARGE period)

// Bus Decode
localparam NUM_BYTE      = DW / 8;                      // Number of byte
localparam BW            = $clog2(NUM_BYTE);            // Address With to select the byte

// SDRAM Command
// {cs_n, ras_n, cas_n, we_m} = CMD
localparam CMD_DESL      = 4'b1111;                     // COMMAND INHIBIT, Device de-select
localparam CMD_NOP       = 4'b0111;                     // NO OPERATION
localparam CMD_ACTIVE    = 4'b0011;                     // BANK ACTIVE
localparam CMD_READ      = 4'b0101;                     // READ
localparam CMD_WRITE     = 4'b0100;                     // WRITE
localparam CMD_BST       = 4'b0110;                     // BURST TERMINATE
localparam CMD_PRECHARGE = 4'b0010;                     // PRECHARGE
localparam CMD_REFRESH   = 4'b0001;                     // AUTO REFRESH or SELF REFRESH
localparam CMD_LMR       = 4'b0000;                     // LOAD MODE REGISTER

// Initialization cycle and counter width
localparam INIT_NOP_CYCLE = INIT_TIME * CLK_FREQ;
localparam INIT_CNT_WIDTH = $clog2(INIT_NOP_CYCLE);

// Refresh counter threshold
localparam REFRESH_INTERVAL = (tREF * 1000 * CLK_FREQ / ROW_COUNT);

// Command counter width
localparam CMD_CNT_WIDTH = 4;

/////////////////////////////////////////////////
// State Machine Declaration
/////////////////////////////////////////////////

// SDRAM Main Control State Machine
typedef enum logic [3:0] {
    SDRAM_RESET,              // Start up State
    SDRAM_INIT,               // SDRAM initialization
    SDRAM_MODE_REG_SET,       // Mode Register set
    SDRAM_IDLE,               // IDLE state (after bank have been pre-charged)
    SDRAM_ROW_ACTIVE,         // Active a row
    SDRAM_WRITE,              // Write without auto precharge
    SDRAM_WRITE_A,            // Write with auto precharge
    SDRAM_READ,               // Read without auto precharge
    SDRAM_READ_A,             // Read with auto precharge
    SDRAM_PRECHARGE,          // Precharge the bank
    SDRAM_AUTO_REFRESH        // Auto Refresh
} sdram_state_t;

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

// main state machine
sdram_state_t               sdram_state, sdram_state_n;
logic                       s_RESET;
logic                       s_INIT;
logic                       s_MODE_REG_SET;
logic                       s_IDLE;
logic                       s_ROW_ACTIVE;
logic                       s_WRITE;
logic                       s_WRITE_A;
logic                       s_READ;
logic                       s_READ_A;
logic                       s_PRECHARGE;
logic                       s_AUTO_REFRESH;
logic                       arc_RESET_to_INIT;
logic                       arc_INIT_to_IDLE;
logic                       arc_IDLE_to_ROW_ACTIVE;
logic                       arc_IDLE_to_AUTO_REFRESH;
logic                       arc_ROW_ACTIVE_to_WRITE_A;
logic                       arc_ROW_ACTIVE_to_READ_A;
logic                       arc_WRITE_A_to_IDLE;
logic                       arc_READ_A_to_IDLE;
logic                       arc_PRECHARGE_to_IDLE;
logic                       arc_AUTO_REFRESH_to_IDLE;
logic                       arc_AUTO_REFRESH_to_ROW_ACTIVE;

// init state machine
sdram_init_state_t          init_state, init_state_n;

// Internal system bus, these are registered version of the system bus
logic                       int_bus_read;
logic                       int_bus_write;
logic [AW-1:0]              int_bus_addr;
logic                       int_bus_burst;
logic [2:0]                 int_bus_burst_len;
logic [DW-1:0]              int_bus_wdata;
logic [DW/8-1:0]            int_bus_byteenable;
logic                       int_bus_ready;
logic                       int_bus_rvalid;
logic [DW-1:0]              int_bus_rdata;

logic                       bus_req;            // new bus request
logic                       int_bus_req;        // internal bus request

// Address mapping to sdram {bank, row, col}
logic [1:0]                 bank;               // band address
logic [RAW-1:0]             row;                // row address
logic [CAW-1:0]             col;                // column address

// Internal sdram control signal
logic                       int_sdram_cke;
logic                       int_sdram_cs_n;
logic                       int_sdram_ras_n;
logic                       int_sdram_cas_n;
logic                       int_sdram_we_n;
logic [RAW-1:0]             int_sdram_addr;
logic [1:0]                 int_sdram_ba;
logic [DW/8-1:0]            int_sdram_dqm;
logic [DW-1:0]              int_sdram_dqo;
logic                       int_sdram_dq_en;

logic                       sdram_dq_en;        // enable dq output
logic [DW-1:0]              sdram_dqo;          // registered version of int_sdram_dqp

// initialization and refresh counter
logic [INIT_CNT_WIDTH-1:0]  ir_cnt;
logic                       ir_cnt_zero;        // counter reach zero

// command counter and cmd indicator
logic [CMD_CNT_WIDTH-1:0]   cmd_cnt;
logic                       cmd_cpl;
logic                       cmd_cpl_pre;        // one cycle before cmd_cpl
logic                       cmd_is_precharge;
logic                       cmd_is_lmr;         // load mode register
logic                       cmd_is_refresh;
logic                       cmd_is_active;
logic                       cmd_is_write_a;
logic                       cmd_is_read_a;

// CL counter to indicate read data ready
logic [1:0]                 read_latency;       // read latency. From when READ is issued to READ data is ready on DQ
logic [1:0]                 read_latency_cnt;
logic                       wait_rdata;         // read request issue, waiting for read data

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

// ----------------------------------------------
// Handling system bus
// ----------------------------------------------

// a new bus request is taken
assign bus_req = (bus_read | bus_write) & bus_ready;

assign int_bus_req = int_bus_read | int_bus_write;

// Register input
always_ff @(posedge clk) begin
    if (!rst_n) begin
        int_bus_read   <= 1'b0;
        int_bus_write  <= 1'b0;
    end
    else begin
        if (bus_req) begin
            int_bus_read   <= bus_read;
            int_bus_write  <= bus_write;
        end
        else if (int_bus_ready) begin
            int_bus_read   <= 1'b0;
            int_bus_write  <= 1'b0;
        end
    end
end

always_ff @(posedge clk) begin
    if (bus_req) begin
        int_bus_addr       <= bus_addr;
        int_bus_burst      <= bus_burst;
        int_bus_burst_len  <= bus_burst_len;
        int_bus_wdata      <= bus_wdata;
        int_bus_byteenable <= bus_byteenable;
    end
end

// Register bus output
always_ff @(posedge clk) begin
    if (!rst_n) begin
        bus_ready  <= 1'b0;
        bus_rvalid <= 1'b0;
    end
    else begin
        bus_ready  <= int_bus_ready;
        bus_rvalid <= int_bus_rvalid;
    end
end

always_ff @(posedge clk) begin
   bus_rdata <= int_bus_rdata;
end

// ----------------------------------------------
// Main state machine
// ----------------------------------------------

// Indicating current state
assign s_RESET        = (sdram_state == SDRAM_RESET);
assign s_INIT         = (sdram_state == SDRAM_INIT);
assign s_MODE_REG_SET = (sdram_state == SDRAM_MODE_REG_SET);
assign s_IDLE         = (sdram_state == SDRAM_IDLE);
assign s_ROW_ACTIVE   = (sdram_state == SDRAM_ROW_ACTIVE);
assign s_WRITE        = (sdram_state == SDRAM_WRITE);
assign s_WRITE_A      = (sdram_state == SDRAM_WRITE_A);
assign s_READ         = (sdram_state == SDRAM_READ);
assign s_READ_A       = (sdram_state == SDRAM_READ_A);
assign s_PRECHARGE    = (sdram_state == SDRAM_PRECHARGE);
assign s_AUTO_REFRESH = (sdram_state == SDRAM_AUTO_REFRESH);

// state transaction arc

// RESET -> INIT: Start SDRAM initialization sequence once coming out of reset
assign arc_RESET_to_INIT = s_RESET;

// INIT -> IDLE: Initialization complete
assign arc_INIT_to_IDLE = s_INIT & (init_state == INIT_DONE);

// IDLE -> ROW_ACTIVE: Get a new bus request
assign arc_IDLE_to_ROW_ACTIVE = s_IDLE & int_bus_req & ~ir_cnt_zero; // FIXME: 1. IDLE takes 2 clock

// IDLE -> AUTO_REFRESH
assign arc_IDLE_to_AUTO_REFRESH = s_IDLE & ir_cnt_zero;

// ROW ACTIVE -> WRITE_A
assign arc_ROW_ACTIVE_to_WRITE_A = s_ROW_ACTIVE & cmd_cpl & int_bus_write;

// ROW ACTIVE -> READ_A
assign arc_ROW_ACTIVE_to_READ_A = s_ROW_ACTIVE & cmd_cpl & int_bus_read;

// WRITE_A -> IDLE: Complete write operation and precharge
assign arc_WRITE_A_to_IDLE = s_WRITE_A & cmd_cpl;

// READ_A -> IDLE: Complete read operation and precharge
assign arc_READ_A_to_IDLE = s_READ_A & cmd_cpl;

// AUTO_REFRESH -> IDLE: Complete the auto refresh operation and no request pending
assign arc_AUTO_REFRESH_to_IDLE = s_AUTO_REFRESH & cmd_cpl & ~int_bus_req;

// AUTO_REFRESH -> IDLE: Complete the auto refresh operation and request pending
assign arc_AUTO_REFRESH_to_ROW_ACTIVE = s_AUTO_REFRESH & cmd_cpl & int_bus_req;

// state transition
always_ff @(posedge clk) begin
    if (!rst_n) begin
        sdram_state <= SDRAM_RESET;
    end
    else begin
        sdram_state <= sdram_state_n;
    end
end

always_comb begin
    case(1)
        arc_RESET_to_INIT:                  sdram_state_n = SDRAM_INIT;
        arc_INIT_to_IDLE:                   sdram_state_n = SDRAM_IDLE;
        arc_IDLE_to_ROW_ACTIVE:             sdram_state_n = SDRAM_ROW_ACTIVE;
        arc_IDLE_to_AUTO_REFRESH:           sdram_state_n = SDRAM_AUTO_REFRESH;
        arc_ROW_ACTIVE_to_WRITE_A:          sdram_state_n = SDRAM_WRITE_A;
        arc_ROW_ACTIVE_to_READ_A:           sdram_state_n = SDRAM_READ_A;
        arc_WRITE_A_to_IDLE:                sdram_state_n = SDRAM_IDLE;
        arc_READ_A_to_IDLE:                 sdram_state_n = SDRAM_IDLE;
        arc_PRECHARGE_to_IDLE:              sdram_state_n = SDRAM_IDLE;
        arc_AUTO_REFRESH_to_IDLE:           sdram_state_n = SDRAM_IDLE;
        arc_AUTO_REFRESH_to_ROW_ACTIVE:     sdram_state_n = SDRAM_ROW_ACTIVE;
        default:                            sdram_state_n = sdram_state;
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
            if (arc_RESET_to_INIT) init_state_n = INIT_WAIT;
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
        if (arc_RESET_to_INIT) ir_cnt <= INIT_NOP_CYCLE;
        else if (arc_INIT_to_IDLE || arc_IDLE_to_AUTO_REFRESH) ir_cnt <= REFRESH_INTERVAL;
        else if (ir_cnt > 0) ir_cnt <= ir_cnt - 1'b1;
    end
end

assign ir_cnt_zero = ir_cnt == 0;

// ----------------------------------------------
// cmd counter
// ----------------------------------------------
// A SDRAM command is usually the command itself followed by several NOP command to meet sdram timing.
// The cmd counter is used to count that and when it reach 0, it indicates a command has been fully completed.
always_ff @(posedge clk) begin
    if (!rst_n) begin
        cmd_cnt <= 'b0;
    end
    else begin
        case(1)
            cmd_is_precharge: cmd_cnt <= cRP [CMD_CNT_WIDTH-1:0] - 1'b1;
            cmd_is_refresh:   cmd_cnt <= cRFC[CMD_CNT_WIDTH-1:0] - 1'b1;
            cmd_is_lmr:       cmd_cnt <= cMRD[CMD_CNT_WIDTH-1:0] - 1'b1;
            cmd_is_active:    cmd_cnt <= cRCD[CMD_CNT_WIDTH-1:0] - 1'b1;
            cmd_is_write_a:   cmd_cnt <= cWR [CMD_CNT_WIDTH-1:0] + cRP[CMD_CNT_WIDTH-1:0] - 1'b1;  // single write only
            cmd_is_read_a:    cmd_cnt <= cfg_cas_latency + 1'b1 + cRP[CMD_CNT_WIDTH-1:0] - 1'b1;   // single read only
            default: if (cmd_cnt > 0) cmd_cnt <= cmd_cnt - 1'b1;
        endcase
    end
end

assign cmd_cpl     = cmd_cnt == 0;
assign cmd_cpl_pre = cmd_cnt == 1;

// ----------------------------------------------
// CAS Latency counter
// ----------------------------------------------

assign read_latency = cfg_cas_latency[1:0];

// Check when read data is available
always_ff @(posedge clk) begin
    if (!rst_n) begin
        read_latency_cnt <= 'b0;
        wait_rdata <= 1'b0;
    end
    else begin
        if (cmd_is_read_a)              read_latency_cnt <= read_latency;
        else if (read_latency_cnt != 0) read_latency_cnt <= read_latency_cnt - 1'b1;

        if (cmd_is_read_a)              wait_rdata <= 1'b1;
        else if (read_latency_cnt == 0) wait_rdata <= 1'b0;
    end
end

// ----------------------------------------------
// SDRAM State Machine Output Function Logic
// ----------------------------------------------

// Decode the bus address to sdram bank, row, col
assign {bank, row, col} = int_bus_addr[AW-1:BW];

assign int_bus_rvalid   = wait_rdata & (read_latency_cnt == 0);
assign int_bus_rdata    = sdram_dq;

always_comb begin

    int_sdram_cke   = 'b1;      // default CLK = high
    sdram_ctrl(CMD_NOP);        // default cmd is NOP
    int_sdram_addr  = 'b0;
    int_sdram_ba    = 'b0;
    int_sdram_dqm   = 'b0;
    int_sdram_dqo   = 'b0;
    int_sdram_dq_en = 'b0;

    cmd_is_precharge = 1'b0;
    cmd_is_refresh   = 1'b0;
    cmd_is_lmr       = 1'b0;
    cmd_is_active    = 1'b0;
    cmd_is_write_a   = 1'b0;
    cmd_is_read_a    = 1'b0;
    cmd_is_precharge = 1'b0;

    // disable bus_ready when we get a new request or then there are request already pending/in progress
    int_bus_ready   = ~bus_req & ~int_bus_req;

    case(sdram_state)

        SDRAM_INIT: begin

            int_bus_ready = 1'b0;   // not ready to take any request during initialization

            case(init_state)
                INIT_IDLE: begin
                    if (arc_RESET_to_INIT) sdram_ctrl(CMD_DESL);
                end
                INIT_WAIT: begin
                    sdram_ctrl(CMD_DESL);
                    // going to INIT_PRECHARGE state: scheduling Precharge command
                    if (ir_cnt_zero) begin
                        sdram_ctrl(CMD_PRECHARGE);
                        cmd_is_precharge = 1'b1;
                        int_sdram_addr[10] = 1'b1;
                    end
                end
                INIT_PRECHARGE: begin
                    // going to AUTO_REF0 state: scheduling 1st Auto Refresh command
                    if (cmd_cpl) begin
                        sdram_ctrl(CMD_REFRESH);      // auto-refresh (cke=1)
                        cmd_is_refresh = 1'b1;
                    end
                end
                INIT_AUTO_REF0: begin
                    // going to AUTO_REF1 state: scheduling 2nd Auto Refresh command
                    if (cmd_cpl) begin
                        sdram_ctrl(CMD_REFRESH);      // auto-refresh (cke=1)
                        cmd_is_refresh = 1'b1;
                    end
                end
                INIT_AUTO_REF1: begin
                    // going to SET_MODE_REG state: scheduling Set Mode Register command
                    if (cmd_cpl) begin
                        sdram_ctrl(CMD_LMR);
                        cmd_is_lmr = 1'b1;
                        int_sdram_addr      = 0;    // set all the served bit to 0
                        int_sdram_addr[2:0] = cfg_burst_length;
                        int_sdram_addr[3]   = cfg_burst_type;
                        int_sdram_addr[6:4] = cfg_cas_latency;
                        int_sdram_addr[9]   = cfg_burst_mode;
                    end
                end
            endcase
        end

        SDRAM_IDLE: begin
            // going to AUTO_REFRESH state: scheduling Auto Refresh command
            if (arc_IDLE_to_AUTO_REFRESH) begin
                sdram_ctrl(CMD_REFRESH);      // auto-refresh (cke=1)
                cmd_is_refresh = 1'b1;
            end
            // going to ROW_ACTIVE state: scheduling ACTIVE command
            else if (arc_IDLE_to_ROW_ACTIVE) begin
                sdram_ctrl(CMD_ACTIVE);
                cmd_is_active = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr = row;
            end
        end

        SDRAM_ROW_ACTIVE: begin
            // going to WRITE_A: schedule WRITE with Auto Precharge
            if (arc_ROW_ACTIVE_to_WRITE_A) begin
                sdram_ctrl(CMD_WRITE);
                cmd_is_write_a = 1'b1;
                int_sdram_addr[10] = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr[CAW-1:0] = col;
                int_sdram_dqm = ~int_bus_byteenable;
                int_sdram_dqo = int_bus_wdata;
                int_sdram_dq_en = 1'b1;
            end
            // going to READ_A: schedule READ with Auto Precharge
            else if (arc_ROW_ACTIVE_to_READ_A) begin
                sdram_ctrl(CMD_READ);
                cmd_is_read_a = 1'b1;
                int_sdram_addr[10] = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr[CAW-1:0] = col;
                int_sdram_dqm = ~int_bus_byteenable;
            end
        end

        SDRAM_WRITE_A: begin
            // Set the bus_ready at the end of WRITE_A state so we can register the input when we enter IDLE state
            // and start to process the new request. This save one clock cycle if there are request pending.
            // TBD: provide a Timing diagram in document
            int_bus_ready = cmd_cpl_pre;
        end

        SDRAM_READ_A: begin
            // Same logic as WRITE_A state
            int_bus_ready = cmd_cpl_pre;
        end

        SDRAM_AUTO_REFRESH: begin
            // Auto refresh complete but request pending. Going to ROW_ACTIVE state
            if (arc_AUTO_REFRESH_to_ROW_ACTIVE) begin
                sdram_ctrl(CMD_ACTIVE);
                cmd_is_active = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr = row;
            end
        end
    endcase
end

// ----------------------------------------------
// Register the SDRAM output
// ----------------------------------------------
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
        sdram_dq_en <= 'b0;
    end
    else begin
        sdram_cke   <= int_sdram_cke;
        sdram_cs_n  <= int_sdram_cs_n;
        sdram_ras_n <= int_sdram_ras_n;
        sdram_cas_n <= int_sdram_cas_n;
        sdram_we_n  <= int_sdram_we_n;
        sdram_addr  <= int_sdram_addr;
        sdram_ba    <= int_sdram_ba;
        sdram_dqm   <= int_sdram_dqm;
        sdram_dqo   <= int_sdram_dqo;
        sdram_dq_en <= int_sdram_dq_en;
    end
end

assign sdram_dq = sdram_dq_en ? sdram_dqo : {DW{1'bz}};

/////////////////////////////////////////////////
// Utility Function
/////////////////////////////////////////////////

// ceil division
function automatic integer ceil_div;
    input integer a;
    input integer b;
    ceil_div = (a + b - 1) / b;
endfunction

// Find max(a, b)
function automatic integer max;
    input integer a;
    input integer b;
    max = a > b ? a : b;
endfunction

// Assign SDRAM command to control signal
task automatic sdram_ctrl(input logic [3:0] cmd);
    int_sdram_cs_n  = cmd[3];
    int_sdram_ras_n = cmd[2];
    int_sdram_cas_n = cmd[1];
    int_sdram_we_n  = cmd[0];
endtask


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

// Showing state in STRING
logic [95:0] sdram_state_str;
always_comb begin
    case (sdram_state)
        SDRAM_RESET:        sdram_state_str = "RESET     ";
        SDRAM_INIT:         sdram_state_str = "INIT      ";
        SDRAM_MODE_REG_SET: sdram_state_str = "MODE_REG  ";
        SDRAM_IDLE:         sdram_state_str = "IDLE      ";
        SDRAM_ROW_ACTIVE:   sdram_state_str = "ROW_ACTIVE";
        SDRAM_WRITE:        sdram_state_str = "WRITE     ";
        SDRAM_WRITE_A:      sdram_state_str = "WRITE_A   ";
        SDRAM_READ:         sdram_state_str = "READ      ";
        SDRAM_READ_A:       sdram_state_str = "READ_A    ";
        SDRAM_PRECHARGE:    sdram_state_str = "PRECHARGE ";
        SDRAM_AUTO_REFRESH: sdram_state_str = "AUTO_REFRESH";
        default:            sdram_state_str = "UNKNOWN   ";
    endcase
end

`endif

endmodule

