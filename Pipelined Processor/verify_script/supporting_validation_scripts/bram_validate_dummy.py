from pynq import Overlay, MMIO
import time
import random

# AXI base addresses
BRAM_IRAM_BASE     = 0x40000000
BRAM_DATA_BASE     = 0x42000000
GPIO_BASE          = 0x41200000
BRAM_SIZE          = 0x4000

# GPIO registers
RST_REG            = 0x0000
DONE_REG           = 0x0008

# Data BRAM offsets
DATA_RAM_START     = 0x1000
ARRAY_START_OFFSET = 0x0040
STATUS_FLAG_OFFSET = 0x1000

# Derived
array_base         = DATA_RAM_START + ARRAY_START_OFFSET  # 0x1040
status_addr        = DATA_RAM_START + STATUS_FLAG_OFFSET  # 0x2000

# Config
ARRAY_SIZE         = 32
MAGIC_NUMBER       = 0xDEADBEEF
MAX_TIMEOUT        = 10
POLL_DELAY         = 0.001

print(f"array_base  = {hex(array_base)}  (expected 0x1040)")
print(f"status_addr = {hex(status_addr)}  (expected 0x2000)")

ol = Overlay("design_1_wrapper.bit")

bram_iram = MMIO(ol.mem_dict['axi_bram_ctrl_0']['phys_addr'],
                 ol.mem_dict['axi_bram_ctrl_0']['addr_range'])
bram_dram = MMIO(ol.mem_dict['axi_bram_ctrl_1']['phys_addr'],
                 ol.mem_dict['axi_bram_ctrl_1']['addr_range'])
gpio      = MMIO(GPIO_BASE, 0x10000)

print(f"IRAM @ {hex(bram_iram.base_addr)}  (expected 0x40000000)")
print(f"DRAM @ {hex(bram_dram.base_addr)}  (expected 0x42000000)")
print(f"GPIO @ {hex(gpio.base_addr)}       (expected 0x41200000)")

instructions = [
    "00001537", "04050513", "01f00293", "02028e63",
    "01f00313", "00050593", "02030463", "0005a383",
    "0045ae03", "007e2eb3", "000e8663", "01c5a023",
    "0075a223", "00458593", "fff30313", "fddff06f",
    "fff28293", "fc9ff06f", "00002637", "deadc6b7",
    "eef68693", "00d62023", "ff1ff06f"
]

for i, instr in enumerate(instructions):
    bram_iram.write(i * 4, int(instr, 16))

# Verify
ok = all(bram_iram.read(i*4) == int(h,16) for i,h in enumerate(instructions))
print(f"Instructions loaded: {len(instructions)}  Verify: {'✓' if ok else '✗ MISMATCH'}")

# Force CH1 to output — must be done before reset
gpio.write(0x0004, 0x00000000)   # CH1 TRI = all outputs
time.sleep(0.01)
verify_tri = gpio.read(0x0004)
print(f"CH1 TRI after fix: {hex(verify_tri)}  (expected 0x0)")

# Now assert reset
gpio.write(RST_REG, 0x0)
time.sleep(0.1)
print(f"Reset asserted — CH1 DATA: {hex(gpio.read(RST_REG))}")

# Assert reset before touching memory
gpio.write(0x0004, 0x00000000)  # TRI = output
gpio.write(RST_REG, 0x0)        # hold in reset

# Clear sentinel
bram_dram.write(status_addr, 0x00000000)

# Write array
for i, val in enumerate(test_array):
    bram_dram.write(array_base + i * 4, val & 0xFFFFFFFF)

# Verify first 8
print("Verify first 8:")
ok = True
for i in range(8):
    got = bram_dram.read(array_base + i * 4)
    signed = got if got < 0x80000000 else got - 0x100000000
    match = "✓" if signed == test_array[i] else "✗"
    if signed != test_array[i]: ok = False
    print(f"  [{i}] expected={test_array[i]:5d}  got={signed:5d}  {match}")

print(f"Sentinel @ {hex(status_addr)}: {hex(bram_dram.read(status_addr))}  (expected 0x0)")

# 1. ASSERT RESET FIRST (Stop the core to ensure clean start)
# Direct connection to Active Low Reset (rst_n)
# Write 0 -> rst_n=0 (Reset Active / Halt)
gpio.write(RST_REG, 0x0)
print(f"Reset Asserted (Core Halted)")
time.sleep(0.1)

# 2. RELEASE RESET (Start the core)
# Write 1 -> rst_n=1 (Reset Inactive / Run)
gpio.write(RST_REG, 0x1)
print(f"Reset released — rst_n=1 (Core Running)")

# 3. POLL FOR COMPLETION
print(f"done_flag before: {hex(gpio.read(DONE_REG))}")

start_time = time.time()
iterations = 0

while True:
    # Read the Done Signal (mapped to GPIO)
    status = gpio.read(DONE_REG)
    
    # Check bit 0 (assuming done_flag is connected to bit 0)
    if status & 0x1: 
        elapsed = time.time() - start_time
        print(f"\n✓ COMPLETION DETECTED!")
        print(f"  Time:       {elapsed:.3f}s")
        print(f"  Iterations: {iterations}")
        # Optional: Check if the magic number is also in RAM as a double-check
        # print(f"  Sentinel:   {hex(bram_dram.read(status_addr))}")
        break
    
    if time.time() - start_time > MAX_TIMEOUT:
        print(f"\n✗ TIMEOUT after {MAX_TIMEOUT}s")
        print(f"  done_flag: {hex(status)}")
        # print(f"  Sentinel:  {hex(bram_dram.read(status_addr))}")
        break
    
    iterations += 1
    if iterations % 1000 == 0:
        print(f"  {iterations} iters ({time.time()-start_time:.2f}s) flag={hex(status)}")
    
    time.sleep(POLL_DELAY)

    results = []
for i in range(ARRAY_SIZE):
    word = bram_dram.read(array_base + i * 4)
    signed = word if word < 0x80000000 else word - 0x100000000
    results.append(signed)

print(f"Got:      {results}")
print(f"Expected: {golden}")
print(f"\n{'✓ SORT CORRECT' if results == golden else '✗ SORT INCORRECT'}")

if results != golden:
    for i,(g,r) in enumerate(zip(golden, results)):
        if g != r:
            print(f"  Mismatch [{i}]: expected {g}, got {r}")