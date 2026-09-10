module testbench();

    reg [3:0] instr_type_i;
    wire [2:0] wb_sel_o;

    integer errors;

    localparam TYPE_ALU_REG = 4'b0000;
    localparam TYPE_ALU_IMM = 4'b0001;
    localparam TYPE_LOAD    = 4'b0010;
    localparam TYPE_STORE   = 4'b0011;
    localparam TYPE_BRANCH  = 4'b0100;
    localparam TYPE_JAL     = 4'b0101;
    localparam TYPE_JALR    = 4'b0110;
    localparam TYPE_LUI     = 4'b0111;
    localparam TYPE_AUIPC   = 4'b1000;
    localparam TYPE_MULT    = 4'b1010;
    localparam TYPE_CRC     = 4'b1011;

    writeback_control dut (
        .instr_type_i(instr_type_i),
        .wb_sel_o(wb_sel_o)
    );

    task check;
        input [8*32-1:0] label;
        input [2:0] expected;
        begin
            #1;
            if (wb_sel_o !== expected) begin
                $display("FAIL: %0s expected=%b got=%b", label, expected, wb_sel_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> wb_sel_o=%b", label, wb_sel_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        instr_type_i = TYPE_ALU_REG; check("ALU_REG -> ALU result",  3'b000);
        instr_type_i = TYPE_ALU_IMM; check("ALU_IMM -> ALU result",  3'b000);
        instr_type_i = TYPE_LUI;     check("LUI -> ALU result (pass-through)", 3'b000);
        instr_type_i = TYPE_AUIPC;   check("AUIPC -> ALU result",   3'b000);
        instr_type_i = TYPE_LOAD;    check("LOAD -> LSU/mem data",  3'b001);
        instr_type_i = TYPE_MULT;    check("MULT -> multiplier result", 3'b010);
        instr_type_i = TYPE_CRC;     check("CRC -> CRC result",     3'b011);
        instr_type_i = TYPE_JAL;     check("JAL -> PC+4",           3'b100);
        instr_type_i = TYPE_JALR;    check("JALR -> PC+4",          3'b100);

        // STORE and BRANCH never write back to a register at all
        // (register_write_o is gated off by control_outputs for
        // these states) -- writeback_control itself has no case
        // for these types, so it should fall to the default (ALU).
        // This is harmless since reg_write_o is 0 anyway for
        // these instruction types, but worth confirming the mux
        // select doesn't glitch to something unexpected.
        instr_type_i = TYPE_STORE;
        check("STORE -> default (unused, reg_write=0 anyway)", 3'b000);

        instr_type_i = TYPE_BRANCH;
        check("BRANCH -> default (unused, reg_write=0 anyway)", 3'b000);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("WRITEBACK_CONTROL TESTBENCH: PASS");
            $display("All writeback source selections correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("WRITEBACK_CONTROL TESTBENCH: FAIL");
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
