#!/bin/bash

# Set the path to your TCL script
TCL_SCRIPT="vjtag_host.tcl"

# Help message function
show_help() {
    echo "Usage:"
    echo "  $0                         # Launch interactive shell"
    echo "  $0 <file> [addr]           # Program the FPGA with <file> at optional [addr] (default: 0)"
    echo "  $0 -h | --help             # Show this help message"
    echo
    echo "Examples:"
    echo "  $0                         # Start interactive VJTAG shell"
    echo "  $0 firmware.hex            # Program firmware.hex starting at address 0"
    echo "  $0 firmware.hex 0x1000     # Program firmware.hex starting at address 0x1000"
}

# Check for Quartus STP
if ! command -v quartus_stp &> /dev/null; then
    echo "Error: quartus_stp not found in PATH."
    exit 1
fi

# Help option
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# If no arguments, launch interactive shell
if [ $# -eq 0 ]; then
    quartus_stp --64bit -t "$TCL_SCRIPT"
    exit $?
fi

# If one or two arguments are given, treat as file + optional address
if [ $# -eq 1 ] || [ $# -eq 2 ]; then
    FILE="$1"
    ADDR="${2:-0}"
    quartus_stp --64bit -t "$TCL_SCRIPT" "$FILE" "$ADDR"
    exit $?
fi

# Invalid usage
echo "Error: Invalid arguments."
show_help
exit 1