module memory_writeback_reg(
    input clk,
    input rst_n,            // Active-low reset
    
    // Control signals from Memory
    input RegWriteM,
    input [1:0] ResultSrcM,
    
    // Data signals from Memory
    input [31:0] ALUResultM,
    input [31:0] ReadDataM,
    input [4:0] RdM,
    input [31:0] PCPlus4M,
    
    // Control outputs to Writeback
    output reg RegWriteW,
    output reg [1:0] ResultSrcW,
    
    // Data outputs to Writeback
    output reg [31:0] ALUResultW,
    output reg [31:0] ReadDataW,
    output reg [4:0] RdW,
    output reg [31:0] PCPlus4W
);

    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset: clear control signals
            RegWriteW <= 1'b0;
            ResultSrcW <= 2'b00;
            
            ALUResultW <= 32'b0;
            ReadDataW <= 32'b0;
            RdW <= 5'b0;
            PCPlus4W <= 32'b0;
        end
        else begin
            // Normal operation: pass values through
            RegWriteW <= RegWriteM;
            ResultSrcW <= ResultSrcM;
            
            ALUResultW <= ALUResultM;
            ReadDataW <= ReadDataM;
            RdW <= RdM;
            PCPlus4W <= PCPlus4M;
        end
    end

endmodule