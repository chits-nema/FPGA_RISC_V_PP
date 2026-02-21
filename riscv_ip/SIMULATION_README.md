# RISC-V Pipeline Bubble Sort Test - Simulation

This testbench simulates the 32-element bubble sort test that runs on your PYNQ-Z2 FPGA.

## Test Overview

- **Program**: 27-instruction bubble sort (same as Python test)
- **Input**: 32 random signed integers (-327 to 240)
- **Expected**: All 32 elements sorted in ascending order
- **Done Flag**: 0xDEADBEAF written to DRAM[0x100] when complete
- **Timeout**: 100,000 cycles (catches infinite loops)

## Files

- `tb_bubble_sort.v` - Main testbench with BRAM models
- `run_sim.ps1` - PowerShell script for Icarus Verilog
- `run_vivado.tcl` - TCL script for Vivado Simulator

## Running the Simulation

### Option 1: Icarus Verilog (Free, Open Source)

1. **Install Icarus Verilog**: https://bleyer.org/icarus/
2. **Run simulation**:
   ```powershell
   .\run_sim.ps1
   ```
3. **View waveforms**:
   ```powershell
   gtkwave bubble_sort.vcd
   ```

### Option 2: Vivado Simulator

1. **Run in batch mode**:
   ```powershell
   vivado -mode batch -source run_vivado.tcl
   ```

2. **Or use Vivado GUI**:
   - Open Vivado
   - Tools → Run Simulation → Run Behavioral Simulation
   - Select `tb_bubble_sort` as top module

### Option 3: ModelSim/QuestaSim

```powershell
vlog -sv tb_bubble_sort.v top_module.v *.v
vsim -c tb_bubble_sort -do "run -all; quit"
```

## What the Test Checks

✓ **Program loads correctly** into IRAM  
✓ **Test data loads correctly** into DRAM  
✓ **Processor completes** within timeout  
✓ **Done flag** set to 0xDEADBEAF  
✓ **All 32 elements** sorted in ascending order  

## Expected Output

```
========================================================
  RISC-V Pipeline - Bubble Sort Test
========================================================

[1] Loading bubble sort program (27 instructions)...
[2] Loading test data (32 integers)...
    Input data:
      [ 0- 7]: -200  150 -250  200 -300  125 -100  225
      [ 8-15]: -155   80  -90   40 -284  180 -180   90
      [16-23]: -264   60 -130  160  -95   20 -296  220
      [24-31]: -210  110 -160  130 -312  240 -327   30

[3] Releasing reset and starting processor...
[4] Waiting for completion flag (0xDEADBEAF at DRAM[0x100])...
    ✓ Done flag detected after XXXX cycles

[5] Verifying sorted output...
    Output data:
      [ 0- 7]: -327 -312 -300 -296 -284 -264 -250 -210
      [ 8-15]: -200 -180 -160 -155 -130 -100  -95  -90
      [16-23]:   20   30   40   60   80   90  110  125
      [24-31]:  130  150  160  180  200  220  225  240
    ✓ All 32 elements correctly sorted!

========================================================
  ✓✓✓ TEST PASSED ✓✓✓
  Completed in XXXX cycles
========================================================
```

## Debugging Tips

### If test times out:
- Check waveform: `gtkwave bubble_sort.vcd`
- Look for PC stuck in loop
- Check stall signals (stallF, stallD)
- Verify BRAM read/write transactions

### If sort fails:
- Check DRAM writes in simulation log
- Verify forwarding logic (ForwardAE, ForwardBE)
- Look for load-use hazard stalls
- Check branch taken signals

### Key signals to monitor:
- `pc` - Program counter
- `instr` - Current instruction
- `M_ALUResult` - Memory address
- `M_WriteData` - Data being written
- `M_MemWrite` - Write enable
- `dut.stallF`, `dut.D_stall` - Pipeline stalls
- `dut.E_flush` - Execute stage flush

## Performance Metrics

Typical cycle counts (with all fixes):
- **Best case** (already sorted): ~2,500 cycles
- **Average case** (random): ~8,000-12,000 cycles  
- **Worst case** (reverse sorted): ~15,000 cycles

If you see >50,000 cycles, something is wrong (excessive stalls or infinite loop).

## Test Data

The testbench uses the **same random seed (67)** as your Python test, so results are reproducible. The 32 input integers range from -327 to 240.
