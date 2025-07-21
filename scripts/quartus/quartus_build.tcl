# ---------------------------------------------------------------
# Copyright (c) 2022. Heqing Huang (feipenghhq@gmail.com)
# Author: Heqing Huang
# Date Created: 04/19/2022
# ---------------------------------------------------------------
# Tcl Script for Quartus
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
project_new $QUARTUS_PRJ -overwrite -part $QUARTUS_PART -family $QUARTUS_FAMILY

# Porject Assignment
set_global_assignment -name VERILOG_MACRO "SYNTHESIS=1"
set_global_assignment -name TOP_LEVEL_ENTITY $QUARTUS_TOP
#set_global_assignment -name VERILOG_NON_CONSTANT_LOOP_LIMIT 10000
#set_global_assignment -name VERILOG_CONSTANT_LOOP_LIMIT 30000
#set_global_assignment -name NUM_PARALLEL_PROCESSORS ALL

# Read in the Define
foreach define $QUARTUS_DEFINE {
    set msg "Reading RTL Define: "
    puts [append msg $define]
    set_global_assignment -name VERILOG_MACRO  $define
}

# Read in RTL
foreach vlog $QUARTUS_VERILOG {
    set msg "Reading RTL file: "
    puts [append msg $vlog]
    set_global_assignment -name SYSTEMVERILOG_FILE $vlog
}

# Read in QIP
if { [llength $QUARTUS_QIP] > 0 } {
    foreach qip $QUARTUS_QIP {
        set msg "Adding QIP: "
        puts [append msg $qip]
        set_global_assignment -name QIP_FILE $qip
    }
}

# Read in SDC
if { [llength $QUARTUS_SDC] > 0 } {
    foreach sdc $QUARTUS_SDC {
        set msg "Reading SDC file: "
        puts [append msg $sdc]
        set_global_assignment -name SDC_FILE $sdc
    }
}

# Read in RTL SEARCH file
foreach vlog $QUARTUS_SEARCH {
    set msg "Reading RTL SEARCH path: "
    puts [append msg $vlog]
    set_global_assignment -name SEARCH_PATH $vlog
}

set_global_assignment -name TOP_LEVEL_ENTITY $QUARTUS_TOP

# source pin assignment
source $QUARTUS_PIN

# additional assignment for CYCLONE II
if { $QUARTUS_FAMILY eq "Cyclone II" } {
set_global_assignment -name CYCLONEII_RESERVE_NCEO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name RESERVE_ASDO_AFTER_CONFIGURATION "USE AS REGULAR IO"
set_global_assignment -name USE_CONFIGURATION_DEVICE ON
}

export_assignments

# ------------------------------------------
# Synthesis(map), Implementation(fit), and assemble
# ------------------------------------------

package require ::quartus::flow
execute_module -tool map
execute_module -tool fit
execute_module -tool asm

project_close
