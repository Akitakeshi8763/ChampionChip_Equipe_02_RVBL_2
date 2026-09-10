// =============================================================
// IMPORTANT DV NOTE (read before running in ChipInventor):
//
// The current src/rtl/firmware_memory.v does NOT compile as
// committed. Starting at address 0x00400054, every case-item
// assigns to `o_Instruction` (capital I) instead of the actual
// declared output port `o_instruction` (lowercase i). Verilog
// is case-sensitive, so these are different identifiers.
// Confirmed with Icarus Verilog: 238 compile errors, one per
// bad assignment line, e.g.:
//     firmware_memory.v:32: error: Could not find variable
//     ``o_Instruction'' in ``firmware_memory''
//
// This testbench targets the CORRECTED version of the module
// (a global case-sensitive replace of o_Instruction ->
// o_instruction, no other changes) so the actual lookup-table
// contents can be verified. The design team must apply this
// fix before firmware_memory.v can be simulated at all.
// =============================================================

module testbench();

    reg [31:0] i_address;
    reg imem_oe_o;
    wire [31:0] o_instruction;

    integer errors;

    firmware_memory dut (
        .i_address(i_address),
        .imem_oe_o(imem_oe_o),
        .o_instruction(o_instruction)
    );

    task check;
        input [8*40-1:0] label;
        input [31:0] expected;
        begin
            #1;
            if (o_instruction !== expected) begin
                $display("FAIL: %0s expected=%h got=%h", label, expected, o_instruction);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> o_instruction=%h", label, o_instruction);
            end
        end
    endtask

    initial begin
        errors = 0;
        imem_oe_o = 0;
        i_address = 0;

        // -----------------------------------------------------
        // imem_oe_o=0: output should not be driven by any case
        // item (this DUT has no explicit else, so o_instruction
        // simply holds its prior value / x -- we only check
        // behavior with oe asserted, which is imem_oe_o's
        // documented purpose)
        // -----------------------------------------------------

        // -----------------------------------------------------
        // First instruction, well before the bug boundary
        // -----------------------------------------------------
        imem_oe_o = 1;
        i_address = 32'h00400000;
        check("addr 0x00400000 (first instr)", 32'h123452B7);

        i_address = 32'h00400004;
        check("addr 0x00400004", 32'h12345337);

        // -----------------------------------------------------
        // Last instruction BEFORE the bug boundary (uses correct
        // lowercase o_instruction even in the original file)
        // -----------------------------------------------------
        i_address = 32'h00400050;
        check("addr 0x00400050 (last correct-case entry)", 32'h3A731063);

        // -----------------------------------------------------
        // FIRST instruction AT the bug boundary -- this is
        // exactly the line that fails to compile in the
        // as-committed file (o_Instruction, capital I)
        // -----------------------------------------------------
        i_address = 32'h00400054;
        check("addr 0x00400054 (first buggy-case entry, now fixed)", 32'h0F02F313);

        i_address = 32'h00400058;
        check("addr 0x00400058", 32'h0F000393);

        // -----------------------------------------------------
        // Deep into the bug region: confirm the fix holds
        // consistently, not just at the boundary
        // -----------------------------------------------------
        i_address = 32'h004003FC;
        check("addr 0x004003FC (deep in bug region)", 32'h90ABCDEF);

        i_address = 32'h00400400;
        check("addr 0x00400400", 32'h11111111);

        // -----------------------------------------------------
        // Last defined instruction in the table
        // -----------------------------------------------------
        i_address = 32'h00400408;
        check("addr 0x00400408 (last defined entry)", 32'h33333333);

        // -----------------------------------------------------
        // Undefined address: must return NOP via default case
        // -----------------------------------------------------
        i_address = 32'h00400500; // past the last defined entry
        check("addr 0x00400500 (undefined) -> NOP default", 32'h00000013);

        i_address = 32'hDEADBEEF; // wildly out of range
        check("wildly out-of-range address -> NOP default", 32'h00000013);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("FIRMWARE_MEMORY TESTBENCH: PASS (fixed version)");
            $display("All addresses, including the former bug");
            $display("boundary at 0x00400054, return correct");
            $display("instruction words. See file header note --");
            $display("the as-committed file does NOT compile.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("FIRMWARE_MEMORY TESTBENCH: FAIL");
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
