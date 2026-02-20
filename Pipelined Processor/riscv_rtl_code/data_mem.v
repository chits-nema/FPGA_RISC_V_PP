module dmem #(parameter MEM_DEPTH = 64)(
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);
    reg [31:0] RAM[0:MEM_DEPTH-1];

    always @(posedge clk) begin
        if (we) begin
            RAM[a[31:2]] <= wd;
        end
    end

    assign rd = RAM[a[31:2]]; //word aligned - asynchronous read


endmodule