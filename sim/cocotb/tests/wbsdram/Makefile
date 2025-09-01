# Makefile

REPO = $(shell git rev-parse --show-toplevel)

TOPLEVEL = tb_wbsdram

TOPLEVEL_LANG 	?= verilog
SIM 			?= icarus
MODULE 			?= cocotb_basic_test

CLK_FREQ 		?= 50
WAVES 			?= 0

VERILOG_SOURCES += $(REPO)/rtl/sdram/sdram_controller.sv
VERILOG_SOURCES += $(REPO)/rtl/sdram/sdram_cmd.sv
VERILOG_SOURCES += $(REPO)/rtl/sdram/sdram_init.sv
VERILOG_SOURCES += $(REPO)/rtl/sdram/sdram_ctrl.sv
VERILOG_SOURCES += $(REPO)/rtl/wbsdram/wbsdram.sv
VERILOG_SOURCES += $(REPO)/sim/cocotb/tb/tb_wbsdram.sv
VERILOG_SOURCES += $(REPO)/sim/cocotb/model/MT48LC8M16A2.v

VERILOG_INCLUDE_DIRS += $(REPO)/rtl/sdram

COMPILE_ARGS    += -D SIMULATION=1
COMPILE_ARGS    += -P tb_sdram_controller.CLK_FREQ=$(CLK_FREQ)

sim: clean
include $(shell cocotb-config --makefiles)/Makefile.sim

# ------------------------------------------------
# MISC
# ------------------------------------------------

waveform:
	gtkwave sim_build/$(TOPLEVEL).fst waveform.gtkw &

clean::
	rm -r -f .pytest_cache cocotb.log results.xml
