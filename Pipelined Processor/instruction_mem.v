module imem #(parameter MEM_DEPTH = 64)(
    input [31:0] a,
    output [31:0] rd
);
reg [31:0] RAM[0:MEM_DEPTH - 1];


assign rd = RAM[a[31:2]]; //a represents address in imem

endmodule