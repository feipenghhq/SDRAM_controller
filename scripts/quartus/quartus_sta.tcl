# ---------------------------------------------------------------
# Copyright (c) 2022. Heqing Huang (feipenghhq@gmail.com)
# Author: Heqing Huang
# Date Created: 04/19/2022
# ---------------------------------------------------------------
# Tcl Script for Quartus STA
# Reference: https://www.intel.com/content/www/us/en/docs/programmable/683068/18-1/timing-analyzer-tcl-commands.html
# ---------------------------------------------------------------

# ------------------------------------------
# Create project and read in rtl files
# ------------------------------------------

set QUARTUS_PART        $::env(QUARTUS_PART)
set QUARTUS_FAMILY      $::env(QUARTUS_FAMILY)
set QUARTUS_PRJ         $::env(QUARTUS_PRJ)
set QUARTUS_TOP         $::env(QUARTUS_TOP)
set QUARTUS_VERILOG     $::env(QUARTUS_VERILOG)
set QUARTUS_SEARCH      $::env(QUARTUS_SEARCH)
set QUARTUS_SDC         $::env(QUARTUS_SDC)
set QUARTUS_QIP         $::env(QUARTUS_QIP)
set QUARTUS_PIN         $::env(QUARTUS_PIN)
set QUARTUS_DEFINE      $::env(QUARTUS_DEFINE)

# Load Quartus II Tcl Project package
package require ::quartus::project
project_open $QUARTUS_PRJ

# Run timing analysis
package require ::quartus::sta

create_timing_netlist

# Read in SDC
if { [llength $QUARTUS_SDC] > 0 } {
    foreach sdc $QUARTUS_SDC {
        read_sdc $sdc
    }
}

update_timing_netlist


# Report Timing result

report_clocks -file "timing_report/clock.rpt"
create_timing_summary -panel_name "Setup Summary" -file "timing_report/setup_summary.rpt" -append
create_timing_summary -hold -panel_name "Hold Summary" -file "timing_report/hold_summary.rpt" -append

foreach_in_collection clk [get_clocks *] {
    set name [get_clock_info -name $clk]
    set report_file "timing_report/report_${name}.txt"
    report_timing -to_clock $clk -setup -npaths 10 -detail full_path -panel_name {Setup: clk} -file $report_file -append
}

project_close
