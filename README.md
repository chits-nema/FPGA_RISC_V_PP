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

---

## Project Structure

```
FPGA_RISC_V_PP/
├── README.md                           # Project documentation
├── fgpa_outputs/                       # Generated bitstream files
│   ├── design_1_wrapper.bit           # FPGA bitstream
│   └── design_1_wrapper.hwh           # Hardware handoff file
├── Hardware Design/                    # Verilog source files
│   └── riscv_ip/                      # RISC-V core modules
│       ├── top_module.v               # Top-level RISC-V core
│       ├── rv_pl_wrapper.v            # AXI wrapper for Zynq integration
│       ├── program_counter.v          # PC logic and branch control
│       ├── controller.v               # Main control unit
│       ├── main_decoder.v             # Instruction decoder
│       ├── ALU_Decoder.v              # ALU operation decoder
│       ├── alu.v                      # Arithmetic Logic Unit
│       ├── reg_file.v                 # 32-entry register file
│       ├── extend_unit.v              # Immediate extension logic
│       ├── hazard_unit.v              # Data hazard detection & forwarding
│       ├── IF_ID.v                    # Fetch-Decode pipeline register
│       ├── ID_EX.v                    # Decode-Execute pipeline register
│       ├── EX_MA.v                    # Execute-Memory pipeline register
│       ├── MA_WB.v                    # Memory-Writeback pipeline register
│       ├── multiplexer.v              # Various multiplexer modules
│       ├── generic_building_blocks.v  # Utility components
│       ├── component.xml              # Vivado IP packaging metadata
│       ├── block design/              # Vivado block design files
│       └── xgui/                      # Vivado GUI configuration
├── testing_programs/                  # Test programs
│   ├── test_sort.s                    # RISC-V assembly bubble sort
│   └── tb_bubble_sort.v               # Verilog testbench
└── verification_script/               # Verification notebooks
    └── riscv_sort_verification.ipynb  # Jupyter notebook for testing
```

---

## Features

- **Full RV32I Base Instruction Set** — All integer instructions (load, store, arithmetic, logic, branch, jump)
- **5-Stage Classic Pipeline** — IF, ID, EX, MEM, WB with inter-stage registers
- **Data Hazard Handling** — Forwarding paths and pipeline stalls to resolve RAW hazards
- **Harvard Architecture** — Separate instruction and data memories eliminate port conflicts
- **AXI4-Lite Integration** — Seamless PS-PL communication via standard AXI protocol
- **Software-Controlled Execution** — Python scripts load programs and monitor execution status
- **Bubble Sort Benchmark** — 32-element integer array sorting with 2,980 instructions
- **PYNQ Framework Support** — Ready to deploy on Zynq-based PYNQ boards

---

## Prerequisites

### Hardware
- **FPGA Board:** Zynq-7000 series (e.g., PYNQ-Z1, PYNQ-Z2)
- **Host Computer:** Windows/Linux machine with USB connectivity

### Software
- **Vivado Design Suite** (2020.1 or later) — for synthesis and bitstream generation
- **PYNQ Image** (v2.7 or later) — installed on the target board's SD card
- **Python 3.6+** with the following packages:
  - `pynq` — FPGA overlay management
  - `jupyter` — interactive notebook interface
  - `numpy` — numerical operations

---

## Getting Started

### 1. Hardware Setup

1. Flash the PYNQ image onto an SD card and boot the PYNQ board
2. Connect the board to your network via Ethernet or configure Wi-Fi
3. Access the Jupyter Notebook interface at `http://pynq:9090` (default password: `xilinx`)

### 2. Loading the Bitstream

Copy the bitstream files to your PYNQ board:

```bash
scp fgpa_outputs/design_1_wrapper.bit xilinx@pynq:/home/xilinx/
scp fgpa_outputs/design_1_wrapper.hwh xilinx@pynq:/home/xilinx/
```

### 3. Running the Verification Script

1. Upload `verification_script/riscv_sort_verification.ipynb` to the PYNQ Jupyter interface
2. Open the notebook and run all cells sequentially
3. The notebook will:
   - Load the FPGA overlay
   - Compile the assembly program to machine code
   - Write instructions and test data to BRAM
   - Execute the RISC-V core
   - Compare results with a reference Python implementation

---

## Usage

### Running the Bubble Sort Test

The included test program (`test_sort.s`) sorts a 32-element array:

1. **Assembly Code:** A fully-unrolled bubble sort with 496 compare-swap blocks
2. **Execution:** Runs directly on the RISC-V core in FPGA fabric
3. **Verification:** Results are read back and compared against expected values
4. **Completion Signal:** Writes `0xDEADBEEF` to address `0x100` when finished

### Writing Custom Programs

To run your own RISC-V programs:

1. Write RV32I assembly code targeting the instruction set
2. Assemble using a RISC-V toolchain (e.g., `riscv32-unknown-elf-as`)
3. Extract machine code and load into instruction BRAM via the Python script
4. Use data BRAM addresses `0x000–0x0FF` for variables
5. Trigger execution by releasing the reset signal via AXI GPIO

---

## Testing

### Testbench Simulation

A Verilog testbench is provided for functional verification:

```bash
cd "Hardware Design/riscv_ip"
iverilog -o sim tb_bubble_sort.v top_module.v alu.v controller.v # ... (add all modules)
vvp sim
```

The testbench loads the bubble sort program and verifies correct operation through waveform inspection.

### On-Board Verification

The Jupyter notebook provides automated verification:
- Generates random test data
- Executes on both FPGA and Python
- Compares results element-by-element
- Reports pass/fail status with diagnostic outputs

---

## Performance

| Metric | Value |
|---|---|
| **Clock Frequency** | 100 MHz (FCLK_CLK0) |
| **CPI (Bubble Sort)** | ~1.2 (with hazards and stalls) |
| **Execution Time (32 elements)** | ~35–40 µs |
| **Memory Bandwidth** | 400 MB/s (32-bit @ 100 MHz) |

---

## Known Limitations

- **No Cache:** Direct BRAM access only; performance depends on single-cycle memory
- **No Interrupts:** Polling-based completion detection
- **Limited Instruction Memory:** 4 KB instruction BRAM
- **Limited Data Memory:** 2 KB data BRAM
- **No Multiply/Divide:** RV32I base only (no M-extension)

---

## Future Enhancements

- [ ] Add RV32M extension (multiply/divide instructions)
- [ ] Implement branch prediction to reduce control hazards
- [ ] Add performance counters (cycle count, stalls, flushes)
- [ ] Support for compressed instructions (RV32IC)
- [ ] Integration with FreeRTOS or bare-metal C programs
- [ ] Expand memory via external DRAM controller

---

## References

- [RISC-V ISA Specification](https://riscv.org/technical/specifications/)
- [PYNQ Framework Documentation](http://www.pynq.io/)
- [AXI Protocol Specification](https://developer.arm.com/documentation/ihi0022/e/)

---

## License

This project is developed as part of academic coursework at TU Munich. Please contact the authors for usage permissions.

---

## Acknowledgments

Special thanks to the Chair of Computer Architecture and Operating Systems at TU Munich for project guidance and resources.

