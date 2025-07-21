# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: VJTAG Host
# Author: Heqing Huang
# Date Created: 07/12/2025
#
# -------------------------------------------------------------------
# Tcl file to interact with the Virtual JTAG Host
# -------------------------------------------------------------------

set Usage {
------------------------------------------------------------------------------------------------------------------------
VJTAG_HOST(1)                 Altera VJTAG Utility                VJTAG_HOST(1)

NAME
       vjtag_host.tcl - Interactive shell to communicate with Altera VJTAG interface on target FPGA

SYNOPSIS
       quartus_stp -t vjtag_host.tcl
       quartus_stp -t vjtag_host.tcl [program] [addr]

DESCRIPTION
       This Tcl script communicates with the target FPGA using Altera's VJTAG
       interface. It provides an interactive shell for debugging, memory
       access, and programming memory via virtual JTAG.

       If a file is provided, it will be programmed into the FPGA starting at
       the given address. If no address is specified, address 0 is used.

USAGE
       quartus_stp -t vjtag_host.tcl
              Start an interactive shell.

       quartus_stp -t vjtag_host.tcl file.hex [addr]
              Program the file to FPGA RAM starting at optional addr (default is 0).

SUPPORTED COMMANDS IN INTERACTIVE SHELL
       help
              Print help message.

       exit
              Exit the command shell.

       read <addr>
              Read data at the specified <addr>.

       write <addr> <data>
              Write <data> to the specified <addr>.

       program <addr> <file>
              Program a RAM or continuous memory space starting at <addr> using the
              contents of <file>. The address of subsequent data is automatically
              calculated.

CONFIG FILE
       The script uses a configuration file to define FPGA target parameters:

       instance_id
              The VJTAG instance ID. Found in the Quartus synthesis report by searching
              for parameter sld_instance_index (e.g., instance_id: 0).

       addr_width
              Number of address bits (e.g., 16).

       data_width
              Number of data bits (e.g., 16).

AUTHOR
       Heqing Huang

SEE ALSO
       quartus_stp(1), jtag(1)

------------------------------------------------------------------------------------------------------------------------
}


package require json

#--------------------------------------
# Global Variable
#--------------------------------------

set usbblaster ""
set device ""
set instance_id 0
set addr_width 0
set data_width 0
set print_read_data 0

#--------------------------------------
# Helper Procedure
#--------------------------------------

proc ceil_div {a b} {
    return [expr {($a + $b - 1) / $b}]
}

#--------------------------------------
# Procedure to interact with VJTAG
#--------------------------------------

# setup USB blaster, select device, and open device
proc setup_blaster {} {
    global usbblaster
    global device
    # List all available programming hardware, and select the USB-Blaster.
    foreach hardware_name [get_hardware_names] {
        if {[string match "USB-Blaster*" $hardware_name]} {
            set usbblaster $hardware_name
        }
    }
    puts "Selected Hardware: $usbblaster"
    # List all devices on the chain, and select the first device on the chain.
    foreach device_name [get_device_names -hardware_name $usbblaster] {
        if {[string match "@1*" $device_name]} {
            set device $device_name
        }
    }
    puts "Selected Device: $device"
    # open device
    open_device -hardware_name $usbblaster -device_name $device
}

# Set VIR register
proc set_vir {value} {
    global instance_id
    device_virtual_ir_shift -instance_index $instance_id -ir_value $value -no_captured_ir_value
}

# Set VDR register
proc set_vdr {length value} {
    global instance_id
    device_virtual_dr_shift -instance_index $instance_id -length $length -dr_value $value -value_in_hex -no_captured_dr_value
}

# Read VDR register
proc read_vdr {length value} {
    global instance_id
    return [device_virtual_dr_shift -instance_index $instance_id -length $length -dr_value $value -value_in_hex]
}

# Close device
proc close {} {
    catch {device_unlock}
    catch {close_device}
}

#------------------------------------------------
# Procedure for sending specific command
#------------------------------------------------

# CMD: reset assertion
proc cmd_rst_assert {} {
    set_vir 0xFE
    set_vdr 1 0
}

# CMD: reset de-assertion
proc cmd_rst_deassert {} {
    set_vir 0xFF
    set_vdr 1 0
}

# CMD: write
# Example: send_write_cmd 0004FF11 32
proc cmd_write {word length} {
    set_vir 0x2
    set_vdr $length $word
}

# CMD: read
# Example: send_read_cmd 0004 16 0000 16
proc cmd_read {word length dummy read_length} {
    # send read request
    set_vir 0x1
    set_vdr $length $word
    # read return data back
    set_vir 0x0
    return [read_vdr $read_length $dummy]
}

#------------------------------------------------
# Procedure for interactive script
#------------------------------------------------

# read the config file
proc read_config {} {
    global instance_id
    global addr_width
    global data_width
    # Read JSON file converted from YAML
    set fh [open "config.json" r]
    set json_data [read $fh]
    #close $fh

    set dict_data [::json::json2dict $json_data]
    set instance_id [dict get $dict_data instance_id]
    set addr_width [dict get $dict_data addr_width]
    set data_width [dict get $dict_data data_width]
    puts "VJTAG Config:"
    puts "  - VJTAG Host instance ID: $instance_id"
    puts "  - Addr Width (bit): $addr_width"
    puts "  - Data Width (bit): $data_width"
}

# process exit command
proc process_exit {} {
    close
    exit
}

proc process_write {addr data} {
    device_lock -timeout 10000
    global addr_width
    global data_width
    scan $addr %i addr
    scan $data %i data
    set length [expr $addr_width + $data_width]
    set word [expr {($addr << $data_width) | $data}]
    set word [format "%0*X" [ceil_div $length 4] $word]
    cmd_write $word $length
    device_unlock
}

proc process_read {addr} {
    global print_read_data
    global addr_width
    global data_width
    device_lock -timeout 10000
    scan $addr %i addr
    set addr [format "%0*X" [ceil_div $addr_width 4] $addr]
    set dummy [format "%0*X" [ceil_div $data_width 4] 0]
    set data [cmd_read $addr $addr_width $dummy $data_width]
    device_unlock
    if {$print_read_data} {
        puts "Received $data"
    }
    return $data
}

proc process_program {addr file} {
    global addr_width
    global data_width

    device_lock -timeout 10000
    puts "Assert reset"
    cmd_rst_assert

    puts "Programming File :$file. Starting address: $addr"
    set fp [open $file r]
    while {[gets $fp data] >= 0} {
        # convert binary to decimal
        if {[regexp {^[01]+$} $data]} {
            set data [expr 0b$data]
        }
        # write the data
        scan $addr %i addr
        scan $data %i data
        set length [expr $addr_width + $data_width]
        set word [expr {($addr << $addr_width) | $data}]
        set word [format "%0*X" [ceil_div $length 4] $word]
        cmd_write $word $length

        # advance the address
        set addr [expr $addr + [ceil_div $addr_width 8]]
    }

    puts "De-assert reset"
    cmd_rst_deassert
    device_unlock
}

# the main interpreter procedure
proc interpreter {} {
    global Usage
    setup_blaster
    puts "\nWelcome to VJTAG interactive shell. Please enter commands"
    while {1} {
        puts -nonewline "> "
        flush stdout
        gets stdin input
        set fields [split $input]
        set cmd  [lindex $fields 0]
        set addr [lindex $fields 1]
        set data [lindex $fields 2]
        set file [lindex $fields 2]
        switch -- $cmd {
            "help"    {puts "$Usage"}
            "exit"    {process_exit}
            "write"   {process_write    $addr $data}
            "read"    {process_read $addr}
            "program" {process_program $addr $file}
            default {puts "Unsupported command. You can type help to see all the available commands"}
        }
    }
}

#------------------------------------------------
# Main Procedure
#------------------------------------------------
proc main {} {
    read_config
    if {$::argc == 0} {
        interpreter
    } else {
        if {$::argc == 1} {
            set file [lindex $::argv 0]
            set addr 0
        } elseif {$::argc == 2} {
            set file [lindex $::argv 0]
            set addr [lindex $::argv 1]
        }
        setup_blaster
        process_program $addr $file
        process_exit
    }
}

if {[info script] eq $::argv0} {
    set print_read_data 1
    main
}
