
GIT_ROOT 	= $(shell git rev-parse --show-toplevel)
SCRIPT_DIR 	= $(GIT_ROOT)/scripts/quartus

# device part
PART = EP2C35F672C7
# device family
FAMILY = Cyclone II
# project name
PROJECT ?= sdram
# top level name
TOP ?= top
# verilog source files
VERILOG += $(GIT_ROOT)/rtl/sdram/sdram_controller.sv
VERILOG += $(GIT_ROOT)/rtl/chip/sdram_IS42S16400.sv
VERILOG += $(GIT_ROOT)/fpga/de2/rtl/vjtag_host/vjtag_ctrl.sv
VERILOG += $(GIT_ROOT)/fpga/de2/rtl/vjtag_host/vjtag_ip.v
VERILOG += $(GIT_ROOT)/fpga/de2/rtl/vjtag_host/vjtag_host.sv
VERILOG += $(GIT_ROOT)/fpga/de2/top.sv
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
