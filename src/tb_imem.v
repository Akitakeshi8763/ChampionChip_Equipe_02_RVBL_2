// =============================================================
// IMPORTANT DV NOTE (read before running in ChipInventor):
//
// The current src/rtl/imem.v does NOT compile as committed.
// Line 31 contains:  data_o = DATA_W'b0;
// which is invalid Verilog syntax (a parameter name cannot be
// used as a sized-literal width this way). This was confirmed
// with Icarus Verilog:
//     imem.v:31: syntax error
//     imem.v:31: error: Malformed statement
//
// This testbench targets the CORRECTED version of the module
// (the only change is line 31 -> data_o = {DATA_W{1'b0}};)
// so that the rest of imem's behavior (combinational read,
// $readmemh firmware loading, address-to-word-index conversion)
// can actually be verified. The design team must apply this
// one-line fix before imem.v can be simulated at all, in
// ChipInventor or any other tool.
//
// This testbench also uses a small DEPTH override (16 words
// instead of the real 1,048,576) purely so the testbench file
// itself stays fast to elaborate; the read/write logic being
// tested is identical regardless of array size. For the actual
// Phase 2 submission, DV should re-run this same testbench
// against the full-size (DEPTH=1048576) module once ChipInventor
// has applied the fix, using the real firmware.hex.
// =============================================================

module testbench();

    reg [31:0] address_i;
    reg oe_i;
    wire [31:0] data_o;

    integer errors;

    // Small depth for fast simulation; real deployment uses
    // DEPTH=1048576 (4MB) per the Block Guide's memory map.
    imem #(.DEPTH(16), .INIT_FILE("src/tb/imem_testdata/firmware_test.hex")) dut (
        .address_i(address_i),
        .oe_i(oe_i),
        .data_o(data_o)
    );

    task check;
        input [8*40-1:0] label;
        input [31:0] expected;
        begin
            #1;
            if (data_o !== expected) begin
                $display("FAIL: %0s expected=%h got=%h", label, expected, data_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> data_o=%h", label, data_o);
            end
        end
    endtask

    initial begin
        errors = 0;
        oe_i = 0;
        address_i = 0;

        // -----------------------------------------------------
        // oe_i=0: output must be forced to 0 regardless of
        // address (this exact line is what fails to compile in
        // the as-committed imem.v -- see file header note)
        // -----------------------------------------------------
        address_i = 32'h00000000;
        oe_i = 0;
        check("oe_i=0: data_o forced to 0", 32'h0);

        // -----------------------------------------------------
        // Word 0 read: instruction 0x00842283 (matches Block
        // Guide Table 14's example firmware content)
        // -----------------------------------------------------
        address_i = 32'h00000000;
        oe_i = 1;
        check("Word 0 read: 0x00842283", 32'h00842283);

        // -----------------------------------------------------
        // Word 1 read (byte address 4): 0xf0000437
        // -----------------------------------------------------
        address_i = 32'h00000004;
        oe_i = 1;
        check("Word 1 read: 0xf0000437", 32'hf0000437);

        // -----------------------------------------------------
        // Word 2 read (byte address 8): 0xdeadbeef
        // -----------------------------------------------------
        address_i = 32'h00000008;
        oe_i = 1;
        check("Word 2 read: 0xdeadbeef", 32'hdeadbeef);

        // -----------------------------------------------------
        // Word 3 read (byte address 12): 0x00000013 (NOP)
        // -----------------------------------------------------
        address_i = 32'h0000000C;
        oe_i = 1;
        check("Word 3 read: 0x00000013 (NOP)", 32'h00000013);

        // -----------------------------------------------------
        // Non-word-aligned address: bottom 2 bits must be
        // dropped when forming the word index (address 0x1, 0x2,
        // 0x3 should all still read word 0's content, matching
        // how the address_decoder pre-masks these bits, but
        // exercising imem's own internal masking independently)
        // -----------------------------------------------------
        address_i = 32'h00000001;
        oe_i = 1;
        check("Unaligned addr 0x1 -> still reads word 0", 32'h00842283);

        address_i = 32'h00000003;
        oe_i = 1;
        check("Unaligned addr 0x3 -> still reads word 0", 32'h00842283);

        // -----------------------------------------------------
        // Combinational behavior: data_o must update immediately
        // when address_i changes, with oe_i already high (no
        // clock edge required, unlike dmem's synchronous read)
        // -----------------------------------------------------
        oe_i = 1;
        address_i = 32'h00000000;
        #1;
        if (data_o !== 32'h00842283) begin
            $display("FAIL: combinational read check (addr=0) failed");
            errors = errors + 1;
        end
        address_i = 32'h00000004; // change address with oe_i still high
        #1;
        if (data_o !== 32'hf0000437) begin
            $display("FAIL: combinational read did not update immediately on address change");
            errors = errors + 1;
        end
        else begin
            $display("PASS: combinational read updates immediately on address change (no clock needed)");
        end

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("IMEM TESTBENCH: PASS (fixed version)");
            $display("Combinational read, firmware loading, and");
            $display("address masking all correct once the line-31");
            $display("syntax bug is fixed. See file header note --");
            $display("the as-committed imem.v does NOT compile.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("IMEM TESTBENCH: FAIL");
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
