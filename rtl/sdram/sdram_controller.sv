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
// Other Features:
//     1. system bus input are registered for better timing
//     2. system bus output are registered for better timing
// -------------------------------------------------------------------



module sdram_controller #(
    // global parameter
    parameter AW = 24,          // Bus Address width. Should match with SDRAM size
    parameter DW = 16,          // Bus Data width
    parameter CLK_FREQ = 100,   // (MHz) clock frequency

    // sdram parameter
    parameter RAW = 12,         // Row address width
    parameter CAW = 9,          // Column address width

    // sdram timing parameter
    parameter tRAS = 42,        // (ns) ACTIVE-to-PRECHARGE command
    parameter tRC  = 60,        // (ns) ACTIVE-to-ACTIVE command period
    parameter tRCD = 18,        // (ns) ACTIVE-to-READ or WRITE delay
    parameter tREF = 64,        // (ms) Refresh Period
    parameter tRFC = 60,        // (ns) AUTO REFRESH period
    parameter tRP  = 18,        // (ns) PRECHARGE command period
    parameter tRRD = 20,        // (ns) ACTIVE bank a to ACTIVE bank b command
    parameter tWR  = 20,        // (ns) WRITE recovery time (WRITE completion to PRECHARGE period)
    parameter cMRD = 3,         // (cycle) LOAD MODE REGISTER command to ACTIVE or REFRESH command
    // TBD, FIXME
    //parameter tSRX = 10,        // (ns) Self refresh exit time

    // sdram initialization sequence
    parameter INIT_TIME = 200   // (us) initialization NOP time
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
    output logic            sdram_cke,              // Clock Enable. CKE is high active.
    output logic            sdram_cs_n,             // Chip Select: CSn enables and disables command decoder.
    output logic            sdram_ras_n,            // Row Address Select.
    output logic            sdram_cas_n,            // Column Address Select.
    output logic            sdram_we_n,             // Write Enable.
    output logic [RAW-1:0]  sdram_addr,             // Address for row/column addressing.
    output logic [1:0]      sdram_ba,               // Bank Address. Fixed for 4 banks
    output logic [DW/8-1:0] sdram_dqm,              // Data Mask
    inout  wire  [DW-1:0]   sdram_dq                // Data Input/Output bus.

);

/////////////////////////////////////////////////
// Local Parameter and macro
/////////////////////////////////////////////////

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

// roundup division
`define ceil_div(a, b)  ((a + b - 1) / b)
// max
`define max(a, b)       ((a > b) ? a : b)

// Calculate the SDRAM timing in terms of number of clock cycle
localparam cRAS = `ceil_div(tRAS * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE-to-PRECHARGE command
localparam cRC  = `ceil_div(tRC  * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE-to-ACTIVE command period
localparam cRCD = `ceil_div(tRCD * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE-to-READ or WRITE delay
localparam cRFC = `ceil_div(tRFC * CLK_FREQ, 1000);     // (CLK Cycle) AUTO REFRESH period
localparam cRP  = `ceil_div(tRP  * CLK_FREQ, 1000);     // (CLK Cycle) PRECHARGE command period
localparam cRRD = `ceil_div(tRRD * CLK_FREQ, 1000);     // (CLK Cycle) ACTIVE bank a to ACTIVE bank b command
localparam cWR  = `ceil_div(tWR  * CLK_FREQ, 1000);     // (CLK Cycle) WRITE recovery time (WRITE completion to PRECHARGE period)
localparam cR2P = `ceil_div((tRAS-tRCD) * CLK_FREQ, 1000);  // (CLK_CYCLE) READ-to-PRECHARGE Command

// Initialization cycle and counter width
localparam INIT_NOP_CYCLE = 200 * CLK_FREQ;
localparam INIT_CNT_WIDTH = $clog2(INIT_NOP_CYCLE);

// Refresh counter threshold
localparam REFRESH_INTERVAL = (tREF * 1000 * CLK_FREQ / (2**RAW));

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
    PRECHARGE,          // Precharge the bank
    AUTO_REFRESH        // Auto Refresh
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

// main state machine
sdram_main_state_t          main_state, main_state_n;

logic                       s_is_reset;
logic                       s_is_init;
logic                       s_is_mode_reg_set;
logic                       s_is_idle;
logic                       s_is_row_active;
logic                       s_is_write;
logic                       s_is_write_a;
logic                       s_is_read;
logic                       s_is_read_a;
logic                       s_is_precharge;
logic                       s_is_auto_refresh;

logic                       arc_reset_2_init;
logic                       arc_init_2_idle;
logic                       arc_idle_2_row_active;
logic                       arc_idle_2_auto_refresh;
logic                       arc_row_active_2_write_a;
logic                       arc_row_active_2_read_a;
logic                       arc_write_a_2_precharge;
logic                       arc_read_a_2_precharge;
logic                       arc_precharge_2_idle;
logic                       arc_auto_refresh_2_idle;
logic                       arc_auto_refresh_2_row_active;

// init state machine
sdram_init_state_t          init_state, init_state_n;

// registered system bus (can be registered or not depending on the parameter)
logic                       bus_read_q;
logic                       bus_write_q;
logic [AW-1:0]              bus_addr_q;

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

logic                       bus_req;            // bus request pending
logic                       bus_req_cpl;            // bus request completion

// Address mapping
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
logic [DW-1:0]              sdram_dqo;          // registered version of int_sdram_dqp

// initialization/refresh counter
logic [INIT_CNT_WIDTH-1:0]  ir_cnt;
logic                       ir_cnt_zero;        // counter reach zero

// command period counter and state indicator
logic [CMD_CNT_WIDTH-1:0]   cmd_cnt;
logic                       cmd_cpl;            // indicate that a cmd has been complete
logic                       cmd_is_precharge;
logic                       cmd_is_lmr;         // load mode register
logic                       cmd_is_refresh;
logic                       cmd_is_active;
logic                       cmd_is_write;
logic                       cmd_is_read;
logic [CMD_CNT_WIDTH-1:0]   read_to_precharge_cyc;  // read to precharge cycle

// CL counter to indicate read data ready
logic [1:0]                 cas_cnt;
logic                       wait_rdata;         // read request issue, waiting for read data

/////////////////////////////////////////////////
// Main logic
/////////////////////////////////////////////////

// ----------------------------------------------
// Handling system bus
// ----------------------------------------------

assign bus_req = (bus_read | bus_write) & bus_ready;

// Register Input
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
        else if (bus_req_cpl) begin
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

// Register Bus Output
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

// state assignment
assign s_is_reset        = (main_state == RESET);
assign s_is_init         = (main_state == INIT);
assign s_is_mode_reg_set = (main_state == MODE_REG_SET);
assign s_is_idle         = (main_state == IDLE);
assign s_is_row_active   = (main_state == ROW_ACTIVE);
assign s_is_write        = (main_state == WRITE);
assign s_is_write_a      = (main_state == WRITE_A);
assign s_is_read         = (main_state == READ);
assign s_is_read_a       = (main_state == READ_A);
assign s_is_precharge    = (main_state == PRECHARGE);
assign s_is_auto_refresh = (main_state == AUTO_REFRESH);

// state transaction arc

// RESET -> INIT: Start SDRAM initialization sequence once coming out of reset
assign arc_reset_2_init = s_is_reset;
// INIT -> IDLE: Initialization complete
assign arc_init_2_idle = s_is_init & (init_state == INIT_DONE);
// IDLE -> ROW_ACTIVE: Get a new Bus request
assign arc_idle_2_row_active = s_is_idle & (int_bus_read | int_bus_write);
// IDLE -> AUTO_REFRESH
assign arc_idle_2_auto_refresh = s_is_idle & ir_cnt_zero;
// ROW ACTIVE -> WRITE_A
assign arc_row_active_2_write_a = s_is_row_active & cmd_cpl & int_bus_write;
// ROW ACTIVE -> READ_A
assign arc_row_active_2_read_a = s_is_row_active & cmd_cpl & int_bus_read;
// WRITE_A -> PRECHARGE: Complete write operation and wait tWR
assign arc_write_a_2_precharge = s_is_write_a & cmd_cpl;
// READ_A -> PRECHARGE: Complete read operation and wait time (read_to_precharge_cyc)
assign arc_read_a_2_precharge = s_is_read_a & cmd_cpl;
// PRECHARGE -> IDLE: Complete the precharge operation
assign arc_precharge_2_idle = s_is_precharge & cmd_cpl;
// AUTO_REFRESH -> IDLE: Complete the auto refresh operation and no request pending
assign arc_auto_refresh_2_idle = s_is_auto_refresh & cmd_cpl & ~(int_bus_write | int_bus_read);
// AUTO_REFRESH -> IDLE: Complete the auto refresh operation but request pending
assign arc_auto_refresh_2_row_active = s_is_auto_refresh & cmd_cpl & (int_bus_write | int_bus_read);

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
        arc_reset_2_init:               main_state_n = INIT;
        arc_init_2_idle:                main_state_n = IDLE;
        arc_idle_2_row_active:          main_state_n = ROW_ACTIVE;
        arc_idle_2_auto_refresh:        main_state_n = AUTO_REFRESH;
        arc_row_active_2_write_a:       main_state_n = WRITE_A;
        arc_row_active_2_read_a:        main_state_n = READ_A;
        arc_write_a_2_precharge:        main_state_n = PRECHARGE;
        arc_read_a_2_precharge:         main_state_n = PRECHARGE;
        arc_precharge_2_idle:           main_state_n = IDLE;
        arc_auto_refresh_2_idle:        main_state_n = IDLE;
        arc_auto_refresh_2_row_active:  main_state_n = ROW_ACTIVE;
        default:                        main_state_n = main_state;
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
            if (arc_reset_2_init) init_state_n = INIT_WAIT;
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
        if (arc_reset_2_init)  ir_cnt <= INIT_NOP_CYCLE;
        else if (arc_init_2_idle || arc_idle_2_auto_refresh) ir_cnt <= REFRESH_INTERVAL;
        else if (ir_cnt > 0)   ir_cnt <= ir_cnt - 1'b1;
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
            cmd_is_active:    cmd_cnt <= cRCD[CMD_CNT_WIDTH-1:0];
            cmd_is_write:     cmd_cnt <= cWR [CMD_CNT_WIDTH-1:0];
            cmd_is_read:      cmd_cnt <= read_to_precharge_cyc;
            default: if (cmd_cnt > 0) cmd_cnt <= cmd_cnt - 1'b1;
        endcase
    end
end

assign cmd_cpl = cmd_cnt == 0;

// Note for READ with Auto Precharge:
// From SPEC: If auto precharge is enabled, the row being accessed is pre-charged at the completion of the burst.
// This means that if read burst complete (last data present) at T, then precharge command should be issued at T-tRP.
// For a Single READ with Auto Precharge operation, Precharge should be issue after meeting tRAS requirement.
// For now, since we only support a single read, we should goto PRECHARGE state when meeting the above 2 requirement.
// which is the maximum of CAS latency and tRAS - tRCD
assign read_to_precharge_cyc = `max(cfg_cas_latency, cR2P[CMD_CNT_WIDTH-1:0]);

// ----------------------------------------------
// CAS Latency counter
// ----------------------------------------------
// Check when read data is available
always_ff @(posedge clk) begin
    if (!rst_n) begin
        cas_cnt <= 'b0;
        wait_rdata <= 1'b0;
    end
    else begin
        if (cmd_is_read) begin
            cas_cnt <= cfg_cas_latency[1:0];
            wait_rdata <= 1'b1;
        end
        else if (cas_cnt != 0) begin
            cas_cnt <= cas_cnt - 1'b1;
        end
        else if (cas_cnt == 0) begin
            wait_rdata <= 1'b0;
        end
    end
end

// ----------------------------------------------
// SDRAM State Machine Output Function Logic
// ----------------------------------------------

// Decode the bus address to sdram bank, row, col
assign {bank, row, col} = int_bus_addr[AW-1:BW];

assign int_bus_rvalid  = wait_rdata & (cas_cnt == 0);
assign int_bus_rdata   = sdram_dq;

// Micro to assign the control signal given a operation
`define cmd(op) {int_sdram_cs_n, int_sdram_ras_n, int_sdram_cas_n, int_sdram_we_n} = op

always_comb begin

    int_sdram_cke   = 'b1;      // default CLK = high
    int_sdram_cs_n  = 'b0;      // default NOP command
    int_sdram_ras_n = 'b1;
    int_sdram_cas_n = 'b1;
    int_sdram_we_n  = 'b1;
    int_sdram_addr  = 'b0;
    int_sdram_ba    = 'b0;
    int_sdram_dqm   = 'b0;
    int_sdram_dqo   = 'b0;

    int_bus_ready   = 1'b0;
    bus_req_cpl     = 1'b0;

    cmd_is_precharge = 1'b0;
    cmd_is_refresh   = 1'b0;
    cmd_is_lmr       = 1'b0;
    cmd_is_active    = 1'b0;
    cmd_is_write     = 1'b0;
    cmd_is_read      = 1'b0;
    cmd_is_precharge = 1'b0;

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
                        cmd_is_precharge = 1'b1;
                        int_sdram_addr[10] = 1'b1;    // precharge all bank
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
                        int_sdram_addr[2:0] = cfg_burst_length;
                        int_sdram_addr[3]   = cfg_burst_type;
                        int_sdram_addr[6:4] = cfg_cas_latency;
                        int_sdram_addr[8:7] = 2'b0;
                        int_sdram_addr[9]   = cfg_burst_mode;
                        int_sdram_addr[RAW-1:10] = 'b0;
                    end
                end
                INIT_DONE: begin
                    `cmd(CMD_NOP);
                end
                default: `cmd(CMD_NOP);
            endcase
        end

        // IDLE state
        IDLE: begin
            `cmd(CMD_NOP);
            bus_req_cpl = 1'b1;
            // Logic need to consider one extra latency of bus_ready because we flop it before sending it out
            // 1. Set int_bus_ready = 1 when we are about to enter IDLE state
            // 2. Set int_bus_ready = 0 when we get taking a new request in IDLE state
            // OPT: This can be further optimized, we can register the bus request at PRECHARGE stage
            //      and go ROW_ACTIVE stage directly after completing PRECHARGE
            if (arc_precharge_2_idle || arc_auto_refresh_2_idle) int_bus_ready = 1'b1;
            //if (main_state != IDLE) int_bus_ready = 1'b1;
            else                    int_bus_ready = ~(bus_read | bus_write);
        end

        // ROW_ACTIVE state
        ROW_ACTIVE: begin
            if (main_state != ROW_ACTIVE) begin    // active a row
                `cmd(CMD_ACTIVE);
                cmd_is_active = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr = row;
            end
        end

        // WRITE_A State
        WRITE_A: begin
            if (arc_row_active_2_write_a) begin
                `cmd(CMD_WRITE);
                cmd_is_write = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr[CAW-1:0] = col;
                int_sdram_dqm = ~int_bus_byteenable;
                int_sdram_dqo = int_bus_wdata;
            end
        end

        // READ_A State
        READ_A: begin
            if (arc_row_active_2_read_a) begin
                `cmd(CMD_READ);
                cmd_is_read = 1'b1;
                int_sdram_ba = bank;
                int_sdram_addr[CAW-1:0] = col;
                int_sdram_dqm = ~int_bus_byteenable;
            end
        end

        // PRECHARGE
        PRECHARGE: begin
            if (main_state != PRECHARGE) begin
                `cmd(CMD_PRECHARGE);
                cmd_is_precharge = 1'b1;
                int_sdram_addr[10] = 1'b1;    // precharge all bank.
            end
        end

        // AUTO_REFRESH
        AUTO_REFRESH: begin
            if (arc_idle_2_auto_refresh) begin
                `cmd(CMD_REFRESH);      // auto-refresh (cke=1)
                cmd_is_refresh = 1'b1;
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
    end
end

assign sdram_dq = (sdram_we_n == 0) ? sdram_dqo : {DW{1'bz}};

/////////////////////////////////////////////////
// SIMULATION
/////////////////////////////////////////////////

`ifdef SIMULATION

// Showing state in STRING
logic [95:0] main_state_str;
always_comb begin
    case (main_state)
        RESET:        main_state_str = "RESET     ";
        INIT:         main_state_str = "INIT      ";
        MODE_REG_SET: main_state_str = "MODE_REG  ";
        IDLE:         main_state_str = "IDLE      ";
        ROW_ACTIVE:   main_state_str = "ROW_ACTIVE";
        WRITE:        main_state_str = "WRITE     ";
        WRITE_A:      main_state_str = "WRITE_A   ";
        READ:         main_state_str = "READ      ";
        READ_A:       main_state_str = "READ_A    ";
        PRECHARGE:    main_state_str = "PRECHARGE ";
        AUTO_REFRESH: main_state_str = "AUTO_REFRESH";
        default:      main_state_str = "UNKNOWN   ";
    endcase
end

`endif

endmodule
