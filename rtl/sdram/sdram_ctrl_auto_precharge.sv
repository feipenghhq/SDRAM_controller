// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 07/16/2025
//
// -------------------------------------------------------------------
// SDRAM Controller with Auto Precharge
//
// Features:
//     1. Single Read/Write access with Auto-precharge.
//     2. Non-pipelined interface on system bus.
//
// -------------------------------------------------------------------

`default_nettype none

module sdram_ctrl_auto_precharge #(
    parameter CLK_FREQ  = 100,      // (MHz) clock frequency
    parameter AW        = 24,       // Bus Address width. Should match with SDRAM size
    parameter DW        = 16,       // Bus Data width
    parameter BUS_MODE  = 0,        // Fixed to Non-pipeline mode (0)
    // SDRAM Size
    parameter RAW       = 12,       // SDRAM Address width
    parameter CAW       = 9,        // SDRAM Column address width
    // SDRAM timing parameter
    parameter tRAS      = 42,       // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC       = 60,       // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD      = 18,       // (ns) ACTIVE-to-READ or WRITE delay
    parameter tRFC      = 60,       // (ns) AUTO REFRESH period
    parameter tRP       = 18,       // (ns) PRECHARGE command period
    parameter tRRD      = 20,       // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter tWR       = 20,       // (ns) WRITE recovery time (WRITE completion to PRECHARGE period)
    parameter tREF      = 64        // (ms) Refresh Period
) (
    input  logic            clk,
    input  logic            rst_n,

    // System Bus
    input  logic            bus_req_read,           // read request
    input  logic            bus_req_write,          // write request
    input  logic [AW-1:0]   bus_req_addr,           // address
    input  logic            bus_req_burst,          // indicate burst transfer
    input  logic [2:0]      bus_req_burst_len,      // Burst length
    input  logic [DW-1:0]   bus_req_wdata,          // write data
    input  logic [DW/8-1:0] bus_req_byteenable,     // byte enable
    output logic            bus_req_ready,          // ready

    output logic            bus_rsp_valid,          // read data valid
    output logic [DW-1:0]   bus_rsp_rdata,          // read data

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
// Local Parameter
/////////////////////////////////////////////////

// Calculate the SDRAM timing in clock cycle
`define sdram_ceil_div(a, b) ((a) + (b) - 1) / (b)
localparam cRAS = `sdram_ceil_div(tRAS * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE-to-PRECHARGE command
localparam cRC  = `sdram_ceil_div(tRC  * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE-to-ACTIVE command period
localparam cRCD = `sdram_ceil_div(tRCD * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE-to-READ or WRITE delay
localparam cRFC = `sdram_ceil_div(tRFC * CLK_FREQ, 1000);   // (CLK Cycle) AUTO REFRESH period
localparam cRP  = `sdram_ceil_div(tRP  * CLK_FREQ, 1000);   // (CLK Cycle) PRECHARGE command period
localparam cRRD = `sdram_ceil_div(tRRD * CLK_FREQ, 1000);   // (CLK Cycle) ACTIVE bank a to ACTIVE bank b command
localparam cWR  = `sdram_ceil_div(tWR  * CLK_FREQ, 1000);   // (CLK Cycle) WRITE recovery time (WRITE completion to PRECHARGE period)
`undef sdram_ceil_div
// Other SDRAM parameter
localparam cMRD      = 3;        // (cycle) LOAD MODE REGISTER cycle. JEDEC specify 3 clocks.
localparam INIT_TIME = 100;      // (us) initialization NOP time

// Bus Decode
localparam ROW_COUNT = 2**RAW;   // SDRAM row count
localparam NUM_BYTE  = DW / 8;                          // Number of byte
localparam BW        = $clog2(NUM_BYTE);                // Address With to select the byte

// SDRAM Command
// {cs_n, ras_n, cas_n, we_m} = CMD
localparam CMD_DESL      = 4'b1111;                     // COMMAND INHIBIT, Device de-select
localparam CMD_NOP       = 4'b0111;                     // NO OPERATION
localparam CMD_ACTIVE    = 4'b0011;                     // BANK ACTIVE
localparam CMD_READ      = 4'b0101;                     // READ
localparam CMD_WRITE     = 4'b0100;                     // WRITE
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
    SDRAM_RESET,        // Start up State
    SDRAM_INIT,         // SDRAM initialization
    SDRAM_IDLE,         // IDLE state (after bank have been pre-charged)
    SDRAM_ROW_ACTIVE,   // Active a row
    SDRAM_WRITE_A,      // Write with auto precharge
    SDRAM_READ_A,       // Read with auto precharge
    SDRAM_AUTO_REFRESH  // Auto Refresh
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
sdram_state_t               sdram_state, sdram_state_next;
logic                       s_RESET;
logic                       s_INIT;
logic                       s_IDLE;
logic                       s_ROW_ACTIVE;
logic                       s_WRITE_A;
logic                       s_READ_A;
logic                       s_AUTO_REFRESH;
logic                       arc_RESET_to_INIT;
logic                       arc_INIT_to_IDLE;
logic                       arc_IDLE_to_ROW_ACTIVE;
logic                       arc_IDLE_to_AUTO_REFRESH;
logic                       arc_ROW_ACTIVE_to_WRITE_A;
logic                       arc_ROW_ACTIVE_to_READ_A;
logic                       arc_WRITE_A_to_IDLE;
logic                       arc_READ_A_to_IDLE;
logic                       arc_AUTO_REFRESH_to_IDLE;
logic                       arc_AUTO_REFRESH_to_ROW_ACTIVE;

// init state machine
sdram_init_state_t          init_state, init_state_next;

// input register
logic                       bus_req_read_q;
logic                       bus_req_write_q;
logic [AW-1:0]              bus_req_addr_q;
logic [DW-1:0]              bus_req_wdata_q;
logic [DW/8-1:0]            bus_req_byteenable_q;

logic                       bus_rsp_valid_next;
logic [DW-1:0]              bus_rsp_rdata_next;

logic                       bus_req_act;        // new bus request is accepted
logic                       int_bus_req;        // internal bus request pending
logic                       int_bus_cpl;        // internal bus request complete

logic                       int_busy;           // sdram busy
logic                       int_busy_next;      // sdram busy

// Address mapping to sdram {bank, row, col}
logic [1:0]                 bank;               // band address
logic [RAW-1:0]             row;                // row address
logic [CAW-1:0]             col;                // column address

// sdram command
logic [3:0]                 sdram_cmd;

// Internal sdram control signal
logic                       sdram_cke_next;
logic                       sdram_cs_n_next;
logic                       sdram_ras_n_next;
logic                       sdram_cas_n_next;
logic                       sdram_we_n_next;
logic [RAW-1:0]             sdram_addr_next;
logic [1:0]                 sdram_ba_next;
logic [DW/8-1:0]            sdram_dqm_next;
logic                       sdram_dq_out_en_next;
logic [DW-1:0]              sdram_dq_out_next;

logic                       sdram_dq_out_en;
logic [DW-1:0]              sdram_dq_out;

logic [RAW-1:0]             sdram_addr_col;

// initialization and refresh counter
logic [INIT_CNT_WIDTH-1:0]  ir_cnt;
logic                       ir_cpl;
logic                       init_wait_cpl;
logic                       refresh_req;

// command counter and cmd indicator
logic [CMD_CNT_WIDTH-1:0]   cmd_cnt;
logic                       cmd_cpl;
logic                       pre_cmd_cpl;        // one cycle before cmd_cpl

// CL counter to indicate read data ready
logic [1:0]                 read_latency;       // read latency. From when READ is issued to READ data is ready on DQ
logic [1:0]                 read_latency_cnt;
logic                       read_latency_cpl;   // read latency complete
logic                       wait_read_data;
logic                       cmd_is_read_a;


/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

// ----------------------------------------------
// Input and Output Register for the system bus
// ----------------------------------------------

// Register the bus input
always_ff @(posedge clk) begin
    if (!rst_n) begin
        bus_req_read_q   <= 1'b0;
        bus_req_write_q  <= 1'b0;
    end
    else begin
        if (bus_req_act) begin
            bus_req_read_q   <= bus_req_read;
            bus_req_write_q  <= bus_req_write;
        end
        else if (int_bus_cpl) begin
            bus_req_read_q   <= 1'b0;
            bus_req_write_q  <= 1'b0;
        end
    end
end

always_ff @(posedge clk) begin
    if (bus_req_act) begin
        bus_req_addr_q       <= bus_req_addr;
        bus_req_wdata_q      <= bus_req_wdata;
        bus_req_byteenable_q <= bus_req_byteenable;
    end
end

// Register bus output
always_ff @(posedge clk) begin
    if (!rst_n) begin
        bus_rsp_valid <= 1'b0;
    end
    else begin
        bus_rsp_valid <= bus_rsp_valid_next;
    end
end

always_ff @(posedge clk) begin
   bus_rsp_rdata <= bus_rsp_rdata_next;
end

// Write request finishes immediately as long as the SDRAM controller is not busy.
// Read request need wait till before the read data is available.
assign bus_req_ready = (bus_req_write & ~int_busy) | (bus_req_read & bus_rsp_valid_next);

// ----------------------------------------------
// Main state machine
// ----------------------------------------------

assign s_RESET        = (sdram_state == SDRAM_RESET);
assign s_INIT         = (sdram_state == SDRAM_INIT);
assign s_IDLE         = (sdram_state == SDRAM_IDLE);
assign s_ROW_ACTIVE   = (sdram_state == SDRAM_ROW_ACTIVE);
assign s_WRITE_A      = (sdram_state == SDRAM_WRITE_A);
assign s_READ_A       = (sdram_state == SDRAM_READ_A);
assign s_AUTO_REFRESH = (sdram_state == SDRAM_AUTO_REFRESH);

// RESET -> INIT: Start SDRAM initialization sequence once coming out of reset
assign arc_RESET_to_INIT = s_RESET;

// INIT -> IDLE: Initialization complete
assign arc_INIT_to_IDLE = s_INIT & (init_state == INIT_DONE);

// IDLE -> ROW_ACTIVE
assign arc_IDLE_to_ROW_ACTIVE = s_IDLE & ~refresh_req & int_bus_req;
// IDLE -> AUTO_REFRESH
assign arc_IDLE_to_AUTO_REFRESH = s_IDLE & refresh_req;

// ROW ACTIVE -> WRITE_A
assign arc_ROW_ACTIVE_to_WRITE_A = s_ROW_ACTIVE & cmd_cpl & bus_req_write_q;
// ROW ACTIVE -> READ_A
assign arc_ROW_ACTIVE_to_READ_A = s_ROW_ACTIVE & cmd_cpl & bus_req_read_q;

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
        sdram_state <= sdram_state_next;
    end
end

always_comb begin
    case(1)
        arc_RESET_to_INIT:                  sdram_state_next = SDRAM_INIT;
        arc_INIT_to_IDLE:                   sdram_state_next = SDRAM_IDLE;
        arc_IDLE_to_ROW_ACTIVE:             sdram_state_next = SDRAM_ROW_ACTIVE;
        arc_IDLE_to_AUTO_REFRESH:           sdram_state_next = SDRAM_AUTO_REFRESH;
        arc_ROW_ACTIVE_to_WRITE_A:          sdram_state_next = SDRAM_WRITE_A;
        arc_ROW_ACTIVE_to_READ_A:           sdram_state_next = SDRAM_READ_A;
        arc_WRITE_A_to_IDLE:                sdram_state_next = SDRAM_IDLE;
        arc_READ_A_to_IDLE:                 sdram_state_next = SDRAM_IDLE;
        arc_AUTO_REFRESH_to_IDLE:           sdram_state_next = SDRAM_IDLE;
        arc_AUTO_REFRESH_to_ROW_ACTIVE:     sdram_state_next = SDRAM_ROW_ACTIVE;
        default:                            sdram_state_next = sdram_state;
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
        init_state <= init_state_next;
    end
end

always_comb begin
    init_state_next = init_state;
    case(init_state)
        INIT_IDLE: begin
            if (arc_RESET_to_INIT) init_state_next = INIT_WAIT;
        end
        INIT_WAIT: begin
            if (init_wait_cpl) init_state_next = INIT_PRECHARGE;
        end
        INIT_PRECHARGE: begin
            if (cmd_cpl) init_state_next = INIT_AUTO_REF0;
        end
        INIT_AUTO_REF0: begin
            if (cmd_cpl) init_state_next = INIT_AUTO_REF1;
        end
        INIT_AUTO_REF1: begin
            if (cmd_cpl) init_state_next = INIT_SET_MODE_REG;
        end
        INIT_SET_MODE_REG: begin
            if (cmd_cpl) init_state_next = INIT_DONE;
        end
        INIT_DONE: begin
            init_state_next = INIT_DONE;
        end
        default: init_state_next = init_state;
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

assign ir_cpl = ir_cnt == 0;
assign init_wait_cpl = ir_cpl;
assign refresh_req = ir_cpl;

// ----------------------------------------------
// cmd counter
// ----------------------------------------------
// A SDRAM command is usually the command itself followed by several NOP command to meet sdram timing.
// The cmd counter count number of cycle (CMD + NOP) the command need to complete.
always_ff @(posedge clk) begin
    if (!rst_n) begin
        cmd_cnt <= 'b0;
    end
    else begin
        // load the counter when a new command is issue. otherwise decrease the counter till it reach 0.
        case(sdram_cmd)
            CMD_PRECHARGE: cmd_cnt <= cRP [CMD_CNT_WIDTH-1:0] - 1'b1;
            CMD_REFRESH:   cmd_cnt <= cRFC[CMD_CNT_WIDTH-1:0] - 1'b1;
            CMD_LMR:       cmd_cnt <= cMRD[CMD_CNT_WIDTH-1:0] - 1'b1;
            CMD_ACTIVE:    cmd_cnt <= cRCD[CMD_CNT_WIDTH-1:0] - 1'b1;
            CMD_WRITE:     cmd_cnt <= cWR [CMD_CNT_WIDTH-1:0] + cRP[CMD_CNT_WIDTH-1:0] - 1'b1;
            CMD_READ:      cmd_cnt <= cfg_cas_latency + 1'b1  + cRP[CMD_CNT_WIDTH-1:0] - 1'b1;
            default:       if (cmd_cnt > 0) cmd_cnt <= cmd_cnt - 1'b1;
        endcase
    end
end

assign cmd_cpl = cmd_cnt == 0;
assign pre_cmd_cpl = cmd_cnt == 1;

// ----------------------------------------------
// CAS Latency counter
// ----------------------------------------------

assign cmd_is_read_a = sdram_cmd == CMD_READ;
assign read_latency = cfg_cas_latency[1:0];
assign read_latency_cpl = read_latency_cnt == 'b0;

// Check when read data is available
always_ff @(posedge clk) begin
    if (!rst_n) begin
        read_latency_cnt <= 'b0;
        wait_read_data <= 1'b0;
    end
    else begin
        if (cmd_is_read_a)          read_latency_cnt <= read_latency;
        else if (!read_latency_cpl) read_latency_cnt <= read_latency_cnt - 1'b1;

        if (cmd_is_read_a)         wait_read_data <= 1'b1;
        else if (read_latency_cpl) wait_read_data <= 1'b0;
    end
end

// ----------------------------------------------
// SDRAM State Machine Output Function Logic
// ----------------------------------------------

assign bus_req_act = (bus_req_read | bus_req_write) & ~int_busy;
assign int_bus_req = bus_req_read_q | bus_req_write_q;

assign bus_rsp_valid_next = wait_read_data & (read_latency_cnt == 0);
assign bus_rsp_rdata_next = sdram_dq;

// System address to SDRAM mapping:
assign {bank, row, col} = bus_req_addr_q[AW-1:BW];

assign sdram_cs_n_next  = sdram_cmd[3];
assign sdram_ras_n_next = sdram_cmd[2];
assign sdram_cas_n_next = sdram_cmd[1];
assign sdram_we_n_next  = sdram_cmd[0];

// Column address
generate
if (CAW > 10) begin
    assign sdram_addr_col[9:0]        = col[9:0];
    assign sdram_addr_col[10]         = 1'b0;
    assign sdram_addr_col[CAW-1+1:11] = col[CAW-1:10];
end
else begin
    assign sdram_addr_col[CAW-1:0]   = col;
    assign sdram_addr_col[RAW-1:CAW] = 'b0;
end
endgenerate

always_ff @(posedge clk) begin
    if (!rst_n) begin
        int_busy <= 1'b1;
    end
    else begin
        int_busy <= int_busy_next;
    end
end

always_comb begin

    sdram_cmd       = CMD_NOP;
    sdram_cke_next  = 'b1;
    sdram_addr_next = 'b0;
    sdram_ba_next   = 'b0;
    sdram_dqm_next  = 'b0;
    sdram_dq_out_next = 'b0;
    sdram_dq_out_en_next = 'b0;

    int_bus_cpl = 1'b0;
    int_busy_next = bus_req_act | int_bus_req;

    case(sdram_state)

        SDRAM_RESET: begin
            int_busy_next = 1'b1;
        end

        SDRAM_INIT: begin
            int_busy_next = 1'b1;
            case(init_state)
                INIT_IDLE: begin
                    if (arc_RESET_to_INIT) sdram_cmd = CMD_DESL;
                end
                INIT_WAIT: begin
                    sdram_cmd = CMD_DESL;
                    if (init_wait_cpl) begin
                        sdram_cmd = CMD_PRECHARGE;
                        sdram_addr_next[10] = 1'b1;
                    end
                end
                INIT_PRECHARGE: begin
                    if (cmd_cpl) begin
                        sdram_cmd = CMD_REFRESH;
                    end
                end
                INIT_AUTO_REF0: begin
                    if (cmd_cpl) begin
                        sdram_cmd = CMD_REFRESH;
                    end
                end
                INIT_AUTO_REF1: begin
                    // going to SET_MODE_REG state: scheduling Set Mode Register command
                    if (cmd_cpl) begin
                        sdram_cmd = CMD_LMR;
                        sdram_addr_next      = 0;
                        sdram_addr_next[2:0] = cfg_burst_length;
                        sdram_addr_next[3]   = cfg_burst_type;
                        sdram_addr_next[6:4] = cfg_cas_latency;
                        sdram_addr_next[9]   = cfg_burst_mode;
                    end
                end
                default:  ;
            endcase
        end

        SDRAM_IDLE: begin
            // going to AUTO_REFRESH state: scheduling Auto Refresh command
            if (arc_IDLE_to_AUTO_REFRESH) begin
                sdram_cmd = CMD_REFRESH;
            end
            // going to ROW_ACTIVE state: scheduling ACTIVE command
            else if (arc_IDLE_to_ROW_ACTIVE) begin
                sdram_cmd = CMD_ACTIVE;
                sdram_ba_next = bank;
                sdram_addr_next = row;
            end
        end

        SDRAM_ROW_ACTIVE: begin
            if (arc_ROW_ACTIVE_to_WRITE_A) begin
                sdram_cmd = CMD_WRITE;
                sdram_addr_next = {sdram_addr_col[RAW-1:11], 1'b1, sdram_addr_col[9:0]};
                sdram_ba_next = bank;
                sdram_dqm_next = ~bus_req_byteenable_q;
                sdram_dq_out_next = bus_req_wdata_q;
                sdram_dq_out_en_next = 1'b1;
            end
            else if (arc_ROW_ACTIVE_to_READ_A) begin
                sdram_cmd = CMD_READ;
                sdram_addr_next = {sdram_addr_col[RAW-1:11], 1'b1, sdram_addr_col[9:0]};
                sdram_ba_next = bank;
                sdram_dqm_next = ~bus_req_byteenable_q;
            end
        end

        SDRAM_WRITE_A: begin
            int_bus_cpl = cmd_cpl;
            int_busy_next = ~pre_cmd_cpl;
        end

        SDRAM_READ_A: begin
            int_bus_cpl = cmd_cpl;
            int_busy_next = ~pre_cmd_cpl;
        end

        SDRAM_AUTO_REFRESH: begin
            // Auto refresh complete but request pending. Going to ROW_ACTIVE state
            if (arc_AUTO_REFRESH_to_ROW_ACTIVE) begin
                sdram_cmd = CMD_ACTIVE;
                sdram_ba_next = bank;
                sdram_addr_next = row;
            end
        end
        default: ;
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
        sdram_dq_out  <= 'b0;
        sdram_dq_out_en <= 'b0;
    end
    else begin
        sdram_cke   <= sdram_cke_next;
        sdram_cs_n  <= sdram_cs_n_next;
        sdram_ras_n <= sdram_ras_n_next;
        sdram_cas_n <= sdram_cas_n_next;
        sdram_we_n  <= sdram_we_n_next;
        sdram_addr  <= sdram_addr_next;
        sdram_ba    <= sdram_ba_next;
        sdram_dqm   <= sdram_dqm_next;
        sdram_dq_out <= sdram_dq_out_next;
        sdram_dq_out_en <= sdram_dq_out_en_next;
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

// Showing state in STRING
logic [95:0] sdram_state_str;
always_comb begin
    case (sdram_state)
        SDRAM_RESET:        sdram_state_str = "RESET     ";
        SDRAM_INIT:         sdram_state_str = "INIT      ";
        SDRAM_IDLE:         sdram_state_str = "IDLE      ";
        SDRAM_ROW_ACTIVE:   sdram_state_str = "ROW_ACTIVE";
        SDRAM_WRITE_A:      sdram_state_str = "WRITE_A   ";
        SDRAM_READ_A:       sdram_state_str = "READ_A    ";
        SDRAM_AUTO_REFRESH: sdram_state_str = "AUTO_REFRESH";
        default:            sdram_state_str = "UNKNOWN   ";
    endcase
end

`endif

endmodule
