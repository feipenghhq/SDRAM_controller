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

import random
import os

from test_random import test_random_read_write
from test_sequential import test_sequential_read_write
from cocotb.regression import TestFactory

random_factory = TestFactory(test_random_read_write)
random_factory.add_option("num_op", [0x4000])
random_factory.add_option("num_seq", [1000])
random_factory.generate_tests()

sequential_factory = TestFactory(test_sequential_read_write)
sequential_factory.add_option("start_addr", [0])
sequential_factory.add_option("end_addr",   [0x4000])
sequential_factory.generate_tests()
