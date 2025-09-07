# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/21/2025
#
# -------------------------------------------------------------------
# Regression L1 Test
# -------------------------------------------------------------------

from cocotb_random_test import random_read_write
from cocotb_sequential_test import sequential_read_write
from cocotb.regression import TestFactory

random_factory = TestFactory(random_read_write)
random_factory.add_option("num_op", [0x4000])
random_factory.add_option("num_seq", [1000])
random_factory.generate_tests()

sequential_factory = TestFactory(sequential_read_write)
sequential_factory.add_option("start_addr", [0])
sequential_factory.add_option("end_addr",   [0x4000])
sequential_factory.generate_tests()