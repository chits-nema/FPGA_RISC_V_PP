module pc(
    input wire clk,
    input wire rst_n,  // Active-low reset
    input wire en, //stallf signal to hold pc value
    input [31:0] pc_in,
    output reg [31:0] out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out <= 32'b0;
        end else if (en) begin
            // When stalled (en=1), hold current value
            out <= out;
        end else begin
            // When not stalled (en=0), update PC
            out <= pc_in;
        end
    end

endmodule