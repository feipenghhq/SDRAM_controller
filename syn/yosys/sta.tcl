# Load Liberty timing library
read_liberty gscl45nm.lib

# Load synthesized netlist (from Yosys)
read_verilog netlist.v

# Link design
link_design sdram_controller

# Set primary clock
create_clock -period 10 [get_ports clk]  ;# e.g., 100MHz

# Perform timing analysis
report_checks -path_delay min_max

# exit
exit
