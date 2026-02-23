module hazard(
    input wire clk,
    input wire reset,
    
    // Execute stage signals
    input wire RegWriteE,        // Register write enable in Execute
    input wire ResultSrcE,       // ResultSrc[0] - indicates load instruction in Execute
    input wire [4:0] Rs1E,       // Source register 1 in Execute
    input wire [4:0] Rs2E,       // Source register 2 in Execute
    input wire [4:0] RdE,        // Destination register in Execute
    input wire PcSrcE,           // Branch taken signal from Execute

    // Memory stage signals
    input wire RegWriteM,        // Register write enable in Memory
    input wire ResultSrcM,       // ResultSrc[0] - indicates load instruction in Memory
    input wire MemReadM,         // High when M stage has active load (for BRAM latency handling)
    input wire [4:0] RdM,        // Destination register in Memory

    // Writeback stage signals
    input wire RegWriteW,        // Register write enable in Writeback
    input wire [4:0] RdW,        // Destination register in Writeback

    // Decode stage signals
    input wire [4:0] Rs1D,       // Source register 1 in Decode
    input wire [4:0] Rs2D,       // Source register 2 in Decode

    // Forwarding control outputs
    output reg [1:0] ForwardAE,  // Forward control for ALU input A
    output reg [1:0] ForwardBE,  // Forward control for ALU input B

    // Stall control outputs (all pipeline stages)
    output reg stallF,           // Stall Fetch
    output reg stallD,           // Stall Decode
    output reg stallE,           // Stall Execute
    output reg stallM,           // Stall Memory

    // Flush control outputs
    output reg FlushD,           // Flush Decode
    output reg FlushE,           // Flush Execute
    output reg FlushM            // Flush Memory (insert bubble when E stalls)
);

    // Internal hazard detection signals
    wire lwstall;           // Load-use hazard: load in E or M, dependent in D

    //=====================================================================================
    // FORWARDING LOGIC
    //=====================================================================================
    // Forward from M or W stage to resolve data hazards
    // Don't forward from M stage if it's a load (data not ready until W)

    // Forwarding logic for ALU input A (Rs1E)
    always @(*) begin
        if (RegWriteM & (Rs1E != 0) & (Rs1E == RdM) & !ResultSrcM) begin
            // Forward from Memory stage (non-load instructions only)
            ForwardAE = 2'b10;
        end else if (RegWriteW & (Rs1E != 0) & (Rs1E == RdW)) begin
            // Forward from Writeback stage (always safe, including loads)
            ForwardAE = 2'b01;
        end else begin
            // No forwarding, use register file value
            ForwardAE = 2'b00;
        end
    end

    // Forwarding logic for ALU input B (Rs2E)
    always @(*) begin
        if (RegWriteM & (Rs2E != 0) & (Rs2E == RdM) & !ResultSrcM) begin
            // Forward from Memory stage (non-load instructions only)
            ForwardBE = 2'b10;
        end else if (RegWriteW & (Rs2E != 0) & (Rs2E == RdW)) begin
            // Forward from Writeback stage (always safe, including loads)
            ForwardBE = 2'b01;
        end else begin
            // No forwarding, use register file value
            ForwardBE = 2'b00;
        end
    end

    //=====================================================================================
    // LOAD-USE HAZARD DETECTION
    //=====================================================================================
    
    // Separate detection for different hazard cases
    // Case 1: Load in E or M, dependent in D (stall F and D)
    wire lwstall_D;
    assign lwstall_D = (ResultSrcE & ((Rs1D == RdE) | (Rs2D == RdE))) |
                       (ResultSrcM & ((Rs1D == RdM) | (Rs2D == RdM)));
    
    // Case 2: Load in M, dependent in E (stall F, D, and E)
    // This is critical for back-to-back loads followed by dependent instruction
    // Example: lw t2; lw t3; slt t4,t3,t2 <- when slt is in E, t3 is still loading in M!
    wire lwstall_E;
    assign lwstall_E = ResultSrcM & ((Rs1E == RdM) | (Rs2E == RdM));

    //=====================================================================================
    // STALL AND FLUSH CONTROL
    //=====================================================================================
    
    // Register to delay FlushE by one cycle to create FlushM
    reg FlushE_delayed;
    
    always @(posedge clk or negedge reset) begin
        if (!reset)
            FlushE_delayed <= 1'b0;
        else
            FlushE_delayed <= FlushE;
    end
    
    always @(*) begin
        // Default: no stalls or flushes
        stallF = 1'b0;
        stallD = 1'b0;
        stallE = 1'b0;
        stallM = 1'b0;
        FlushD = 1'b0;
        FlushE = 1'b0;
        FlushM = FlushE_delayed;  // Flush M when E was flushed last cycle        
        // Stall for load-use hazard with dependent in D (load in E or M, dependent in D)
        if (lwstall_D) begin
            stallF = 1'b1;  // Hold fetch
            stallD = 1'b1;  // Hold decode
            stallE = 1'b0;  // Let load continue through pipeline
            // Load proceeds E→M→W normally while dependent instruction waits in D
        end
        
        // Additional bubble insertion for load in M with dependent in E
        // This handles: lw (M), dependent instruction (E) - insert NOP, let load reach W
        // This is INDEPENDENT of lwstall_D - both can be true simultaneously!
        if (lwstall_E) begin
            stallF = 1'b1;   // Hold fetch
            stallD = 1'b1;   // Hold decode
            FlushE = 1'b1;   // Insert bubble in E stage
            // Load in M proceeds to W, dependent instruction stays in D
        end
        
        // Branch/Jump flush control (takes priority over stalls)
        if (PcSrcE) begin
            FlushE = 1'b1;  // Flush E on branch taken
            FlushD = 1'b1;  // Flush D on branch taken  
        end
    end

endmodule