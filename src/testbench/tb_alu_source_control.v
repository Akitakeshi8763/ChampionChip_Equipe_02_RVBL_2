module testbench();

    reg [3:0] instr_type_i;
    wire alu_src_a_o, alu_src_b_o;

    integer errors;

    localparam TYPE_ALU_REG = 4'b0000;
    localparam TYPE_ALU_IMM = 4'b0001;
    localparam TYPE_LOAD    = 4'b0010;
    localparam TYPE_STORE   = 4'b0011;
    localparam TYPE_BRANCH  = 4'b0100;
    localparam TYPE_JAL     = 4'b0101;
    localparam TYPE_JALR    = 4'b0110;
    localparam TYPE_LUI     = 4'b0111;
    localparam TYPE_AUIPC   = 4'b1000;
    localparam TYPE_MULT    = 4'b1010;
    localparam TYPE_CRC     = 4'b1011;

    alu_source_control dut (
        .instr_type_i(instr_type_i),
        .alu_src_a_o(alu_src_a_o),
        .alu_src_b_o(alu_src_b_o)
    );

    task check;
        input [8*32-1:0] label;
        input exp_a; // 0=rs1, 1=PC
        input exp_b; // 0=rs2, 1=immediate
        begin
            #1;
            if (alu_src_a_o !== exp_a || alu_src_b_o !== exp_b) begin
                $display("FAIL: %0s expected(a=%b,b=%b) got(a=%b,b=%b)",
                    label, exp_a, exp_b, alu_src_a_o, alu_src_b_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> a=%b(%0s) b=%b(%0s)", label, alu_src_a_o,
                    (alu_src_a_o ? "PC" : "rs1"), alu_src_b_o, (alu_src_b_o ? "imm" : "rs2"));
            end
        end
    endtask

    initial begin
        errors = 0;

        // R-type ALU: rs1, rs2
        instr_type_i = TYPE_ALU_REG;
        check("ALU_REG -> rs1,rs2", 1'b0, 1'b0);

        // I-type ALU: rs1, immediate
        instr_type_i = TYPE_ALU_IMM;
        check("ALU_IMM -> rs1,imm", 1'b0, 1'b1);

        // Load address calc: rs1 + imm
        instr_type_i = TYPE_LOAD;
        check("LOAD -> rs1,imm", 1'b0, 1'b1);

        // Store address calc: rs1 + imm
        instr_type_i = TYPE_STORE;
        check("STORE -> rs1,imm", 1'b0, 1'b1);

        // JALR target: rs1 + imm
        instr_type_i = TYPE_JALR;
        check("JALR -> rs1,imm", 1'b0, 1'b1);

        // Branch target: PC + imm
        instr_type_i = TYPE_BRANCH;
        check("BRANCH -> PC,imm", 1'b1, 1'b1);

        // JAL target: PC + imm
        instr_type_i = TYPE_JAL;
        check("JAL -> PC,imm", 1'b1, 1'b1);

        // AUIPC: PC + imm
        instr_type_i = TYPE_AUIPC;
        check("AUIPC -> PC,imm", 1'b1, 1'b1);

        // LUI: only needs immediate on B (A is don't-care/rs1 by default)
        instr_type_i = TYPE_LUI;
        check("LUI -> rs1(unused),imm", 1'b0, 1'b1);

        // MULT / CRC are not routed through alu_src at all in this
        // module (they bypass the ALU entirely) -- default case
        // should apply: rs1, rs2
        instr_type_i = TYPE_MULT;
        check("MULT (default, unused by ALU) -> rs1,rs2", 1'b0, 1'b0);

        instr_type_i = TYPE_CRC;
        check("CRC (default, unused by ALU) -> rs1,rs2", 1'b0, 1'b0);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("ALU_SOURCE_CONTROL TESTBENCH: PASS");
            $display("All operand-source selections correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("ALU_SOURCE_CONTROL TESTBENCH: FAIL");
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
