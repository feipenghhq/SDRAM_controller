#!/bin/bash

# Set the path to your TCL script
TCL_SCRIPT="sdram_test.tcl"

# Check for Quartus STP
if ! command -v quartus_stp &> /dev/null; then
    echo "Error: quartus_stp not found in PATH."
    exit 1
fi

quartus_stp --64bit -t "$TCL_SCRIPT"
exit $?



