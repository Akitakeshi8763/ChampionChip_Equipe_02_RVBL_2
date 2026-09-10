module testbench();

    reg [3:0] instr_type_i;
    reg [2:0] funct3_i;
    wire [2:0] branch_sel_o;
    wire branch_valid_o;

    integer errors;

    localparam TYPE_ALU_REG = 4'b0000;
    localparam TYPE_LOAD    = 4'b0010;
    localparam TYPE_BRANCH  = 4'b0100;
    localparam TYPE_JAL     = 4'b0101;

    branch_control dut (
        .instr_type_i(instr_type_i),
        .funct3_i(funct3_i),
        .branch_sel_o(branch_sel_o),
        .branch_valid_o(branch_valid_o)
    );

    task check;
        input [8*40-1:0] label;
        input [2:0] exp_sel;
        input exp_valid;
        begin
            #1;
            if (branch_sel_o !== exp_sel || branch_valid_o !== exp_valid) begin
                $display("FAIL: %0s expected(sel=%b,valid=%b) got(sel=%b,valid=%b)",
                    label, exp_sel, exp_valid, branch_sel_o, branch_valid_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> sel=%b valid=%b", label, branch_sel_o, branch_valid_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        // Sweep all 6 real RISC-V branch funct3 codes while
        // instr_type_i == BRANCH
        instr_type_i = TYPE_BRANCH; funct3_i = 3'b000; // BEQ
        check("BRANCH funct3=000 (BEQ)", 3'b000, 1'b1);

        instr_type_i = TYPE_BRANCH; funct3_i = 3'b001; // BNE
        check("BRANCH funct3=001 (BNE)", 3'b001, 1'b1);

        instr_type_i = TYPE_BRANCH; funct3_i = 3'b100; // BLT
        check("BRANCH funct3=100 (BLT)", 3'b100, 1'b1);

        instr_type_i = TYPE_BRANCH; funct3_i = 3'b101; // BGE
        check("BRANCH funct3=101 (BGE)", 3'b101, 1'b1);

        instr_type_i = TYPE_BRANCH; funct3_i = 3'b110; // BLTU
        check("BRANCH funct3=110 (BLTU)", 3'b110, 1'b1);

        instr_type_i = TYPE_BRANCH; funct3_i = 3'b111; // BGEU
        check("BRANCH funct3=111 (BGEU)", 3'b111, 1'b1);

        // Non-branch instruction types must force valid=0
        // regardless of funct3_i content
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b000;
        check("ALU_REG (not branch) -> valid=0", 3'b000, 1'b0);

        instr_type_i = TYPE_LOAD; funct3_i = 3'b010;
        check("LOAD (not branch) -> valid=0", 3'b000, 1'b0);

        instr_type_i = TYPE_JAL; funct3_i = 3'b101;
        check("JAL (not branch) -> valid=0", 3'b000, 1'b0);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("BRANCH_CONTROL TESTBENCH: PASS");
            $display("Branch select passthrough and gating correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("BRANCH_CONTROL TESTBENCH: FAIL");
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
