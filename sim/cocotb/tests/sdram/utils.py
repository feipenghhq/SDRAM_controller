# -------------------------------------------------------------------
# Copyright 2025 by Heqing Huang (feipenghhq@gamil.com)
# -------------------------------------------------------------------
#
# Project: SDRAM
# Author: Heqing Huang
# Date Created: 08/29/2025
#
# -------------------------------------------------------------------
# Common utilities
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

# Import required functions
from env import init_env, init_sdram, load_config
from bus import init_bus, single_write, single_read, single_read_resp, read_resp

# Initialization
async def init(dut, sdram_debug=False):
    """
    Initialize all the required items and wait for sdram initialization
    """
    load_config(dut)
    init_bus(dut)
    await init_env(dut, sdram_debug=sdram_debug)
    await init_sdram(dut)
