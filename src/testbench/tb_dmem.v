module testbench();

    reg clk_i;
    reg [31:0] address_i;
    reg we_i;
    reg oe_i;
    reg [3:0] bw_i;
    reg [31:0] data_i;
    wire [31:0] data_o;

    integer errors;

    dmem dut (
        .clk_i(clk_i),
        .address_i(address_i),
        .we_i(we_i),
        .oe_i(oe_i),
        .bw_i(bw_i),
        .data_i(data_i),
        .data_o(data_o)
    );

    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

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
        we_i = 0; oe_i = 0; bw_i = 4'b0000; address_i = 0; data_i = 0;

        // -----------------------------------------------------
        // Build word 0 byte-by-byte using independent byte
        // lanes, matching Block Guide Table 12:
        // 0x10010000=0xF1 0x10010001=0xF2 0x10010002=0xF3
        // 0x10010003=0xF4  (word address 0x0000)
        // Write full word at once using all 4 lanes: 0xF4F3F2F1
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000000; // local/decoded address, word 0
        data_i = 32'hF4F3F2F1;
        we_i = 1; bw_i = 4'b1111;
        @(posedge clk_i);
        #1;
        we_i = 0; bw_i = 4'b0000;

        // -----------------------------------------------------
        // Full-word read (lw): must return 0xF4F3F2F1 exactly
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000000;
        oe_i = 1;
        @(posedge clk_i);
        check("lw @ word0: full word", 32'hF4F3F2F1);
        oe_i = 0;

        // -----------------------------------------------------
        // Independent byte-lane write: overwrite ONLY byte lane
        // 2 (bits [23:16]) with 0x99, per Block Guide's example
        // of writing 0x12 into byte 2 without touching the rest.
        // Starting word = 0xF4F3F2F1; write lane2 with 0x99AA
        // (only 0x99 in [23:16] should land)
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000000;
        data_i = 32'h00990000; // 0x99 sits in bits [23:16]
        we_i = 1; bw_i = 4'b0100; // lane 2 only
        @(posedge clk_i);
        #1;
        we_i = 0; bw_i = 4'b0000;

        @(negedge clk_i);
        address_i = 32'h00000000;
        oe_i = 1;
        @(posedge clk_i);
        check("Byte-lane 2 write: only byte2 changed (0xF499F2F1)", 32'hF499F2F1);
        oe_i = 0;

        // -----------------------------------------------------
        // Independent byte-lane write: byte lane 0 only
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000000;
        data_i = 32'h000000AB;
        we_i = 1; bw_i = 4'b0001; // lane 0 only
        @(posedge clk_i);
        #1;
        we_i = 0; bw_i = 4'b0000;

        @(negedge clk_i);
        address_i = 32'h00000000;
        oe_i = 1;
        @(posedge clk_i);
        check("Byte-lane 0 write: only byte0 changed (0xF499F2AB)", 32'hF499F2AB);
        oe_i = 0;

        // -----------------------------------------------------
        // Independent byte-lane write: byte lane 1 and 3
        // simultaneously (sh writes span 2 lanes when aligned,
        // but this also proves arbitrary lane combos work)
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000000;
        data_i = 32'hCC00DD00;
        we_i = 1; bw_i = 4'b1010; // lanes 1 and 3
        @(posedge clk_i);
        #1;
        we_i = 0; bw_i = 4'b0000;

        @(negedge clk_i);
        address_i = 32'h00000000;
        oe_i = 1;
        @(posedge clk_i);
        check("Byte-lanes 1+3 write: bytes 1,3 changed (0xCC99DDAB)", 32'hCC99DDAB);
        oe_i = 0;

        // -----------------------------------------------------
        // oe_i=0: data_o must go to 0, not hold stale data
        // (per dmem's explicit else-branch behavior)
        // -----------------------------------------------------
        @(negedge clk_i);
        oe_i = 0;
        @(posedge clk_i);
        check("oe_i=0: data_o forced to 0", 32'h00000000);

        // -----------------------------------------------------
        // Second word (word address 1 / byte address 4): must
        // be completely independent from word 0
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000004; // word index 1
        data_i = 32'hAAAAAAAA;
        we_i = 1; bw_i = 4'b1111;
        @(posedge clk_i);
        #1;
        we_i = 0; bw_i = 4'b0000;

        @(negedge clk_i);
        address_i = 32'h00000004;
        oe_i = 1;
        @(posedge clk_i);
        check("Word 1 independent write/read", 32'hAAAAAAAA);
        oe_i = 0;

        // Confirm word 0 was untouched by the word 1 write
        @(negedge clk_i);
        address_i = 32'h00000000;
        oe_i = 1;
        @(posedge clk_i);
        check("Word 0 unaffected by word 1 write", 32'hCC99DDAB);
        oe_i = 0;

        // -----------------------------------------------------
        // we_i=0: a write attempt with bw_i set must NOT modify
        // memory (we_i gates the entire write, independent of bw_i)
        // -----------------------------------------------------
        @(negedge clk_i);
        address_i = 32'h00000000;
        data_i = 32'hFFFFFFFF;
        we_i = 0; bw_i = 4'b1111; // bw set but we_i=0
        @(posedge clk_i);
        #1;

        @(negedge clk_i);
        address_i = 32'h00000000;
        oe_i = 1;
        @(posedge clk_i);
        check("we_i=0 blocks write despite bw_i set", 32'hCC99DDAB);
        oe_i = 0;

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("DMEM TESTBENCH: PASS");
            $display("Byte-lane masking, word independence, and");
            $display("synchronous read/write timing all correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("DMEM TESTBENCH: FAIL");
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
