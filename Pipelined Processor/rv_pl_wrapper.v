`include "top_module.v"

module rv_pl_wrapper (
    input clk,
    input rst,

    //IMEM Interface
    output [31:0] imem_addr, //Goes from wrapper to IBRAM
    input [31:0] imem_dout,  //IBRAM to wrapper (to be sent to top module)

    //DMEM Interface
    output [31:0] dmem_addr, 
    output dmem_we, 
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
    .rst_n(rst),
    .F_pc(F_pc),
    .F_instr(imem_dout),
    .M_ALUResult(M_ALUResult),
    .M_MemWrite(M_MemWrite),
    .M_WriteData(M_WriteData),
    .M_ReadDataW(dmem_dout)
);

//Connecting the imem interface
assign imem_addr = F_pc;

//Connecting the data memory interface
assign dmem_addr = M_ALUResult;
assign dmem_we = M_MemWrite;
assign dmem_din = M_WriteData;

//Signal done flag when program writes DEADBEEF into 0x2000
always @(posedge clk or negedge rst) begin
    if (!rst) done_flag <= 1'b0;
    else if (dmem_we && dmem_addr == 32'h00002000 && dmem_din == 32'hDEADBEEF) 
        done_flag <= 1'b1;
end

endmodule
