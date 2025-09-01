#!/usr/bin/env bash
set -e

# If first argument is "clean", remove sim_build and exit
if [ "$1" == "clean" ]; then
    rm -rf sim_build .pytest_cache
    exit 0
fi

# First argument = test name (required)
if [ -z "$1" ]; then
    echo "Usage: $0 <test_name> [waves=1]"
    exit 1
fi

TEST_NAME="$1"
shift

# Default waves=0
WAVES=0

# Parse optional waves argument
for arg in "$@"; do
    case $arg in
        waves=1)
            WAVES=1
            shift
            ;;
        waves=0)
            WAVES=0
            shift
            ;;
    esac
done

# Run pytest
pytest -o log_cli=True pytest_runner.py --test="$TEST_NAME" --waves="$WAVES"