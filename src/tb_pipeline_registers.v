module testbench();

    // =========================================================
    // Shared stimulus/clock for all 6 DUT instances
    // =========================================================
    reg clk;
    reg reset;
    reg write_enable;
    reg [31:0] data_in;

    wire [31:0] a_out, b_out, aluout_out, ir_out, mdr_out, oldpc_out;

    integer errors;

    // =========================================================
    // Instantiate all 6 pipeline registers with shared stimulus.
    // Per direct source inspection, all 6 modules
    // (A_register, B_register, ALU_Out_Register,
    // instruction_register, memorydata_register,
    // old_PC_Register) are byte-for-byte identical:
    // simple synchronous-write, asynchronous-reset registers.
    // This single testbench exercises all 6 in parallel to
    // confirm each compiles and behaves identically, rather
    // than duplicating the same test 6 times.
    // =========================================================
    A_register dut_a (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .data_in(data_in), .data_out(a_out)
    );

    B_register dut_b (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .data_in(data_in), .data_out(b_out)
    );

    ALU_Out_Register dut_aluout (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .data_in(data_in), .data_out(aluout_out)
    );

    instruction_register dut_ir (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .data_in(data_in), .data_out(ir_out)
    );

    memorydata_register dut_mdr (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .data_in(data_in), .data_out(mdr_out)
    );

    old_PC_Register dut_oldpc (
        .clk(clk), .reset(reset), .write_enable(write_enable),
        .data_in(data_in), .data_out(oldpc_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Compare all 6 outputs at once against one expected value,
    // since they should always behave identically given
    // identical stimulus.
    task check_all;
        input [8*32-1:0] label;
        input [31:0] expected;
        begin
            #1;
            if (a_out !== expected) begin
                $display("FAIL: %0s (A_register) expected=%h got=%h", label, expected, a_out);
                errors = errors + 1;
            end
            if (b_out !== expected) begin
                $display("FAIL: %0s (B_register) expected=%h got=%h", label, expected, b_out);
                errors = errors + 1;
            end
            if (aluout_out !== expected) begin
                $display("FAIL: %0s (ALU_Out_Register) expected=%h got=%h", label, expected, aluout_out);
                errors = errors + 1;
            end
            if (ir_out !== expected) begin
                $display("FAIL: %0s (instruction_register) expected=%h got=%h", label, expected, ir_out);
                errors = errors + 1;
            end
            if (mdr_out !== expected) begin
                $display("FAIL: %0s (memorydata_register) expected=%h got=%h", label, expected, mdr_out);
                errors = errors + 1;
            end
            if (oldpc_out !== expected) begin
                $display("FAIL: %0s (old_PC_Register) expected=%h got=%h", label, expected, oldpc_out);
                errors = errors + 1;
            end
            if (a_out === expected && b_out === expected && aluout_out === expected &&
                ir_out === expected && mdr_out === expected && oldpc_out === expected) begin
                $display("PASS: %0s -> all 6 registers = %h", label, expected);
            end
        end
    endtask

    initial begin
        errors = 0;
        reset = 1;
        write_enable = 0;
        data_in = 32'hFFFFFFFF; // deliberately non-zero to prove reset actually clears

        @(posedge clk);
        #1;
        check_all("Async reset -> all outputs 0", 32'h0);

        reset = 0;

        // write_enable=0: outputs must hold at 0 despite new data_in
        data_in = 32'hDEADBEEF;
        @(posedge clk);
        #1;
        check_all("write_enable=0: holds at 0", 32'h0);

        // write_enable=1: all 6 latch the new value on the clock edge
        @(negedge clk);
        write_enable = 1;
        data_in = 32'h12345678;
        @(posedge clk);
        #1;
        write_enable = 0;
        check_all("write_enable=1: latch 0x12345678", 32'h12345678);

        // write_enable=0 again: must hold previous value even
        // though data_in changes underneath
        data_in = 32'hABCDABCD;
        @(posedge clk);
        #1;
        check_all("write_enable=0 (after latch): holds 0x12345678", 32'h12345678);

        // Second write with a different value
        @(negedge clk);
        write_enable = 1;
        data_in = 32'h55AA55AA;
        @(posedge clk);
        #1;
        write_enable = 0;
        check_all("Second write: latch 0x55AA55AA", 32'h55AA55AA);

        // Mid-sequence async reset: must clear immediately,
        // not on the next clock edge
        reset = 1;
        #2;
        if (a_out !== 32'h0 || b_out !== 32'h0 || aluout_out !== 32'h0 ||
            ir_out !== 32'h0 || mdr_out !== 32'h0 || oldpc_out !== 32'h0) begin
            $display("FAIL: mid-sequence async reset did not clear all registers immediately");
            errors = errors + 1;
        end
        else begin
            $display("PASS: mid-sequence async reset -> all cleared immediately");
        end
        reset = 0;

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("PIPELINE REGISTERS TESTBENCH: PASS");
            $display("A_register, B_register, ALU_Out_Register,");
            $display("instruction_register, memorydata_register,");
            $display("and old_PC_Register all behave correctly");
            $display("and identically.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("PIPELINE REGISTERS TESTBENCH: FAIL");
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
