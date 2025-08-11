# Makefile

REPO = $(shell git rev-parse --show-toplevel)

# defaults
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
#WAVES = 1

VERILOG_SOURCES += $(REPO)/rtl/sdram/sdram_controller.sv
VERILOG_SOURCES += $(REPO)/sim/cocotb/tb/tb_sdram_controller.sv
VERILOG_SOURCES += $(REPO)/sim/cocotb/model/MT48LC8M16A2.v

COMPILE_ARGS += -D SIMULATION=1

FREQ ?= 133
COMPILE_ARGS += -D CLK_FREQ=$(FREQ)

# TOPLEVEL is the name of the toplevel module in your Verilog or VHDL file
TOPLEVEL = tb_sdram_controller

# MODULE is the basename of the Python test file
MODULE = test_basic

# include cocotb's make rules to take care of the simulator setup
include $(shell cocotb-config --makefiles)/Makefile.sim

lint:
	verilator --lint-only -Wall $(RTL_SOURCES) --top-module sdram_controller

waveform:
	gtkwave sim_build/$(TOPLEVEL).fst wave.gtkw &