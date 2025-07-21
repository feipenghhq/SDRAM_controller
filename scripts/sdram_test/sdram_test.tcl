# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/20/2025
#
# -------------------------------------------------------------------
# TCL script to use vjtag_host to test SDRAM
# -------------------------------------------------------------------

source "vjtag_host.tcl"

# Generate random read/write sequence and random data
# Use as test data for random memory access test
proc gen_test {num_op num_seq} {
    global data_width

    # Seed random if needed (Tcl 8.5+)
    package require Tcl 8.5
    expr {srand([clock seconds])}

    # Initialize lists
    set addr_data {}            ; # random address and data pair
    set valid_idx {}            ; # List of index to addr_data. Indicate that location has valid data
    set test_sequence {}        ; # List of (op, index). op: 0 - write, 1 - read. index: index to addr_data

    # Generate random address and data
    for {set i 0} {$i < $num_seq} {incr i} {
        set addr [expr {int(rand() * 0x800000)}]
        set data [expr {int(rand() * 0x10000)}]

        # align address to word size
        set word_size [ceil_div $data_width 8]
        set aligned_addr [expr {$addr & ~($word_size - 1)}]

        lappend addr_data [list $aligned_addr $data]
    }

    # First operation must be write
    set idx [expr {int(rand() * $num_seq)}]
    lappend valid_idx $idx
    lappend test_sequence [list 0 $idx]

    # Generate rest of sequence
    for {set i 0} {$i < $num_op} {incr i} {
        set op [expr {int(rand() * 2)}]
        if {$op == 1} { # Read: choose from valid indices
            # randomly select an index from the valid_idx
            set vidx [expr {int(rand() * [llength $valid_idx])}]
            set idx [lindex $valid_idx $vidx]
        } else { # Write: choose any index
            # randomly pick up a addr/data pair
            set idx [expr {int(rand() * $num_seq)}]
            # add idx to valid_idx if it does not exist
            if {[lsearch -exact $valid_idx $idx] == -1} {
                lappend valid_idx $idx
            }
        }
        lappend test_sequence [list $op $idx]
    }

    # Debug prints
    set debug 0
    if {$debug} {
        puts "Addr/Data List:"
        foreach item $addr_data {
            puts $item
        }
        puts "\nTest Sequence:"
        foreach item $test_sequence {
            puts "Op: [lindex $item 0], Idx: [lindex $item 1]"
        }
    }

    return [list $test_sequence $addr_data]
}

# Memory Access test.
# Make sure each memory address can be accessed correctly. The write data will be same as addr
# Parameter
# - start: start address (need to align with word boundary)
# - end: end address (inclusive)
proc access_test {start end} {
    global data_width

    # Read config and setup USB blaster
    read_config
    setup_blaster

    # run test sequence
    puts [format "\nStarting memory access test! Starting Address 0x%X. End Address 0x%X" $start $end]
    set error 0

    # write to all the location
    set word_size [ceil_div $data_width 8]
    for {set addr $start} {$addr <= $end} {incr addr $word_size} {
        process_write $addr $addr
        #puts [format "WRITE: Addr: 0x%X, Data: 0x%X" $addr $addr]
    }

    # read to all the location
    for {set addr $start} {$addr <= $end} {incr addr $word_size} {
        set read_data [process_read $addr]
        scan $read_data %x read_data
        #puts [format " READ: Addr: 0x%X, Data: 0x%X" $addr $read_data]
        if {$addr != $read_data} {
            set error [expr $error + 1]
            puts [format "ERROR: Wrong read data at Addr: 0x%X. Expected Data: 0x%X. Actual Data: 0x%X" $addr $addr $read_data]
        }
    }

    # Check result
    if {$error == 0} {
        puts "----------------"
        puts "  TEST PASSED"
        puts "----------------"
    } else {
        puts "----------------"
        puts "  TEST FAILED"
        puts "----------------"
    }

}

# Random Memory Access test
proc random_test {} {
    set num_op  2000
    set num_seq 1

    # Read config and setup USB blaster
    read_config
    setup_blaster

    # generate test
    set items [gen_test $num_op $num_seq]
    set test_sequence [lindex $items 0]
    set addr_data [lindex $items 1]

    # run test sequence
    puts "\nStarting random memory access test!"
    set error 0
    foreach seq $test_sequence {
        set op  [lindex $seq 0]
        set idx [lindex $seq 1]
        set items [lindex $addr_data $idx]
        set addr [lindex $items 0]
        set data [lindex $items 1]

        if {$op == 0} {  # write
            process_write $addr $data
            #puts [format "WRITE: Addr: 0x%X, Data: 0x%X" $addr $data]
        }

        if {$op == 1} {  # read
            set read_data [process_read $addr]
            scan $read_data %x read_data
            #puts [format " READ: Addr: 0x%X, Data: 0x%X" $addr $read_data]
            if {$data != $read_data} {
                set error [expr $error + 1]
                puts [format "ERROR: Wrong read data at Addr: 0x%X. Expected Data: 0x%X. Actual Data: 0x%X" $addr $data $read_data]
            }
        }

        # Debug prints
        set debug 0
        if {$debug} {
            puts "Test Operation: Op: $op, Addr: $addr, Data: $data"
        }
    }


    # Check result
    if {$error == 0} {
        puts "----------------"
        puts "  TEST PASSED"
        puts "----------------"
    } else {
        puts "----------------"
        puts "  TEST FAILED"
        puts "----------------"
    }

}

if {[info script] eq $::argv0} {
    access_test 0x0 0x1000
    #random_test
}
