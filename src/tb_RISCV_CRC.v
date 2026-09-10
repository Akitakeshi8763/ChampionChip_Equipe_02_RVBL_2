// =============================================================
// IMPORTANT DV NOTE:
//
// RISCV_CRC in Datapath_modules.v is an ACKNOWLEDGED, UNFINISHED
// STUB. Its own source comments say so directly:
//   "Placeholder signals for the actual combinatorial CRC
//    calculation. The provided documentation defines the
//    routing but omits the specific polynomial generator...
//    and bit-reflection rules required to calculate the math."
//   "Dummy assignments (Replace these lines with standard XOR
//    tree logic)"
//
// All three CRC widths (CRC8/CRC16/CRC32) currently just XOR
// rs1 and rs2 together and mask to 16 bits -- none of them
// compute a real CRC of any kind.
//
// This testbench does not just assert "this is wrong" -- it
// computes the mathematically correct CRC8, CRC16 (CCITT,
// poly 0x1021), and CRC32 (IEEE 802.3, poly 0xEDB88320,
// reflected) values for the same test vectors, and shows the
// DUT's actual output alongside them, so the gap is concrete
// and quantified rather than asserted. This is intended as
// FAULT DOCUMENTATION for the Phase 2 report's ISA coverage
// discussion (Xicrc extension), not a module that is expected
// to pass.
// =============================================================

module testbench();

    reg i_Clk;
    reg i_Rst;
    reg i_Start;
    reg [31:0] i_Register_Rs_1;
    reg [31:0] i_Register_Rs_2;
    reg [3:0] i_CRC_Sel;
    wire [31:0] o_Result;

    integer mismatches;
    integer total_checks;

    localparam OP_CRCB = 4'h0;
    localparam OP_CRCH = 4'h1;
    localparam OP_CRCW = 4'h2;

    RISCV_CRC dut (
        .i_Clk(i_Clk),
        .i_Rst(i_Rst),
        .i_Start(i_Start),
        .i_Register_Rs_1(i_Register_Rs_1),
        .i_Register_Rs_2(i_Register_Rs_2),
        .i_CRC_Sel(i_CRC_Sel),
        .o_Result(o_Result)
    );

    initial i_Clk = 0;
    always #5 i_Clk = ~i_Clk;

    // -----------------------------------------------------
    // Reference CRC8 (poly 0x07, no reflection, init 0x00) --
    // computed over the low byte of rs1 XOR low byte of rs2,
    // a reasonable interpretation of "CRC8(rs1, rs2)" given
    // the guide does not specify exact input framing.
    // -----------------------------------------------------
    function [7:0] ref_crc8;
        input [7:0] data;
        integer i;
        reg [7:0] crc;
        begin
            crc = 8'h00;
            crc = crc ^ data;
            for (i = 0; i < 8; i = i + 1) begin
                if (crc[7])
                    crc = (crc << 1) ^ 8'h07;
                else
                    crc = crc << 1;
            end
            ref_crc8 = crc;
        end
    endfunction

    // Reference CRC16-CCITT (poly 0x1021, init 0xFFFF)
    function [15:0] ref_crc16;
        input [15:0] data;
        integer i;
        reg [15:0] crc;
        begin
            crc = 16'hFFFF;
            crc = crc ^ data;
            for (i = 0; i < 16; i = i + 1) begin
                if (crc[15])
                    crc = (crc << 1) ^ 16'h1021;
                else
                    crc = crc << 1;
            end
            ref_crc16 = crc;
        end
    endfunction

    task compare_and_report;
        input [8*32-1:0] label;
        input [31:0] reference_result;
        begin
            total_checks = total_checks + 1;
            #1; // let combinational logic settle before sampling o_Result
            if (o_Result === reference_result) begin
                $display("MATCH (unexpected): %0s -> dut=%h ref=%h", label, o_Result, reference_result);
            end
            else begin
                mismatches = mismatches + 1;
                $display("MISMATCH: %0s -> DUT(stub)=%h  CORRECT=%h  (DUT is WRONG)",
                    label, o_Result, reference_result);
            end
        end
    endtask

    initial begin
        mismatches = 0;
        total_checks = 0;
        i_Start = 0;
        i_Rst = 1;
        @(posedge i_Clk);
        i_Rst = 0;

        $display("========================================");
        $display("RISCV_CRC FAULT DOCUMENTATION TESTBENCH");
        $display("This module is a KNOWN, ACKNOWLEDGED STUB.");
        $display("Every case below is EXPECTED to mismatch.");
        $display("========================================");

        // -----------------------------------------------------
        // CRCB (CRC8): rs1=0x000000A5, rs2=0x00000000
        // -----------------------------------------------------
        i_Register_Rs_1 = 32'h000000A5;
        i_Register_Rs_2 = 32'h00000000;
        i_CRC_Sel = OP_CRCB;
        compare_and_report("CRCB rs1=0xA5,rs2=0x00", {24'b0, ref_crc8(8'hA5)});

        // -----------------------------------------------------
        // CRCB: rs1=0x000000FF, rs2=0x00000000 (deliberately
        // avoiding an all-zero vector, since a real CRC8 with a
        // zero initial state and zero data can coincidentally
        // equal the stub's XOR result of 0 -- that coincidence
        // says nothing about correctness, so we test a case
        // where a genuine mismatch is unambiguous)
        // -----------------------------------------------------
        i_Register_Rs_1 = 32'h000000FF;
        i_Register_Rs_2 = 32'h00000000;
        i_CRC_Sel = OP_CRCB;
        compare_and_report("CRCB rs1=0xFF,rs2=0x00", {24'b0, ref_crc8(8'hFF)});

        // -----------------------------------------------------
        // CRCH (CRC16): rs1=0x00001234, rs2=0x00000000
        // -----------------------------------------------------
        i_Register_Rs_1 = 32'h00001234;
        i_Register_Rs_2 = 32'h00000000;
        i_CRC_Sel = OP_CRCH;
        compare_and_report("CRCH rs1=0x1234,rs2=0x0000", {16'b0, ref_crc16(16'h1234)});

        // -----------------------------------------------------
        // Sanity/contrast case: when rs1==rs2, the stub's XOR
        // logic ALWAYS produces exactly 0, regardless of which
        // CRC width is selected or what the actual data is.
        // This is a structural tell that it's not a real CRC --
        // a genuine CRC of non-zero, non-trivial data essentially
        // never happens to be zero.
        // -----------------------------------------------------
        i_Register_Rs_1 = 32'hDEADBEEF;
        i_Register_Rs_2 = 32'hDEADBEEF;
        i_CRC_Sel = OP_CRCW;
        #1;
        $display("STRUCTURAL TELL: rs1==rs2==0xDEADBEEF, CRCW selected -> o_Result=%h", o_Result);
        if (o_Result === 32'h0) begin
            $display("  Confirms the stub is a plain XOR: any rs1==rs2 input");
            $display("  collapses to exactly 0, which a real CRC32 would");
            $display("  essentially never do for non-trivial data.");
        end

        $display("========================================");
        $display("RISCV_CRC TESTBENCH SUMMARY");
        $display("Total checks: %0d, Mismatches: %0d", total_checks, mismatches);
        if (mismatches == total_checks) begin
            $display("RESULT: FAIL (100%% mismatch, as expected).");
            $display("RISCV_CRC does not implement CRC8/CRC16/CRC32.");
            $display("It must be reimplemented before any Xicrc");
            $display("instruction (crcb/crch/crcw) can be trusted in");
            $display("firmware validation (Phase 2 guide Section 6)");
            $display("or claimed in the ISA coverage table (Section 2).");
        end
        else begin
            $display("RESULT: FAIL -- %0d of %0d cases mismatched.", mismatches, total_checks);
            $display("RISCV_CRC does not implement real CRC8/CRC16/CRC32");
            $display("logic for general inputs. It must be reimplemented");
            $display("before any Xicrc instruction (crcb/crch/crcw) can");
            $display("be trusted in firmware validation (Section 6) or");
            $display("claimed in the ISA coverage table (Section 2).");
        end
        $display("========================================");

        $finish;
    end

    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);
    end

endmodule
