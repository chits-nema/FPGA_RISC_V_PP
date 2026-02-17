# RISC-V Bubble Sort for 32 Signed Integers
.text
.globl _start

_start:
    # Load base address of array into a0
    lui a0, 0x1          # a0 = 0x1000 (data RAM base)
    addi a0, a0, 0x40    # a0 = 0x1040 (array start) This offset is common for stack space, global variables, etc.
    
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
    # Write status flag with the MAGIC NUMBER at 0x2000
    lui a2, 0x2              # a2 = 0x2000
    lui a3, 0xDEADF          # a3 = 0xDEADF000
    addi a3, a3, -273        # a3 = 0xDEADBEEF
    sw a3, 0(a2)             # Write DEADBEEF to 0x2000
    
    # Infinite loop
    jal zero, done
