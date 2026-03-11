# Singlecore Memory Project

## Overview

This project implements a single-core memory system with UART to USB functionality using Xilinx Vivado. It includes firmware for the embedded processor and Vivado project files for FPGA synthesis and implementation.

## Project Structure

- `Do_an_1.xpr`: Main Vivado project file
- `firmware1.c`: Embedded C firmware source code
- `link.ld`: Linker script for the embedded processor
- `bin2mem.py`: Python script to convert binary files to memory initialization files
- `build.bat`: Batch script for building the project
- `timescale 1ns1ps.txt`: Timing scale configuration
- `Do_an_1.hw/`: Hardware platform files
- `Do_an_1.ip_user_files/`: IP core user files
- `Do_an_1.runs/`: Synthesis and implementation run files
- `Do_an_1.sim/`: Simulation files
- `Do_an_1.srcs/`: Source files (constraints, simulation, sources)

## Requirements

- Xilinx Vivado (version compatible with the project)
- Python 3.x (for bin2mem.py script)
- Windows/Linux development environment

## Building the Project

1. Open the project in Vivado:
   ```
   vivado Do_an_1.xpr
   ```

2. Generate the bitstream by running synthesis and implementation.

3. Program the FPGA with the generated bitstream.

## Firmware

The firmware (`firmware1.c`) runs on the embedded processor and handles UART communication. Use the `bin2mem.py` script to convert the compiled firmware binary into memory initialization files for the FPGA block RAM.

## Simulation

Simulation files are located in `Do_an_1.sim/sim_1/behav/xsim/`. Use Vivado's simulation tools to run behavioral simulations.
