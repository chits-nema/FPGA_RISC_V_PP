`timescale 1ns/1ps
`ifndef LAT
`define LAT 2
`endif

module rv_pl_bram_latency_tb;

    // Clock / reset
    reg clk;
    reg rst_n;

    // IF/IMEM interface
    wire [31:0] F_pc;
    reg  [31:0] F_instr;

    // MEM/DMEM interface
    wire [31:0] M_ALUResult;
    wire        M_MemWrite;
    wire [31:0] M_WriteData;
    reg  [31:0] M_ReadDataW;

    // Instantiate DUT (rv_pl from top_module.v)
    rv_pl uut(
        .clk(clk),
        .rst_n(rst_n),
        .F_pc(F_pc),
        .F_instr(F_instr),
        .M_ALUResult(M_ALUResult),
        .M_MemWrite(M_MemWrite),
        .M_WriteData(M_WriteData),
        .M_ReadDataW(M_ReadDataW)
    );

    // Simple parameterizable BRAM read latency model
    parameter IMEM_SIZE = 256;
    parameter DMEM_SIZE = 256;
    localparam LATp = `LAT; // read latency cycles (override with -DLAT=N)

    reg [31:0] imem [0:IMEM_SIZE-1];
    reg [31:0] dmem [0:DMEM_SIZE-1];
    reg [31:0] instr_pipe [0:LATp-1];
    reg [31:0] data_pipe [0:LATp-1];
    reg [31:0] if_addr_word;
    reg [31:0] mem_addr_word;

    integer i;
    integer cycle;
    reg prev_stallF;
    reg prev_FlushE;

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz / 10ns period
    end

    // Reset pulse
    initial begin
        rst_n = 0;
        #20;
        rst_n = 1;
    end

    // VCD dump and cycle counter init
    initial begin
        $dumpfile("rv_pl_tb.vcd");
        $dumpvars(0, uut);
        cycle = 0;
        prev_stallF = 1'b0;
        prev_FlushE = 1'b0;
    end

    // Cycle counter and textual monitors
    always @(posedge clk) begin
        if (rst_n) begin
            cycle = cycle + 1;
            // Monitor stall/flush transitions
            if (uut.hazard_unit.stallF !== prev_stallF) begin
                $display("CYCLE %0d: stallF=%b", cycle, uut.hazard_unit.stallF);
            end
            prev_stallF = uut.hazard_unit.stallF;
            if (uut.hazard_unit.FlushE !== prev_FlushE) begin
                $display("CYCLE %0d: FlushE=%b", cycle, uut.hazard_unit.FlushE);
            end
            prev_FlushE = uut.hazard_unit.FlushE;

            // Forwarding changes
            if (uut.hazard_unit.ForwardAE !== 2'b00 || uut.hazard_unit.ForwardBE !== 2'b00) begin
                $display("CYCLE %0d: ForwardAE=%b ForwardBE=%b", cycle, uut.hazard_unit.ForwardAE, uut.hazard_unit.ForwardBE);
            end

            // Branch decisions and PC target
            if (uut.E_PCSrc) begin
                $display("CYCLE %0d: E_PCSrc=1 E_pcTarget=%h E_pc=%h", cycle, uut.E_pcTarget, uut.E_pc);
            end

            // Memory writes
            if (uut.M_MemWrite) begin
                $display("CYCLE %0d: MEMWRITE addr=%h data=%h", cycle, uut.M_ALUResult, uut.M_WriteData);
            end
        end
    end

    // Additional per-cycle pipeline register monitors
    always @(posedge clk) begin
        if (rst_n) begin
            $display("CYCLE %0d: D_instr=%h D_MemWrite=%b | E_Rd=%0d E_RegWrite=%b E_MemWrite=%b | M_Rd=%0d M_RegWrite=%b M_MemWrite=%b", cycle, uut.D_instr, uut.D_MemWrite, uut.E_Rd, uut.E_RegWrite, uut.E_MemWrite, uut.M_Rd, uut.M_RegWrite, uut.M_MemWrite);
        end
    end

    // Helper: construct B-type BEQ instruction (funct3=000, opcode=0x63)
    function [31:0] make_beq;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer offset; // byte offset (can be negative)
        reg [12:0] imm;
        reg imm12;
        reg imm11;
        reg [5:0] imm10_5;
        reg [3:0] imm4_1;
        begin
            imm = offset & 13'h1fff;
            imm12 = (imm >> 12) & 1;
            imm11 = (imm >> 11) & 1;
            imm10_5 = (imm >> 5) & 6'h3f;
            imm4_1 = (imm >> 1) & 4'hf;
            make_beq = (imm12 << 31) | (imm10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (3'b000 << 12) | (imm4_1 << 8) | (imm11 << 7) | 7'b1100011;
        end
    endfunction

    // Simple instruction and data memory behavior with LAT-cycle read
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < LATp; i = i + 1) instr_pipe[i] <= 32'h00000013; // NOP
            M_ReadDataW <= 32'hFFFFFFFF;
            for (i = 0; i < IMEM_SIZE; i = i + 1) imem[i] <= 32'h00000013; // NOP
            for (i = 0; i < DMEM_SIZE; i = i + 1) dmem[i] <= 32'hFFFFFFFF;
            for (i = 0; i < LATp; i = i + 1) data_pipe[i] <= 32'h0;
        end else begin
            // Instruction read path (byte address -> word index)
            // Fetch imem at address F_pc>>2, push through latency pipeline
            if_addr_word = F_pc[31:2];
            if (if_addr_word < IMEM_SIZE)
                instr_pipe[0] <= imem[if_addr_word];
            else
                instr_pipe[0] <= 32'h00000013; // NOP for out-of-range
            for (i = 1; i < LATp; i = i + 1) instr_pipe[i] <= instr_pipe[i-1];
            F_instr <= instr_pipe[LATp-1];

            // Data read path: push dmem[addr] into data_pipe
            mem_addr_word = M_ALUResult[31:2];
            if (M_MemWrite) begin
                if (mem_addr_word < DMEM_SIZE)
                    dmem[mem_addr_word] <= M_WriteData;
            end
            if (mem_addr_word < DMEM_SIZE)
                data_pipe[0] <= dmem[mem_addr_word];
            else
                data_pipe[0] <= 32'h0;
            for (i = 1; i < LATp; i = i + 1) data_pipe[i] <= data_pipe[i-1];
            M_ReadDataW <= data_pipe[LATp-1];
        end
    end

    // Load a small test program (similar to user's Python test)
    initial begin
        // Wait for reset to complete
        #30;

        // Clear memories
        for (i = 0; i < IMEM_SIZE; i = i + 1) imem[i] = 32'h00000013; // NOP
        for (i = 0; i < DMEM_SIZE; i = i + 1) dmem[i] = 32'hFFFFFFFF;

        // Program (addresses are word indices 0..)
        // 0x00: addi x1, x0, 0  -> 0x00000093
        // 0x04: addi x2, x0, 0  -> 0x00000113
        // 0x08: addi x1, x1, 1  -> 0x00108093
        // 0x0C: addi x3, x0, 3  -> 0x00300193
        // 0x10: beq  x1, x3, +12 -> make_beq(1,3,+12)
        // 0x14: addi x2, x2, 1  -> 0x00110113
        // 0x18: beq  x0, x0, -16 -> make_beq(0,0,-16)
        // 0x1C: sw   x1, 0(x0)   -> 0x00102023
        // 0x20: sw   x2, 4(x0)   -> 0x00202223
        // 0x24: halt (use an illegal/unique opcode to stop simulation monitoring)

        imem[0] = 32'h00000093;
        imem[1] = 32'h00000113;
        imem[2] = 32'h00108093;
        imem[3] = 32'h00300193;
        imem[4] = make_beq(1,3,12);
        imem[5] = 32'h00110113;
        imem[6] = make_beq(0,0,-16);
        imem[7] = 32'h00102023;
        imem[8] = 32'h00202223;
        imem[9] = 32'h00000063; // HALT (for our detection only)

        // Let simulation run for a while to execute program under latency
        #3000;

        $display("--- SIM RESULT ---");
        $display("dmem[0] = %0d (expect 3)", dmem[0]);
        $display("dmem[1] = %0d (expect 0)", dmem[1]);
        $finish;
    end

endmodule
