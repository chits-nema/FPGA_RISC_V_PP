`timescale 1ns / 1ps
`include "top_module.v"
module rv_pl_tb;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Test tracking
    integer test_num = 0;
    integer errors = 0;
    integer cycle_count = 0;
    
    // Instantiate the processor
    rv_pl dut(
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (rst_n)
            cycle_count = cycle_count + 1;
        else
            cycle_count = 0;
    end
    
    // ========================================================================
    // Test Tasks
    // ========================================================================
    
    task reset_processor;
        begin
            rst_n = 0;  // Assert reset (active-low)
            repeat(3) @(posedge clk);
            rst_n = 1;  // Release reset
            @(posedge clk);
            cycle_count = 0;
            $display("\n[%0t] Processor reset complete", $time);
        end
    endtask
    
    task display_test;
        input [200*8:1] test_name;
        begin
            test_num = test_num + 1;
            $display("\n========================================");
            $display("TEST %0d: %s", test_num, test_name);
            $display("========================================");
        end
    endtask
    
    task check_register;
        input [4:0] reg_addr;
        input [31:0] expected_value;
        input [100*8:1] test_desc;
        reg [31:0] actual_value;
        begin
            actual_value = dut.RF.rf[reg_addr];
            if (actual_value !== expected_value) begin
                $display("[FAIL] %s", test_desc);
                $display("       Register x%0d = 0x%h, expected 0x%h", 
                         reg_addr, actual_value, expected_value);
                errors = errors + 1;
            end else begin
                $display("[PASS] %s: x%0d = 0x%h", test_desc, reg_addr, actual_value);
            end
        end
    endtask
    
    task check_memory;
        input [31:0] addr;
        input [31:0] expected_value;
        input [100*8:1] test_desc;
        reg [31:0] actual_value;
        begin
            actual_value = dut.DMEM.RAM[addr[31:2]];
            if (actual_value !== expected_value) begin
                $display("[FAIL] %s", test_desc);
                $display("       Memory[0x%h] = 0x%h, expected 0x%h", 
                         addr, actual_value, expected_value);
                errors = errors + 1;
            end else begin
                $display("[PASS] %s: Mem[0x%h] = 0x%h", test_desc, addr, actual_value);
            end
        end
    endtask
    
    task wait_cycles;
        input integer n;
        begin
            repeat(n) @(posedge clk);
            #1;  // clearSmall delay to allow negedge writes to complete
        end
    endtask
    
    task load_program;
        input [200*8:1] program_name;
        begin
            $display("\n[%0t] Loading program: %s", $time, program_name);
            // Program will be loaded via $readmemh in the instruction memory
        end
    endtask
    
    // ========================================================================
    // Pipeline State Monitoring
    // ========================================================================
    
    task display_pipeline_state;
        begin
            $display("\n--- Pipeline State (Cycle %0d) ---", cycle_count);
            $display("FETCH:   PC=0x%h, Instr=0x%h", dut.F_pc, dut.F_instr);
            $display("DECODE:  PC=0x%h, Instr=0x%h, Rs1=%0d, Rs2=%0d, Rd=%0d", 
                     dut.D_pc, dut.D_instr, dut.D_Rs1, dut.D_Rs2, dut.D_Rd);
            $display("EXECUTE: PC=0x%h, ALUResult=0x%h, Rs1=%0d, Rs2=%0d, Rd=%0d", 
                     dut.E_pc, dut.E_ALUResult, dut.E_Rs1, dut.E_Rs2, dut.E_Rd);
            $display("MEMORY:  ALUResult=0x%h, WriteData=0x%h, Rd=%0d, MemWrite=%b", 
                     dut.M_ALUResult, dut.M_WriteData, dut.M_Rd, dut.M_MemWrite);
            $display("WB:      Result=0x%h, Rd=%0d, RegWrite=%b", 
                     dut.W_Result, dut.W_Rd, dut.W_RegWrite);
            $display("HAZARDS: StallF=%b, StallD=%b, FlushD=%b, FlushE=%b, FwdA=%b, FwdB=%b",
                     dut.stallF, dut.D_stall, dut.D_flush, dut.E_flush, 
                     dut.ForwardAE, dut.ForwardBE);
        end
    endtask
    
    // ========================================================================
    // Program Loading Task
    // ========================================================================
    
    task load_program_from_file;
        input [200*8:1] filename;
        begin
            $display("[INFO] Loading program from: %s", filename);
            $readmemh(filename, dut.IMEM.RAM);
            $display("[INFO] Program loaded successfully");
        end
    endtask
    
    task load_data_from_file;
        input [200*8:1] filename;
        begin
            $display("[INFO] Loading data memory from: %s", filename);
            $readmemh(filename, dut.DMEM.RAM);
            $display("[INFO] Data memory loaded successfully");
        end
    endtask
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    
    initial begin
        $display("========================================");
        $display("RISC-V Pipelined Processor Testbench");
        $display("========================================");
        
        // Initialize
        rst_n = 1;
        
        // ====================================================================
        // TEST 1: Reset Test
        // ====================================================================
        display_test("Processor Reset");
        reset_processor();
        
        // Check initial state
        $display("Checking initial state after reset...");
        check_register(0, 32'h0, "x0 is hardwired to 0");
        check_register(1, 32'h0, "x1 initialized to 0");
        
        if (dut.F_pc !== 32'h0) begin
            $display("[FAIL] PC not reset to 0: PC = 0x%h", dut.F_pc);
            errors = errors + 1;
        end else begin
            $display("[PASS] PC reset to 0x00000000");
        end
        
        // ====================================================================
        // TEST 2: Simple Arithmetic Instructions
        // ====================================================================
        display_test("Simple Arithmetic (ADDI, ADD, SUB)");
        
        // Manually load simple test program FIRST
        // addi x1, x0, 5     -> x1 = 5
        // addi x2, x0, 10    -> x2 = 10
        // add  x3, x1, x2    -> x3 = 15
        // sub  x4, x2, x1    -> x4 = 5
        $display("[INFO] Loading test program manually...");
        dut.IMEM.RAM[0] = 32'h00500093; // addi x1, x0, 5
        dut.IMEM.RAM[1] = 32'h00A00113; // addi x2, x0, 10
        dut.IMEM.RAM[2] = 32'h002081B3; // add x3, x1, x2
        dut.IMEM.RAM[3] = 32'h40110233; // sub x4, x2, x1
        $display("[INFO] Program loaded successfully");
        
        // Now reset so PC starts at 0
        reset_processor();
        
        wait_cycles(10);
        
        check_register(1, 32'd5, "x1 = 5 (addi)");
        check_register(2, 32'd10, "x2 = 10 (addi)");
        check_register(3, 32'd15, "x3 = 15 (add)");
        check_register(4, 32'd5, "x4 = 5 (sub)");
        
        // ====================================================================
        // TEST 3: Data Forwarding Test
        // ====================================================================
        display_test("Data Forwarding (RAW Hazard)");
        
        load_program_from_file("test_programs/test_forwarding.hex");
        reset_processor();
        
        wait_cycles(10);
        
        check_register(1, 32'd5, "x1 = 5");
        check_register(2, 32'd6, "x2 = 6 (forwarded x1)");
        check_register(3, 32'd7, "x3 = 7 (forwarded x2)");
        
        // ====================================================================
        // TEST 4: Load-Use Hazard (Stall Test)
        // ====================================================================
        display_test("Load-Use Hazard Detection");
        
        // Load data memory
        load_data_from_file("test_programs/test_load_data.hex");
        
        // Load program
        load_program_from_file("test_programs/test_load_use.hex");
        reset_processor();
        
        wait_cycles(12);
        
        check_register(1, 32'hDEADBEEF, "x1 loaded from memory");
        check_register(2, 32'hDEADBEF0, "x2 computed after stall");
        
        // ====================================================================
        // TEST 5: Store and Load Instructions
        // ====================================================================
        display_test("Store and Load Instructions");
        
        load_program_from_file("test_programs/test_memory.hex");
        reset_processor();
        
        wait_cycles(10);
        
        check_register(10, 32'h01234000, "x10 = 0x01234000 (lui)");
        check_memory(32'h0, 32'h01234000, "Memory[0] stored correctly");
        check_register(11, 32'h01234000, "x11 loaded from memory");
        
        // ====================================================================
        // TEST 6: Branch Instruction
        // ====================================================================
        display_test("Branch Equal (BEQ)");
        
        load_program_from_file("test_programs/test_branch.hex");
        reset_processor();
        
        wait_cycles(12);
        
        check_register(1, 32'd5, "x1 = 5");
        check_register(2, 32'd5, "x2 = 5");
        // x3 and x4 should keep their old values if branch correctly skips instructions
        // x3 was set to 7 in Test 3, x4 retains value from earlier execution
        check_register(3, 32'd7, "x3 = 7 (instruction skipped by branch, retains old value)");
        check_register(4, 32'd1, "x4 = 1 (instruction skipped by branch, retains old value)");
        check_register(5, 32'd3, "x5 = 3 (branch target executed)");
        
        // ====================================================================
        // TEST 7: JAL (Jump and Link)
        // ====================================================================
        display_test("Jump and Link (JAL)");
        
        load_program_from_file("test_programs/test_jal.hex");
        reset_processor();
        
        wait_cycles(10);
        
        check_register(1, 32'h4, "x1 = 4 (return address PC+4)");
        // x2 should keep old value (5 from branch test) if jump correctly skips instruction
        check_register(2, 32'h5, "x2 = 5 (instruction skipped by jump, retains old value)");
        check_register(3, 32'h3, "x3 = 3 (after jump target)");
        
        // ====================================================================
        // TEST 8: Multiple Hazards
        // ====================================================================
        display_test("Complex Program with Multiple Hazards");
        
        load_data_from_file("test_programs/test_complex_data.hex");
        load_program_from_file("test_programs/test_complex.hex");
        reset_processor();
        
        wait_cycles(15);
        
        check_register(1, 32'd101, "x1 = 101");
        check_register(2, 32'd200, "x2 = 200");
        check_register(3, 32'd301, "x3 = 301");
        check_memory(32'h4, 32'd301, "Memory[4] = 301");
        
        // ====================================================================
        // TEST 9: Pipeline Visualization
        // ====================================================================
        display_test("Pipeline State Visualization");
        
        load_program_from_file("test_programs/test_arithmetic.hex");
        reset_processor();
        
        wait_cycles(8);
        
        // ====================================================================
        // Summary
        // ====================================================================
        #100;
        $display("\n========================================");
        $display("TEST SUMMARY");
        $display("========================================");
        $display("Total Tests: %0d", test_num);
        $display("Errors: %0d", errors);
        $display("========================================");
        
        if (errors == 0) begin
            $display("✓ ALL TESTS PASSED!");
        end else begin
            $display("✗ SOME TESTS FAILED");
        end
        
        $display("\nSimulation complete at time %0t", $time);
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;  // 100us timeout
        $display("\n[ERROR] Simulation timeout!");
        $finish;
    end

endmodule