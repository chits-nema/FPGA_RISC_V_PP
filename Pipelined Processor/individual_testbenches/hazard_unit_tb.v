`timescale 1ns/1ps
`include "../hazard_unit.v"

module hazard_unit_tb;
    //inputs 
    reg [4:0] Rs1D, Rs2D, Rs1E, Rs2E, RdE, RdM, RdW;
    reg ResultSrcE0, regWriteE, PCSrcE, RegWriteM, RegWriteW;
    reg clk, reset;
    
    //outputs
    wire [1:0] ForwardAE;
    wire [1:0] ForwardBE;
    wire stallF, stallD, FlushD, FlushE;
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end

    hazard uut(
        .clk(clk),
        .reset(reset),
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .RdM(RdM),
        .RdW(RdW),
        .ResultSrcE(ResultSrcE0),
        .RegWriteE(regWriteE),
        .PcSrcE(PCSrcE),
        .RegWriteM(RegWriteM),
        .RegWriteW(RegWriteW),
        .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE),
        .stallF(stallF),
        .stallD(stallD),
        .FlushD(FlushD),
        .FlushE(FlushE)
    ); 

    //counter for tests
    integer test_num = 0;
    integer errors = 0;

    //check outputs are expected
    task check_outputs;
        input [1:0] exp_fwdA;
        input [1:0] exp_fwdB;
        input exp_stallF;
        input exp_stallD;
        input exp_flushD;
        input exp_flushE;
        input [200*8:1] test_name;
        begin
            test_num = test_num + 1;
            #1;  // Small delay for signals to settle
            
            if (ForwardAE !== exp_fwdA || ForwardBE !== exp_fwdB ||
                stallF !== exp_stallF || stallD !== exp_stallD ||
                FlushD !== exp_flushD || FlushE !== exp_flushE) begin
                
                $display("ERROR Test %0d: %s", test_num, test_name);
                $display("  Expected: FwdA=%b FwdB=%b StallF=%b StallD=%b FlushD=%b FlushE=%b",
                         exp_fwdA, exp_fwdB, exp_stallF, exp_stallD, exp_flushD, exp_flushE);
                $display("  Got:      FwdA=%b FwdB=%b StallF=%b StallD=%b FlushD=%b FlushE=%b",
                         ForwardAE, ForwardBE, stallF, stallD, FlushD, FlushE);
                errors = errors + 1;
            end else begin
                $display("PASS Test %0d: %s", test_num, test_name);
            end
        end
    endtask

    //Task to initialize all inputs
    task init_inputs;
        begin
            Rs1D = 0; Rs2D = 0;
            Rs1E = 0; Rs2E = 0; RdE = 0;
            RdM = 0; RdW = 0;
            ResultSrcE0 = 0; regWriteE = 0; PCSrcE = 0;
            RegWriteM = 0; RegWriteW = 0;
        end
    endtask

    initial begin
        $dumpfile("hazard_unit_tb.vcd");
        $dumpvars(0, hazard_unit_tb);
        
        // Initialize reset
        reset = 1;
        #15;
        reset = 0;
        #5;
        
        $display("========================================");
        $display("Starting Hazard Unit Tests");
        $display("========================================");
        
        // Initialize
        init_inputs;
        #10;
        
        // ====================================================================
        // TEST 1: No Hazards - No forwarding needed
        // ====================================================================
        init_inputs;
        Rs1E = 5'd1;
        Rs2E = 5'd2;
        RegWriteM = 1;
        RegWriteW = 1;
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 0, 0, "No hazards");
        
        // ====================================================================
        // TEST 2: Forward from MEM to ALU input A
        // ====================================================================
        init_inputs;
        Rs1E = 5'd5;      // Need x5
        Rs2E = 5'd2;
        RdM = 5'd5;       // MEM stage writing to x5
        RegWriteM = 1;
        #10;
        check_outputs(2'b10, 2'b00, 0, 0, 0, 0, "Forward MEM to SrcA");
        
        // ====================================================================
        // TEST 3: Forward from MEM to ALU input B
        // ====================================================================
        init_inputs;
        Rs1E = 5'd1;
        Rs2E = 5'd7;      // Need x7
        RdM = 5'd7;       // MEM stage writing to x7
        RegWriteM = 1;
        #10;
        check_outputs(2'b00, 2'b10, 0, 0, 0, 0, "Forward MEM to SrcB");
        
        // ====================================================================
        // TEST 4: Forward from WB to ALU input A
        // ====================================================================
        init_inputs;
        Rs1E = 5'd10;     // Need x10
        Rs2E = 5'd2;
        RdW = 5'd10;      // WB stage writing to x10
        RegWriteW = 1;
        #10;
        check_outputs(2'b01, 2'b00, 0, 0, 0, 0, "Forward WB to SrcA");
        
        // ====================================================================
        // TEST 5: Forward from WB to ALU input B
        // ====================================================================
        init_inputs;
        Rs1E = 5'd1;
        Rs2E = 5'd12;     // Need x12
        RdW = 5'd12;      // WB stage writing to x12
        RegWriteW = 1;
        #10;
        check_outputs(2'b00, 2'b01, 0, 0, 0, 0, "Forward WB to SrcB");
        
        // ====================================================================
        // TEST 6: Forward from both MEM and WB (MEM has priority)
        // ====================================================================
        init_inputs;
        Rs1E = 5'd8;      // Need x8
        Rs2E = 5'd9;
        RdM = 5'd8;       // MEM stage writing to x8
        RdW = 5'd8;       // WB stage also writing to x8 (MEM has priority)
        RegWriteM = 1;
        RegWriteW = 1;
        #10;
        check_outputs(2'b10, 2'b00, 0, 0, 0, 0, "MEM priority over WB");
        
        // ====================================================================
        // TEST 7: Forward to both inputs from MEM and WB
        // ====================================================================
        init_inputs;
        Rs1E = 5'd15;     // Need x15
        Rs2E = 5'd16;     // Need x16
        RdM = 5'd15;      // MEM writing to x15
        RdW = 5'd16;      // WB writing to x16
        RegWriteM = 1;
        RegWriteW = 1;
        #10;
        check_outputs(2'b10, 2'b01, 0, 0, 0, 0, "Forward MEM to A, WB to B");
        
        // ====================================================================
        // TEST 8: No forward to x0 (zero register)
        // ====================================================================
        init_inputs;
        Rs1E = 5'd0;      // x0 (should never forward)
        Rs2E = 5'd0;      // x0 (should never forward)
        RdM = 5'd0;       // Even if MEM writes to x0
        RdW = 5'd0;       // Even if WB writes to x0
        RegWriteM = 1;
        RegWriteW = 1;
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 0, 0, "No forward to x0");
        
        // ====================================================================
        // TEST 9: Load-Use Hazard (stall required)
        // ====================================================================
        init_inputs;
        Rs1D = 5'd3;      // Decode needs x3
        Rs2D = 5'd4;
        RdE = 5'd3;       // Execute is loading into x3
        ResultSrcE0 = 1;  // Load instruction
        #10;
        check_outputs(2'b00, 2'b00, 1, 1, 0, 1, "Load-use hazard on Rs1D");
        
        // ====================================================================
        // TEST 10: Load-Use Hazard on Rs2D
        // ====================================================================
        init_inputs;
        Rs1D = 5'd1;
        Rs2D = 5'd6;      // Decode needs x6
        RdE = 5'd6;       // Execute is loading into x6
        ResultSrcE0 = 1;  // Load instruction
        #10;
        check_outputs(2'b00, 2'b00, 1, 1, 0, 1, "Load-use hazard on Rs2D");
        
        // ====================================================================
        // TEST 11: Load-Use Hazard on both Rs1D and Rs2D
        // ====================================================================
        init_inputs;
        Rs1D = 5'd7;      // Decode needs x7
        Rs2D = 5'd7;      // Also needs x7
        RdE = 5'd7;       // Execute is loading into x7
        ResultSrcE0 = 1;  // Load instruction
        #10;
        check_outputs(2'b00, 2'b00, 1, 1, 0, 1, "Load-use hazard on both");
        
        // ====================================================================
        // TEST 12: No Load-Use Hazard (not a load instruction)
        // ====================================================================
        init_inputs;
        Rs1D = 5'd5;
        Rs2D = 5'd6;
        RdE = 5'd5;
        ResultSrcE0 = 0;  // Not a load
        regWriteE = 1;
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 0, 0, "No hazard - not a load");
        
        // ====================================================================
        // TEST 13: No Load-Use Hazard (different registers)
        // ====================================================================
        init_inputs;
        Rs1D = 5'd10;
        Rs2D = 5'd11;
        RdE = 5'd12;      // Different register
        ResultSrcE0 = 1;  // Load instruction
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 0, 0, "No hazard - different regs");
        
        // ====================================================================
        // TEST 14: Branch Taken (flush required)
        // ====================================================================
        init_inputs;
        PCSrcE = 1;       // Branch taken
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 1, 1, "Branch taken - flush");
        
        // ====================================================================
        // TEST 15: Branch Not Taken (no flush)
        // ====================================================================
        init_inputs;
        PCSrcE = 0;       // Branch not taken
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 0, 0, "Branch not taken");
        
        // ====================================================================
        // TEST 16: Load-Use + Branch (load has priority in flush logic)
        // ====================================================================
        init_inputs;
        Rs1D = 5'd8;
        RdE = 5'd8;
        ResultSrcE0 = 1;  // Load
        PCSrcE = 1;       // Branch taken
        #10;
        check_outputs(2'b00, 2'b00, 1, 1, 1, 1, "Load-use with branch"); //asserting both flushes to 1 the priority ranking should be implemented by the pipeline register 

        
        // ====================================================================
        // TEST 17: RegWrite disabled (no forwarding)
        // ====================================================================
        init_inputs;
        Rs1E = 5'd14;
        Rs2E = 5'd15;
        RegWriteM = 0;    // Not writing
        RegWriteW = 0;    // Not writing
        #10;
        check_outputs(2'b00, 2'b00, 0, 0, 0, 0, "No forward - RegWrite disabled");
        
        // ====================================================================
        // TEST 18: Complex scenario - Forward + No hazard on other input
        // ====================================================================
        init_inputs;
        Rs1E = 5'd20;     // Forward from MEM
        Rs2E = 5'd21;     // No forward needed (different from RdM/RdW)
        RdM = 5'd20;      // MEM writing to x20
        RdW = 5'd22;      // WB writing to x22 (not needed)
        RegWriteM = 1;
        RegWriteW = 1;
        #10;
        check_outputs(2'b10, 2'b00, 0, 0, 0, 0, "Forward A only");
        
        // ====================================================================
        // Summary
        // ====================================================================
        #10;
        $display("========================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_num);
        $display("  Passed: %0d", test_num - errors);
        $display("  Failed: %0d", errors);
        $display("========================================");
        
        if (errors == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        
        $finish;
    end
endmodule