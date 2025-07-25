
GIT_ROOT 	= $(shell git rev-parse --show-toplevel)
SCRIPT_DIR 	= $(GIT_ROOT)/scripts/quartus

# device part
PART = EP4CE115F29C8
# device family
FAMILY = "Cyclone IV E"
# project name
PROJECT ?= sdram
# top level name
TOP ?= top
# verilog source files
VERILOG += $(GIT_ROOT)/rtl/sdram/sdram_controller.sv
VERILOG += $(GIT_ROOT)/rtl/chip/sdram_IS42S16320D.sv
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/vjtag_ctrl.sv
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/vjtag_ip.v
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/vjtag_host.sv
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/pll_25.v
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/pll_50.v
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/pll_100.v
VERILOG += $(GIT_ROOT)/fpga/de2-115/rtl/pll_130.v
VERILOG += $(GIT_ROOT)/fpga/de2-115/top.sv
# verilog include directory
SEARCH ?=
# verilog define
DEFINE ?=
# sdc files
SDC	?= $(PWD)/timing.sdc
# pin assignment files
PIN ?= $(PWD)/pin.tcl
# project output directory
OUT_DIR ?= outputs

include $(GIT_ROOT)/scripts/quartus/makefile.mk
