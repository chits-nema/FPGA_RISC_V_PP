# Testing python file to check if the external bram implementation works properly
from pynq import Overlay
import time

# Load the overlay (adjust filename to match your bitstream)
overlay = Overlay('design.bit')

# Get handles to BRAMs
imem = overlay.imem
dmem = overlay.dmem

# Get handle to wrapper for control signals
processor = overlay.rv_pl_wrapper

def load_hex_program(filename):
    """Load a hex program file and return list of instructions"""
    program = []
    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if line:  # Skip empty lines
                instr = int(line, 16)  # Convert hex string to integer
                program.append(instr)
    return program

def load_program_to_imem(program):
    """Write program instructions to instruction memory"""
    for i, instr in enumerate(program):
        imem[i] = instr
    print(f"Loaded {len(program)} instructions into IMEM")

def reset_processor():
    """Reset the processor"""
    processor.rst = 0  # Assert reset (active low)
    time.sleep(0.01)
    processor.rst = 1  # Deassert reset
    print("Processor reset complete")

def run_until_done(timeout=1000):
    """Run processor until done_flag is set or timeout"""
    cycles = 0
    while cycles < timeout:
        if processor.done_flag:
            print(f"Program completed in ~{cycles} cycles")
            return True
        time.sleep(0.001)
        cycles += 1
    print(f"Timeout after {timeout} cycles")
    return False

def read_dmem_word(address):
    """Read a word from data memory at given address"""
    # Address should be word-aligned
    word_addr = address >> 2
    return dmem[word_addr]

def run_test(test_name):
    """Run a specific test program"""
    print(f"\n{'='*50}")
    print(f"Running test: {test_name}")
    print(f"{'='*50}")
    
    # Load program
    program = load_hex_program(f'test_programs/{test_name}.hex')
    load_program_to_imem(program)
    
    # Reset and run
    reset_processor()
    success = run_until_done()
    
    if success:
        # Read result from address 0x2000 (where DEADBEEF is written)
        result = read_dmem_word(0x2000)
        print(f"Result at 0x2000: 0x{result:08X}")
        
        if result == 0xDEADBEEF:
            print(f"✓ Test {test_name} PASSED")
        else:
            print(f"✗ Test {test_name} FAILED - unexpected result")
    else:
        print(f"✗ Test {test_name} FAILED - timeout")
    
    return success

# ============ MAIN TEST EXECUTION ============
if __name__ == "__main__":
    # List of available tests
    tests = [
        'test_arithmetic',
        'test_forwarding',
        'test_load_use',
        'test_branch',
        'test_jal',
        'test_memory',
        'test_load_data',
        'test_complex',
        'test_complex_data'
    ]
    
    print("RISC-V Pipelined Processor Test Suite")
    print("="*50)
    
    # Run all tests
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if run_test(test):
                passed += 1
            else:
                failed += 1
        except Exception as e:
            print(f"✗ Test {test} ERROR: {e}")
            failed += 1
    
    # Summary
    print(f"\n{'='*50}")
    print(f"Test Summary: {passed} passed, {failed} failed")
    print(f"{'='*50}")