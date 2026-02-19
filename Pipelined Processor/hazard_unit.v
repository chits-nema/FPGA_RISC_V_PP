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
    reg lw_stall_r; //second stall cycle
    reg pcsrc_r; // remembers previous PcSrcE to detect rising edge

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
    // Don't trigger on writes to x0 (RdE == 0) - avoid spurious stalls
    assign lwstall = ResultSrcE & (RdE != 5'b0) & ((Rs1D == RdE) | (Rs2D == RdE));
    
    //register to extend stall for second cycle
    
    always @(posedge clk) begin
    if (!reset)
        lw_stall_r <= 1'b0;
    else
        lw_stall_r <= lwstall;  // delay stall by one cycle
    end

    // track previous PcSrcE to make branch flush a one-shot event
    always @(posedge clk) begin
        if (!reset)
            pcsrc_r <= 1'b0;
        else
            pcsrc_r <= PcSrcE;
    end
    
    //stall control logic. now covers 2 cycles
    always @(*) begin
        // one-cycle stall when branch is first detected to let PC update
        // and avoid re-fetching the same branch instruction
        reg pcsrc_stall;
        pcsrc_stall = PcSrcE & ~pcsrc_r;

        stallF = lwstall | lw_stall_r | pcsrc_stall;
        stallD = lwstall | lw_stall_r | pcsrc_stall;

        //flush on load-use in first cycle only. Do NOT flush ID->EX for branch
        // (branch should clear IF/ID only) so instructions in Decode that
        // must proceed into Execute (e.g. stores/loads) are not accidentally
        // cleared on the same clock edge.
        FlushE = lwstall;

        //flush IF/ID when branch taken (clear next fetch)
        FlushD = PcSrcE;
    end

endmodule