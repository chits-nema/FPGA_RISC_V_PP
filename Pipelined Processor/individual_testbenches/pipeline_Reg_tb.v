`timescale 1ns / 1ps
`include "program_counter.v"
`include "EX_MA.v"
`include "ID_EX.v"
`include "MA_WB.v"
`include "IF_ID.v"
module pipeline_registers_tb;

    // Clock and reset
    reg clk;
    reg reset;
    
    // Test counter
    integer test_num = 0;
    integer errors = 0;
    
    // ========================================================================
    // PC Register Test Signals
    // ========================================================================
    reg StallF_pc;      // This will connect to 'en' (active-high stall)
    reg [31:0] PCNext;
    wire [31:0] PC;
    
    // ========================================================================
    // F/D Register Test Signals
    // ========================================================================
    reg StallD_fd;
    reg FlushD_fd;
    reg [31:0] InstrF;
    reg [31:0] PCF;
    reg [31:0] PCPlus4F;
    wire [31:0] InstrD;
    wire [31:0] PCD;
    wire [31:0] PCPlus4D;
    
    // ========================================================================
    // D/E Register Test Signals
    // ========================================================================
    reg FlushE_de;
    reg RegWriteD, MemWriteD, JumpD, BranchD, ALUSrcD;
    reg [1:0] ResultSrcD;
    reg [2:0] ALUControlD;
    reg [31:0] RD1D, RD2D, PCD_de, ImmExtD, PCPlus4D_de;
    reg [4:0] Rs1D, Rs2D, RdD;
    wire RegWriteE, MemWriteE, JumpE, BranchE, ALUSrcE;
    wire [1:0] ResultSrcE;
    wire [2:0] ALUControlE;
    wire [31:0] RD1E, RD2E, PCE, ImmExtE, PCPlus4E;
    wire [4:0] Rs1E, Rs2E, RdE;
    
    // ========================================================================
    // E/M Register Test Signals
    // ========================================================================
    reg RegWriteE_em, MemWriteE_em;
    reg [1:0] ResultSrcE_em;
    reg [31:0] ALUResultE, WriteDataE, PCPlus4E_em;
    reg [4:0] RdE_em;
    wire RegWriteM, MemWriteM;
    wire [1:0] ResultSrcM;
    wire [31:0] ALUResultM, WriteDataM, PCPlus4M;
    wire [4:0] RdM;
    
    // ========================================================================
    // M/W Register Test Signals
    // ========================================================================
    reg RegWriteM_mw;
    reg [1:0] ResultSrcM_mw;
    reg [31:0] ALUResultM_mw, ReadDataM, PCPlus4M_mw;
    reg [4:0] RdM_mw;
    wire RegWriteW;
    wire [1:0] ResultSrcW;
    wire [31:0] ALUResultW, ReadDataW, PCPlus4W;
    wire [4:0] RdW;
    
    // ========================================================================
    // Instantiate Modules
    // ========================================================================
    
    // PC Register (adjusted for your implementation)
    pc pc_reg(
        .clk(clk),
        .rst(reset),          // Active-low reset in your module
        .en(StallF_pc),       // Active-high stall signal
        .pc_in(PCNext),
        .out(PC)
    );
    
    // F/D Pipeline Register
    if_id_reg fd_reg(
        .clk(clk),
        .rst_n(reset),
        .en(StallD_fd),
        .clr(FlushD_fd),
        .F_instr(InstrF),
        .F_pc(PCF),
        .F_pc_plus_4(PCPlus4F),
        .D_instr(InstrD),
        .D_pc(PCD),
        .D_pc_plus_4(PCPlus4D)
    );
    
    // D/E Pipeline Register
    decode_execute_reg de_reg(
        .clk(clk),
        .reset(reset),
        .FlushE(FlushE_de),
        .RegWriteD(RegWriteD),
        .ResultSrcD(ResultSrcD),
        .MemWriteD(MemWriteD),
        .JumpD(JumpD),
        .BranchD(BranchD),
        .ALUControlD(ALUControlD),
        .ALUSrcD(ALUSrcD),
        .RD1D(RD1D),
        .RD2D(RD2D),
        .PCD(PCD_de),
        .Rs1D(Rs1D),
        .Rs2D(Rs2D),
        .RdD(RdD),
        .ImmExtD(ImmExtD),
        .PCPlus4D(PCPlus4D_de),
        .RegWriteE(RegWriteE),
        .ResultSrcE(ResultSrcE),
        .MemWriteE(MemWriteE),
        .JumpE(JumpE),
        .BranchE(BranchE),
        .ALUControlE(ALUControlE),
        .ALUSrcE(ALUSrcE),
        .RD1E(RD1E),
        .RD2E(RD2E),
        .PCE(PCE),
        .Rs1E(Rs1E),
        .Rs2E(Rs2E),
        .RdE(RdE),
        .ImmExtE(ImmExtE),
        .PCPlus4E(PCPlus4E)
    );
    
    // E/M Pipeline Register
    execute_memory_reg em_reg(
        .clk(clk),
        .reset(reset),
        .RegWriteE(RegWriteE_em),
        .ResultSrcE(ResultSrcE_em),
        .MemWriteE(MemWriteE_em),
        .ALUResultE(ALUResultE),
        .WriteDataE(WriteDataE),
        .RdE(RdE_em),
        .PCPlus4E(PCPlus4E_em),
        .RegWriteM(RegWriteM),
        .ResultSrcM(ResultSrcM),
        .MemWriteM(MemWriteM),
        .ALUResultM(ALUResultM),
        .WriteDataM(WriteDataM),
        .RdM(RdM),
        .PCPlus4M(PCPlus4M)
    );
    
    // M/W Pipeline Register
    memory_writeback_reg mw_reg(
        .clk(clk),
        .reset(reset),
        .RegWriteM(RegWriteM_mw),
        .ResultSrcM(ResultSrcM_mw),
        .ALUResultM(ALUResultM_mw),
        .ReadDataM(ReadDataM),
        .RdM(RdM_mw),
        .PCPlus4M(PCPlus4M_mw),
        .RegWriteW(RegWriteW),
        .ResultSrcW(ResultSrcW),
        .ALUResultW(ALUResultW),
        .ReadDataW(ReadDataW),
        .RdW(RdW),
        .PCPlus4W(PCPlus4W)
    );
    
    // ========================================================================
    // Clock Generation
    // ========================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period
    end
    
    // ========================================================================
    // Test Tasks
    // ========================================================================
    
    task reset_system;
        begin
            reset = 0;  // Active-low reset
            #1;  // Allow asynchronous reset to propagate
            
            // Set InstrF to NOP before releasing reset
            // so it latches NOP instead of 0 when reset is released
            InstrF = 32'h00000013;
            
            @(posedge clk);
            @(posedge clk);
            reset = 1;  // Release reset
            @(posedge clk);
        end
    endtask
    
    task display_test;
        input [200*8:1] test_name;
        begin
            test_num = test_num + 1;
            $display("\n=== Test %0d: %s ===", test_num, test_name);
        end
    endtask
    
    task check_value;
        input [31:0] actual;
        input [31:0] expected;
        input [100*8:1] signal_name;
        begin
            if (actual !== expected) begin
                $display("  ERROR: %s = 0x%h, expected 0x%h", signal_name, actual, expected);
                errors = errors + 1;
            end else begin
                $display("  PASS: %s = 0x%h", signal_name, actual);
            end
        end
    endtask
    
    // ========================================================================
    // Test Sequence
    // ========================================================================
    
    initial begin
        $display("========================================");
        $display("Pipeline Registers Testbench");
        $display("========================================");
        
        // Initialize all inputs
        reset = 1;  // Start with reset de-asserted (active-low)
        StallF_pc = 0;
        PCNext = 0;
        StallD_fd = 0;
        FlushD_fd = 0;
        InstrF = 0;
        PCF = 0;
        PCPlus4F = 0;
        FlushE_de = 0;
        RegWriteD = 0; MemWriteD = 0; JumpD = 0; BranchD = 0; ALUSrcD = 0;
        ResultSrcD = 0; ALUControlD = 0;
        RD1D = 0; RD2D = 0; PCD_de = 0; ImmExtD = 0; PCPlus4D_de = 0;
        Rs1D = 0; Rs2D = 0; RdD = 0;
        RegWriteE_em = 0; MemWriteE_em = 0; ResultSrcE_em = 0;
        ALUResultE = 0; WriteDataE = 0; PCPlus4E_em = 0; RdE_em = 0;
        RegWriteM_mw = 0; ResultSrcM_mw = 0;
        ALUResultM_mw = 0; ReadDataM = 0; PCPlus4M_mw = 0; RdM_mw = 0;
        
        @(posedge clk);
        
        // ====================================================================
        // TEST 1: Reset Test - All Registers
        // ====================================================================
        display_test("Reset all pipeline registers");
        reset_system();
    
        // Check PC reset
        check_value(PC, 32'h0, "PC after reset");
        
        // Check F/D reset (should be NOP since we set InstrF to NOP in reset_system)
        check_value(InstrD, 32'h00000013, "InstrD after reset (NOP)");
        check_value(PCD, 32'h0, "PCD after reset");
        
        // Check D/E reset (control signals should be 0)
        check_value({31'b0, RegWriteE}, 32'h0, "RegWriteE after reset");
        check_value({30'b0, ResultSrcE}, 32'h0, "ResultSrcE after reset");
        check_value({31'b0, MemWriteE}, 32'h0, "MemWriteE after reset");
        
        // Check E/M reset
        check_value({31'b0, RegWriteM}, 32'h0, "RegWriteM after reset");
        check_value(ALUResultM, 32'h0, "ALUResultM after reset");
        
        // Check M/W reset
        check_value({31'b0, RegWriteW}, 32'h0, "RegWriteW after reset");
        check_value(ALUResultW, 32'h0, "ALUResultW after reset");
        
        // ====================================================================
        // TEST 2: PC Register - Normal Operation
        // ====================================================================
        display_test("PC register normal operation");
        reset_system();
        
        StallF_pc = 0;
        PCNext = 32'h00000004;
        @(posedge clk);
        check_value(PC, 32'h00000004, "PC incremented");
        
        StallF_pc = 0;
        PCNext = 32'h00000008;
        @(posedge clk);
        check_value(PC, 32'h00000008, "PC incremented again");
        
        // ====================================================================
        // TEST 3: PC Register - Stall
        // ====================================================================
        display_test("PC register with stall");
        
        PCNext = 32'h0000000C;
        StallF_pc = 1;  // Stall enabled
        @(posedge clk);
        check_value(PC, 32'h00000008, "PC held during stall");
        
        StallF_pc = 0;  // Release stall
        @(posedge clk);
        check_value(PC, 32'h0000000C, "PC updated after stall");
        
        // ====================================================================
        // TEST 4: F/D Register - Normal Operation
        // ====================================================================
        display_test("F/D register normal operation");
        reset_system();
        
        InstrF = 32'h12345678;
        PCF = 32'h00000100;
        PCPlus4F = 32'h00000104;
        
        @(posedge clk);
        check_value(InstrD, 32'h12345678, "InstrD passed through");
        check_value(PCD, 32'h00000100, "PCD passed through");
        check_value(PCPlus4D, 32'h00000104, "PCPlus4D passed through");
        
        // ====================================================================
        // TEST 5: F/D Register - Stall
        // ====================================================================
        display_test("F/D register with stall");
        
        InstrF = 32'hABCDEF00;
        PCF = 32'h00000200;
        PCPlus4F = 32'h00000204;
        StallD_fd = 1;  // Enable stall
        
        @(posedge clk);
        // Should keep previous values
        check_value(InstrD, 32'h12345678, "InstrD held during stall");
        check_value(PCD, 32'h00000100, "PCD held during stall");
        
        StallD_fd = 0;  // Release stall
        @(posedge clk);
        check_value(InstrD, 32'hABCDEF00, "InstrD updated after stall");
        check_value(PCD, 32'h00000200, "PCD updated after stall");
        
        // ====================================================================
        // TEST 6: F/D Register - Flush
        // ====================================================================
        display_test("F/D register with flush");
        
        InstrF = 32'hDEADBEEF;
        PCF = 32'h00000300;
        PCPlus4F = 32'h00000304;
        FlushD_fd = 1;  // Enable flush
        
        @(posedge clk);
        check_value(InstrD, 32'h00000013, "InstrD flushed to NOP");
        check_value(PCD, 32'h0, "PCD flushed to 0");
        
        // ====================================================================
        // TEST 7: F/D Register - Flush Priority over Stall
        // ====================================================================
        display_test("F/D register - flush priority over stall");
        
        InstrF = 32'hBADC0DE5;
        PCF = 32'h00000400;
        PCPlus4F = 32'h00000404;
        StallD_fd = 1;  // Both stall
        FlushD_fd = 1;  // and flush enabled
        
        @(posedge clk);
        check_value(InstrD, 32'h00000013, "Flush takes priority (NOP)");
        check_value(PCD, 32'h0, "PCD flushed despite stall");
        
        StallD_fd = 0;
        FlushD_fd = 0;
        
        // ====================================================================
        // TEST 8: D/E Register - Normal Operation
        // ====================================================================
        display_test("D/E register normal operation");
        reset_system();
        
        RegWriteD = 1;
        ResultSrcD = 2'b01;
        MemWriteD = 0;
        ALUControlD = 3'b010;
        RD1D = 32'h11111111;
        RD2D = 32'h22222222;
        Rs1D = 5'd5;
        Rs2D = 5'd6;
        RdD = 5'd7;
        
        @(posedge clk);
        check_value({31'b0, RegWriteE}, 32'h1, "RegWriteE passed through");
        check_value({30'b0, ResultSrcE}, 32'h1, "ResultSrcE passed through");
        check_value(RD1E, 32'h11111111, "RD1E passed through");
        check_value(RD2E, 32'h22222222, "RD2E passed through");
        check_value({27'b0, Rs1E}, 32'd5, "Rs1E passed through");
        check_value({27'b0, RdE}, 32'd7, "RdE passed through");
        
        // ====================================================================
        // TEST 9: D/E Register - Flush (Insert Bubble)
        // ====================================================================
        display_test("D/E register with flush");
        
        RegWriteD = 1;
        ResultSrcD = 2'b10;
        MemWriteD = 1;
        FlushE_de = 1;  // Enable flush
        
        @(posedge clk);
        check_value({31'b0, RegWriteE}, 32'h0, "RegWriteE cleared by flush");
        check_value({31'b0, MemWriteE}, 32'h0, "MemWriteE cleared by flush");
        check_value({30'b0, ResultSrcE}, 32'h0, "ResultSrcE cleared by flush");
        
        FlushE_de = 0;
        
        // ====================================================================
        // TEST 10: E/M Register - Normal Operation
        // ====================================================================
        display_test("E/M register normal operation");
        reset_system();
        
        RegWriteE_em = 1;
        ResultSrcE_em = 2'b01;
        MemWriteE_em = 1;
        ALUResultE = 32'hAAAAAAAA;
        WriteDataE = 32'hBBBBBBBB;
        RdE_em = 5'd10;
        
        @(posedge clk);
        check_value({31'b0, RegWriteM}, 32'h1, "RegWriteM passed through");
        check_value({30'b0, ResultSrcM}, 32'h1, "ResultSrcM passed through");
        check_value({31'b0, MemWriteM}, 32'h1, "MemWriteM passed through");
        check_value(ALUResultM, 32'hAAAAAAAA, "ALUResultM passed through");
        check_value(WriteDataM, 32'hBBBBBBBB, "WriteDataM passed through");
        check_value({27'b0, RdM}, 32'd10, "RdM passed through");
        
        // ====================================================================
        // TEST 11: M/W Register - Normal Operation
        // ====================================================================
        display_test("M/W register normal operation");
        reset_system();
        
        RegWriteM_mw = 1;
        ResultSrcM_mw = 2'b10;
        ALUResultM_mw = 32'hCCCCCCCC;
        ReadDataM = 32'hDDDDDDDD;
        RdM_mw = 5'd15;
        
        @(posedge clk);
        check_value({31'b0, RegWriteW}, 32'h1, "RegWriteW passed through");
        check_value({30'b0, ResultSrcW}, 32'h2, "ResultSrcW passed through");
        check_value(ALUResultW, 32'hCCCCCCCC, "ALUResultW passed through");
        check_value(ReadDataW, 32'hDDDDDDDD, "ReadDataW passed through");
        check_value({27'b0, RdW}, 32'd15, "RdW passed through");
        
        // ====================================================================
        // TEST 12: Full Pipeline Data Flow
        // ====================================================================
        display_test("Full pipeline data propagation");
        reset_system();
        
        // Cycle 1: Load F/D
        InstrF = 32'h00000001;
        PCF = 32'h1000;
        @(posedge clk);
        $display("  Cycle 1: InstrD = 0x%h", InstrD);
        
        // Cycle 2: Load D/E
        RegWriteD = 1;
        RD1D = 32'hFEEDFACE;
        RdD = 5'd20;
        @(posedge clk);
        $display("  Cycle 2: RD1E = 0x%h, RdE = %d", RD1E, RdE);
        
        // Cycle 3: Load E/M
        RegWriteE_em = 1;
        ALUResultE = 32'hCAFEBABE;
        RdE_em = 5'd20;
        @(posedge clk);
        $display("  Cycle 3: ALUResultM = 0x%h, RdM = %d", ALUResultM, RdM);
        
        // Cycle 4: Load M/W
        RegWriteM_mw = 1;
        ALUResultM_mw = 32'hCAFEBABE;
        RdM_mw = 5'd20;
        @(posedge clk);
        $display("  Cycle 4: ALUResultW = 0x%h, RdW = %d", ALUResultW, RdW);
        check_value(ALUResultW, 32'hCAFEBABE, "Data propagated through pipeline");
        
        // ====================================================================
        // Summary
        // ====================================================================
        #20;
        $display("\n========================================");
        $display("Test Summary:");
        $display("  Total Tests: %0d", test_num);
        $display("  Errors: %0d", errors);
        $display("========================================");
        
        if (errors == 0)
            $display("ALL TESTS PASSED!");
        else
            $display("SOME TESTS FAILED!");
        
        $finish;
    end

endmodule