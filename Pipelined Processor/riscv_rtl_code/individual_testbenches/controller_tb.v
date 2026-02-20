`include "controller.v"
`timescale 1ns / 1ps

module controller_tb;
    reg [6:0] opcode;
    reg [2:0] funct3;
    reg funct7_5;
    wire [3:0] alu_control;
    wire [2:0] sel_ext;
    wire sel_alu_src_b;
    wire sel_alu_src_a;
    wire rf_we;
    wire dmem_we, Zero, Branch, Jump, PCSrc;
    wire [1:0] sel_result;
    
    integer errors = 0;

    // Instantiate the controller module
    controller CTRL (
        .op(opcode),
        .funct3(funct3),
        .funct7b5(funct7_5),
        .Zero(Zero),
        .Branch(Branch),
        .Jump(Jump),
        .ALUControl(alu_control),
        .ImmSrc(sel_ext),
        .ALUSrcBSel(sel_alu_src_b),
        .ALUSrcASel(sel_alu_src_a),
        .RegWrite(rf_we),
        .MemWrite(dmem_we),
        .ResultSrc(sel_result),
        .PCSrc(PCSrc)
    );
    
    // Task to check assertions
    task check_signals;
        input [3:0] exp_alu_ctrl;
        input exp_rf_we;
        input exp_dmem_we;
        input [1:0] exp_result_src;
        input exp_alu_src_b;
        input exp_alu_src_a;
        input [2:0] exp_imm_src;
        input exp_branch;
        input exp_jump;
        input [1:0] exp_aluop;
        input [8*20:1] test_name;  // String as packed array (20 characters max)
        begin
            if (alu_control !== exp_alu_ctrl) begin
                $display("ERROR [%s]: ALUControl = %b, expected %b", test_name, alu_control, exp_alu_ctrl);
                errors = errors + 1;
            end
            if (rf_we !== exp_rf_we) begin
                $display("ERROR [%s]: RegWrite = %b, expected %b", test_name, rf_we, exp_rf_we);
                errors = errors + 1;
            end
            if (dmem_we !== exp_dmem_we) begin
                $display("ERROR [%s]: MemWrite = %b, expected %b", test_name, dmem_we, exp_dmem_we);
                errors = errors + 1;
            end
            if (sel_result !== exp_result_src) begin
                $display("ERROR [%s]: ResultSrc = %b, expected %b", test_name, sel_result, exp_result_src);
                errors = errors + 1;
            end
            if (sel_alu_src_b !== exp_alu_src_b) begin
                $display("ERROR [%s]: ALUSrcB = %b, expected %b", test_name, sel_alu_src_b, exp_alu_src_b);
                errors = errors + 1;
            end
            if (sel_alu_src_a !== exp_alu_src_a) begin
                $display("ERROR [%s]: ALUSrcA = %b, expected %b", test_name, sel_alu_src_a, exp_alu_src_a);
                errors = errors + 1;
            end
            if (sel_ext !== exp_imm_src && exp_imm_src !== 3'bxxx) begin
                $display("ERROR [%s]: ImmSrc = %b, expected %b", test_name, sel_ext, exp_imm_src);
                errors = errors + 1;
            end
            if (Branch !== exp_branch) begin
                $display("ERROR [%s]: Branch = %b, expected %b", test_name, Branch, exp_branch);
                errors = errors + 1;
            end
            if (Jump !== exp_jump) begin
                $display("ERROR [%s]: Jump = %b, expected %b", test_name, Jump, exp_jump);
                errors = errors + 1;
            end
            // Check internal ALUOp signal from main decoder
            if (CTRL.ALUOp !== exp_aluop) begin
                $display("ERROR [%s]: ALUOp (internal) = %b, expected %b", test_name, CTRL.ALUOp, exp_aluop);
                errors = errors + 1;
            end
            
            if (alu_control == exp_alu_ctrl && rf_we == exp_rf_we && dmem_we == exp_dmem_we && 
                sel_result == exp_result_src && sel_alu_src_b == exp_alu_src_b && 
                sel_alu_src_a == exp_alu_src_a && Branch == exp_branch && Jump == exp_jump &&
                CTRL.ALUOp == exp_aluop && (sel_ext == exp_imm_src || exp_imm_src == 3'bxxx)) begin
                $display("PASS [%s]: All signals correct", test_name);
            end
        end
    endtask

    task init();
        begin
        opcode = 7'b0000000;
        funct3 = 3'b000;
        funct7_5 = 1'b0;
        end   
    endtask

    initial begin
        $dumpfile("controller_tb.vcd");
        $dumpvars(0, controller_tb);

        init();
        #10;

        // Test R-type instructions
        $display("\n=== R-Type Instructions ===");
        
        // ADD (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b000;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0000, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "ADD");

        // SUB (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b000;
        funct7_5 = 1'b1;
        #10;
        check_signals(4'b0001, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "SUB");

        // AND (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b111;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0010, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "AND");

        // OR (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b110;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0011, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "OR");

        // XOR (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b100;
        funct7_5 = 1'bx;
        #10;
        check_signals(4'b0111, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "XOR");

        //SLL (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b001;
        funct7_5 = 1'bx;
        #10;
        check_signals(4'b1010, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "SLL");

        //SLTU (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b011;
        funct7_5 = 1'bx;
        #10;
        check_signals(4'b1011, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "SLTU");

        //SRA (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b101;
        funct7_5 = 1'b1;
        #10;
        check_signals(4'b1000, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "SRA");

        //SRL (R-type)
        opcode = 7'b0110011;
        funct3 = 3'b101;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b1001, 1'b1, 1'b0, 2'b00, 1'b0, 1'b0, 3'bxxx, 1'b0, 1'b0, 2'b10, "SRL");

        // Test I-type instructions
        $display("\n=== I-Type Instructions ===");
        
        // ADDI
        opcode = 7'b0010011;
        funct3 = 3'b000;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0000, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "ADDI");

        // ORI
        opcode = 7'b0010011;
        funct3 = 3'b110;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0011, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "ORI");

        // ANDI
        opcode = 7'b0010011;
        funct3 = 3'b111;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0010, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "ANDI");

        // XOR (I-type)
        opcode = 7'b0010011;
        funct3 = 3'b100;
        funct7_5 = 1'bx;
        #10;
        check_signals(4'b0111, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "XORI");

        //SLL (I-type)
        opcode = 7'b0010011;
        funct3 = 3'b001;
        funct7_5 = 1'bx;
        #10;
        check_signals(4'b1010, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "SLLI");

        //SLTU (I-type)
        opcode = 7'b0010011;
        funct3 = 3'b011;
        funct7_5 = 1'bx;
        #10;
        check_signals(4'b1011, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "SLTUI");

        //SRA (I-type)
        opcode = 7'b0010011;
        funct3 = 3'b101;
        funct7_5 = 1'b1;
        #10;
        check_signals(4'b1000, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "SRAI");

        //SRL (I-type)
        opcode = 7'b0010011;
        funct3 = 3'b101;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b1001, 1'b1, 1'b0, 2'b00, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b10, "SRLI");


        // Test Load instruction
        $display("\n=== Load Instructions ===");
        opcode = 7'b0000011;
        funct3 = 3'b010; // LW
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0000, 1'b1, 1'b0, 2'b01, 1'b1, 1'b0, 3'b000, 1'b0, 1'b0, 2'b00, "LW");

        // Test Store instruction
        $display("\n=== Store Instructions ===");
        opcode = 7'b0100011;
        funct3 = 3'b010; // SW
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0000, 1'b0, 1'b1, 2'bxx, 1'b1, 1'b0, 3'b001, 1'b0, 1'b0, 2'b00, "SW");

        // Test Branch instruction
        $display("\n=== Branch Instructions ===");
        opcode = 7'b1100011;
        funct3 = 3'b000; // BEQ
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0001, 1'b0, 1'b0, 2'bxx, 1'b0, 1'b0, 3'b010, 1'b1, 1'b0, 2'b01, "BEQ");

        // Test JAL instruction
        $display("\n=== Jump Instructions ===");
        opcode = 7'b1101111;
        funct3 = 3'b000;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'bxxxx, 1'b1, 1'b0, 2'b10, 1'bx, 1'b0, 3'b011, 1'b0, 1'b1, 2'bxx, "JAL");

        // Test LUI instruction
        $display("\n=== Upper Immediate Instructions ===");
        opcode = 7'b0110111;
        funct3 = 3'b000;
        funct7_5 = 1'b0;
        #10;
        check_signals(4'b0000, 1'b1, 1'b0, 2'b00, 1'b1, 1'b1, 3'b100, 1'b0, 1'b0, 2'b00, "LUI");
        


        // Display summary
        $display("\n=== Test Summary ===");
        if (errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("TESTS FAILED: %0d errors found", errors);
        end

        $finish;
    end
endmodule