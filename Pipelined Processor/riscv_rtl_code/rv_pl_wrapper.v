module rv_pl_wrapper (
    input clk,
    input rst_n,

    //IMEM Interface
    output [31:0] imem_addr, //Goes from wrapper to IBRAM 'only 11 bits are used 2048 words bram '
    input [31:0] imem_dout,  //IBRAM to wrapper (to be sent to top module)
 
    //DMEM Interface
    output [31:0] dmem_addr, 
    output [3:0] dmem_we, // vivado bram has it as 4bits
    output [31:0] dmem_din, 
    input [31:0] dmem_dout,
    output reg done_flag
);

//Internal wires for the pipelined processor
wire [31:0] F_pc;
wire [31:0] M_ALUResult;
wire M_MemWrite;
wire [31:0] M_WriteData;

rv_pl rv_pl (
    .clk(clk),
    .rst_n(rst_n),
    .F_pc(F_pc),
    .F_instr(imem_dout),
    .M_ALUResult(M_ALUResult),
    .M_MemWrite(M_MemWrite),
    .M_WriteData(M_WriteData),
    .M_ReadDataW(dmem_dout)
);

//Connecting the imem interface
assign imem_addr = {18'b0, F_pc[13:2]}; // not sure if we should consider the depth or this is okay

//Connecting the data memory interface
assign dmem_addr = {18'b0, M_ALUResult[13:2]};
assign dmem_we = M_MemWrite ? 4'b1111 : 4'b0000 ; //dmem_we is 4 bits, M_MemWrite is 1 bit, this is how we'll translate it
assign dmem_din = M_WriteData;

//Signal done flag when program writes DEADBEEF into 0x2000
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) done_flag <= 1'b0;
    else if (M_MemWrite && M_ALUResult == 32'h00002000 && M_WriteData == 32'hDEADBEEF) 
        done_flag <= 1'b1;
end

endmodule
