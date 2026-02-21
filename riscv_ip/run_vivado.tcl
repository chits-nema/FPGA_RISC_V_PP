# ========================================================
# Vivado Simulation Script for Bubble Sort Test
# ========================================================
# Usage: vivado -mode batch -source run_vivado.tcl

puts "========================================"
puts "  RISC-V Pipeline - Vivado Simulation"
puts "========================================"

# Create simulation project
create_project -force sim_project ./sim_project -part xc7z020clg400-1

# Add design files
add_files -fileset sources_1 {
    top_module.v
    hazard_unit.v
    program_counter.v
    IF_ID.v
    reg_file.v
    controller.v
    extend_unit.v
    ID_EX.v
    alu.v
    EX_MA.v
    MA_WB.v
    multiplexer.v
    generic_building_blocks.v
    main_decoder.v
    ALU_Decoder.v
}

# Add testbench
add_files -fileset sim_1 tb_bubble_sort.v

# Set top module
set_property top tb_bubble_sort [get_filesets sim_1]

# Run elaboration
puts "\n\[1\] Elaborating design..."
synth_design -top tb_bubble_sort -part xc7z020clg400-1 -mode out_of_context

# Launch simulation
puts "\n\[2\] Launching simulation..."
launch_simulation

# Run simulation (100us should be enough)
puts "\n\[3\] Running simulation for 100us..."
run 100us

# Save waveform
puts "\n\[4\] Saving waveform..."
close_sim

puts "\n========================================" 
puts "  Simulation Complete"
puts "========================================"
puts "Check simulation log in sim_project/sim_project.sim/"
