`timescale 1ns / 1ps
`include "rv_pl_wrapper.v"

module rv_pl_wrapper_tb;

    // Clock and reset
    reg clk;
    reg rst;
    
    // IMEM Interface
    wire [31:0] imem_addr;
    wire [31:0] imem_dout;
    
    // DMEM Interface
    wire [31:0] dmem_addr;
    wire dmem_we;
    wire [31:0] dmem_din;
    wire [31:0] dmem_dout;
    wire done_flag;
    
    // Test tracking
    integer test_num = 0;
    integer errors = 0;
    integer cycle_count = 0;
    
    // External BRAM models
    reg [31:0] IMEM [0:63];  // Instruction memory
    reg [31:0] DMEM [0:63];  // Data memory
    
    // Instantiate the wrapper
    rv_pl_wrapper dut(
        .clk(clk),
        .rst(rst),
        .imem_addr(imem_addr),
        .imem_dout(imem_dout),
        .dmem_addr(dmem_addr),
        .dmem_we(dmem_we),
        .dmem_din(dmem_din),
        .dmem_dout(dmem_dout),
        .done_flag(done_flag)
    );
    
    // IMEM read logic (combinational/async read)
    assign imem_dout = IMEM[imem_addr[31:2]];
    
    // DMEM write logic (synchronous write)
    always @(posedge clk) begin
        if (dmem_we) begin
            DMEM[dmem_addr[31:2]] <= dmem_din;
        end
    end
    
    // DMEM read logic (combinational/async read)
    assign dmem_dout = DMEM[dmem_addr[31:2]];
    
    // Clock generation (10ns period = 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (rst)
            cycle_count = cycle_count + 1;
        else
            cycle_count = 0;
    end
    
    // Monitor done_flag
    always @(posedge clk) begin
        if (done_flag) begin
            $display("\n[%0t] ✓ DONE FLAG SET - Program completed!", $time);
        end
    end
    
    // ========================================================================
    // Test Tasks
    // ========================================================================
    
    task reset_processor;
        begin
            rst = 0;  // Assert reset (active-low)
            repeat(3) @(posedge clk);
            rst = 1;  // Release reset
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
            actual_value = dut.rv_pl.RF.rf[reg_addr];
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
            actual_value = DMEM[addr[31:2]];
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
            #1;  // Small delay to allow negedge writes to complete
        end
    endtask
    
    task load_program_from_file;
        input [200*8:1] filename;
        begin
            $display("[INFO] Loading program from: %s", filename);
            $readmemh(filename, IMEM);
            $display("[INFO] Program loaded successfully");
        end
    endtask
    
    task load_data_from_file;
        input [200*8:1] filename;
        begin
            $display("[INFO] Loading data memory from: %s", filename);
            $readmemh(filename, DMEM);
            $display("[INFO] Data memory loaded successfully");
        end
    endtask
    
    task clear_memories;
        integer i;
        begin
            for (i = 0; i < 64; i = i + 1) begin
                IMEM[i] = 32'h0;
                DMEM[i] = 32'h0;
            end
        end
    endtask
    
    // ========================================================================
    // Pipeline State Monitoring (access internal signals)
    // ========================================================================
    
    task display_pipeline_state;
        begin
            $display("\n--- Pipeline State (Cycle %0d) ---", cycle_count);
            $display("FETCH:   PC=0x%h, Instr=0x%h", dut.rv_pl.F_pc, imem_dout);
            $display("DECODE:  PC=0x%h, Instr=0x%h, Rs1=%0d, Rs2=%0d, Rd=%0d", 
                     dut.rv_pl.D_pc, dut.rv_pl.D_instr, dut.rv_pl.D_Rs1, 
                     dut.rv_pl.D_Rs2, dut.rv_pl.D_Rd);
            $display("EXECUTE: PC=0x%h, ALUResult=0x%h, Rs1=%0d, Rs2=%0d, Rd=%0d", 
                     dut.rv_pl.E_pc, dut.rv_pl.E_ALUResult, dut.rv_pl.E_Rs1, 
                     dut.rv_pl.E_Rs2, dut.rv_pl.E_Rd);
            $display("MEMORY:  ALUResult=0x%h, WriteData=0x%h, Rd=%0d, MemWrite=%b", 
                     dmem_addr, dmem_din, dut.rv_pl.M_Rd, dmem_we);
            $display("WB:      Result=0x%h, Rd=%0d, RegWrite=%b", 
                     dut.rv_pl.W_Result, dut.rv_pl.W_Rd, dut.rv_pl.W_RegWrite);
            $display("HAZARDS: StallF=%b, StallD=%b, FlushD=%b, FlushE=%b, FwdA=%b, FwdB=%b",
                     dut.rv_pl.stallF, dut.rv_pl.D_stall, dut.rv_pl.D_flush, 
                     dut.rv_pl.E_flush, dut.rv_pl.ForwardAE, dut.rv_pl.ForwardBE);
        end
    endtask
    
    // ========================================================================
    // Main Test Sequence
    // ========================================================================
    
    initial begin
        // Setup waveform dump (for GTKWave)
        $dumpfile("rv_pl_wrapper_tb.vcd");
        $dumpvars(0, rv_pl_wrapper_tb);
        
        $display("========================================");
        $display("RISC-V Pipelined Processor Testbench");
        $display("(External BRAM Configuration)");
        $display("========================================");
        
        // Initialize
        rst = 1;
        clear_memories();
        
        // ====================================================================
        // TEST 1: Reset Test
        // ====================================================================
        display_test("Processor Reset");
        reset_processor();
        
        // Check initial state
        $display("Checking initial state after reset...");
        check_register(0, 32'h0, "x0 is hardwired to 0");
        check_register(1, 32'h0, "x1 initialized to 0");
        
        if (dut.rv_pl.F_pc !== 32'h0) begin
            $display("[FAIL] PC not reset to 0: PC = 0x%h", dut.rv_pl.F_pc);
            errors = errors + 1;
        end else begin
            $display("[PASS] PC reset to 0x00000000");
        end
        
        // ====================================================================
        // TEST 2: Simple Arithmetic Instructions
        // ====================================================================
        display_test("Simple Arithmetic (test_arithmetic.hex)");
        
        load_program_from_file("test_programs/test_arithmetic.hex");
        reset_processor();
        
        wait_cycles(10);
        
        check_register(1, 32'd5, "x1 = 5 (addi)");
        check_register(2, 32'd10, "x2 = 10 (addi)");
        check_register(3, 32'd15, "x3 = 15 (add)");
        check_register(4, 32'd5, "x4 = 5 (sub)");
        
        // ====================================================================
        // TEST 3: Data Forwarding Test
        // ====================================================================
        display_test("Data Forwarding (test_forwarding.hex)");
        
        load_program_from_file("test_programs/test_forwarding.hex");
        reset_processor();
        
        wait_cycles(10);
        
        check_register(1, 32'd5, "x1 = 5");
        check_register(2, 32'd6, "x2 = 6 (forwarded x1)");
        check_register(3, 32'd7, "x3 = 7 (forwarded x2)");
        
        // ====================================================================
        // TEST 4: Load-Use Hazard
        // ====================================================================
        display_test("Load-Use Hazard (test_load_use.hex)");
        
        load_data_from_file("test_programs/test_load_data.hex");
        load_program_from_file("test_programs/test_load_use.hex");
        reset_processor();
        
        wait_cycles(15);
        
        check_register(1, 32'hDEADBEEF, "x1 loaded from memory");
        check_register(2, 32'hDEADBEF0, "x2 computed after stall");
        
        // ====================================================================
        // TEST 5: Memory Operations
        // ====================================================================
        display_test("Store and Load (test_memory.hex)");
        
        load_program_from_file("test_programs/test_memory.hex");
        reset_processor();
        
        wait_cycles(12);
        
        check_memory(32'h0, 32'h01234000, "Memory[0] stored correctly");
        check_register(11, 32'h01234000, "x11 loaded from memory");
        
        // ====================================================================
        // TEST 6: Branch Instructions
        // ====================================================================
        display_test("Branch Equal (test_branch.hex)");
        
        load_program_from_file("test_programs/test_branch.hex");
        reset_processor();
        
        wait_cycles(12);
        
        check_register(1, 32'd5, "x1 = 5");
        check_register(2, 32'd5, "x2 = 5");
        check_register(5, 32'd3, "x5 = 3 (branch target executed)");
        
        // ====================================================================
        // TEST 7: JAL
        // ====================================================================
        display_test("Jump and Link (test_jal.hex)");
        
        load_program_from_file("test_programs/test_jal.hex");
        reset_processor();
        
        wait_cycles(10);
        
        check_register(1, 32'h4, "x1 = 4 (return address)");
        check_register(3, 32'h3, "x3 = 3 (after jump)");
        
        // ====================================================================
        // TEST 8: Complex Program
        // ====================================================================
        display_test("Complex Program (test_complex.hex)");
        
        load_data_from_file("test_programs/test_complex_data.hex");
        load_program_from_file("test_programs/test_complex.hex");
        reset_processor();
        
        wait_cycles(20);
        
        check_register(1, 32'd101, "x1 = 101");
        check_register(2, 32'd200, "x2 = 200");
        check_register(3, 32'd301, "x3 = 301");
        check_memory(32'h4, 32'd301, "Memory[4] = 301");
        
        // ====================================================================
        // Pipeline State Visualization
        // ====================================================================
        display_test("Pipeline State Visualization");
        load_program_from_file("test_programs/test_arithmetic.hex");
        reset_processor();
        
        $display("\n--- Monitoring first 8 cycles ---");
        repeat(8) begin
            display_pipeline_state();
            wait_cycles(1);
        end
        
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
