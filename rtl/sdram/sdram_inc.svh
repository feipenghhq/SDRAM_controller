// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/26/2025
//
// -------------------------------------------------------------------
// Include File
// -------------------------------------------------------------------

`default_nettype none

`ifndef __SDRAM_INC_H__
`define __SDRAM_INC_H__

// SDRAM command
`define CMD_DESL       4'b1111
`define CMD_NOP        4'b0111
`define CMD_ACTIVE     4'b0011
`define CMD_READ       4'b0101
`define CMD_WRITE      4'b0100
`define CMD_PRECHARGE  4'b0010
`define CMD_REFRESH    4'b0001
`define CMD_LMR        4'b0000

// Ceil division
`define SDRAM_CEIL_DIV(a, b) ((a) + (b) - 1) / (b)

`endif
