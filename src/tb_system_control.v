module testbench();

    reg [31:0] instruction_i;
    wire [1:0] system_op_o;
    wire system_valid_o;

    integer errors;

    system_control dut (
        .instruction_i(instruction_i),
        .system_op_o(system_op_o),
        .system_valid_o(system_valid_o)
    );

    task check;
        input [8*40-1:0] label;
        input [1:0] exp_op;
        input exp_valid;
        begin
            #1;
            if (system_op_o !== exp_op || system_valid_o !== exp_valid) begin
                $display("FAIL: %0s expected(op=%b,valid=%b) got(op=%b,valid=%b)",
                    label, exp_op, exp_valid, system_op_o, system_valid_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> op=%b valid=%b", label, system_op_o, system_valid_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        // ECALL: exact bit pattern 0x00000073
        instruction_i = 32'h00000073;
        check("ECALL exact match", 2'b01, 1'b1);

        // EBREAK: exact bit pattern 0x00100073
        instruction_i = 32'h00100073;
        check("EBREAK exact match", 2'b10, 1'b1);

        // FENCE: opcode=0001111, funct3=000, other fields don't matter
        instruction_i = 32'b0000_0000_0000_00000_000_00000_0001111;
        check("FENCE (all other bits 0)", 2'b00, 1'b1);

        // FENCE with garbage in the don't-care fields (rd, rs1,
        // pred/succ/fm bits) -- must still be recognized since
        // those fields are architecturally ignored by a basic
        // FENCE decode
        instruction_i = 32'b1111_1111_1111_11111_000_11111_0001111;
        check("FENCE (garbage in don't-care fields)", 2'b00, 1'b1);

        // Near-miss: FENCE opcode but wrong funct3 (would be
        // FENCE.I in some encodings, but this decoder only
        // recognizes funct3=000 as FENCE) -> must NOT be valid
        instruction_i = 32'b0000_0000_0000_00000_001_00000_0001111;
        check("FENCE opcode but funct3=001 -> invalid", 2'b11, 1'b0);

        // Near-miss: one bit off from ECALL -> must NOT match
        instruction_i = 32'h00000072;
        check("Near-ECALL (off by 1 bit) -> invalid", 2'b11, 1'b0);

        // Near-miss: one bit off from EBREAK -> must NOT match
        instruction_i = 32'h00100072;
        check("Near-EBREAK (off by 1 bit) -> invalid", 2'b11, 1'b0);

        // Completely unrelated instruction (e.g. ADD x0,x0,x0)
        instruction_i = 32'h00000033;
        check("Unrelated instruction (ADD x0,x0,x0) -> invalid", 2'b11, 1'b0);

        // All-zero instruction is NOT the same as ECALL (opcode
        // 0000000 vs ECALL's 1110011) -- sanity check they're
        // not confused
        instruction_i = 32'h00000000;
        check("All-zero instruction -> invalid (not ECALL)", 2'b11, 1'b0);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("SYSTEM_CONTROL TESTBENCH: PASS");
            $display("FENCE/ECALL/EBREAK detection correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("SYSTEM_CONTROL TESTBENCH: FAIL");
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
