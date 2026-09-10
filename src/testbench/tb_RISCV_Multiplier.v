module testbench();

    reg i_Clk;
    reg i_Rst;
    reg i_Mul_Start;
    reg [31:0] i_Instruction;
    reg [31:0] i_Multiplier;   // rs1
    reg [31:0] i_Multiplicand; // rs2
    wire [31:0] o_Result;
    wire o_Done;

    integer errors;

    localparam F3_MUL    = 3'b000;
    localparam F3_MULH   = 3'b001;
    localparam F3_MULHSU = 3'b010;
    localparam F3_MULHU  = 3'b011;

    // Build a minimal instruction word with the desired funct3
    // in bits [14:12]; other fields are irrelevant to this DUT.
    function [31:0] mk_instr;
        input [2:0] f3;
        begin
            mk_instr = {17'b0, f3, 12'b0};
        end
    endfunction

    RISCV_Multiplier dut (
        .i_Clk(i_Clk),
        .i_Rst(i_Rst),
        .i_Mul_Start(i_Mul_Start),
        .i_Instruction(i_Instruction),
        .i_Multiplier(i_Multiplier),
        .i_Multiplicand(i_Multiplicand),
        .o_Result(o_Result),
        .o_Done(o_Done)
    );

    initial i_Clk = 0;
    always #5 i_Clk = ~i_Clk;

    // Run one full multiply: pulse start for 1 cycle, then wait
    // for o_Done. The FSM takes 32 (shift-add) + 1 (adjust) + 1
    // (done) = 34 cycles after the start cycle before o_Done
    // asserts, so we wait generously and poll.
    task run_mult;
        input [31:0] rs1;
        input [31:0] rs2;
        input [2:0] f3;
        input [8*32-1:0] label;
        input [31:0] expected;
        integer timeout_count;
        begin
            i_Multiplier   = rs1;
            i_Multiplicand = rs2;
            i_Instruction  = mk_instr(f3);
            @(posedge i_Clk);
            i_Mul_Start = 1'b1;
            @(posedge i_Clk);
            i_Mul_Start = 1'b0;

            timeout_count = 0;
            while (o_Done !== 1'b1 && timeout_count < 60) begin
                @(posedge i_Clk);
                timeout_count = timeout_count + 1;
            end

            if (timeout_count >= 60) begin
                $display("FAIL: %0s -- o_Done never asserted (timeout)", label);
                errors = errors + 1;
            end
            else begin
                #1; // settle
                if (o_Result !== expected) begin
                    $display("FAIL: %0s expected=%h got=%h (done after %0d cycles)",
                        label, expected, o_Result, timeout_count);
                    errors = errors + 1;
                end
                else begin
                    $display("PASS: %0s -> result=%h (done after %0d cycles)",
                        label, o_Result, timeout_count);
                end
            end

            // Let FSM return to IDLE before next test
            @(posedge i_Clk);
        end
    endtask

    initial begin
        errors = 0;
        i_Rst = 1;
        i_Mul_Start = 0;
        i_Multiplier = 0;
        i_Multiplicand = 0;
        i_Instruction = 0;
        @(posedge i_Clk);
        @(posedge i_Clk);
        i_Rst = 0;
        @(posedge i_Clk);

        // -----------------------------------------------------
        // MUL: 6 * 7 = 42, lower 32 bits, both signed but no
        // overflow concerns at this magnitude
        // -----------------------------------------------------
        run_mult(32'd6, 32'd7, F3_MUL, "MUL 6*7=42", 32'd42);

        // -----------------------------------------------------
        // MUL: -5 * 3 = -15 (signed lower 32 bits)
        // -----------------------------------------------------
        run_mult(-32'sd5, 32'd3, F3_MUL, "MUL -5*3=-15", -32'sd15);

        // -----------------------------------------------------
        // MUL: -4 * -4 = 16
        // -----------------------------------------------------
        run_mult(-32'sd4, -32'sd4, F3_MUL, "MUL -4*-4=16", 32'd16);

        // -----------------------------------------------------
        // MULH: signed*signed upper 32 bits.
        // 0x7FFFFFFF * 2 = 0xFFFFFFFE (64-bit), upper=0x00000000
        // Chosen because it's a clean, hand-verifiable case:
        // 0x7FFFFFFF * 2 = 4294967294 = 0x00000000_FFFFFFFE
        // -----------------------------------------------------
        run_mult(32'h7FFFFFFF, 32'd2, F3_MULH, "MULH 0x7FFFFFFF*2 upper", 32'h00000000);

        // -----------------------------------------------------
        // MULH: -1 * -1 = 1 (as signed 64-bit: 0x1), upper=0
        // -----------------------------------------------------
        run_mult(-32'sd1, -32'sd1, F3_MULH, "MULH -1*-1 upper", 32'h00000000);

        // -----------------------------------------------------
        // MULH: -2 * 0x40000000 (signed*signed)
        // -2 * 1073741824 = -2147483648 = 0xFFFFFFFF_80000000 (64-bit signed)
        // upper 32 bits = 0xFFFFFFFF
        // -----------------------------------------------------
        run_mult(-32'sd2, 32'h40000000, F3_MULH, "MULH -2*0x40000000 upper", 32'hFFFFFFFF);

        // -----------------------------------------------------
        // MULHSU: rs1 SIGNED, rs2 UNSIGNED, upper 32 bits.
        // rs1=-1 (signed) treated as -1; rs2=0xFFFFFFFF treated
        // as unsigned 4294967295.
        // -1 * 4294967295 = -4294967295 (as a mathematical value)
        // In 64-bit two's complement: 0xFFFFFFFF_00000001
        // upper 32 bits = 0xFFFFFFFF
        // -----------------------------------------------------
        run_mult(-32'sd1, 32'hFFFFFFFF, F3_MULHSU, "MULHSU -1(signed)*0xFFFFFFFF(unsigned) upper", 32'hFFFFFFFF);

        // -----------------------------------------------------
        // MULHSU: rs1=2 (signed, positive), rs2=0x80000000
        // (unsigned = 2147483648)
        // 2 * 2147483648 = 4294967296 = 0x1_00000000 (needs bit 32)
        // upper 32 bits = 0x00000001
        // -----------------------------------------------------
        run_mult(32'd2, 32'h80000000, F3_MULHSU, "MULHSU 2(signed)*0x80000000(unsigned) upper", 32'h00000001);

        // -----------------------------------------------------
        // MULHU: rs1 and rs2 BOTH unsigned, upper 32 bits.
        // 0xFFFFFFFF * 0xFFFFFFFF (unsigned) = 0xFFFFFFFE00000001
        // upper 32 bits = 0xFFFFFFFE
        // -----------------------------------------------------
        run_mult(32'hFFFFFFFF, 32'hFFFFFFFF, F3_MULHU, "MULHU 0xFFFFFFFF*0xFFFFFFFF upper", 32'hFFFFFFFE);

        // -----------------------------------------------------
        // MULHU: 0x80000000 * 2 (both unsigned) = 0x100000000
        // upper 32 bits = 0x00000001
        // -----------------------------------------------------
        run_mult(32'h80000000, 32'd2, F3_MULHU, "MULHU 0x80000000*2 upper", 32'h00000001);

        // -----------------------------------------------------
        // Edge case: multiply by zero
        // -----------------------------------------------------
        run_mult(32'd0, 32'hDEADBEEF, F3_MUL, "MUL 0*x=0", 32'd0);

        // -----------------------------------------------------
        // Back-to-back operations: confirm FSM correctly resets
        // to IDLE and accepts a new start pulse immediately
        // after a previous multiply completes (already exercised
        // implicitly above since run_mult is called repeatedly,
        // but add one more explicit check here for clarity)
        // -----------------------------------------------------
        run_mult(32'd100, 32'd100, F3_MUL, "Back-to-back: MUL 100*100=10000", 32'd10000);

        #20;
        if (errors == 0) begin
            $display("========================================");
            $display("RISCV_MULTIPLIER TESTBENCH: PASS");
            $display("All MUL/MULH/MULHSU/MULHU cases correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("RISCV_MULTIPLIER TESTBENCH: FAIL");
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
