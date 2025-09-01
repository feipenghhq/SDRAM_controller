# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/31/2025
#
# -------------------------------------------------------------------
# Run pytest
# -------------------------------------------------------------------

import pytest
from pytest_utils import run_test
from pathlib import Path

# get all the verilog source file and include directories
def get_verilog_sources(git_repo):
    sdram_dir = Path(f'{git_repo}/rtl/sdram')
    wbsdram_dir = Path(f'{git_repo}/rtl/wbsdram')
    verilog_sources = [
        sdram_dir / 'sdram_cmd.sv',
        sdram_dir / 'sdram_ctrl.sv',
        sdram_dir / 'sdram_init.sv',
        sdram_dir / 'sdram_controller.sv',
        wbsdram_dir / 'wbsdram.sv',
        git_repo  / 'sim/cocotb/model/MT48LC8M16A2.v',
        git_repo  / 'sim/cocotb/tb/tb_wbsdram.sv'
    ]
    include_dirs = [sdram_dir]
    return verilog_sources, include_dirs

@pytest.mark.parametrize('clk_freq', [50, 100, 133])
def test_wbsdram(test, clk_freq, waves=0):
    top = 'tb_wbsdram'
    run_test(top, get_verilog_sources, test, clk_freq, waves)
