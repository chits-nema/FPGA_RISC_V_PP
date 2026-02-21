#!/usr/bin/env python3
"""Decode RISC-V B-type instruction immediate field"""

def decode_b_type_immediate(instr):
    """
    B-type immediate encoding:
    imm[12|10:5] = inst[31:25]
    imm[4:1|11] = inst[11:7]
    
    Actual layout in instruction:
    bit 31: imm[12] (sign bit)
    bit 30-25: imm[10:5]
    bit 11-8: imm[4:1]  
    bit 7: imm[11]
    bit 0: always 0 (2-byte aligned)
    """
    # Extract fields
    imm_12 = (instr >> 31) & 0x1          # bit 31
    imm_11 = (instr >> 7) & 0x1           # bit 7
    imm_10_5 = (instr >> 25) & 0x3F       # bits 30-25
    imm_4_1 = (instr >> 8) & 0xF          # bits 11-8
    
    # Reconstruct 13-bit immediate (bit 0 is always 0)
    imm_unsigned = (imm_12 << 12) | (imm_11 << 11) | (imm_10_5 << 5) | (imm_4_1 << 1)
    
    # Sign extend to 32 bits
    if imm_12:
        # Negative number - sign extend
        imm_signed = imm_unsigned - (1 << 13)
    else:
        imm_signed = imm_unsigned
    
    return imm_signed

# Test with instruction 21
instr_21 = 0xFA000EE3
offset_21 = decode_b_type_immediate(instr_21)

print(f"Instruction: 0x{instr_21:08X}")
print(f"Binary: {instr_21:032b}")
print(f"")
print(f"Immediate breakdown:")
print(f"  imm[12]   (bit 31):    {(instr_21 >> 31) & 0x1}")
print(f"  imm[11]   (bit 7):     {(instr_21 >> 7) & 0x1}")
print(f"  imm[10:5] (bits 30-25): {((instr_21 >> 25) & 0x3F):06b} = {(instr_21 >> 25) & 0x3F}")
print(f"  imm[4:1]  (bits 11-8):  {((instr_21 >> 8) & 0xF):04b} = {(instr_21 >> 8) & 0xF}")
print(f"")
print(f"Reconstructed offset: {offset_21} (0x{offset_21 & 0xFFFFFFFF:08X})")
print(f"")

# Test expected behavior
PC = 0x58
target = PC + offset_21
print(f"Branch from PC=0x{PC:02X} (88 decimal)")
print(f"Target = 0x{PC:02X} + {offset_21} = 0x{target & 0xFF:02X} ({target} decimal)")
print(f"")

# What offset would give 0x20?
actual_target = 0x20
needed_offset = actual_target - PC
print(f"To reach 0x{actual_target:02X}, offset would need to be: {needed_offset} (0x{needed_offset & 0xFFFFFFFF:08X})")

# Decode other branch instructions for comparison
print("\n" + "="*60)
print("Checking all branch instructions in program:")
print("="*60)

branches = [
    (5, 0x04048263, 0x14, "beq x9, x0, +68 (to DONE)"),
    (9, 0x02048663, 0x24, "beq x9, x0, +44 (to outer incr)"),
    (15, 0x00048663, 0x3C, "beq x9, x0, +12 (skip swap)"),
    (19, 0xFC000AE3, 0x4C, "beq x0, x0, -44 (to inner loop)"),
    (21, 0xFA000EE3, 0x54, "beq x0, x0, -68 (to outer loop)"),
]

for idx, code, pc, desc in branches:
    offset = decode_b_type_immediate(code)
    target = pc + offset
    print(f"[{idx:2d}] PC=0x{pc:02X}: {desc}")
    print(f"     0x{code:08X} -> offset={offset:+4d} (0x{offset&0xFFFF:04X}) -> target=0x{target&0xFF:02X}")
