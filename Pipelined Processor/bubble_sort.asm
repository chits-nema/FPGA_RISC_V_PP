# RISC-V Bubble Sort for 32 Signed Integers
# Sorts 32 integers in place using only R, I, branch, jal, and lui instructions
# Array starts at address 0x40 in data memory

.data
    .align 2
    # Sample array of 32 signed integers (you can modify these values)
    array: .word 15, -3, 7, 22, -8, 1, 19, -12, 4, 11, -5, 8, 16, -1, 3, 25
           .word -9, 6, 13, -7, 2, 18, -4, 9, 14, -2, 5, 20, -6, 235, 17, -10

.text
.globl _start

_start:
    # Load base address of array into a0
    lui a0, 0x0          # Upper 20 bits
    addi a0, a0, 0x40    # a0 = base address (0x40)
    
    # Initialize outer loop counter: n-1 = 31 passes
    addi t0, zero, 31    # t0 = outer loop counter (31 passes)
    
outer_loop:
    # Check if outer loop is done
    beq t0, zero, done
    
    # Initialize inner loop counter
    addi t1, zero, 31    # t1 = inner loop counter
    
    # Reset array pointer for inner loop
    addi a1, a0, 0       # a1 = current position in array
    
inner_loop:
    # Check if inner loop is done
    beq t1, zero, outer_continue
    
    # Load two adjacent elements
    lw t2, 0(a1)         # t2 = array[i]
    lw t3, 4(a1)         # t3 = array[i+1]
    
    # Compare array[i] and array[i+1]
    # If array[i] <= array[i+1], skip swap
    slt t4, t3, t2       # t4 = 1 if array[i+1] < array[i], else 0
    beq t4, zero, no_swap
    
    # Swap: array[i] and array[i+1]
    sw t3, 0(a1)         # array[i] = t3 (was array[i+1])
    sw t2, 4(a1)         # array[i+1] = t2 (was array[i])
    
no_swap:
    # Move to next pair
    addi a1, a1, 4       # Increment pointer by 4 bytes
    addi t1, t1, -1      # Decrement inner loop counter
    jal zero, inner_loop # Jump back to inner loop
    
outer_continue:
    # Decrement outer loop counter
    addi t0, t0, -1
    jal zero, outer_loop # Jump back to outer loop
    
done:
    # Sorting complete - infinite loop or exit
    jal zero, done       # Loop here (or add your exit code)


# Notes:
# - Array base address: 0x40
# - Array size: 32 signed integers (128 bytes total)
# - Uses bubble sort algorithm with optimization (n-1 passes)
# - Only uses: R-type (slt, add, sub, etc.), I-type (addi, lw, sw, etc.), 
#   branch (beq), jal, and lui instructions
#
# Register usage:
# a0: Base address of array (0x40)
# a1: Current position pointer in array
# t0: Outer loop counter (number of passes remaining)
# t1: Inner loop counter (comparisons in current pass)
# t2: First element in comparison (array[i])
# t3: Second element in comparison (array[i+1])
# t4: Comparison result