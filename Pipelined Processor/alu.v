module alu(
    input [31:0] SrcA, 
    input [31:0] SrcB, 
    input [3:0] ALUControl, 
    output reg [31:0] ALUResult, 
    output reg Zero
);

    always @(*) begin
        case(ALUControl)
            4'b0000 : ALUResult = SrcA + SrcB;  //add
            4'b0001 : ALUResult = SrcA - SrcB;  //sub
            4'b0010 : ALUResult = SrcA & SrcB;  //and
            4'b0011 : ALUResult = SrcA | SrcB;  //or
            4'b0101 : ALUResult = ($signed(SrcA) < $signed(SrcB)) ? 32'b1 : 32'b0;  //slt - this is signed
            4'b0111 : ALUResult = SrcA ^ SrcB; //xor
            4'b1000 : ALUResult = SrcA >>> SrcB[4:0]; //sra
            4'b1001 : ALUResult = SrcA >> SrcB[4:0]; //srl
            4'b1010 : ALUResult = SrcA << SrcB[4:0]; //sll
            4'b1011 : ALUResult = (SrcA < SrcB) ? 32'b1 : 32'b0; //sltu - this is unsigned
            default : ALUResult = 32'bx;
        endcase

        Zero = (ALUResult == 0) ? 1'b1 : 1'b0;
    end

endmodule