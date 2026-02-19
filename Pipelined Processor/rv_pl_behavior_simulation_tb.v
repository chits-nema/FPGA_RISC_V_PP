`timescale 1ns/1ps
`ifndef LAT
`define LAT 2
`endif

module rv_pl_behavioral_signal_check_tb;

    // ---------------------------
    // Clock / reset
    // ---------------------------
    reg clk;
    reg rst_n;

    // DUT external ports
    wire [31:0] F_pc;
    reg  [31:0] F_instr;
    wire [31:0] M_ALUResult;
    wire        M_MemWrite;
    wire [31:0] M_WriteData;
    reg  [31:0] M_ReadDataW;

    rv_pl dut(
        .clk(clk),
        .rst_n(rst_n),
        .F_pc(F_pc),
        .F_instr(F_instr),
        .M_ALUResult(M_ALUResult),
        .M_MemWrite(M_MemWrite),
        .M_WriteData(M_WriteData),
        .M_ReadDataW(M_ReadDataW)
    );

    // ---------------------------
    // BRAM latency model
    // ---------------------------
    parameter IMEM_SIZE = 256;
    parameter DMEM_SIZE = 256;
    localparam LATp = `LAT;

    reg [31:0] imem [0:IMEM_SIZE-1];
    reg [31:0] dmem [0:DMEM_SIZE-1];
    reg [31:0] instr_pipe [0:LATp-1];
    reg [31:0] data_pipe  [0:LATp-1];

    integer i;
    integer cycle;
    integer error_count;

    reg [31:0] prev_pc;
    reg prev_branch;
    reg prev_stallF;

    // ---------------------------
    // ISA helper encoders
    // ---------------------------
    function [31:0] make_beq;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer offset;
        reg [12:0] imm;
        begin
            imm = offset & 13'h1fff;
            make_beq = ({imm[12], imm[10:5], rs2, rs1, 3'b000, imm[4:1], imm[11], 7'b1100011});
        end
    endfunction

    function [31:0] make_bne;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer offset;
        reg [12:0] imm;
        begin
            imm = offset & 13'h1fff;
            make_bne = ({imm[12], imm[10:5], rs2, rs1, 3'b001, imm[4:1], imm[11], 7'b1100011});
        end
    endfunction

    // ---------------------------
    // Utilities
    // ---------------------------
    task clear_mem;
        begin
            for (i = 0; i < IMEM_SIZE; i = i + 1) imem[i] = 32'h00000013; // NOP
            for (i = 0; i < DMEM_SIZE; i = i + 1) dmem[i] = 32'hFFFFFFFF;
        end
    endtask

    task check_eq;
        input [31:0] got;
        input [31:0] exp;
        input [255:0] msg;
        begin
            if (got !== exp) begin
                $display("[FAIL] %0s got=0x%08h exp=0x%08h @cycle=%0d", msg, got, exp, cycle);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %0s = 0x%08h", msg, got);
            end
        end
    endtask

    task run_for_cycles;
        input integer n;
        integer k;
        begin
            for (k = 0; k < n; k = k + 1) @(posedge clk);
        end
    endtask

    // ---------------------------
    // Clock / reset
    // ---------------------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 1'b0;
        #20;
        rst_n = 1'b1;
    end

    // ---------------------------
    // BRAM model
    // ---------------------------
    always @(posedge clk) begin
        integer iw;
        integer dw;
        if (!rst_n) begin
            for (i = 0; i < LATp; i = i + 1) begin
                instr_pipe[i] <= 32'h00000013;
                data_pipe[i]  <= 32'h0;
            end
            F_instr <= 32'h00000013;
            M_ReadDataW <= 32'h0;
        end else begin
            iw = F_pc[31:2];
            if (iw >= 0 && iw < IMEM_SIZE)
                instr_pipe[0] <= imem[iw];
            else
                instr_pipe[0] <= 32'h00000013;

            for (i = 1; i < LATp; i = i + 1)
                instr_pipe[i] <= instr_pipe[i-1];
            F_instr <= instr_pipe[LATp-1];

            dw = M_ALUResult[31:2];
            if (M_MemWrite && dw >= 0 && dw < DMEM_SIZE)
                dmem[dw] <= M_WriteData;

            if (dw >= 0 && dw < DMEM_SIZE)
                data_pipe[0] <= dmem[dw];
            else
                data_pipe[0] <= 32'h0;

            for (i = 1; i < LATp; i = i + 1)
                data_pipe[i] <= data_pipe[i-1];
            M_ReadDataW <= data_pipe[LATp-1];
        end
    end

    // ---------------------------
    // Signal health checks
    // ---------------------------
    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;

            // Unknown checks on key control/forwarding signals
            if (^dut.hazard_unit.stallF === 1'bx ||
                ^dut.hazard_unit.stallD === 1'bx ||
                ^dut.hazard_unit.FlushD === 1'bx ||
                ^dut.hazard_unit.FlushE === 1'bx ||
                ^dut.E_PCSrc            === 1'bx ||
                ^dut.M_MemWrite         === 1'bx ||
                ^dut.W_RegWrite         === 1'bx) begin
                $display("[FAIL] X detected on control signals @cycle=%0d", cycle);
                error_count = error_count + 1;
            end

            // Forwarding select sanity
            if (dut.hazard_unit.ForwardAE > 2'b10 || dut.hazard_unit.ForwardBE > 2'b10) begin
                $display("[FAIL] invalid forwarding select A=%b B=%b @cycle=%0d",
                    dut.hazard_unit.ForwardAE, dut.hazard_unit.ForwardBE, cycle);
                error_count = error_count + 1;
            end

            // Fetch stall semantics: when stalled, PC must hold.
            if (prev_stallF && (F_pc !== prev_pc)) begin
                $display("[FAIL] stallF=1 but PC changed prev=0x%08h now=0x%08h @cycle=%0d", prev_pc, F_pc, cycle);
                error_count = error_count + 1;
            end

            // If a branch was taken in previous cycle, PC should not remain stuck forever.
            if (prev_branch && (F_pc === prev_pc) && !dut.hazard_unit.stallF) begin
                $display("[FAIL] branch taken but PC did not move @cycle=%0d", cycle);
                error_count = error_count + 1;
            end

            prev_pc     <= F_pc;
            prev_branch <= dut.E_PCSrc;
            prev_stallF <= dut.hazard_unit.stallF;
        end else begin
            cycle      <= 0;
            prev_pc    <= 32'h0;
            prev_branch<= 1'b0;
            prev_stallF<= 1'b0;
        end
    end

    // ---------------------------
    // Tests
    // ---------------------------
    task test_branch_slip;
        begin
            $display("\n=== TEST1: branch slip detector ===");
            clear_mem();

            // 0x00 addi x1, x0, 0
            // 0x04 addi x2, x0, 0
            // 0x08 addi x1, x1, 1
            // 0x0C addi x3, x0, 3
            // 0x10 bne  x1, x3, -8
            // 0x14 addi x2, x2, 1   (must be squashed while looping)
            // 0x18 sw   x1, 0(x0)
            // 0x1C sw   x2, 4(x0)
            // 0x20 halt
            imem[0] = 32'h00000093;
            imem[1] = 32'h00000113;
            imem[2] = 32'h00108093;
            imem[3] = 32'h00300193;
            imem[4] = make_bne(5'd1, 5'd3, -8);
            imem[5] = 32'h00110113;
            imem[6] = 32'h00102023;
            imem[7] = 32'h00202223;
            imem[8] = 32'h00000063;

            run_for_cycles(120);
            check_eq(dmem[0], 32'd3, "branch loop count x1");
            check_eq(dmem[1], 32'd0, "branch slip count x2");
        end
    endtask

    task test_load_use;
        begin
            $display("\n=== TEST2: load-use under latency ===");
            clear_mem();

            // init data @ dmem[0] = 7
            dmem[0] = 32'd7;

            // 0x00 lw   x5,0(x0)
            // 0x04 addi x6,x5,1      (dependent on load)
            // 0x08 addi x7,x6,2      (dependent chain)
            // 0x0C sw   x6,4(x0)
            // 0x10 sw   x7,8(x0)
            // 0x14 halt
            imem[0] = 32'h00002283;
            imem[1] = 32'h00128313;
            imem[2] = 32'h00230393;
            imem[3] = 32'h00602223;
            imem[4] = 32'h00702423;
            imem[5] = 32'h00000063;

            run_for_cycles(120);
            check_eq(dmem[1], 32'd8, "lw->addi result (x6)");
            check_eq(dmem[2], 32'd10, "dependent chain result (x7)");
        end
    endtask

    initial begin
        error_count = 0;
        cycle = 0;

        $dumpfile("rv_pl_behavioral_signal_check_tb.vcd");
        $dumpvars(0, rv_pl_behavioral_signal_check_tb);

        @(posedge rst_n);
        run_for_cycles(5);

        test_branch_slip();
        run_for_cycles(10);
        test_load_use();
        run_for_cycles(10);

        if (error_count == 0) begin
            $display("\nALL CHECKS PASSED");
        end else begin
            $display("\nCHECKS FAILED, error_count=%0d", error_count);
        end
        $finish;
    end

endmodule
