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


#
# Tests:
# - access_test: write to a continuous memory space and then read the data back
# - single_read_loc: read a single memory location N times
# - double_read_loc: read 2 memory location for N times alternatively
# - random_test: "randomly" access the memory. (Will only read from the already written location)
#

source "vjtag_host.tcl"

#--------------------------------------
# Global Variable
#--------------------------------------
set last_indicator 0;   # last message is printed by progress indicator

#--------------------------------------
# Helper Procedures
#--------------------------------------

# Process indicator: show the test progress
# update every threshold%
proc progress_indicator {cnt cnt_total last_percent} {
    global last_indicator
    set bar_width 25
    set threshold 10
    set percent [expr {int(($cnt) * 100.0 / $cnt_total)}]
    set filled [expr {int($percent * $bar_width / 100)}]
    set empty [expr {$bar_width - $filled}]
    set filled_str [string repeat "#" $filled]
    set empty_str [string repeat " " $empty]
    set bar "\[$filled_str$empty_str\]"

    if {$percent >= $last_percent + $threshold} {
        if {$last_indicator} {
            puts -nonewline "\rProgress: $bar $percent%   "
            flush stdout
        } else {
            puts -nonewline "Progress: $bar $percent%   "
            flush stdout
        }
        set last_percent $percent
    }
    set last_indicator 1
    return $last_percent
}

# Print Error message. Work together with process_indicator
proc print_err {msg} {
    global last_indicator
    if {$last_indicator == 1} {
        set last_indicator 0
        puts stdout "\r$msg"
    } else {
        puts stdout $msg
    }
    flush stdout
}

proc print_result {error} {
    puts ""
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

#--------------------------------------
# Memory Test
#--------------------------------------

# Memory Access test.
# Make sure each memory address can be accessed correctly. The write data will be same as addr
# Parameter
# - start: start address (need to align with word boundary)
# - end: end address (inclusive)
proc access_test {start end} {
    global data_width
    # run test sequence
    puts [format "\nStarting memory access test! Starting Address 0x%X. End Address 0x%X" $start $end]
    set word_size [ceil_div $data_width 8]
    set length [expr ($end - $start) / $word_size]
    set error 0

    # write to all the location
    set cnt 0
    set last_percent 0
    puts stdout "Writing memory:"
    for {set addr $start} {$addr <= $end} {incr addr $word_size} {
        process_write $addr $addr
        #puts [format "WRITE: Addr: 0x%X, Data: 0x%X" $addr $addr]

        # progress indicator
        set last_percent [progress_indicator $cnt $length $last_percent]
        set cnt [expr $cnt + 1]
    }
    puts stdout "\nComplete!"

    # read to all the location
    set cnt 0
    set last_percent 0
    puts stdout "Reading memory."
    for {set addr $start} {$addr <= $end} {incr addr $word_size} {
        set read_data [process_read $addr]
        scan $read_data %x read_data
        #puts [format " READ: Addr: 0x%X, Data: 0x%X" $addr $read_data]
        if {$addr != $read_data} {
            set error [expr $error + 1]
            print_err [format "ERROR: Wrong read data at Addr: 0x%X. Expected Data: 0x%X. Actual Data: 0x%X" $addr $addr $read_data]
        }
        # progress indicator
        set last_percent [progress_indicator $cnt $length $last_percent]
        set cnt [expr $cnt + 1]
    }
    puts stdout "\nComplete!"

    print_result $error
}

# Read a single memory location for N times
# Parameter
# - addr: Address to be read
# - data: Data to be written
# - n: number of read
proc single_read_loc {addr data n} {
    global data_width

    puts [format "\nStarting single read test! Address 0x%X. Data 0x%X. Repeat times: %d" $addr $data $n]
    set error 0

    # write
    process_write $addr $data

    # read
    set last_percent 0
    for {set cnt 0} {$cnt <= $n} {incr cnt} {
        set read_data [process_read $addr]
        scan $read_data %x read_data
        if {$data != $read_data} {
            set error [expr $error + 1]
            print_err [format "ERROR: \[Occurrence %d\] Get wrong read data: 0x%X" $cnt $read_data]
        }
        # progress indicator
        set last_percent [progress_indicator $cnt $n $last_percent]
    }

    print_result $error
}

# Read 2 memory location for N times alternatively
# Parameter
# - addr1: Address to be read
# - data1: Data to be written
# - addr2: Address to be read
# - data2: Data to be written
# - n: number of read
proc double_read_loc {addr1 data1 addr2 data2 n} {
    global data_width

    puts [format "\nStarting single read test! Repeat times: %d" $n]
    puts [format "@0 Address 0x%X. Data 0x%X" $addr1 $data1]
    puts [format "@1 Address 0x%X. Data 0x%X" $addr2 $data2]
    puts ""
    set error 0

    # write
    process_write $addr1 $data1
    process_write $addr2 $data2

    # read
    set last_percent 0
    for {set cnt 0} {$cnt < $n} {incr cnt} {
        set read_data [process_read $addr1]
        scan $read_data %x read_data
        if {$data1 != $read_data} {
            set error [expr $error + 1]
            print_err [format "ERROR: \[Occurrence %5d\] @0 Get wrong read data: 0x%X" $cnt $read_data]
        }
        set read_data [process_read $addr2]
        scan $read_data %x read_data
        if {$data2 != $read_data} {
            set error [expr $error + 1]
            print_err [format "ERROR: \[Occurrence %5d\] @1 Get wrong read data: 0x%X" $cnt $read_data]
        }
        # progress indicator
        set last_percent [progress_indicator $cnt $n $last_percent]
    }

    print_result $error
}

# Random Memory Access test
proc random_test {num_op num_seq} {



    # generate test
    set items [gen_test $num_op $num_seq]
    set test_sequence [lindex $items 0]
    set addr_data [lindex $items 1]

    # run test sequence
    puts "\nStarting random memory access test!"
    set error 0
    set cnt 0
    set last_percent 0
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
                puts stderr [format "ERROR: Wrong read data at Addr: 0x%X. Expected Data: 0x%X. Actual Data: 0x%X" $addr $data $read_data]
            }
        }

        # progress indicator
        set last_percent [progress_indicator $cnt $num_op $last_percent]
        set cnt [expr $cnt + 1]
    }

    print_result $error
}

if {[info script] eq $::argv0} {
    # Read config and setup USB blaster
    read_config
    setup_blaster
    #single_read_loc 0x1B8 0x1B8 1000
    #double_read_loc 0x0 0x1111 0x2 0x2222 1000
    access_test 0x0 0x10
    access_test 0x0 0x1000
    random_test 10000 10
    close
}
