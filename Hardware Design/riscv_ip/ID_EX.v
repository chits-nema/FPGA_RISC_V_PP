module decode_execute_reg(
    input clk,
    input rst_n,            // Active-low reset
    input FlushE,           // Flush signal (clear control signals)
    input stallE,           // Stall signal (hold current values)
    
    // Control signals from Decode
    input RegWriteD,
    input [1:0] ResultSrcD,
    input MemWriteD,
    input JumpD,
    input BranchD,
    input [3:0] ALUControlD,
    input ALUSrcD,
    input ALUSrcASelD,
    
    // Data signals from Decode
    input [31:0] RD1D,      // Register data 1
    input [31:0] RD2D,      // Register data 2
    input [31:0] PCD,
    input [4:0] Rs1D,
    input [4:0] Rs2D,
    input [4:0] RdD,
    input [31:0] ImmExtD,
    input [31:0] PCPlus4D,
    
    // Control outputs to Execute
    output reg RegWriteE,
    output reg [1:0] ResultSrcE,
    output reg MemWriteE,
    output reg JumpE,
    output reg BranchE,
    output reg [3:0] ALUControlE,
    output reg ALUSrcE,
    output reg ALUSrcASelE,
    
    // Data outputs to Execute
    output reg [31:0] RD1E,
    output reg [31:0] RD2E,
    output reg [31:0] PCE,
    output reg [4:0] Rs1E,
    output reg [4:0] Rs2E,
    output reg [4:0] RdE,
    output reg [31:0] ImmExtE,
    output reg [31:0] PCPlus4E
);

always @(posedge clk) begin
        if (!rst_n) begin
            // Reset: clear everything
            RegWriteE <= 1'b0;
            ResultSrcE <= 2'b00;
            MemWriteE <= 1'b0;
            JumpE <= 1'b0;
            BranchE <= 1'b0;
            ALUControlE <= 4'b0000;
            ALUSrcE <= 1'b0;
            ALUSrcASelE <= 1'b0;
            
            RD1E <= 32'b0;
            RD2E <= 32'b0;
            PCE <= 32'b0;
            Rs1E <= 5'b0;
            Rs2E <= 5'b0;
            RdE <= 5'b0;
            ImmExtE <= 32'b0;
            PCPlus4E <= 32'b0;
        end
        else if (stallE) begin
            // Stall: hold all current values (don't update from D stage)
            // All outputs keep their current values
            RegWriteE <= RegWriteE;
            ResultSrcE <= ResultSrcE;
            MemWriteE <= MemWriteE;
            JumpE <= JumpE;
            BranchE <= BranchE;
            ALUControlE <= ALUControlE;
            ALUSrcE <= ALUSrcE;
            ALUSrcASelE <= ALUSrcASelE;
            
            RD1E <= RD1E;
            RD2E <= RD2E;
            PCE <= PCE;
            Rs1E <= Rs1E;
            Rs2E <= Rs2E;
            RdE <= RdE;
            ImmExtE <= ImmExtE;
            PCPlus4E <= PCPlus4E;
        end
        else if (FlushE) begin
            // Flush: ONLY clear control signals to insert NOP
            // CRITICAL: Keep E's CURRENT data values, don't update from D!
            // When FlushE and stallD happen together (lwstall_E), D may have stale/zero data
            // Latching from D would propagate those zeros to E, then to WriteDataM
            RegWriteE <= 1'b0;
            ResultSrcE <= 2'b00;
            MemWriteE <= 1'b0;
            JumpE <= 1'b0;
            BranchE <= 1'b0;
            ALUControlE <= 4'b0000;
            ALUSrcE <= 1'b0;
            ALUSrcASelE <= 1'b0;
            
            // Keep current E values unchanged (don't update from D stage)
            // Data doesn't matter since all control signals are 0, but keeping
            // current data prevents zeros from D stage entering the pipeline
            RD1E <= RD1E;
            RD2E <= RD2E;
            PCE <= PCE;
            Rs1E <= Rs1E;
            Rs2E <= Rs2E;
            RdE <= RdE;
            ImmExtE <= ImmExtE;
            PCPlus4E <= PCPlus4E;
        end
        else begin
            // Normal operation: latch new values from decode stage
            RD1E <= RD1D;
            RD2E <= RD2D;
            PCE <= PCD;
            Rs1E <= Rs1D;
            Rs2E <= Rs2D;
            RdE <= RdD;
            ImmExtE <= ImmExtD;
            PCPlus4E <= PCPlus4D;
            
            RegWriteE <= RegWriteD;
            ResultSrcE <= ResultSrcD;
            MemWriteE <= MemWriteD;
            JumpE <= JumpD;
            BranchE <= BranchD;
            ALUControlE <= ALUControlD;
            ALUSrcE <= ALUSrcD;
            ALUSrcASelE <= ALUSrcASelD;
        end
    end


endmodule