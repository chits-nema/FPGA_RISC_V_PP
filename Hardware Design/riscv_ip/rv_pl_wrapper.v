module rv_pl_wrapper (
    input clk,
    input rst_n,

    //IMEM Interface (Read-only from processor side)
    output [31:0] imem_addr, //Byte address to IBRAM
    output imem_en,          //Enable signal for IBRAM
    input [31:0] imem_dout,  //Instruction data from IBRAM
 
    //DMEM Interface (Read/Write from processor side)
    output [31:0] dmem_addr, //Byte address to DBRAM
    output dmem_en,          //Enable signal for DBRAM
    output [3:0] dmem_we,    //Write enable (4-bit for byte-enable)
    output [31:0] dmem_din,  //Write data to DBRAM
    input [31:0] dmem_dout,  //Read data from DBRAM
    
    output reg done_flag
);

//Internal wires for the pipelined processor
wire [31:0] F_pc;
wire [31:0] M_ALUResult;
wire M_MemWrite;
wire [31:0] M_WriteData;
wire stallF;

rv_pl rv_pl (
    .clk(clk),
    .rst_n(rst_n),
    .F_pc(F_pc),
    .F_instr(imem_dout),
    .stallF_out(stallF),
    .M_ALUResult(M_ALUResult),
    .M_MemWrite(M_MemWrite),
    .M_WriteData(M_WriteData),
    .M_ReadDataW(dmem_dout)
);

//Connecting the imem interface
// Pass full byte address - BRAM controller handles word alignment internally
assign imem_addr = F_pc;           // Full byte address from PC
assign imem_en = !stallF;          // Disable fetch during stalls to prevent misalignment

//Connecting the data memory interface
// Pass full byte address - BRAM controller handles word alignment internally
assign dmem_addr = M_ALUResult;    // Full byte address from ALU
assign dmem_en = 1'b1;             // Always enabled
assign dmem_we = M_MemWrite ? 4'b1111 : 4'b0000; // Write all bytes or none
assign dmem_din = M_WriteData;

//Signal done flag when program writes DEADBEEF into 0x2000
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) done_flag <= 1'b0;
    else if (M_MemWrite && M_ALUResult == 32'h00002000 && M_WriteData == 32'hDEADBEEF) 
        done_flag <= 1'b1;
end

endmodule
