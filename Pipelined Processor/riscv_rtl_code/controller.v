`include "ALU_Decoder.v"
`include "main_decoder.v"

module controller(
    input [6:0] op,
    input [2:0] funct3,
    input funct7b5,
    output [1:0] ResultSrc,
    output MemWrite,
    output Branch, ALUSrcBSel,
    output RegWrite, Jump,
    output [2:0] ImmSrc,
    output [3:0] ALUControl,
    output ALUSrcASel
);

    wire [1:0] ALUOp;

    maindec md(.op(op), .ResultSrc(ResultSrc), .MemWrite(MemWrite), .Branch(Branch), .ALUSrcBSel(ALUSrcBSel), .RegWrite(RegWrite), .Jump(Jump), .ImmSrc(ImmSrc), .ALUOp(ALUOp), .ALUSrcASel(ALUSrcASel));
    aludec ad(op[5], funct3, funct7b5, ALUOp, ALUControl);

endmodule