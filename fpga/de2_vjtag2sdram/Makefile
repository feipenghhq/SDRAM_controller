
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
VERILOG += $(GIT_ROOT)/rtl/sdram/sdram_init.sv
VERILOG += $(GIT_ROOT)/rtl/sdram/sdram_cmd.sv
VERILOG += $(GIT_ROOT)/rtl/sdram/sdram_ctrl.sv
VERILOG += $(GIT_ROOT)/rtl/wbsdram/wbsdram.sv
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/pll/altpll_25.v
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/pll/altpll_50.v
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/pll/altpll_100.v
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/pll/altpll_130.v
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/pll/altpll_top.v
VERILOG += $(GIT_ROOT)/rtl/fpga_examples/vjtag2sdram/fpga_vjtag2sdram.sv
VERILOG += $(GIT_ROOT)/ip/Altera-VJTAG-Host/rtl/vjtag/vjtag_ctrl.sv
VERILOG += $(GIT_ROOT)/ip/Altera-VJTAG-Host/rtl/vjtag/vjtag_ip.v
VERILOG += $(GIT_ROOT)/ip/Altera-VJTAG-Host/rtl/vjtag/vjtag2wb.sv
VERILOG += $(GIT_ROOT)/fpga/de2_vjtag2sdram/top.sv
# verilog include directory
SEARCH += $(GIT_ROOT)/rtl/sdram
# verilog define
DEFINE ?=
# sdc files
SDC	?= $(PWD)/timing.sdc
# pin assignment files
PIN ?= $(PWD)/pin.tcl
# project output directory
OUT_DIR ?= outputs

include $(GIT_ROOT)/scripts/quartus/makefile.mk
