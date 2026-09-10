module testbench();

    reg [3:0] instr_type_i;
    reg [2:0] funct3_i;
    wire [2:0] lsu_op_o;
    wire lsu_valid_o;

    integer errors;

    localparam TYPE_ALU_REG = 4'b0000;
    localparam TYPE_LOAD    = 4'b0010;
    localparam TYPE_STORE   = 4'b0011;
    localparam TYPE_BRANCH  = 4'b0100;

    lsu_control dut (
        .instr_type_i(instr_type_i),
        .funct3_i(funct3_i),
        .lsu_op_o(lsu_op_o),
        .lsu_valid_o(lsu_valid_o)
    );

    task check;
        input [8*40-1:0] label;
        input [2:0] exp_op;
        input exp_valid;
        begin
            #1;
            if (lsu_op_o !== exp_op || lsu_valid_o !== exp_valid) begin
                $display("FAIL: %0s expected(op=%b,valid=%b) got(op=%b,valid=%b)",
                    label, exp_op, exp_valid, lsu_op_o, lsu_valid_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> op=%b valid=%b", label, lsu_op_o, lsu_valid_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        // LOAD: funct3 passes through as-is, valid asserted.
        // Sweep all 5 real load funct3 codes (LB,LH,LW,LBU,LHU)
        instr_type_i = TYPE_LOAD; funct3_i = 3'b000; // LB
        check("LOAD funct3=000 (LB)", 3'b000, 1'b1);

        instr_type_i = TYPE_LOAD; funct3_i = 3'b001; // LH
        check("LOAD funct3=001 (LH)", 3'b001, 1'b1);

        instr_type_i = TYPE_LOAD; funct3_i = 3'b010; // LW
        check("LOAD funct3=010 (LW)", 3'b010, 1'b1);

        instr_type_i = TYPE_LOAD; funct3_i = 3'b100; // LBU
        check("LOAD funct3=100 (LBU)", 3'b100, 1'b1);

        instr_type_i = TYPE_LOAD; funct3_i = 3'b101; // LHU
        check("LOAD funct3=101 (LHU)", 3'b101, 1'b1);

        // STORE: funct3 passes through, valid asserted.
        // Real store funct3 codes: SB=000, SH=001, SW=010
        instr_type_i = TYPE_STORE; funct3_i = 3'b000;
        check("STORE funct3=000 (SB)", 3'b000, 1'b1);

        instr_type_i = TYPE_STORE; funct3_i = 3'b001;
        check("STORE funct3=001 (SH)", 3'b001, 1'b1);

        instr_type_i = TYPE_STORE; funct3_i = 3'b010;
        check("STORE funct3=010 (SW)", 3'b010, 1'b1);

        // Non-memory instruction types must force valid=0
        // regardless of whatever garbage sits on funct3_i
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b111;
        check("ALU_REG (not mem op) -> valid=0", 3'b000, 1'b0);

        instr_type_i = TYPE_BRANCH; funct3_i = 3'b011;
        check("BRANCH (not mem op) -> valid=0", 3'b000, 1'b0);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("LSU_CONTROL TESTBENCH: PASS");
            $display("funct3 passthrough and valid gating correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("LSU_CONTROL TESTBENCH: FAIL");
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
