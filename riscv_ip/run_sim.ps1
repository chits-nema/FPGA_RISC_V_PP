# ========================================================
# RISC-V Pipeline Bubble Sort Simulation Script
# ========================================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  RISC-V Pipeline - Simulation" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Check if Icarus Verilog is installed
$iverilog = Get-Command iverilog -ErrorAction SilentlyContinue
$vvp = Get-Command vvp -ErrorAction SilentlyContinue

if ($iverilog -and $vvp) {
    Write-Host "`n[1] Using Icarus Verilog (iverilog)" -ForegroundColor Green
    
    # Compile all Verilog files
    Write-Host "[2] Compiling..." -ForegroundColor Yellow
    
    $files = @(
        "tb_bubble_sort.v",
        "top_module.v",
        "hazard_unit.v",
        "program_counter.v",
        "IF_ID.v",
        "reg_file.v",
        "controller.v",
        "extend_unit.v",
        "ID_EX.v",
        "alu.v",
        "EX_MA.v",
        "MA_WB.v",
        "multiplexer.v",
        "generic_building_blocks.v",
        "main_decoder.v",
        "ALU_Decoder.v"
    )
    
    iverilog -g2012 -o sim.vvp @files
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    ✓ Compilation successful" -ForegroundColor Green
        
        # Run simulation
        Write-Host "[3] Running simulation..." -ForegroundColor Yellow
        vvp sim.vvp
        
        if (Test-Path "bubble_sort.vcd") {
            Write-Host "`n[4] Waveform saved to: bubble_sort.vcd" -ForegroundColor Green
            Write-Host "    View with: gtkwave bubble_sort.vcd" -ForegroundColor Cyan
        }
        
        # Cleanup
        if (Test-Path "sim.vvp") {
            Remove-Item sim.vvp
        }
    } else {
        Write-Host "    ✗ Compilation failed!" -ForegroundColor Red
    }
    
} else {
    Write-Host "`n[ERROR] Icarus Verilog not found!" -ForegroundColor Red
    Write-Host "`nInstall options:" -ForegroundColor Yellow
    Write-Host "  1. Icarus Verilog: https://bleyer.org/icarus/" -ForegroundColor Cyan
    Write-Host "  2. Or use Vivado Simulator (see run_vivado.tcl)" -ForegroundColor Cyan
    Write-Host "`nAlternatively, run in Vivado:" -ForegroundColor Yellow
    Write-Host "  vivado -mode batch -source run_vivado.tcl" -ForegroundColor Cyan
}

Write-Host ""
