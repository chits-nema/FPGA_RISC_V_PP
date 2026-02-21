# Vivado TCL script to run bubble sort testbench simulation

# Create simulation directory
file mkdir sim_results

# Compile all Verilog files
read_verilog -sv tb_bubble_sort.v
read_verilog -sv top_module.v
read_verilog -sv controller.v
read_verilog -sv hazard_unit.v
read_verilog -sv main_decoder.v
read_verilog -sv ALU_Decoder.v
read_verilog -sv alu.v
read_verilog -sv reg_file.v
read_verilog -sv extend_unit.v
read_verilog -sv program_counter.v
read_verilog -sv multiplexer.v
read_verilog -sv generic_building_blocks.v
read_verilog -sv IF_ID.v
read_verilog -sv ID_EX.v
read_verilog -sv EX_MA.v
read_verilog -sv MA_WB.v

# Set top module
set_property top tb_bubble_sort [current_fileset]

# Launch simulation
launch_simulation

# Run simulation for 2ms (enough time for bubble sort to complete)
run 2ms

# Close simulation
close_sim

puts "==================================="
puts "Simulation Complete!"
puts "Check simulation output above for results"
puts "==================================="
