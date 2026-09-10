module testbench();

    reg [31:0] instruction_i;
    wire [6:0] opcode_o;
    wire [2:0] funct3_o;
    wire [6:0] funct7_o;

    integer errors;

    instruction_decoder dut (
        .instruction_i(instruction_i),
        .opcode_o(opcode_o),
        .funct3_o(funct3_o),
        .funct7_o(funct7_o)
    );

    task check;
        input [8*32-1:0] label;
        input [6:0] exp_opcode;
        input [2:0] exp_funct3;
        input [6:0] exp_funct7;
        begin
            #1;
            if (opcode_o !== exp_opcode || funct3_o !== exp_funct3 || funct7_o !== exp_funct7) begin
                $display("FAIL: %0s  exp(op=%b f3=%b f7=%b) got(op=%b f3=%b f7=%b)",
                    label, exp_opcode, exp_funct3, exp_funct7, opcode_o, funct3_o, funct7_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> opcode=%b funct3=%b funct7=%b", label, opcode_o, funct3_o, funct7_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        // -----------------------------------------------------
        // ADD x1, x2, x3
        // funct7=0000000 rs2=00011 rs1=00010 funct3=000 rd=00001 opcode=0110011
        // -----------------------------------------------------
        instruction_i = 32'b0000000_00011_00010_000_00001_0110011;
        check("ADD x1,x2,x3", 7'b0110011, 3'b000, 7'b0000000);

        // -----------------------------------------------------
        // SUB x1, x2, x3
        // funct7=0100000
        // -----------------------------------------------------
        instruction_i = 32'b0100000_00011_00010_000_00001_0110011;
        check("SUB x1,x2,x3", 7'b0110011, 3'b000, 7'b0100000);

        // -----------------------------------------------------
        // ADDI x5, x6, 100  (I-type; funct7 field is actually
        // part of the immediate here, but the decoder just
        // slices bits mechanically regardless of type, so we
        // check it extracts exactly what the bit positions say)
        // imm[11:0]=000001100100 rs1=00110 funct3=000 rd=00101 opcode=0010011
        // -----------------------------------------------------
        instruction_i = 32'b000001100100_00110_000_00101_0010011;
        check("ADDI x5,x6,100", 7'b0010011, 3'b000, instruction_i[31:25]);

        // -----------------------------------------------------
        // LW x10, 8(x11)
        // opcode=0000011 funct3=010(LW)
        // -----------------------------------------------------
        instruction_i = 32'b000000001000_01011_010_01010_0000011;
        check("LW x10,8(x11)", 7'b0000011, 3'b010, instruction_i[31:25]);

        // -----------------------------------------------------
        // All-ones instruction: sanity check upper/lower bit
        // boundaries are exactly right (off-by-one would show
        // here immediately since every bit is 1)
        // -----------------------------------------------------
        instruction_i = 32'hFFFFFFFF;
        check("All-ones sanity", 7'b1111111, 3'b111, 7'b1111111);

        // -----------------------------------------------------
        // All-zeros instruction
        // -----------------------------------------------------
        instruction_i = 32'h00000000;
        check("All-zeros sanity", 7'b0000000, 3'b000, 7'b0000000);

        // -----------------------------------------------------
        // Isolated bit walk through opcode field (bits 6:0) to
        // confirm no bit is mis-mapped
        // -----------------------------------------------------
        instruction_i = 32'h00000001; // opcode bit 0 only
        check("opcode bit0 walk", 7'b0000001, 3'b000, 7'b0000000);

        instruction_i = 32'h00000040; // opcode bit 6 only (bit 6 of instr = bit 6 of opcode)
        check("opcode bit6 walk", 7'b1000000, 3'b000, 7'b0000000);

        instruction_i = 32'h00001000; // funct3 bit 0 only (instr bit 12)
        check("funct3 bit0 walk", 7'b0000000, 3'b001, 7'b0000000);

        instruction_i = 32'h80000000; // funct7 MSB only (instr bit 31)
        check("funct7 MSB walk", 7'b0000000, 3'b000, 7'b1000000);

        // -----------------------------------------------------
        // FINAL RESULT
        // -----------------------------------------------------
        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("INSTRUCTION_DECODER TESTBENCH: PASS");
            $display("All bit-field extractions correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("INSTRUCTION_DECODER TESTBENCH: FAIL");
            $display("Number of errors = %0d", errors);
            $display("========================================");
        end

        $finish;
    end

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);
    end

endmodule
