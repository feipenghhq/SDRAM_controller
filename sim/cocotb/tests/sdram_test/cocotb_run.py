# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 09/09/2025
#
# -------------------------------------------------------------------
# Cocotb testbench
# -------------------------------------------------------------------

import sys
import subprocess
from pathlib import Path

def get_git_root() -> Path:
    try:
        root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        return Path(root)
    except subprocess.CalledProcessError:
        return None  # not a git repository

# Add 'tb' folder to Python path
repo_root = get_git_root()
tb_path = str(repo_root / "sim" / "cocotb" / "tb")
if tb_path not in sys.path:
    sys.path.insert(0, tb_path)

# import required functions
from env import init_env, init_sdram, load_config

import cocotb
from cocotb.triggers import Timer, RisingEdge

@cocotb.test()
async def run(dut):
    load_config(dut)
    await init_env(dut, sdram_debug=False)
    await init_sdram(dut)
    await  RisingEdge(dut.complete)
    await Timer(100, units='ns')
