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

def run_test(top, f_verilog_source, test, clk_freq, waves=0):

    toplevel = top
    git_repo = get_git_root()
    verilog_sources, include_dirs = f_verilog_source(git_repo)

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
