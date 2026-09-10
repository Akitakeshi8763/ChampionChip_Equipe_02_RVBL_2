module testbench();

    reg [31:0] core_data_o;
    reg [31:0] core_address_o;
    reg [2:0] op_size_o;
    reg load_en_i;
    reg store_en_i;
    wire [31:0] core_data_i;
    wire [31:0] mem_data_i;
    wire [31:0] mem_address_i;
    wire [3:0] byte_write_i;
    reg [31:0] mem_data_o;

    integer errors;

    localparam SIZE_B  = 3'b000;
    localparam SIZE_H  = 3'b001;
    localparam SIZE_W  = 3'b010;
    localparam SIZE_BU = 3'b100;
    localparam SIZE_HU = 3'b101;

    lsu dut (
        .core_data_o(core_data_o),
        .core_address_o(core_address_o),
        .op_size_o(op_size_o),
        .load_en_i(load_en_i),
        .store_en_i(store_en_i),
        .core_data_i(core_data_i),
        .mem_data_i(mem_data_i),
        .mem_address_i(mem_address_i),
        .byte_write_i(byte_write_i),
        .mem_data_o(mem_data_o)
    );

    task check_load;
        input [8*48-1:0] label;
        input [31:0] expected;
        begin
            #1;
            if (core_data_i !== expected) begin
                $display("FAIL: %0s expected=%h got=%h", label, expected, core_data_i);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> core_data_i=%h", label, core_data_i);
            end
        end
    endtask

    task check_store;
        input [8*48-1:0] label;
        input [31:0] exp_data;
        input [3:0] exp_bw;
        begin
            #1;
            if (mem_data_i !== exp_data || byte_write_i !== exp_bw) begin
                $display("FAIL: %0s expected(data=%h,bw=%b) got(data=%h,bw=%b)",
                    label, exp_data, exp_bw, mem_data_i, byte_write_i);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> mem_data_i=%h byte_write_i=%b", label, mem_data_i, byte_write_i);
            end
        end
    endtask

    initial begin
        errors = 0;
        load_en_i = 0; store_en_i = 0;
        core_data_o = 0; core_address_o = 0; op_size_o = 0; mem_data_o = 0;

        // =====================================================
        // LOAD PATH -- using Block Guide Table 12/Section 3.3.1's
        // exact worked example: word at 0x10010000 contains
        // bytes F1,F2,F3,F4 (little-endian: mem_data_o=0xF4F3F2F1)
        // =====================================================
        mem_data_o = 32'hF4F3F2F1;
        load_en_i = 1;

        // lbu @ offset 0: loads byte F1, zero-extended -> 0x000000F1
        core_address_o = 32'h10010000; op_size_o = SIZE_BU;
        check_load("lbu @offset0: expect 0x000000F1", 32'h000000F1);

        // lb @ offset 0: loads byte F1, sign-extended (bit7=1) -> 0xFFFFFFF1
        op_size_o = SIZE_B;
        check_load("lb @offset0: expect 0xFFFFFFF1 (sign ext)", 32'hFFFFFFF1);

        // lhu @ offset 0: loads halfword F2F1, zero-extended -> 0x0000F2F1
        op_size_o = SIZE_HU;
        check_load("lhu @offset0: expect 0x0000F2F1", 32'h0000F2F1);

        // lh @ offset 0: loads halfword F2F1, sign-extended (bit15=1) -> 0xFFFFF2F1
        op_size_o = SIZE_H;
        check_load("lh @offset0: expect 0xFFFFF2F1 (sign ext)", 32'hFFFFF2F1);

        // lw @ offset 0: loads full word -> 0xF4F3F2F1
        op_size_o = SIZE_W;
        check_load("lw @offset0: expect 0xF4F3F2F1", 32'hF4F3F2F1);

        // -----------------------------------------------------
        // Guide's worked example: reading byte address
        // 0x10010002 with lbu returns only byte 0xF3, repositioned
        // to 0x000000F3 (per Block Guide Section 3.3.1's exact text)
        // -----------------------------------------------------
        core_address_o = 32'h10010002; op_size_o = SIZE_BU;
        check_load("lbu @offset2 (guide's exact example): expect 0x000000F3", 32'h000000F3);

        // lb @ offset 2: byte F3 (bit7=1) sign-extended -> 0xFFFFFFF3
        op_size_o = SIZE_B;
        check_load("lb @offset2: expect 0xFFFFFFF3 (sign ext)", 32'hFFFFFFF3);

        // lbu @ offset 1: byte F2 zero-extended -> 0x000000F2
        core_address_o = 32'h10010001; op_size_o = SIZE_BU;
        check_load("lbu @offset1: expect 0x000000F2", 32'h000000F2);

        // lbu @ offset 3: byte F4 zero-extended -> 0x000000F4
        core_address_o = 32'h10010003; op_size_o = SIZE_BU;
        check_load("lbu @offset3: expect 0x000000F4", 32'h000000F4);

        // lh @ offset 2: upper halfword F4F3, sign-extended (bit15=1) -> 0xFFFFF4F3
        core_address_o = 32'h10010002; op_size_o = SIZE_H;
        check_load("lh @offset2: expect 0xFFFFF4F3 (sign ext, upper half)", 32'hFFFFF4F3);

        // lhu @ offset 2: upper halfword F4F3, zero-extended -> 0x0000F4F3
        op_size_o = SIZE_HU;
        check_load("lhu @offset2: expect 0x0000F4F3", 32'h0000F4F3);

        // -----------------------------------------------------
        // Positive-sign-bit case: confirm lb/lh do NOT incorrectly
        // sign-extend when bit7/bit15 is actually 0
        // -----------------------------------------------------
        mem_data_o = 32'h7F7F7F7F; // every byte has bit7=0
        core_address_o = 32'h10010000; op_size_o = SIZE_B;
        check_load("lb with positive byte (0x7F): no sign ext -> 0x0000007F", 32'h0000007F);

        op_size_o = SIZE_H;
        check_load("lh with positive halfword (0x7F7F): no sign ext -> 0x00007F7F", 32'h00007F7F);

        // load_en_i=0: output must go to 0 regardless of other inputs
        load_en_i = 0;
        op_size_o = SIZE_W;
        core_address_o = 32'h10010000;
        check_load("load_en_i=0: core_data_i forced to 0", 32'h0);

        // =====================================================
        // STORE PATH -- verify byte_write_i mask and data
        // positioning for sb/sh/sw at various offsets
        // =====================================================
        load_en_i = 0;
        store_en_i = 1;

        // sw @ offset 0: full word passes through, all 4 lanes
        core_data_o = 32'hAABBCCDD;
        core_address_o = 32'h10010000; op_size_o = SIZE_W;
        check_store("sw @offset0: full word, bw=1111", 32'hAABBCCDD, 4'b1111);

        // sb @ offset 0: byte in lane 0
        core_data_o = 32'h000000AB;
        core_address_o = 32'h10010000; op_size_o = SIZE_B;
        check_store("sb @offset0: byte in lane0, bw=0001", 32'h000000AB, 4'b0001);

        // sb @ offset 1: byte shifted into lane 1
        core_address_o = 32'h10010001; op_size_o = SIZE_B;
        check_store("sb @offset1: byte in lane1, bw=0010", 32'h0000AB00, 4'b0010);

        // -----------------------------------------------------
        // Guide's exact worked example (Section 3.3.2): writing
        // 0x12 to address 0x10010002 must produce byte_write=0100
        // and the data positioned as 0x00120000
        // -----------------------------------------------------
        core_data_o = 32'h00000012;
        core_address_o = 32'h10010002; op_size_o = SIZE_B;
        check_store("sb @offset2 (guide's exact example): data=0x00120000, bw=0100", 32'h00120000, 4'b0100);

        // sb @ offset 3: byte shifted into lane 3
        core_data_o = 32'h000000CD;
        core_address_o = 32'h10010003; op_size_o = SIZE_B;
        check_store("sb @offset3: byte in lane3, bw=1000", 32'hCD000000, 4'b1000);

        // sh @ offset 0: halfword in lower 2 lanes
        core_data_o = 32'h0000BEEF;
        core_address_o = 32'h10010000; op_size_o = SIZE_H;
        check_store("sh @offset0: halfword in lanes0-1, bw=0011", 32'h0000BEEF, 4'b0011);

        // sh @ offset 2: halfword in upper 2 lanes
        core_data_o = 32'h0000BEEF;
        core_address_o = 32'h10010002; op_size_o = SIZE_H;
        check_store("sh @offset2: halfword in lanes2-3, bw=1100", 32'hBEEF0000, 4'b1100);

        // store_en_i=0: no write should be indicated
        store_en_i = 0;
        core_data_o = 32'hFFFFFFFF;
        op_size_o = SIZE_W;
        check_store("store_en_i=0: no write (data=0, bw=0000)", 32'h0, 4'b0000);

        // mem_address_i must always mirror core_address_o directly
        core_address_o = 32'hDEADB000;
        #1;
        if (mem_address_i !== 32'hDEADB000) begin
            $display("FAIL: mem_address_i does not mirror core_address_o");
            errors = errors + 1;
        end
        else begin
            $display("PASS: mem_address_i correctly mirrors core_address_o");
        end

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("LSU TESTBENCH: PASS");
            $display("All load/store sizes, sign/zero extension,");
            $display("and byte-lane positioning match the Block");
            $display("Guide's worked examples exactly.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("LSU TESTBENCH: FAIL");
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
