module if_id_reg(
    input clk, rst_n,
    input en, //F_stall
    input clr, //D_flush
    input [31:0] F_pc,
    input [31:0] F_instr,
    input [31:0] F_pc_plus_4,
    output reg [31:0] D_pc,
    output reg [31:0] D_instr,
    output reg [31:0] D_pc_plus_4
);
    always @(posedge clk) begin
        if (!rst_n) begin
            //reset to NOP (addi x0, x0, 0)
            D_instr <= 32'h00000013;
            D_pc <= 32'h0;
            D_pc_plus_4 <= 32'h0;
        end else if (clr) begin
            // Flush: only clear instruction to NOP, keep PC valid for hazard detection
            D_instr <= 32'h00000013;
            // Don't clear D_pc and D_pc_plus_4 - needed for hazard logic
        end else if (en) begin
            // Stalled - keep current values
            D_instr <= D_instr;
            D_pc <= D_pc;
            D_pc_plus_4 <= D_pc_plus_4;
        end else begin
            // Not stalled - update with new values
            D_instr <= F_instr;
            D_pc <= F_pc;
            D_pc_plus_4 <= F_pc_plus_4;
        end
    end

endmodule