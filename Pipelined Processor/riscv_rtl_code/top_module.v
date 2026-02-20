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
//wire [31:0] F_pc;
wire [31:0] F_pc_plus_4;
//wire [31:0] F_instr;
wire stallF;

//-----------------------------------------------------DECODE------------------------------------
wire [31:0] D_instr;
wire D_stall, D_flush;
wire [31:0] D_pc;
wire [4:0] D_Rs1; //19:15
wire [4:0] D_Rs2; //24:20
wire [4:0] D_Rd;  //11:7
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
//
wire [31:0] E_pc;
wire [4:0] E_Rs1; //19:15
wire [4:0] E_Rs2; //24:20
wire [4:0] E_Rd;  //11:7
wire [31:0] E_ImmExt;
wire [31:0] E_pc_plus_4;
wire [1:0] E_ResultSrc;
wire E_MemWrite;
wire E_Branch;
wire E_RegWrite, E_Jump;
wire [3:0] E_ALUControl;

//ALU and forwarding signals
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
//wire M_MemWrite;
//wire [31:0] M_ALUResult;
//wire [31:0] M_WriteData;
wire [4:0] M_Rd;
wire [31:0] M_pc_plus_4;
//wire [31:0] M_ReadDataW;
//-----------------------------------------------------------WRITEBACK----------------------------------------------------
wire W_RegWrite;
wire [1:0] W_ResultSrc;
wire [31:0] W_ALUResult;
wire [31:0] W_ReadData;
wire [4:0] W_Rd;
wire [31:0] W_Result;
wire [31:0] W_pc_plus_4;

//Hazard control sigsnals
wire [1:0] ForwardAE, ForwardBE;

// Program Counter
pc pc_reg(
    .clk(clk),
    .rst_n(rst_n),
    .en(stallF),
    .pc_in(F_pc_next),
    .out(F_pc)
);

// PC + 4 Adder
adder pc_add(
    .a(F_pc),
    .b(32'd4),
    .y(F_pc_plus_4)
);

// PC Source Mux (PC_next = PCSrc ? E_pcTarget : PC+4)
// Use case equality to treat undefined PCSrc as 0 (no branch)
assign F_pc_next = (E_PCSrc === 1'b1) ? E_pcTarget : F_pc_plus_4;

// Instruction Memory
/*imem #(64) IMEM(
    .a(F_pc),
    .rd(F_instr)
);
*/

//=============================================== IF/ID Pipeline Register (PLR1) ===============================================
if_id_reg PLR1(
    .clk(clk),
    .rst_n(rst_n),
    .en(stallF),
    .clr(D_flush),
    .F_pc(F_pc),
    .F_instr(F_instr),
    .F_pc_plus_4(F_pc_plus_4),
    .D_pc(D_pc),
    .D_instr(D_instr),
    .D_pc_plus_4(D_pc_plus_4)
);

//=============================================== DECODE STAGE ===============================================
// Extract register addresses
assign D_Rs1 = D_instr[19:15];
assign D_Rs2 = D_instr[24:20];
assign D_Rd = D_instr[11:7];

// Register File
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

// Controller
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

// Extend Unit
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
    // Control signals
    .RegWriteD(D_RegWrite),
    .ResultSrcD(D_ResultSrc),
    .MemWriteD(D_MemWrite),
    .JumpD(D_Jump),
    .BranchD(D_Branch),
    .ALUControlD(D_ALUControl),
    .ALUSrcD(D_ALUSrcBSel),
    .ALUSrcASelD(D_ALUSrcASel),
    // Data signals
    .RD1D(D_RD1),
    .RD2D(D_RD2),
    .PCD(D_pc),
    .Rs1D(D_Rs1),
    .Rs2D(D_Rs2),
    .RdD(D_Rd),
    .ImmExtD(D_ImmExt),
    .PCPlus4D(D_pc_plus_4),
    // Outputs
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
// Forward Mux A (for ALU SrcA)
mux3 #(32) forward_mux_a(
    .d0(E_RD1),
    .d1(W_Result),
    .d2(M_ALUResult),
    .s(ForwardAE),
    .y(E_SrcA_forwarded)
);

// ALU SrcA Mux (select between forwarded value or 0 for LUI)
mux2 #(32) alu_srca_mux(
    .d0(E_SrcA_forwarded),
    .d1(32'b0),
    .s(E_ALUSrcASel),
    .y(E_SrcA)
);

// Forward Mux B (for ALU SrcB)
mux3 #(32) forward_mux_b(
    .d0(E_RD2),
    .d1(W_Result),
    .d2(M_ALUResult),
    .s(ForwardBE),
    .y(E_SrcB_forwarded)
);

// Store E_SrcB_forwarded as WriteData for memory stage
assign E_WriteData = E_SrcB_forwarded;

// ALU SrcB Mux (select between forwarded RD2 or Immediate)
mux2 #(32) alu_srcb_mux(
    .d0(E_SrcB_forwarded),
    .d1(E_ImmExt),
    .s(E_ALUSrcBSel),
    .y(E_SrcB)
);

// ALU
alu main_alu(
    .SrcA(E_SrcA),
    .SrcB(E_SrcB),
    .ALUControl(E_ALUControl),
    .ALUResult(E_ALUResult),
    .Zero(E_Zero)
);

// PC Source logic (Branch taken or Jump)
assign E_PCSrc = (E_Branch & E_Zero) | E_Jump;

// PC Target calculation (for branches/jumps)
adder pc_target_add(
    .a(E_pc),
    .b(E_ImmExt),
    .y(E_pcTarget)
);

//=============================================== EX/MA Pipeline Register (PLR3) ===============================================
execute_memory_reg PLR3(
    .clk(clk),
    .rst_n(rst_n),
    .flush(1'b0),  // Not used for control hazards (branches/jumps) - only for exceptions
    // Control signals
    .RegWriteE(E_RegWrite),
    .ResultSrcE(E_ResultSrc),
    .MemWriteE(E_MemWrite),
    // Data signals
    .ALUResultE(E_ALUResult),
    .WriteDataE(E_WriteData),
    .RdE(E_Rd),
    .PCPlus4E(E_pc_plus_4),
    // Outputs
    .RegWriteM(M_RegWrite),
    .ResultSrcM(M_ResultSrc),
    .MemWriteM(M_MemWrite),
    .ALUResultM(M_ALUResult),
    .WriteDataM(M_WriteData),
    .RdM(M_Rd),
    .PCPlus4M(M_pc_plus_4)
);

//=============================================== MEMORY STAGE ===============================================
// Data Memory
/*dmem DMEM(
    .clk(clk),
    .we(M_MemWrite),
    .a(M_ALUResult),
    .wd(M_WriteData),
    .rd(M_ReadDataW)
);
*/

//=============================================== MA/WB Pipeline Register (PLR4) ===============================================
memory_writeback_reg PLR4(
    .clk(clk),
    .rst_n(rst_n),
    // Control signals
    .RegWriteM(M_RegWrite),
    .ResultSrcM(M_ResultSrc),
    // Data signals
    .ALUResultM(M_ALUResult),
    .ReadDataM(M_ReadDataW),
    .RdM(M_Rd),
    .PCPlus4M(M_pc_plus_4),
    // Outputs
    .RegWriteW(W_RegWrite),
    .ResultSrcW(W_ResultSrc),
    .ALUResultW(W_ALUResult),
    .ReadDataW(W_ReadData),
    .RdW(W_Rd),
    .PCPlus4W(W_pc_plus_4)
);

//=============================================== WRITEBACK STAGE ===============================================
// Result Mux (select between ALUResult, ReadData, or PC+4)
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
    .stallF(stallF),
    .stallD(D_stall),
    .FlushD(D_flush),
    .FlushE(E_flush),
    .ForwardAE(ForwardAE),
    .ForwardBE(ForwardBE),
    .BranchD(D_Branch),
    .clk(clk),
    .reset(rst_n)
);

endmodule
