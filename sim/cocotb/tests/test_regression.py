# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 07/21/2025
#
# -------------------------------------------------------------------
# Regression Test
# -------------------------------------------------------------------

from test_random_rw import test_random_read_write
from cocotb.regression import TestFactory

factory = TestFactory(test_random_read_write)
factory.add_option("num_op", [10000, 10000])
factory.add_option("num_seq", [1000])
factory.generate_tests()
