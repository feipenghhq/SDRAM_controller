// -------------------------------------------------------------------
// Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
// -------------------------------------------------------------------
//
// Project: SDRAM Controller
// Author: Heqing Huang
// Date Created: 08/07/2025
//
// -------------------------------------------------------------------
// SDRAM Parameter Override
// -------------------------------------------------------------------

// -------------------------------------------------------------------
// Micron MT48LC8M16A2
// - SDRAM Size: 128Mb
// - Data width: x16
// - Row width:  12
// - Col width:  9
// -------------------------------------------------------------------

// SPEED = -6A
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (24),
    .RAW        (12),
    .CAW        (9 ),
    .tRAS       (42),
    .tRC        (60),
    .tRCD       (18),
    .tRFC       (60),
    .tRP        (18),
    .tRRD       (12),
    .tWR        (15), // 1 CLK + 7ns
    .tREF       (64)
*/

// SPEED = -7E
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (24),
    .RAW        (12),
    .CAW        (9 ),
    .tRAS       (37),
    .tRC        (60),
    .tRCD       (15),
    .tRFC       (66),
    .tRP        (15),
    .tRRD       (14)
    .tWR        (15), // 1 CLK + 7ns
    .tREF       (64)
*/

// SPEED = -6A
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (24),
    .RAW        (12),
    .CAW        (9 ),
    .tRAS       (44),
    .tRC        (66),
    .tRCD       (20),
    .tRFC       (66),
    .tRP        (20),
    .tRRD       (15)
    .tWR        (15), // 1 CLK + 7.5ns
    .tREF       (64)
*/

// -------------------------------------------------------------------
// ISSI IS42S16400
// - SDRAM Size: 64Mb
// - Data width: x16
// - Row width:  12
// - Col width:  8
// -------------------------------------------------------------------


// SPEED = -7
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (23),
    .RAW        (12),
    .CAW        (8 ),
    .tRAS       (45),
    .tRC        (68),
    .tRCD       (20),
    .tRFC       (68),
    .tRP        (20),
    .tRRD       (15)
    .tWR        (15), // tDPL in the datasheet
    .tREF       (64)
*/


// speed = -8
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (23),
    .RAW        (12),
    .CAW        (8 ),
    .tRAS       (50),
    .tRC        (70),
    .tRCD       (20),
    .tRFC       (70),
    .tRP        (20),
    .tRRD       (20)
    .tWR        (20), // tDPL in the datasheet
    .tREF       (64)
*/

// -------------------------------------------------------------------
// ISSI IS42S16320D
// - SDRAM Size: 512Mb
// - Data width: x16
// - Row width:  12
// - Col width:  8
// -------------------------------------------------------------------

// SPEED = -5
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (26),
    .RAW        (13),
    .CAW        (10),
    .tRAS       (38),
    .tRC        (55),
    .tRCD       (15),
    .tRFC       (55),
    .tRP        (15),
    .tRRD       (10)
    .tWR        (10),
    .tREF       (64)
*/


// SPEED = -6
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (26),
    .RAW        (13),
    .CAW        (10),
    .tRAS       (42),
    .tRC        (60),
    .tRCD       (18),
    .tRFC       (60),
    .tRP        (18),
    .tRRD       (12)
    .tWR        (12),
    .tREF       (64)
*/

// SPEED = -7
/*
    .CLK_FREQ   (133),
    .DW         (16),
    .AW         (26),
    .RAW        (13),
    .CAW        (10),
    .tRAS       (37),
    .tRC        (60),
    .tRCD       (15),
    .tRFC       (60),
    .tRP        (15),
    .tRRD       (14)
    .tWR        (14),
    .tREF       (64)
*/


// -------------------------------------------------------------------
// Template
// -------------------------------------------------------------------

/*
    .CLK_FREQ   (),
    .DW         (),
    .AW         (),
    .RAW        (),
    .CAW        (),
    .tRAS       (),
    .tRC        (),
    .tRCD       (),
    .tRFC       (),
    .tRP        (),
    .tRRD       ()
    .tWR        (),
    .tREF       (64)
*/

