module aludec(
    input opb5,
    input [2:0] funct3,
    input funct7b5,
    input [1:0] ALUOp,
    output reg [3:0] ALUControl
);

    always @(*)begin
        case(ALUOp)
            2'b00:  ALUControl = 4'b0000; //addition for lw and sw
            2'b01:  ALUControl = 4'b0001; //subtraction for beq
            2'b10: case(funct3) //R-type or I-type ALU
                        3'b000: if(funct7b5 & opb5)begin  // sub only for R-type (opb5=1)
                                    ALUControl = 4'b0001; //sub
                                end else ALUControl= 4'b0000; //add,addi
                        3'b001: ALUControl = 4'b1010; //sll 
                        3'b010: ALUControl = 4'b0101; //slt
                        3'b011: ALUControl = 4'b1011; //sltu
                        3'b100: ALUControl = 4'b0111; //xor
                        3'b101: if (funct7b5) begin
                                    ALUControl = 4'b1000 ; //sra
                                end else ALUControl = 4'b1001; //srl 
                        3'b110: ALUControl = 4'b0011; //or
                        3'b111: ALUControl = 4'b0010; //and
                        default: ALUControl = 4'bxxxx; // ???
                    endcase
            default: ALUControl = 4'bxxxx;
        endcase
    end


endmodule