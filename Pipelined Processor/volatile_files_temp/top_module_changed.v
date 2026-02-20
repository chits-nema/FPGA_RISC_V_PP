module rv_pl(
    input clk,
    input rst_n,

    //Ibram Interface
    output [31:0] F_pc,
    input [31:0] F_instr,

    //Memory stage for DMEM Interface
    output [31:0] M_ALUResult,
    output M_MemWrite,
    output [31:0] M_WriteData,
    input [31:0] M_ReadDataW
);

//----------------------------------------------------FETCH-------------------------------------
wire [31:0] F_pc_next;
wire [31:0] F_pc_plus_4;
// CHANGE 1: stallF and D_stall are no longer declared here as simple wires.
// They are now combined signals (hazard unit output | StallM).
// Declared further down after the hazard wires are defined.

//-----------------------------------------------------DECODE------------------------------------
wire [31:0] D_instr;
// CHANGE 1 (continued): D_stall also moved - see declaration near hazard unit.
wire D_flush;
wire [31:0] D_pc;
wire [4:0] D_Rs1;
wire [4:0] D_Rs2;
wire [4:0] D_Rd;
wire [31:0] D_ImmExt;
wire [31:0] D_pc_plus_4;
wire [1:0] D_ResultSrc;
wire D_MemWrite;
wire D_Branch, D_ALUSrcBSel;
wire D_RegWrite, D_Jump;
wire [2:0] D_ImmSrc;
wire [3:0] D_ALUControl;
wire D_ALUSrcASel;
wire [31:0] D_RD1;
wire [31:0] D_RD2;

//-------------------------------------------------------EXECUTE---------------------------------------------
wire [31:0] E_pc;
wire [4:0] E_Rs1;
wire [4:0] E_Rs2;
wire [4:0] E_Rd;
wire [31:0] E_ImmExt;
wire [31:0] E_pc_plus_4;
wire [1:0] E_ResultSrc;
wire E_MemWrite;
wire E_Branch;
wire E_RegWrite, E_Jump;
wire [3:0] E_ALUControl;
wire E_ALUSrcASel, E_ALUSrcBSel;
wire E_PCSrc;
wire E_Zero;
wire [31:0] E_RD1, E_RD2;
wire [31:0] E_SrcA, E_SrcB;
wire [31:0] E_SrcA_forwarded, E_SrcB_forwarded;
wire [31:0] E_WriteData;
wire [31:0] E_pcTarget;
wire [31:0] E_ALUResult;
wire [1:0] E_ForwardA, E_ForwardB;
wire E_flush;

//---------------------------------------------------------MEMORY----------------------------------------------
wire M_RegWrite;
wire [1:0] M_ResultSrc;
wire [4:0] M_Rd;
wire [31:0] M_pc_plus_4;

//-----------------------------------------------------------WRITEBACK----------------------------------------------------
wire W_RegWrite;
wire [1:0] W_ResultSrc;
wire [31:0] W_ALUResult;
wire [31:0] W_ReadData;
wire [4:0] W_Rd;
wire [31:0] W_Result;
wire [31:0] W_pc_plus_4;

wire [1:0] ForwardAE, ForwardBE;

// CHANGE 2: StallM - stalls PLR3 and PLR4 during DMEM BRAM read latency.
// DMEM is synchronous BRAM: address is presented in M stage, but data only
// arrives the cycle after. Without stalling PLR4, it latches before BRAM has
// responded, giving garbage in W_ReadData for load instructions.
wire StallM;
wire MemReadM;
assign MemReadM = (M_ResultSrc == 2'b01); // 01 = load (selects ReadData in writeback mux)
assign StallM   = MemReadM;

// CHANGE 3: Separate raw hazard unit outputs from the final stall signals.
// The hazard unit only handles load-use and branch hazards. It is unaware of StallM.
// We combine them below so the whole pipeline freezes during a DMEM stall.
wire hazard_stallF, hazard_stallD;

// CHANGE 4: Final combined stall signals used everywhere in the pipeline.
// StallM freezes the front too - otherwise new instructions keep advancing
// into M/W stages while they are stalled.
wire stallF  = hazard_stallF | StallM;
wire D_stall = hazard_stallD | StallM;

//=============================================== FETCH STAGE ===============================================

pc pc_reg(
    .clk(clk),
    .rst_n(rst_n),
    .en(stallF),        // uses combined stallF (CHANGE 4)
    .pc_in(F_pc_next),
    .out(F_pc)
);

adder pc_add(
    .a(F_pc),
    .b(32'd4),
    .y(F_pc_plus_4)
);

assign F_pc_next = (E_PCSrc === 1'b1) ? E_pcTarget : F_pc_plus_4;

//=============================================== IF/ID Pipeline Register (PLR1) ===============================================

// CHANGE 5: Delayed PC to align with BRAM instruction output.
// BRAM latches i_addr at posedge clk and outputs i_instr ONE CYCLE LATER.
// So when F_instr is valid on the bus, F_pc has already advanced.
// F_pc_reg_delayed holds the PC from the previous cycle, which is the one
// that actually corresponds to F_instr. Also respects stallF to stay in sync.
reg [31:0] F_pc_reg_delayed;
always @(posedge clk) begin
    if (!rst_n)
        F_pc_reg_delayed <= 32'b0;
    else if (!stallF)   // must stall together with PC and PLR1
        F_pc_reg_delayed <= F_pc;
end

// CHANGE 6: PC+4 for PLR1 must be based on the delayed PC, not F_pc.
// The Decode stage uses D_pc_plus_4 for JAL/JALR return addresses and branch
// target calculations. If it were based on F_pc it would be one cycle ahead,
// producing wrong results.
wire [31:0] F_pc_delayed_plus_4;
adder pc_delayed_add(
    .a(F_pc_reg_delayed),
    .b(32'd4),
    .y(F_pc_delayed_plus_4)
);

// CHANGE 7: Two-cycle branch flush for BRAM fetch latency.
// When a branch is taken, BRAM needs one full cycle to fetch the target instruction.
// The hazard unit only asserts FlushD for one cycle (cycle of branch detection).
// We register E_PCSrc to produce a second flush the following cycle:
//   Cycle 0: branch taken, D_flush=1 from hazard unit -> PLR1 flushed
//   Cycle 1: BRAM still outputting stale instruction -> branch_flush_r=1 -> PLR1 flushed again
//   Cycle 2: BRAM outputs correct instruction at branch target
reg branch_flush_r;
always @(posedge clk) begin
    if (!rst_n) branch_flush_r <= 1'b0;
    else        branch_flush_r <= E_PCSrc;
end
wire FD_flush_final = D_flush | branch_flush_r;

if_id_reg PLR1(
    .clk(clk),
    .rst_n(rst_n),
    .en(stallF),                        // combined stall (CHANGE 4)
    .clr(FD_flush_final),               // CHANGE 7: two-cycle flush (was just D_flush)
    .F_pc(F_pc_reg_delayed),            // CHANGE 5: aligned with BRAM output (was F_pc)
    .F_instr(F_instr),
    .F_pc_plus_4(F_pc_delayed_plus_4),  // CHANGE 6: from delayed PC (was F_pc_plus_4)
    .D_pc(D_pc),
    .D_instr(D_instr),
    .D_pc_plus_4(D_pc_plus_4)
);

//=============================================== DECODE STAGE ===============================================
assign D_Rs1 = D_instr[19:15];
assign D_Rs2 = D_instr[24:20];
assign D_Rd  = D_instr[11:7];

regfile RF(
    .clk(clk),
    .we3(W_RegWrite),
    .a1(D_Rs1),
    .a2(D_Rs2),
    .a3(W_Rd),
    .wd3(W_Result),
    .rd1(D_RD1),
    .rd2(D_RD2)
);

controller control_unit(
    .op(D_instr[6:0]),
    .funct3(D_instr[14:12]),
    .funct7b5(D_instr[30]),
    .ResultSrc(D_ResultSrc),
    .MemWrite(D_MemWrite),
    .Branch(D_Branch),
    .ALUSrcBSel(D_ALUSrcBSel),
    .RegWrite(D_RegWrite),
    .Jump(D_Jump),
    .ImmSrc(D_ImmSrc),
    .ALUControl(D_ALUControl),
    .ALUSrcASel(D_ALUSrcASel)
);

extend ext_unit(
    .instr(D_instr[31:7]),
    .immsrc(D_ImmSrc),
    .immext(D_ImmExt)
);

//=============================================== ID/EX Pipeline Register (PLR2) ===============================================
decode_execute_reg PLR2(
    .clk(clk),
    .rst_n(rst_n),
    .FlushE(E_flush),
    .RegWriteD(D_RegWrite),
    .ResultSrcD(D_ResultSrc),
    .MemWriteD(D_MemWrite),
    .JumpD(D_Jump),
    .BranchD(D_Branch),
    .ALUControlD(D_ALUControl),
    .ALUSrcD(D_ALUSrcBSel),
    .ALUSrcASelD(D_ALUSrcASel),
    .RD1D(D_RD1),
    .RD2D(D_RD2),
    .PCD(D_pc),
    .Rs1D(D_Rs1),
    .Rs2D(D_Rs2),
    .RdD(D_Rd),
    .ImmExtD(D_ImmExt),
    .PCPlus4D(D_pc_plus_4),
    .RegWriteE(E_RegWrite),
    .ResultSrcE(E_ResultSrc),
    .MemWriteE(E_MemWrite),
    .JumpE(E_Jump),
    .BranchE(E_Branch),
    .ALUControlE(E_ALUControl),
    .ALUSrcE(E_ALUSrcBSel),
    .ALUSrcASelE(E_ALUSrcASel),
    .RD1E(E_RD1),
    .RD2E(E_RD2),
    .PCE(E_pc),
    .Rs1E(E_Rs1),
    .Rs2E(E_Rs2),
    .RdE(E_Rd),
    .ImmExtE(E_ImmExt),
    .PCPlus4E(E_pc_plus_4)
);

//=============================================== EXECUTE STAGE ===============================================
mux3 #(32) forward_mux_a(
    .d0(E_RD1),
    .d1(W_Result),
    .d2(M_ALUResult),
    .s(ForwardAE),
    .y(E_SrcA_forwarded)
);

mux2 #(32) alu_srca_mux(
    .d0(E_SrcA_forwarded),
    .d1(32'b0),
    .s(E_ALUSrcASel),
    .y(E_SrcA)
);

mux3 #(32) forward_mux_b(
    .d0(E_RD2),
    .d1(W_Result),
    .d2(M_ALUResult),
    .s(ForwardBE),
    .y(E_SrcB_forwarded)
);

assign E_WriteData = E_SrcB_forwarded;

mux2 #(32) alu_srcb_mux(
    .d0(E_SrcB_forwarded),
    .d1(E_ImmExt),
    .s(E_ALUSrcBSel),
    .y(E_SrcB)
);

alu main_alu(
    .SrcA(E_SrcA),
    .SrcB(E_SrcB),
    .ALUControl(E_ALUControl),
    .ALUResult(E_ALUResult),
    .Zero(E_Zero)
);

assign E_PCSrc = (E_Branch & E_Zero) | E_Jump;

always @(posedge clk) begin
    if (E_PCSrc)
        $display("BRANCH TAKEN: E_pcTarget=0x%08h, E_pc=0x%08h, E_ImmExt=0x%08h",
                  E_pcTarget, E_pc, E_ImmExt);
end

always @(posedge clk) begin
    if (E_PCSrc)
        $display("BRANCH: E_pc=0x%h (should be 0x10 for imem[4]), E_Rd=%0d, E_Rs1=%0d",
                  E_pc, E_Rd, E_Rs1);
end

adder pc_target_add(
    .a(E_pc),
    .b(E_ImmExt),
    .y(E_pcTarget)
);

//=============================================== EX/MA Pipeline Register (PLR3) ===============================================
execute_memory_reg PLR3(
    .clk(clk),
    .rst_n(rst_n),
    .flush(1'b0),
    .stall(StallM),             // CHANGE 2: hold PLR3 while DMEM BRAM responds
    .RegWriteE(E_RegWrite),
    .ResultSrcE(E_ResultSrc),
    .MemWriteE(E_MemWrite),
    .ALUResultE(E_ALUResult),
    .WriteDataE(E_WriteData),
    .RdE(E_Rd),
    .PCPlus4E(E_pc_plus_4),
    .RegWriteM(M_RegWrite),
    .ResultSrcM(M_ResultSrc),
    .MemWriteM(M_MemWrite),
    .ALUResultM(M_ALUResult),
    .WriteDataM(M_WriteData),
    .RdM(M_Rd),
    .PCPlus4M(M_pc_plus_4)
);

//=============================================== MEMORY STAGE ===============================================

//=============================================== MA/WB Pipeline Register (PLR4) ===============================================
memory_writeback_reg PLR4(
    .clk(clk),
    .rst_n(rst_n),
    .stall(StallM),             // CHANGE 2: hold PLR4 so ReadData is captured after BRAM responds
    .RegWriteM(M_RegWrite),
    .ResultSrcM(M_ResultSrc),
    .ALUResultM(M_ALUResult),
    .ReadDataM(M_ReadDataW),
    .RdM(M_Rd),
    .PCPlus4M(M_pc_plus_4),
    .RegWriteW(W_RegWrite),
    .ResultSrcW(W_ResultSrc),
    .ALUResultW(W_ALUResult),
    .ReadDataW(W_ReadData),
    .RdW(W_Rd),
    .PCPlus4W(W_pc_plus_4)
);

//=============================================== WRITEBACK STAGE ===============================================
mux3 #(32) result_mux(
    .d0(W_ALUResult),
    .d1(W_ReadData),
    .d2(W_pc_plus_4),
    .s(W_ResultSrc),
    .y(W_Result)
);

//=============================================== HAZARD UNIT ===============================================
hazard hazard_unit(
    .RegWriteE(E_RegWrite),
    .RegWriteM(M_RegWrite),
    .RegWriteW(W_RegWrite),
    .ResultSrcE(E_ResultSrc[0]),
    .PcSrcE(E_PCSrc),
    .Rs1E(E_Rs1),
    .Rs2E(E_Rs2),
    .Rs1D(D_Rs1),
    .RdE(E_Rd),
    .RdM(M_Rd),
    .RdW(W_Rd),
    .Rs2D(D_Rs2),
    .stallF(hazard_stallF),     // CHANGE 3: raw output, combined with StallM in CHANGE 4
    .stallD(hazard_stallD),     // CHANGE 3: raw output, combined with StallM in CHANGE 4
    .FlushD(D_flush),
    .FlushE(E_flush),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .clk(clk),
    .reset(rst_n)
);

endmodule
