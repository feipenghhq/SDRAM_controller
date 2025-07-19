# Makefile

REPO = $(shell git rev-parse --show-toplevel)

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
WAVES = 1

VERILOG_SOURCES += $(shell find $(REPO)/rtl -name "*.sv")
VERILOG_SOURCES += MT48LC8M16A2.v
VERILOG_SOURCES += tb_top.sv
VERILOG_INCLUDE_DIRS += $(shell dirname $(shell find $(REPO)/rtl -name "*.svh"))

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb_top

# MODULE is the basename of the Python test file
MODULE = test_basic

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim