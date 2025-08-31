# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/29/2025
#
# -------------------------------------------------------------------
# test using pytest
# -------------------------------------------------------------------

import subprocess
import pytest
from cocotb_test.simulator import run
from pathlib import Path

# get git root
def get_git_root(path="."):
    try:
        root = subprocess.check_output(
            ["git", "-C", path, "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL
        ).decode().strip()
        return Path(root)
    except subprocess.CalledProcessError:
        return None

# get all the verilog source file and include directories
def get_verilog_sources(git_repo):
    sdram_dir = Path(f'{git_repo}/rtl/sdram')
    verilog_sources = [
        sdram_dir / 'sdram_cmd.sv',
        sdram_dir / 'sdram_ctrl.sv',
        sdram_dir / 'sdram_init.sv',
        sdram_dir / 'sdram_controller.sv',
        git_repo  / 'sim/cocotb/model/MT48LC8M16A2.v',
        git_repo  / 'sim/cocotb/tb/tb_sdram_controller.sv'
    ]
    include_dirs = [sdram_dir]
    return verilog_sources, include_dirs

@pytest.mark.parametrize('clk_freq', [50, 100, 133])
def test_sdram(test, clk_freq, waves=0):

    git_repo = get_git_root()
    verilog_sources, include_dirs = get_verilog_sources(git_repo)

    toplevel = 'tb_sdram_controller'

    parameters = {}
    parameters['CLK_FREQ'] = clk_freq

    compile_args = ['-D SIMULATION=1']
    sim_args=["-l", "sim.log"]
    extra_env = {'CLK_FREQ': str(clk_freq)}
    sim_build = f'sim_build/{test}_{clk_freq}'

    run(
        verilog_sources=verilog_sources,
        includes=include_dirs,
        toplevel=toplevel,
        module=test,
        parameters=parameters,
        waves=waves,
        compile_args=compile_args,
        sim_args=sim_args,
        extra_env=extra_env,
        sim_build = sim_build,
        sim='icarus',
        toplevel_lang='verilog',
    )
