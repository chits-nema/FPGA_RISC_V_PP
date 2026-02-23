`timescale 1ns / 1ps

module tb_bubble_sort();

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // IRAM interface (instruction memory)
    wire [31:0] F_pc;              // Program counter (fetch address)
    reg [31:0] F_instr;            // Instruction from IRAM
    wire stallF_out;               // Stall signal output
    
    // DRAM interface (data memory)
    wire [31:0] M_ALUResult;       // Address
    wire [31:0] M_WriteData;       // Write data
    wire M_MemWrite;               // Write enable
    reg [31:0] M_ReadDataW;        // Read data from DRAM (registered, 1-cycle latency)
    
    // Memory arrays
    reg [31:0] IRAM [0:4095];     // 4K x 32-bit instruction memory
    reg [31:0] DRAM [0:4095];     // 4K x 32-bit data memory
    
    // Test control
    integer i;
    integer errors;
    integer cycle_count;
    integer max_cycles = 100000;  // Timeout protection
    reg test_done;
    
    //=============================================================================
    // DUT Instantiation
    //=============================================================================
    rv_pl dut (
        .clk(clk),
        .rst_n(rst_n),
        .F_pc(F_pc),
        .F_instr(F_instr),
        .stallF_out(stallF_out),
        .M_ALUResult(M_ALUResult),
        .M_WriteData(M_WriteData),
        .M_MemWrite(M_MemWrite),
        .M_ReadDataW(M_ReadDataW)
    );
    
    //=============================================================================
    // Clock Generation (100 MHz)
    //=============================================================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100 MHz
    end
    
    //=============================================================================
    // Instruction Memory (IRAM) - Synchronous Read (1-cycle latency)
    //=============================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            F_instr <= 32'h00000013;  // NOP on reset
        end else begin
            F_instr <= IRAM[F_pc[13:2]];  // Word-aligned access, 14-bit address space
        end
    end
    
    //=============================================================================
    // Data Memory (DRAM) - Matches FPGA BRAM timing (registered read, 1-cycle latency)
    //=============================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            M_ReadDataW <= 32'h00000000;
        end else begin
            // Synchronous write
            if (M_MemWrite) begin
                DRAM[M_ALUResult[13:2]] <= M_WriteData;
                $display("[%0t] DRAM WRITE: addr=0x%03X data=0x%08X (%0d)", 
                         $time, M_ALUResult, M_WriteData, $signed(M_WriteData));
            end
            // Registered read (1-cycle latency) - matches Xilinx BRAM behavior
            // Note: Read happens every cycle but M_ReadDataW is only used by load instructions
            M_ReadDataW <= DRAM[M_ALUResult[13:2]];
        end
    end
    
    //=============================================================================
    // Cycle Counter & Branch Monitor
    //=============================================================================
    always @(posedge clk) begin
        if (!rst_n)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end
    
    // Monitor load instructions through the pipeline (limit output)
    reg [31:0] M_ALUResult_r;
    reg M_MemRead_r;
    integer mem_read_count = 0;
    always @(posedge clk) begin
        if (rst_n) begin
            M_ALUResult_r <= dut.M_ALUResult;
            M_MemRead_r <= dut.M_ResultSrc[0];  // ResultSrc[0]=1 means load instruction
            
            if (M_MemRead_r && mem_read_count < 100) begin
                $display("[%0t] MEM READ: addr=0x%h (DRAM[%0d]), data_out=0x%h (%0d)",
                         $time, M_ALUResult_r, M_ALUResult_r[31:2], 
                         dut.M_ReadDataW, $signed(dut.M_ReadDataW));
                $display("          Control: RegWriteE=%b, RegWriteM=%b, RegWriteW=%b, RdE=%0d, RdM=%0d, RdW=%0d",
                         dut.E_RegWrite, dut.M_RegWrite, dut.W_RegWrite, dut.E_Rd, dut.M_Rd, dut.W_Rd);
                mem_read_count = mem_read_count + 1;
            end
        end
    end
    
    // Monitor load instructions in E stage
    always @(posedge clk) begin
        if (rst_n && dut.E_ResultSrc[0] && mem_read_count < 100) begin
            $display("[%0t] LOAD IN E: E_pc=0x%02X, RdE=%0d, RegWriteE=%b, FlushE=%b",
                     $time, dut.E_pc, dut.E_Rd, dut.E_RegWrite, dut.E_flush);
        end
    end
    
    // Monitor store operations
    integer store_count = 0;
    reg M_MemWrite_r;
    always @(posedge clk) begin
        if (rst_n) begin
            M_MemWrite_r <= dut.M_MemWrite;
            
            if (M_MemWrite_r && store_count < 300) begin
                $display("[%0t] MEM WRITE: addr=0x%h (DRAM[%0d]), data_in=0x%h (%0d) [WriteDataM]",
                         $time, M_ALUResult_r, M_ALUResult_r[31:2], 
                         dut.M_WriteData, $signed(dut.M_WriteData));
                $display("          Pipeline: E_WriteData=0x%h, E_RD2=0x%h, E_SrcB_fwd=0x%h",
                         dut.E_WriteData, dut.E_RD2, dut.E_SrcB_forwarded);
                $display("          Forwarding: ForwardBE=%b, W_Result=0x%h, M_ALUResult=0x%h",
                         dut.ForwardBE, dut.W_Result, dut.M_ALUResult);
                $display("          Source: Rs2E=%0d, RdM=%0d, RdW=%0d",
                         dut.E_Rs2, dut.M_Rd, dut.W_Rd);
                $display("          Hazards: FlushE=%b, lwstall_D=%b, lwstall_E=%b",
                         dut.E_flush, dut.D_stall, dut.E_stall);
                // CHECK FOR ZERO WRITES THAT SHOULDN'T BE ZERO
                if (dut.M_WriteData == 32'h00000000) begin
                    $display("          *** WARNING: Writing ZERO to memory! Check pipeline state! ***");
                end
                store_count = store_count + 1;
            end
        end
    end
    
    // Monitor register file writes
    always @(negedge clk) begin
        if (rst_n && dut.W_RegWrite && dut.W_Rd != 0) begin
            $display("[%0t] REGFILE WRITE: x%0d <= 0x%08X (%0d), ResultSrc=%b, ALU=0x%08X, ReadData=0x%08X",
                     $time, dut.W_Rd, dut.W_Result, $signed(dut.W_Result), dut.W_ResultSrc,
                     dut.W_ALUResult, dut.W_ReadData);
        end
    end
    
    // Monitor ALU operations for slt (PC=0x38)
    always @(posedge clk) begin
        if (rst_n && dut.E_pc == 8'h38) begin
            $display("[%0t] SLT EXEC: E_pc=0x%02X, Rs1E=%0d, Rs2E=%0d, RdM=%0d, RdW=%0d",
                     $time, dut.E_pc, dut.E_Rs1, dut.E_Rs2, dut.M_Rd, dut.W_Rd);
            $display("             ForwardAE=%b, ForwardBE=%b, RegWriteM=%b, RegWriteW=%b",
                     dut.ForwardAE, dut.ForwardBE, dut.M_RegWrite, dut.W_RegWrite);
            $display("             E_RD1=0x%08X (%0d), E_RD2=0x%08X (%0d)",
                     dut.E_RD1, $signed(dut.E_RD1), dut.E_RD2, $signed(dut.E_RD2));
            $display("             M_ALUResult=0x%08X (%0d), W_Result=0x%08X (%0d)",
                     dut.M_ALUResult, $signed(dut.M_ALUResult), dut.W_Result, $signed(dut.W_Result));
            $display("             E_SrcA=0x%08X (%0d), E_SrcB=0x%08X (%0d), ALUResult=0x%08X",
                     dut.E_SrcA, $signed(dut.E_SrcA), dut.E_SrcB, $signed(dut.E_SrcB), dut.E_ALUResult);
        end
    end
    
    // Monitor beq instruction to see comparison values (PC=0x3C)  
    always @(posedge clk) begin
        if (rst_n && dut.E_pc == 8'h3C) begin
            $display("[%0t] BEQ CHECK: E_pc=0x%02X, RD1=0x%08X (%0d), RD2=0x%08X (%0d), Zero=%b",
                     $time, dut.E_pc, dut.E_RD1, $signed(dut.E_RD1), dut.E_RD2, $signed(dut.E_RD2), dut.E_Zero);
        end
    end
    
    // Monitor branches to debug PC issues
    always @(posedge clk) begin
        if (rst_n && dut.E_PCSrc) begin
            $display("[%0t] BRANCH TAKEN: E_pc=0x%02X, E_ImmExt=0x%08X (%0d), E_pcTarget=0x%02X, F_pc_next=0x%02X",
                     $time, dut.E_pc, dut.E_ImmExt, $signed(dut.E_ImmExt), dut.E_pcTarget, dut.F_pc_next);
        end
    end
    
    //=============================================================================
    // Main Test
    //=============================================================================
    initial begin
        // Initialize waveform dump
        $dumpfile("bubble_sort.vcd");
        $dumpvars(0, tb_bubble_sort);
        // Dump all internal signals from DUT (depth = 0 means all levels)
        $dumpvars(0, dut);
        
        // Initialize signals
        rst_n = 0;
        test_done = 0;
        errors = 0;
        
        // Initialize memories
        for (i = 0; i < 4096; i = i + 1) begin
            IRAM[i] = 32'h00000013;  // NOP (addi x0, x0, 0)
            DRAM[i] = 32'h00000000;
        end
        
        $display("========================================================");
        $display("  RISC-V Pipeline - Bubble Sort Test");
        $display("========================================================");
        
        //---------------------------------------------------------------------
        // Load Bubble Sort Program (27 instructions)
        //---------------------------------------------------------------------
        $display("\n[1] Loading bubble sort program (27 instructions)...");
        IRAM[0]  = 32'h00000093;  //  0: addi x1, x0, 0       ; i = 0
        IRAM[1]  = 32'h01F00113;  //  1: addi x2, x0, 31      ; N-1 = 31
        IRAM[2]  = 32'h00400513;  //  2: addi x10, x0, 4      ; stride = 4
        IRAM[3]  = 32'h00000193;  //  3: addi x3, x0, 0       ; outer loop start
        IRAM[4]  = 32'h0021A4B3;  //  4: slt  x9, x3, x2      ; x9 = (i < N-1)?
        IRAM[5]  = 32'h04048263;  //  5: beq  x9, x0, +68     ; if done, jump to DONE
        IRAM[6]  = 32'h40310233;  //  6: sub  x4, x2, x3      ; x4 = N-1-i
        IRAM[7]  = 32'h00000293;  //  7: addi x5, x0, 0       ; j = 0
        IRAM[8]  = 32'h0042A4B3;  //  8: slt  x9, x5, x4      ; x9 = (j < limit)?
        IRAM[9]  = 32'h02048663;  //  9: beq  x9, x0, +44     ; if done, outer incr
        IRAM[10] = 32'h00229313;  // 10: slli x6, x5, 2       ; x6 = j * 4
        IRAM[11] = 32'h00608333;  // 11: add  x6, x1, x6      ; x6 = base + j*4
        IRAM[12] = 32'h00032383;  // 12: lw   x7, 0(x6)       ; x7 = arr[j]
        IRAM[13] = 32'h00432403;  // 13: lw   x8, 4(x6)       ; x8 = arr[j+1]
        IRAM[14] = 32'h007424B3;  // 14: slt  x9, x8, x7      ; x9 = (arr[j+1] < arr[j])?
        IRAM[15] = 32'h00048663;  // 15: beq  x9, x0, +12     ; if not, skip swap
        IRAM[16] = 32'h00832023;  // 16: sw   x8, 0(x6)       ; arr[j] = arr[j+1]
        IRAM[17] = 32'h00732223;  // 17: sw   x7, 4(x6)       ; arr[j+1] = arr[j]
        IRAM[18] = 32'h00128293;  // 18: addi x5, x5, 1       ; j++
        IRAM[19] = 32'hFC000AE3;  // 19: beq  x0, x0, -44     ; jump to inner loop
        IRAM[20] = 32'h00118193;  // 20: addi x3, x3, 1       ; i++
        IRAM[21] = 32'hFA000EE3;  // 21: beq  x0, x0, -68     ; jump to outer loop
        IRAM[22] = 32'hDEADC637;  // 22: lui  x12, 0xDEADC    ; DONE: upper bits
        IRAM[23] = 32'hEAF60613;  // 23: addi x12, x12, -337  ; x12 = 0xDEADBEAF
        IRAM[24] = 32'h10000693;  // 24: addi x13, x0, 256    ; x13 = 0x100
        IRAM[25] = 32'h00C6A023;  // 25: sw   x12, 0(x13)     ; DRAM[0x100] = DONE
        IRAM[26] = 32'h00000063;  // 26: beq  x0, x0, 0       ; infinite loop
        
        //---------------------------------------------------------------------
        // Load Test Data (32 POSITIVE integers - NO ZEROS)
        //---------------------------------------------------------------------
        $display("[2] Loading test data (32 positive integers - NO ZEROS)...");
        DRAM[0]  = 32'h00000009;  // 9
        DRAM[1]  = 32'h00000031;  // 49
        DRAM[2]  = 32'h0000005F;  // 95
        DRAM[3]  = 32'h0000001A;  // 26
        DRAM[4]  = 32'h00000035;  // 53
        DRAM[5]  = 32'h00000056;  // 86
        DRAM[6]  = 32'h00000011;  // 17
        DRAM[7]  = 32'h0000002D;  // 45
        DRAM[8]  = 32'h00000049;  // 73
        DRAM[9]  = 32'h00000046;  // 70
        DRAM[10] = 32'h00000029;  // 41
        DRAM[11] = 32'h00000054;  // 84
        DRAM[12] = 32'h00000054;  // 84
        DRAM[13] = 32'h00000055;  // 85
        DRAM[14] = 32'h00000022;  // 34
        DRAM[15] = 32'h0000000E;  // 14
        DRAM[16] = 32'h0000003B;  // 59
        DRAM[17] = 32'h0000001B;  // 27
        DRAM[18] = 32'h00000026;  // 38
        DRAM[19] = 32'h00000010;  // 16
        DRAM[20] = 32'h0000004F;  // 79
        DRAM[21] = 32'h00000020;  // 32
        DRAM[22] = 32'h0000004E;  // 78
        DRAM[23] = 32'h00000041;  // 65
        DRAM[24] = 32'h00000028;  // 40
        DRAM[25] = 32'h00000045;  // 69
        DRAM[26] = 32'h00000010;  // 16
        DRAM[27] = 32'h0000003B;  // 59
        DRAM[28] = 32'h00000049;  // 73
        DRAM[29] = 32'h0000004F;  // 79
        DRAM[30] = 32'h00000061;  // 97
        DRAM[31] = 32'h00000054;  // 84
        
        DRAM[64] = 32'h00000000;  // Clear done flag at byte offset 0x100 (word 64)
        
        $display("    Input data:");
        for (i = 0; i < 32; i = i + 8) begin
            $display("      [%2d-%2d]: %4d %4d %4d %4d %4d %4d %4d %4d",
                     i, i+7,
                     $signed(DRAM[i]), $signed(DRAM[i+1]), $signed(DRAM[i+2]), $signed(DRAM[i+3]),
                     $signed(DRAM[i+4]), $signed(DRAM[i+5]), $signed(DRAM[i+6]), $signed(DRAM[i+7]));
        end
        
        //---------------------------------------------------------------------
        // Release Reset and Run
        //---------------------------------------------------------------------
        $display("\n[3] Releasing reset and starting processor...");
        #100;
        rst_n = 1;
        
        //---------------------------------------------------------------------
        // Wait for completion flag or timeout
        //---------------------------------------------------------------------
        $display("[4] Waiting for completion flag (0xDEADBEAF at DRAM[0x100])...");
        wait (DRAM[64] == 32'hDEADBEAF || cycle_count >= max_cycles);
        
        if (cycle_count >= max_cycles) begin
            $display("\n*** ERROR: TIMEOUT after %0d cycles ***", max_cycles);
            $display("    Done flag = 0x%08X (expected 0xDEADBEAF)", DRAM[64]);
            $display("    Last PC = 0x%08X", F_pc);
            errors = errors + 1;
        end else begin
            $display("    ✓ Done flag detected after %0d cycles", cycle_count);
        end
        
        // Let it run a few more cycles to ensure all writes complete
        repeat(10) @(posedge clk);
        
        //---------------------------------------------------------------------
        // Verify Results
        //---------------------------------------------------------------------
        $display("\n[5] Verifying sorted output...");
        $display("    Output data:");
        for (i = 0; i < 32; i = i + 8) begin
            $display("      [%2d-%2d]: %4d %4d %4d %4d %4d %4d %4d %4d",
                     i, i+7,
                     $signed(DRAM[i]), $signed(DRAM[i+1]), $signed(DRAM[i+2]), $signed(DRAM[i+3]),
                     $signed(DRAM[i+4]), $signed(DRAM[i+5]), $signed(DRAM[i+6]), $signed(DRAM[i+7]));
        end
        
        // Check if sorted (ascending order for signed integers)
        for (i = 0; i < 31; i = i + 1) begin
            if ($signed(DRAM[i]) > $signed(DRAM[i+1])) begin
                $display("    ✗ NOT SORTED: DRAM[%0d]=%0d > DRAM[%0d]=%0d",
                         i, $signed(DRAM[i]), i+1, $signed(DRAM[i+1]));
                errors = errors + 1;
            end
        end
        
        if (errors == 0) begin
            $display("    ✓ All 32 elements correctly sorted!");
        end
        
        //---------------------------------------------------------------------
        // Test Summary
        //---------------------------------------------------------------------
        $display("\n========================================================");
        if (errors == 0) begin
            $display("  ✓✓✓ TEST PASSED ✓✓✓");
            $display("  Completed in %0d cycles", cycle_count);
        end else begin
            $display("  ✗✗✗ TEST FAILED ✗✗✗");
            $display("  Errors: %0d", errors);
        end
        $display("========================================================\n");
        
        $finish;
    end
    
    //=============================================================================
    // Timeout Watchdog
    //=============================================================================
    initial begin
        #(max_cycles * 10 + 1000);  // Wait for max cycles + margin
        if (!test_done) begin
            $display("\n*** SIMULATION TIMEOUT ***");
            $finish;
        end
    end

endmodule
