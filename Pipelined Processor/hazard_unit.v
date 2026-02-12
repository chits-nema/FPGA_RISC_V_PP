module hazard(
    
    input wire RegWriteE, // Register write enable in Execute

    input wire RegWriteM, // Register write enable in Memory

    input wire RegWriteW, // Register write enable in Writeback

    input wire ResultSrcE, // ResultSrc[0] - indicates load instruction

    input wire PcSrcE,  // Branch taken signal from Execute

    input wire [4:0] Rs1E, // Source register 1 in Execute

    input wire [4:0] Rs2E, // Source register 2 in Execute

    input wire [4:0] Rs1D, //input from decode (ID) stage, source reg 1 in decode

    input wire [4:0] RdE, // Destination register in Execute
    
    input wire [4:0] RdM, // Destination register in Memory
    
    input wire [4:0] RdW, // Destination register in Writeback

    input wire [4:0] Rs2D, //input from decode (ID) stage, source reg 2 in Decode

    output reg stallF, stallD,     // Stall control outputs F-Fetch D-Decode

    output reg FlushD, FlushE,   // Flush control outputs F-Fetch D-Decode

    output reg [1:0] ForwardAE,  // Forward control for ALU input A

    output reg [1:0] ForwardBE, // Forward control for ALU input B

    input clk, reset
);

    wire lwstall, branchStall;

    //---------------------forwarding logic for data hazard----------------------------------
    //forward from Memory stage
    // Forwarding logic for ALU input A (Rs1E)
    always @(*)begin
        if (RegWriteM & (Rs1E != 0) & (Rs1E == RdM)) begin
            ForwardAE = 2'b10;
        end else if (RegWriteW & (Rs1E != 0) & (Rs1E == RdW))begin
            ForwardAE = 2'b01;
        end else begin
            ForwardAE = 2'b00;
        end
    end

    //forward from Writeback stage
    // Forwarding logic for ALU input B (Rs2E)
    always @(*)begin
        if (RegWriteM & (Rs2E != 0) & (Rs2E == RdM)) begin
            ForwardBE = 2'b10;
        end else if (RegWriteW & (Rs2E != 0) & (Rs2E == RdW)) begin
            ForwardBE = 2'b01;
        end else ForwardBE = 2'b00;
    end

    //Data Hazards using stalls for load word instr
    assign lwstall = ResultSrcE & ((Rs1D == RdE)|(Rs2D==RdE));

    //stall control logic
    always @(*) begin
        stallF = lwstall;
        stallD = lwstall;

        //flush is stall or branch taken
        FlushE = lwstall || PcSrcE;


        //flash if branch taken
        FlushD = PcSrcE;
    end

endmodule