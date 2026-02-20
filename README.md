# RISC-V Implementation on FPGA

A pipelined RISC-V processor implemented on a Zynq FPGA platform (PYNQ), featuring Harvard-style memory architecture, AXI interconnect integration, and software-driven execution control via Python/Jupyter.

**Authors:** Chitsidzo Varaidzo Nemazuwa, Kanaya Nisa Ozora, Nawal Salama  
**Institution:** Chair of Computer Architecture and Operating Systems, TU Munich  
**Date:** February 20, 2026

---

## Overview

This project implements a 5-stage pipelined RISC-V processor deployed on an FPGA. The design separates instruction and data memories using dedicated BRAMs (Harvard architecture), avoiding port contention during simultaneous instruction fetch and load/store operations. The ARM Processing System (PS) on the Zynq controls the FPGA fabric via AXI, loading programs into memory and monitoring execution.

---

## Architecture

### Memory Organization

The design uses **two physically separate BRAMs**:

- **Instruction BRAM** (`blk_mem_gen_1`) — 4 BRAM tiles, accessed exclusively by the RISC-V core for instruction fetch via Port B
- **Data BRAM** (`blk_mem_gen_0`) — 2 BRAM tiles, accessed by the RISC-V core for load/store operations, and by the PS for memory-mapped I/O

This separation eliminates port contention, allowing the core to fetch an instruction and perform a memory access in the same clock cycle.

### Pipeline Stages

The RISC-V core implements a classic 5-stage pipeline:

1. **Fetch** — PC logic, instruction memory interface, branch redirection
2. **Decode** — Register file, immediate generation, control signal decoding, hazard detection inputs
3. **Execute** — ALU, branch comparison logic, operand forwarding multiplexers
4. **Memory** — Data memory interface, store-data selection
5. **Hazard & Forwarding Unit** — Stall detection, forwarding multiplexers, branch flush control

The Execute stage and Hazard/Forwarding logic are the most logic-intensive components due to ALU circuitry, wide forwarding multiplexers, and branch resolution.

### Block Design

The system integrates the following IP blocks:

| Block | Role |
|---|---|
| `rv_pl_wrapper_0` | RISC-V Core |
| `blk_mem_gen_1` | Instruction BRAM |
| `blk_mem_gen_0` | Data BRAM |
| `axi_smc` | AXI SmartConnect (interconnect/arbitration) |
| `axi_bram_ctrl_0/1` | AXI-to-BRAM protocol translation |
| `axi_gpio_0` | Reset control and status signaling |
| `proc_sys_reset_0` | Synchronized reset generation |
| `processing_system7_0` | Zynq ARM Cortex-A9 (PS) |

The PS acts as an AXI master via `M_AXI_GP0`, distributing transactions through the SmartConnect to BRAM controllers and GPIO. A single clock (`FCLK_CLK0`) is distributed across the entire design for synchronous operation.

---

## Resource Utilization

| Module | LUTs | Registers | BRAM Tiles |
|---|---|---|---|
| Top Level | 7078 | 7653 | 6 |
| AXI SmartConnect | 5087 | 5634 | 0 |
| RISC-V Core | 1481 | 1522 | 0 |
| AXI BRAM Ctrl 0 | 188 | 197 | 0 |
| AXI BRAM Ctrl 1 | 193 | 200 | 0 |
| Instruction BRAM | 10 | 12 | 4 |
| Data BRAM | 10 | 12 | 2 |
| AXI GPIO | 35 | 36 | 0 |

The AXI SmartConnect dominates system-level resource usage due to its arbitration and protocol management logic. Within the RISC-V core, the Execute and Hazard/Forwarding stages consume the majority of LUTs.

---

## Processing System (PS) Operation

The PS uses the **PYNQ Overlay framework** to:

1. Load the FPGA bitstream
2. Hold the RISC-V core in reset via AXI GPIO
3. Write instructions and data into BRAMs via AXI memory-mapped writes
4. Release reset to begin execution from address `0x0000`
5. Poll the status register at `0x2000` every second for a completion flag (`0xDEADBEEF`)
6. Read back results and verify against a software-generated reference

