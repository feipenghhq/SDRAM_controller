#########################################################
# Makefile for quartus flow
#########################################################

#########################################################
# Common variable
#########################################################

GIT_ROOT 	= $(shell git rev-parse --show-toplevel)
SCRIPT_DIR 	= $(GIT_ROOT)/scripts/quartus

#########################################################
# Project specific variable
#########################################################

# device part
PART ?=
# device family
FAMILY ?=
# project name
PROJECT ?=
# top level name
TOP ?=
# verilog source files
VERILOG ?=
# verilog define
DEFINE ?=
# sdc files
SDC	?=
# pin assignment files
PIN ?=
# project output directory
OUT_DIR ?= outputs


export QUARTUS_PART 	= $(PART)
export QUARTUS_FAMILY 	= $(FAMILY)
export QUARTUS_PRJ 		= $(PROJECT)
export QUARTUS_TOP    	= $(TOP)
export QUARTUS_VERILOG  = $(VERILOG)
export QUARTUS_SEARCH   = $(SEARCH)
export QUARTUS_SDC		= $(SDC)
export QUARTUS_QIP		= $(QIP)
export QUARTUS_PIN		= $(PIN)
export QUARTUS_DEFINE	= $(DEFINE)

SOF = $(OUT_DIR)/$(PROJECT).sof

#########################################################
# Build process
#########################################################

build: sof
sof: $(SOF)

$(OUT_DIR):
	mkdir -p $(OUT_DIR)

$(SOF): $(OUT_DIR)
	cd $(OUT_DIR) && quartus_sh --64bit -t $(SCRIPT_DIR)/quartus_build.tcl

sta: $(OUT_DIR)
	cd $(OUT_DIR) && quartus_sta --64bit -t $(SCRIPT_DIR)/quartus_sta.tcl

pgm: $(SOF)
	quartus_pgm --mode JTAG -o "p;$(SOF)"

pgmonly:
	quartus_pgm --mode JTAG -o "p;$(SOF)"

clean:
	rm -rf $(OUT_DIR)
