module testbench();

    reg signed [31:0] i_Reg_A;
    reg signed [31:0] i_Reg_B;
    reg [2:0] i_Branch_Sel;
    reg i_Branch_Valid;
    wire o_Branch_Taken;

    integer errors;

    localparam BEQ  = 3'b000;
    localparam BNE  = 3'b001;
    localparam BLT  = 3'b100;
    localparam BGE  = 3'b101;
    localparam BLTU = 3'b110;
    localparam BGEU = 3'b111;

    RISCV_BRANCH_COMPARATOR_A dut (
        .i_Reg_A(i_Reg_A),
        .i_Reg_B(i_Reg_B),
        .i_Branch_Sel(i_Branch_Sel),
        .i_Branch_Valid(i_Branch_Valid),
        .o_Branch_Taken(o_Branch_Taken)
    );

    task check;
        input [8*40-1:0] label;
        input expected;
        begin
            #1;
            if (o_Branch_Taken !== expected) begin
                $display("FAIL: %0s expected=%b got=%b", label, expected, o_Branch_Taken);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> taken=%b", label, o_Branch_Taken);
            end
        end
    endtask

    initial begin
        errors = 0;
        i_Branch_Valid = 1'b1;

        // -----------------------------------------------------
        // BEQ
        // -----------------------------------------------------
        i_Reg_A = 32'd5; i_Reg_B = 32'd5; i_Branch_Sel = BEQ;
        check("BEQ 5==5 -> taken", 1'b1);

        i_Reg_A = 32'd5; i_Reg_B = 32'd6; i_Branch_Sel = BEQ;
        check("BEQ 5==6 -> not taken", 1'b0);

        // -----------------------------------------------------
        // BNE
        // -----------------------------------------------------
        i_Reg_A = 32'd5; i_Reg_B = 32'd6; i_Branch_Sel = BNE;
        check("BNE 5!=6 -> taken", 1'b1);

        i_Reg_A = 32'd5; i_Reg_B = 32'd5; i_Branch_Sel = BNE;
        check("BNE 5!=5 -> not taken", 1'b0);

        // -----------------------------------------------------
        // BLT (signed)
        // -----------------------------------------------------
        i_Reg_A = -32'sd1; i_Reg_B = 32'd1; i_Branch_Sel = BLT;
        check("BLT signed: -1 < 1 -> taken", 1'b1);

        i_Reg_A = 32'd1; i_Reg_B = -32'sd1; i_Branch_Sel = BLT;
        check("BLT signed: 1 < -1 -> not taken", 1'b0);

        i_Reg_A = -32'sd5; i_Reg_B = -32'sd3; i_Branch_Sel = BLT;
        check("BLT signed: -5 < -3 -> taken", 1'b1);

        // -----------------------------------------------------
        // BGE (signed)
        // -----------------------------------------------------
        i_Reg_A = 32'd1; i_Reg_B = -32'sd1; i_Branch_Sel = BGE;
        check("BGE signed: 1 >= -1 -> taken", 1'b1);

        i_Reg_A = -32'sd1; i_Reg_B = 32'd1; i_Branch_Sel = BGE;
        check("BGE signed: -1 >= 1 -> not taken", 1'b0);

        i_Reg_A = 32'd5; i_Reg_B = 32'd5; i_Branch_Sel = BGE;
        check("BGE signed: 5 >= 5 (equal) -> taken", 1'b1);

        // -----------------------------------------------------
        // BLTU (unsigned) -- the critical edge case: a "negative"
        // signed value like 0xFFFFFFFF (-1 signed) is the LARGEST
        // possible unsigned value, so unsigned comparisons must
        // treat it as huge, not as -1.
        // -----------------------------------------------------
        i_Reg_A = 32'hFFFFFFFF; i_Reg_B = 32'd1; i_Branch_Sel = BLTU;
        check("BLTU unsigned: 0xFFFFFFFF < 1 -> NOT taken (huge unsigned)", 1'b0);

        i_Reg_A = 32'd1; i_Reg_B = 32'hFFFFFFFF; i_Branch_Sel = BLTU;
        check("BLTU unsigned: 1 < 0xFFFFFFFF -> taken", 1'b1);

        i_Reg_A = 32'd0; i_Reg_B = 32'd1; i_Branch_Sel = BLTU;
        check("BLTU unsigned: 0 < 1 -> taken", 1'b1);

        // -----------------------------------------------------
        // BGEU (unsigned) -- same edge case, inverted
        // -----------------------------------------------------
        i_Reg_A = 32'hFFFFFFFF; i_Reg_B = 32'd1; i_Branch_Sel = BGEU;
        check("BGEU unsigned: 0xFFFFFFFF >= 1 -> taken (huge unsigned)", 1'b1);

        i_Reg_A = 32'd1; i_Reg_B = 32'hFFFFFFFF; i_Branch_Sel = BGEU;
        check("BGEU unsigned: 1 >= 0xFFFFFFFF -> not taken", 1'b0);

        i_Reg_A = 32'd7; i_Reg_B = 32'd7; i_Branch_Sel = BGEU;
        check("BGEU unsigned: 7 >= 7 (equal) -> taken", 1'b1);

        // -----------------------------------------------------
        // i_Branch_Valid gating: even a condition that would
        // otherwise be true MUST NOT assert o_Branch_Taken when
        // valid=0 (this models a non-branch instruction passing
        // garbage through the comparator's data inputs)
        // -----------------------------------------------------
        i_Reg_A = 32'd5; i_Reg_B = 32'd5; i_Branch_Sel = BEQ;
        i_Branch_Valid = 1'b0;
        check("BEQ 5==5 but Branch_Valid=0 -> not taken", 1'b0);
        i_Branch_Valid = 1'b1;

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("RISCV_BRANCH_COMPARATOR_A TESTBENCH: PASS");
            $display("All branch conditions (signed+unsigned) correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("RISCV_BRANCH_COMPARATOR_A TESTBENCH: FAIL");
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
