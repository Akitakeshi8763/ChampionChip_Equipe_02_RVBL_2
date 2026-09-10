module testbench();

    reg [31:0] rs1;
    reg [31:0] rs2;
    reg [31:0] pc;
    reg [31:0] imm;

    reg [3:0] alu_op;
    reg a_sel;
    reg b_sel;

    wire signed [31:0] result;

    integer errors;

    // =========================================================
    // DUT
    // =========================================================

    RISCV_ALU_4bit dut (
        .i_Register_Rs_1(rs1),
        .i_Register_Rs_2(rs2),
        .i_PC_Output(pc),
        .i_Immediate(imm),
        .i_ALU_Op(alu_op),
        .i_A_Sel(a_sel),
        .i_B_Sel(b_sel),
        .o_Q(result)
    );

    // =========================================================
    // TESTS
    // =========================================================

    initial begin

        errors = 0;

        // Default: use RS1 and RS2
        a_sel = 0;
        b_sel = 0;

        pc  = 32'd100;
        imm = 32'd7;

        // -----------------------------------------------------
        // ADD
        // 10 + 3 = 13
        // NOTE: RISCV_ALU_4bit has no explicit case for 4'b0000;
        // it falls through to "default", which performs ADD.
        // This still functionally verifies ADD, but if the RTL's
        // default case ever changes, this test needs updating.
        // -----------------------------------------------------
        rs1 = 32'd10;
        rs2 = 32'd3;
        alu_op = 4'b0000;

        #10;

        if (result !== 32'd13) begin
            $display("FAIL: ADD  expected=13 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: ADD");
        end

        // -----------------------------------------------------
        // SUB
        // 10 - 3 = 7
        // -----------------------------------------------------
        alu_op = 4'b0001;

        #10;

        if (result !== 32'd7) begin
            $display("FAIL: SUB  expected=7 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: SUB");
        end

        // -----------------------------------------------------
        // AND
        // -----------------------------------------------------
        rs1 = 32'h0000F0F0;
        rs2 = 32'h00000FF0;
        alu_op = 4'b0010;

        #10;

        if (result !== 32'h000000F0) begin
            $display("FAIL: AND  expected=000000F0 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: AND");
        end

        // -----------------------------------------------------
        // OR
        // -----------------------------------------------------
        alu_op = 4'b0011;

        #10;

        if (result !== 32'h0000FFF0) begin
            $display("FAIL: OR   expected=0000FFF0 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: OR");
        end

        // -----------------------------------------------------
        // XOR
        // -----------------------------------------------------
        alu_op = 4'b0100;

        #10;

        if (result !== 32'h0000FF00) begin
            $display("FAIL: XOR  expected=0000FF00 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: XOR");
        end

        // -----------------------------------------------------
        // SLL
        // 1 << 5 = 32
        // -----------------------------------------------------
        rs1 = 32'd1;
        rs2 = 32'd5;
        alu_op = 4'b0101;

        #10;

        if (result !== 32'd32) begin
            $display("FAIL: SLL  expected=32 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: SLL");
        end


        // -----------------------------------------------------
        // SRL
        // 0x80000000 >> 1 = 0x40000000
        // -----------------------------------------------------
        rs1 = 32'h80000000;
        rs2 = 32'd1;
        alu_op = 4'b0110;

        #10;

        if (result !== 32'h40000000) begin
            $display("FAIL: SRL  expected=40000000 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: SRL");
        end


        // -----------------------------------------------------
        // SRA
        // 0x80000000 >>> 1 = 0xC0000000
        // -----------------------------------------------------
        rs1 = 32'h80000000;
        rs2 = 32'd1;
        alu_op = 4'b0111;

        #10;

        if (result !== 32'hC0000000) begin
            $display("FAIL: SRA  expected=C0000000 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: SRA");
        end

        // -----------------------------------------------------
        // SLT
        // -1 < 1 = 1
        // -----------------------------------------------------
        rs1 = 32'hFFFFFFFF;
        rs2 = 32'd1;
        alu_op = 4'b1000;

        #10;

        if (result !== 32'd1) begin
            $display("FAIL: SLT  expected=1 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: SLT");
        end

        // -----------------------------------------------------
        // SLTU
        // 0xFFFFFFFF < 1 unsigned = 0
        // -----------------------------------------------------
        rs1 = 32'hFFFFFFFF;
        rs2 = 32'd1;
        alu_op = 4'b1001;

        #10;

        if (result !== 32'd0) begin
            $display("FAIL: SLTU expected=0 got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: SLTU");
        end


        // -----------------------------------------------------
        // PASS_B
        // B input comes from Immediate
        // -----------------------------------------------------
        rs1 = 32'h12345678;
        imm = 32'hDEADBEEF;

        a_sel = 0;
        b_sel = 1;
        alu_op = 4'b1010;

        #10;

        if (result !== 32'hDEADBEEF) begin
            $display("FAIL: PASS_B expected=DEADBEEF got=%h", result);
            errors = errors + 1;
        end
        else begin
            $display("PASS: PASS_B");
        end


        // -----------------------------------------------------
        // FINAL RESULT
        // -----------------------------------------------------

        if (errors == 0) begin
            $display("========================================");
            $display("ALU TESTBENCH: PASS");
            $display("All ALU operations passed.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("ALU TESTBENCH: FAIL");
            $display("Number of errors = %0d", errors);
            $display("========================================");
        end

        #10;
        $finish;

    end

    // =========================================================
    // WAVEFORM
    // =========================================================

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0,testbench);
    end

endmodule
