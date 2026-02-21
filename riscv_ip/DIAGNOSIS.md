# Pipeline Hazard Bug Diagnosis

## The Problem

Your bubble sort fails with zeros appearing because of **MISSING LOAD-USE HAZARD DETECTION** in `hazard_unit.v`.

## Root Cause

The current hazard unit only detects load-use hazards when:
- Load instruction is in **E or M stage**
- Dependent instruction is in **D stage**

But it **DOES NOT** detect when:
- Load instruction is in **M stage**  
- Dependent instruction is in **E stage** (using Rs1E or Rs2E)

## The Bubble Sort Pattern That Fails

```assembly
lw t2, 0(a1)      # Cycle N: Load t2 (in E stage)
lw t3, 4(a1)      # Cycle N+1: Load t3 (in E stage), t2 now in M stage  
slt t4, t3, t2    # Cycle N+2: Uses t2 and t3 in E stage
                  #   - t2 is in W stage → can forward ✓
                  #   - t3 is in M stage → CANNOT forward (still loading) ✗
                  #   - Hazard unit doesn't detect this!
                  #   - slt uses OLD register value → WRONG RESULT
```

## Why Zeros Appear

When `slt` uses stale data:
1. Comparison produces wrong result (`t4` becomes wrong)
2. Wrong swap decisions are made
3. Stores write values to wrong locations
4. Unwritten memory locations contain zeros from initialization
5. Array gets corrupted with zeros

## The Fix

In `hazard_unit.v`, you need to **ALSO** check if a load in M stage conflicts with Rs1E or Rs2E:

```verilog
// CURRENT CODE (INCOMPLETE):
assign lwstall = (ResultSrcE & ((Rs1D == RdE) | (Rs2D == RdE))) |
                 (ResultSrcM & ((Rs1D == RdM) | (Rs2D == RdM)));

// FIXED CODE (add E-stage checking):
assign lwstall = (ResultSrcE & ((Rs1D == RdE) | (Rs2D == RdE))) |
                 (ResultSrcM & ((Rs1D == RdM) | (Rs2D == RdM))) |
                 (ResultSrcM & ((Rs1E == RdM) | (Rs2E == RdM)));  // NEW!
//                             ^^^^ Check E stage too! ^^^^
```

You'll also need to add `Rs1E` and `Rs2E` as inputs to the hazard module.

## Testing Steps

1. **First**, run the test with NOPs: [test_nop_version.ipynb](test_nop_version.ipynb)
   - If this passes, it confirms pipeline hazards are the issue
   
2. **Then**, apply the fix to `hazard_unit.v`

3. **Finally**, re-run your original bubble sort test

## Alternative: Quick NOP Test

Load this instruction sequence (has NOP delays):
- Located in: `bubble_sort_with_nops.txt`
- This should work even with broken hazard detection
- Confirms the diagnosis
