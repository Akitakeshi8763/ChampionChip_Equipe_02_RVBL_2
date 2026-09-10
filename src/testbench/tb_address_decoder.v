module testbench();

    reg [31:0] core_address_i;
    reg core_we_i;
    reg core_oe_i;
    reg [3:0] core_bw_i;

    wire [31:0] imem_address_o;
    wire imem_oe_o;
    wire [31:0] dmem_address_o;
    wire dmem_we_o;
    wire dmem_oe_o;
    wire [3:0] dmem_bw_o;
    wire sel_o;

    integer errors;

    // Defaults per Block Guide Table 13
    localparam IMEM_BASE = 32'h00400000;
    localparam DMEM_BASE = 32'h10010000;

    address_decoder dut (
        .core_address_i(core_address_i),
        .core_we_i(core_we_i),
        .core_oe_i(core_oe_i),
        .core_bw_i(core_bw_i),
        .imem_address_o(imem_address_o),
        .imem_oe_o(imem_oe_o),
        .dmem_address_o(dmem_address_o),
        .dmem_we_o(dmem_we_o),
        .dmem_oe_o(dmem_oe_o),
        .dmem_bw_o(dmem_bw_o),
        .sel_o(sel_o)
    );

    initial begin
        errors = 0;
        core_we_i = 0;
        core_oe_i = 0;
        core_bw_i = 4'b0000;

        // -----------------------------------------------------
        // IMEM range: base address, read requested
        // -----------------------------------------------------
        core_address_i = IMEM_BASE;
        core_oe_i = 1; core_we_i = 0;
        #1;
        if (imem_oe_o !== 1'b1 || sel_o !== 1'b1 || dmem_oe_o !== 1'b0 || dmem_we_o !== 1'b0) begin
            $display("FAIL: IMEM base, read -- imem_oe=%b sel=%b dmem_oe=%b dmem_we=%b",
                imem_oe_o, sel_o, dmem_oe_o, dmem_we_o);
            errors = errors + 1;
        end
        else $display("PASS: IMEM base, read -> imem_oe=1 sel=1, DMEM untouched");

        // IMEM local address should be 0 at the base
        if (imem_address_o !== 32'h0) begin
            $display("FAIL: IMEM local address at base expected=0 got=%h", imem_address_o);
            errors = errors + 1;
        end
        else $display("PASS: IMEM local address at base = 0");

        // -----------------------------------------------------
        // IMEM range: write attempted -- must be dropped (IMEM
        // cannot be written per Block Guide 4.4)
        // -----------------------------------------------------
        core_address_i = IMEM_BASE + 32'h100;
        core_oe_i = 0; core_we_i = 1;
        #1;
        if (imem_oe_o !== 1'b0 || dmem_we_o !== 1'b0) begin
            $display("FAIL: IMEM write attempt not dropped -- imem_oe=%b dmem_we=%b", imem_oe_o, dmem_we_o);
            errors = errors + 1;
        end
        else $display("PASS: IMEM write attempt correctly dropped (imem_oe=0, dmem_we=0)");

        // -----------------------------------------------------
        // IMEM upper boundary: last valid address (base+size-1)
        // -----------------------------------------------------
        core_address_i = IMEM_BASE + 32'h003FFFFF; // base + 4MB - 1
        core_oe_i = 1; core_we_i = 0;
        #1;
        if (sel_o !== 1'b1 || imem_oe_o !== 1'b1) begin
            $display("FAIL: IMEM upper boundary (base+size-1) not routed to IMEM");
            errors = errors + 1;
        end
        else $display("PASS: IMEM upper boundary (base+size-1) correctly routed");

        // Just past IMEM's range: must NOT route to IMEM or DMEM
        core_address_i = IMEM_BASE + 32'h00400000; // exactly base+size (out of range)
        core_oe_i = 1; core_we_i = 0;
        #1;
        if (sel_o !== 1'b0 || imem_oe_o !== 1'b1) begin
            // Note: sel_o=0 is correct (falls through to DMEM
            // default branch condition check below), but imem_oe_o
            // must be 0 since this address is NOT in IMEM's range
        end
        if (imem_oe_o !== 1'b0) begin
            $display("FAIL: address just past IMEM range still asserts imem_oe_o");
            errors = errors + 1;
        end
        else $display("PASS: address just past IMEM range correctly does not assert imem_oe_o");

        // -----------------------------------------------------
        // DMEM range: base address, write requested
        // -----------------------------------------------------
        core_address_i = DMEM_BASE;
        core_oe_i = 0; core_we_i = 1; core_bw_i = 4'b0001;
        #1;
        if (dmem_we_o !== 1'b1 || sel_o !== 1'b0 || imem_oe_o !== 1'b0 || dmem_bw_o !== 4'b0001) begin
            $display("FAIL: DMEM base, write -- dmem_we=%b sel=%b imem_oe=%b bw=%b",
                dmem_we_o, sel_o, imem_oe_o, dmem_bw_o);
            errors = errors + 1;
        end
        else $display("PASS: DMEM base, write -> dmem_we=1 sel=0, bw passed through, IMEM untouched");

        // DMEM local address should be 0 at the base
        if (dmem_address_o !== 32'h0) begin
            $display("FAIL: DMEM local address at base expected=0 got=%h", dmem_address_o);
            errors = errors + 1;
        end
        else $display("PASS: DMEM local address at base = 0");

        // -----------------------------------------------------
        // DMEM: non-zero offset address maps correctly
        // -----------------------------------------------------
        core_address_i = DMEM_BASE + 32'h100;
        core_oe_i = 1; core_we_i = 0;
        #1;
        if (dmem_address_o !== 32'h100 || dmem_oe_o !== 1'b1) begin
            $display("FAIL: DMEM offset 0x100 -- local_addr=%h dmem_oe=%b", dmem_address_o, dmem_oe_o);
            errors = errors + 1;
        end
        else $display("PASS: DMEM offset 0x100 correctly mapped, read enabled");

        // -----------------------------------------------------
        // DMEM upper boundary (base + 8kB - 1)
        // -----------------------------------------------------
        core_address_i = DMEM_BASE + 32'h1FFF;
        core_oe_i = 1; core_we_i = 0;
        #1;
        if (dmem_oe_o !== 1'b1 || sel_o !== 1'b0) begin
            $display("FAIL: DMEM upper boundary (base+8kB-1) not routed to DMEM");
            errors = errors + 1;
        end
        else $display("PASS: DMEM upper boundary (base+8kB-1) correctly routed");

        // Just past DMEM's range: must not route to DMEM
        core_address_i = DMEM_BASE + 32'h2000; // exactly base+size (out of range)
        core_oe_i = 1; core_we_i = 0;
        #1;
        if (dmem_oe_o !== 1'b0) begin
            $display("FAIL: address just past DMEM range still asserts dmem_oe_o");
            errors = errors + 1;
        end
        else $display("PASS: address just past DMEM range correctly does not assert dmem_oe_o");

        // -----------------------------------------------------
        // Completely unmapped address (neither IMEM nor DMEM):
        // must assert neither oe nor we anywhere -- safe no-op
        // -----------------------------------------------------
        core_address_i = 32'h00000000;
        core_oe_i = 1; core_we_i = 1;
        #1;
        if (imem_oe_o !== 1'b0 || dmem_oe_o !== 1'b0 || dmem_we_o !== 1'b0) begin
            $display("FAIL: unmapped address 0x0 incorrectly asserts a control signal");
            errors = errors + 1;
        end
        else $display("PASS: unmapped address 0x0 -> no control signals asserted (safe)");

        core_address_i = 32'hFFFFFFFF;
        core_oe_i = 1; core_we_i = 1;
        #1;
        if (imem_oe_o !== 1'b0 || dmem_oe_o !== 1'b0 || dmem_we_o !== 1'b0) begin
            $display("FAIL: unmapped address 0xFFFFFFFF incorrectly asserts a control signal");
            errors = errors + 1;
        end
        else $display("PASS: unmapped address 0xFFFFFFFF -> no control signals asserted (safe)");

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("ADDRESS_DECODER TESTBENCH: PASS");
            $display("IMEM/DMEM routing, byte-write passthrough,");
            $display("and out-of-range safety all correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("ADDRESS_DECODER TESTBENCH: FAIL");
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
