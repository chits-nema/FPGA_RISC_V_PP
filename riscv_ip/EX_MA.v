module execute_memory_reg(
    input clk,
    input rst_n,            // Active-low reset
    input flush,            // Flush signal (for exceptions, not control hazards)
    
    // Control signals from Execute
    input RegWriteE,
    input [1:0] ResultSrcE,
    input MemWriteE,
    
    // Data signals from Execute
    input [31:0] ALUResultE,
    input [31:0] WriteDataE,
    input [4:0] RdE,
    input [31:0] PCPlus4E,
    
    // Control outputs to Memory
    output reg RegWriteM,
    output reg [1:0] ResultSrcM,
    output reg MemWriteM,
    
    // Data outputs to Memory
    output reg [31:0] ALUResultM,
    output reg [31:0] WriteDataM,
    output reg [4:0] RdM,
    output reg [31:0] PCPlus4M
);

    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset: clear control signals
            RegWriteM <= 1'b0;
            ResultSrcM <= 2'b00;
            MemWriteM <= 1'b0;
            
            ALUResultM <= 32'b0;
            WriteDataM <= 32'b0;
            RdM <= 5'b0;
            PCPlus4M <= 32'b0;
        end
        else if (flush) begin
            // Flush: ONLY clear control signals to insert NOP
            // CRITICAL: Do NOT clear data! Clearing WriteData to 0 could cause
            // accidental zero writes if MemWrite isn't properly cleared first
            RegWriteM <= 1'b0;
            ResultSrcM <= 2'b00;
            MemWriteM <= 1'b0;
            // Data passes through unchanged (don't care since MemWrite=0, RegWrite=0)
            ALUResultM <= ALUResultE;
            WriteDataM <= WriteDataE;
            RdM <= RdE;
            PCPlus4M <= PCPlus4E;
        end
        else begin
            // Normal operation: pass values through
            RegWriteM <= RegWriteE;
            ResultSrcM <= ResultSrcE;
            MemWriteM <= MemWriteE;
            
            ALUResultM <= ALUResultE;
            WriteDataM <= WriteDataE;
            RdM <= RdE;
            PCPlus4M <= PCPlus4E;
        end
    end

endmodule