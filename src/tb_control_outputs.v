module testbench();

    reg [3:0] current_state_i;
    wire ir_write_o, reg_write_o, oe_o, we_o, mult_start_o, load_en_o, store_en_o;

    integer errors;

    localparam FETCH        = 4'b0000;
    localparam DECODE       = 4'b0001;
    localparam EXEC_ALU     = 4'b0010;
    localparam WRITEBACK    = 4'b0011;
    localparam EXEC_LOAD    = 4'b0100;
    localparam MEM_LOAD     = 4'b0101;
    localparam EXEC_STORE   = 4'b0110;
    localparam MEM_STORE    = 4'b0111;
    localparam EXEC_BRANCH  = 4'b1000;
    localparam EXEC_JUMP    = 4'b1001;
    localparam EXEC_MULT    = 4'b1010;
    localparam EXEC_CRC     = 4'b1011;
    localparam EXEC_SYSTEM  = 4'b1100;
    localparam LOAD_CAPTURE = 4'b1101;

    control_outputs dut (
        .current_state_i(current_state_i),
        .ir_write_o(ir_write_o),
        .reg_write_o(reg_write_o),
        .oe_o(oe_o),
        .we_o(we_o),
        .mult_start_o(mult_start_o),
        .load_en_o(load_en_o),
        .store_en_o(store_en_o)
    );

    // Bundle all 7 outputs into one vector for compact comparison
    wire [6:0] bundle = {ir_write_o, reg_write_o, oe_o, we_o, mult_start_o, load_en_o, store_en_o};

    task check;
        input [8*40-1:0] label;
        input [6:0] expected; // {ir,rw,oe,we,mult,load,store}
        begin
            #1;
            if (bundle !== expected) begin
                $display("FAIL: %0s expected={ir=%b,rw=%b,oe=%b,we=%b,mult=%b,load=%b,store=%b} got={ir=%b,rw=%b,oe=%b,we=%b,mult=%b,load=%b,store=%b}",
                    label, expected[6],expected[5],expected[4],expected[3],expected[2],expected[1],expected[0],
                    ir_write_o,reg_write_o,oe_o,we_o,mult_start_o,load_en_o,store_en_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> {ir=%b,rw=%b,oe=%b,we=%b,mult=%b,load=%b,store=%b}",
                    label, ir_write_o,reg_write_o,oe_o,we_o,mult_start_o,load_en_o,store_en_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        current_state_i = FETCH;
        check("FETCH: ir_write+oe only", 7'b1010000);

        current_state_i = DECODE;
        check("DECODE: everything idle", 7'b0000000);

        current_state_i = EXEC_ALU;
        check("EXEC_ALU: everything idle (combinational ALU)", 7'b0000000);

        current_state_i = WRITEBACK;
        check("WRITEBACK: reg_write only", 7'b0100000);

        current_state_i = EXEC_LOAD;
        check("EXEC_LOAD: everything idle (addr calc only)", 7'b0000000);

        current_state_i = MEM_LOAD;
        check("MEM_LOAD: oe+load_en", 7'b0010010);

        current_state_i = EXEC_STORE;
        check("EXEC_STORE: everything idle (addr calc only)", 7'b0000000);

        current_state_i = MEM_STORE;
        check("MEM_STORE: we+store_en", 7'b0001001);

        current_state_i = EXEC_BRANCH;
        check("EXEC_BRANCH: everything idle", 7'b0000000);

        current_state_i = EXEC_JUMP;
        check("EXEC_JUMP: everything idle", 7'b0000000);

        current_state_i = EXEC_MULT;
        check("EXEC_MULT: mult_start only", 7'b0000100);

        current_state_i = EXEC_CRC;
        check("EXEC_CRC: everything idle (combinational CRC)", 7'b0000000);

        current_state_i = EXEC_SYSTEM;
        check("EXEC_SYSTEM: everything idle", 7'b0000000);

        current_state_i = LOAD_CAPTURE;
        check("LOAD_CAPTURE: oe+load_en (mdr already latched)", 7'b0010010);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("CONTROL_OUTPUTS TESTBENCH: PASS");
            $display("All per-state control signals correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("CONTROL_OUTPUTS TESTBENCH: FAIL");
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
