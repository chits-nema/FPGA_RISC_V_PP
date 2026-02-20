`timescale 1ns/1ps
`ifndef LAT
`define LAT 2
`endif

// Behavioral TB for rv_pl_wrapper (PL-side wrapper only)
// NOTE:
//  - This is NOT for design_1_wrapper (full Zynq PS/DDR top).
//  - rv_pl_wrapper exposes WORD addresses already:
//      imem_addr = F_pc[13:2], dmem_addr = M_ALUResult[13:2]
//    so TB indexes arrays directly (no >>2 in the TB).
module rv_pl_wrapper_behavioral_tb;

    reg clk;
    reg rst_n;

    wire [31:0] imem_addr;
    reg  [31:0] imem_dout;
    wire [31:0] dmem_addr;
    wire [3:0]  dmem_we;
    wire [31:0] dmem_din;
    reg  [31:0] dmem_dout;
    wire        done_flag;

    rv_pl_wrapper dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .imem_addr(imem_addr),
        .imem_dout(imem_dout),
        .dmem_addr(dmem_addr),
        .dmem_we  (dmem_we),
        .dmem_din (dmem_din),
        .dmem_dout(dmem_dout),
        .done_flag(done_flag)
    );

    parameter IMEM_SIZE = 512;
    parameter DMEM_SIZE = 512;
    localparam LATp = `LAT;

    reg [31:0] imem [0:IMEM_SIZE-1];
    reg [31:0] dmem [0:DMEM_SIZE-1];
    reg [31:0] imem_pipe [0:LATp-1];
    reg [31:0] dmem_pipe [0:LATp-1];

    integer i;
    integer k;
    integer ia;
    integer da;
    integer err;
    integer total;

    // ---------------- clock ----------------
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // ---------------- initial reset ----------------
    initial begin
        rst_n = 1'b0;
        #30;
        rst_n = 1'b1;
    end

    // ---------------- memory model ----------------
    // Registered BRAM-like latency model for both IMEM and DMEM
    always @(posedge clk) begin
        if (!rst_n) begin
            for (i = 0; i < LATp; i = i + 1) begin
                imem_pipe[i] <= 32'h00000013;
                dmem_pipe[i] <= 32'hFFFFFFFF;
            end
            imem_dout <= 32'h00000013;
            dmem_dout <= 32'hFFFFFFFF;
        end else begin
            // IMEM read path (word address)
            ia = imem_addr;
            if (ia >= 0 && ia < IMEM_SIZE)
                imem_pipe[0] <= imem[ia];
            else
                imem_pipe[0] <= 32'h00000013;

            for (i = 1; i < LATp; i = i + 1)
                imem_pipe[i] <= imem_pipe[i-1];
            imem_dout <= imem_pipe[LATp-1];

            // DMEM write path (word address)
            da = dmem_addr;
            if (dmem_we != 4'b0000 && da >= 0 && da < DMEM_SIZE)
                dmem[da] <= dmem_din;

            // DMEM read path
            if (da >= 0 && da < DMEM_SIZE)
                dmem_pipe[0] <= dmem[da];
            else
                dmem_pipe[0] <= 32'h0;

            for (i = 1; i < LATp; i = i + 1)
                dmem_pipe[i] <= dmem_pipe[i-1];
            dmem_dout <= dmem_pipe[LATp-1];
        end
    end

    // ---------------- helpers ----------------
    function [31:0] make_beq;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer offset;
        reg [12:0] imm;
        begin
            imm = offset & 13'h1fff;
            make_beq = {imm[12], imm[10:5], rs2, rs1, 3'b000, imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    function [31:0] make_bne;
        input [4:0] rs1;
        input [4:0] rs2;
        input integer offset;
        reg [12:0] imm;
        begin
            imm = offset & 13'h1fff;
            make_bne = {imm[12], imm[10:5], rs2, rs1, 3'b001, imm[4:1], imm[11], 7'b1100011};
        end
    endfunction

    task clear_mem;
        begin
            for (i = 0; i < IMEM_SIZE; i = i + 1) imem[i] = 32'h00000013;
            for (i = 0; i < DMEM_SIZE; i = i + 1) dmem[i] = 32'hFFFFFFFF;
        end
    endtask

    task step_cycles;
        input integer n;
        begin
            for (k = 0; k < n; k = k + 1) @(posedge clk);
        end
    endtask

    task reset_dut;
        begin
            rst_n = 1'b0;
            step_cycles(5);
            rst_n = 1'b1;
            step_cycles(LATp + 4);
        end
    endtask

    task check_word;
        input [31:0] got;
        input [31:0] exp;
        input [159:0] name;
        begin
            total = total + 1;
            if (got !== exp) begin
                $display("[FAIL] %0s : got=0x%08h (%0d) expected=0x%08h (%0d)", name, got, got, exp, exp);
                err = err + 1;
            end else begin
                $display("[PASS] %0s = 0x%08h (%0d)", name, got, got);
            end
        end
    endtask

    // ================================================================
    // TEST 1: RAW forwarding
    // ================================================================
    task test_raw_forwarding;
        begin
            $display("\n--- TEST 1: RAW forwarding (back-to-back ALU) ---");
            clear_mem();

            imem[0] = 32'h00500093; // addi x1, x0, 5
            imem[1] = 32'h00308113; // addi x2, x1, 3
            imem[2] = 32'h002081b3; // add  x3, x1, x2
            imem[3] = 32'h00202023; // sw   x2, 0(x0)
            imem[4] = 32'h00302223; // sw   x3, 4(x0)
            imem[5] = 32'h00000063; // halt

            reset_dut();
            step_cycles(80);

            check_word(dmem[0], 32'd8,  "TEST1 x2 (5+3)");
            check_word(dmem[1], 32'd13, "TEST1 x3 (5+8)");
        end
    endtask

    // ================================================================
    // TEST 2: Load-use hazard
    // ================================================================
    task test_load_use;
        begin
            $display("\n--- TEST 2: Load-use hazard (lw then immediate use) ---");
            clear_mem();
            dmem[0] = 32'd7;

            imem[0] = 32'h00002283; // lw   x5, 0(x0)
            imem[1] = 32'h00128313; // addi x6, x5, 1
            imem[2] = 32'h00230393; // addi x7, x6, 2
            imem[3] = 32'h00602223; // sw   x6, 4(x0)
            imem[4] = 32'h00702423; // sw   x7, 8(x0)
            imem[5] = 32'h00000063; // halt

            reset_dut();
            step_cycles(100);

            check_word(dmem[1], 32'd8,  "TEST2 x6 (lw 7 + 1)");
            check_word(dmem[2], 32'd10, "TEST2 x7 (8 + 2)");
        end
    endtask

    // ================================================================
    // TEST 3: BEQ taken loop
    // NOTE: with this program, x2 is expected to become 2 (not 0),
    // because addi x2,x2,1 executes on the first two non-taken iterations.
    // ================================================================
    task test_beq_loop_expected2;
        begin
            $display("\n--- TEST 3: BEQ taken loop semantics ---");
            clear_mem();

            imem[0] = 32'h00000093;            // addi x1, x0, 0
            imem[1] = 32'h00000113;            // addi x2, x0, 0
            imem[2] = 32'h00300193;            // addi x3, x0, 3
            imem[3] = 32'h00108093;            // addi x1, x1, 1
            imem[4] = make_beq(5'd1,5'd3, 12); // beq x1,x3,+12 -> to store block
            imem[5] = 32'h00110113;            // addi x2,x2,1  (runs for x1=1,2)
            imem[6] = make_beq(5'd0,5'd0,-16); // beq x0,x0,-16
            imem[7] = 32'h00102023;            // sw x1, 0(x0)
            imem[8] = 32'h00202223;            // sw x2, 4(x0)
            imem[9] = 32'h00000063;            // halt

            reset_dut();
            step_cycles(220);

            check_word(dmem[0], 32'd3, "TEST3 x1(loop count)");
            check_word(dmem[1], 32'd2, "TEST3 x2(expected=2 with this loop)");
        end
    endtask

    // ================================================================
    // TEST 4: Branch slip detector (strict no-slip expectation, BEQ-only)
    // Core currently decodes branch opcode as BEQ behavior, so avoid BNE here.
    // ================================================================
    task test_branch_no_slip;
        begin
            $display("\n--- TEST 4: Branch slip detector (expect x2=0) ---");
            clear_mem();

            imem[0] = 32'h00000093;             // addi x1, x0, 0
            imem[1] = 32'h00000113;             // addi x2, x0, 0
            imem[2] = 32'h00300193;             // addi x3, x0, 3
            // LOOP @ 0x0C
            imem[3] = 32'h00108093;             // addi x1, x1, 1
            imem[4] = make_beq(5'd1,5'd3, 12); // beq x1,x3,+12 -> exit to stores
            imem[5] = make_beq(5'd0,5'd0,-8);  // beq x0,x0,-8  -> back to LOOP (always taken)
            imem[6] = 32'h00110113;             // addi x2,x2,1 (slip detector; must never run)
            imem[7] = 32'h00102023;             // sw x1,0(x0)
            imem[8] = 32'h00202223;             // sw x2,4(x0)
            imem[9] = 32'h00000063;             // halt

            reset_dut();
            step_cycles(220);

            check_word(dmem[0], 32'd3, "TEST4 x1(loop count)");
            check_word(dmem[1], 32'd0, "TEST4 x2(no branch slip)");
        end
    endtask

    // ================================================================
    // TEST 5: LW->SW forwarding/dependency
    // ================================================================
    task test_load_store_forward;
        begin
            $display("\n--- TEST 5: LW->SW forwarding (load then store) ---");
            clear_mem();
            dmem[0] = 32'hDEADBEEF;

            imem[0] = 32'h00002283; // lw x5, 0(x0)
            imem[1] = 32'h00502223; // sw x5, 4(x0)
            imem[2] = 32'h00000063; // halt

            reset_dut();
            step_cycles(100);

            check_word(dmem[1], 32'hDEADBEEF, "TEST5 dmem[1] (lw->sw)");
        end
    endtask

    // ================================================================
    // TEST 6: BEQ not-taken
    // ================================================================
    task test_beq_not_taken;
        begin
            $display("\n--- TEST 6: BEQ not-taken (fall-through executes) ---");
            clear_mem();

            imem[0] = 32'h00100093;             // addi x1, x0, 1
            imem[1] = 32'h00200113;             // addi x2, x0, 2
            imem[2] = make_beq(5'd1, 5'd2, 8);  // beq x1,x2,+8 NOT taken
            imem[3] = 32'h00500193;             // addi x3, x0, 5
            imem[4] = 32'h00302023;             // sw x3, 0(x0)
            imem[5] = 32'h00000063;             // halt

            reset_dut();
            step_cycles(100);

            check_word(dmem[0], 32'd5, "TEST6 x3 (fall-through)");
        end
    endtask

    // ================================================================
    // MAIN
    // ================================================================
    initial begin
        err   = 0;
        total = 0;

        $dumpfile("rv_pl_wrapper_behavioral_tb.vcd");
        $dumpvars(0, rv_pl_wrapper_behavioral_tb);

        @(posedge rst_n);
        step_cycles(10);

        test_raw_forwarding();
        step_cycles(20);

        test_load_use();
        step_cycles(20);

        test_beq_loop_expected2();
        step_cycles(20);

        test_branch_no_slip();
        step_cycles(20);

        test_load_store_forward();
        step_cycles(20);

        test_beq_not_taken();
        step_cycles(20);

        $display("\n========================================");
        $display("RESULTS: %0d passed, %0d failed out of %0d checks", total - err, err, total);
        if (err == 0) $display("ALL CHECKS PASSED");
        else          $display("SOME CHECKS FAILED");
        $display("========================================\n");

        $finish;
    end

endmodule