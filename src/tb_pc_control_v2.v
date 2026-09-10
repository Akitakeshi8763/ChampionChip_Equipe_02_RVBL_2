module testbench();

    reg [3:0] current_state_i;
    reg branch_taken_i;
    wire pc_write_o, pc_sel_o;

    integer errors;

    localparam FETCH       = 4'b0000;
    localparam DECODE      = 4'b0001;
    localparam EXEC_ALU    = 4'b0010;
    localparam EXEC_BRANCH = 4'b1000;
    localparam EXEC_JUMP   = 4'b1001;
    localparam EXEC_MULT   = 4'b1010;

    pc_control_v2 dut (
        .current_state_i(current_state_i),
        .branch_taken_i(branch_taken_i),
        .pc_write_o(pc_write_o),
        .pc_sel_o(pc_sel_o)
    );

    task check;
        input [8*40-1:0] label;
        input exp_write;
        input exp_sel;
        begin
            #1;
            if (pc_write_o !== exp_write || pc_sel_o !== exp_sel) begin
                $display("FAIL: %0s expected(write=%b,sel=%b) got(write=%b,sel=%b)",
                    label, exp_write, exp_sel, pc_write_o, pc_sel_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> write=%b sel=%b", label, pc_write_o, pc_sel_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        // FETCH: PC always advances (PC+4), sel=0
        current_state_i = FETCH; branch_taken_i = 1'b0;
        check("FETCH, branch_taken=0", 1'b1, 1'b0);

        current_state_i = FETCH; branch_taken_i = 1'b1;
        check("FETCH, branch_taken=1 (should not matter here)", 1'b1, 1'b0);

        // DECODE / EXEC_ALU / EXEC_MULT: PC must NOT update
        current_state_i = DECODE; branch_taken_i = 1'b0;
        check("DECODE: no PC write", 1'b0, 1'b0);

        current_state_i = EXEC_ALU; branch_taken_i = 1'b0;
        check("EXEC_ALU: no PC write", 1'b0, 1'b0);

        current_state_i = EXEC_MULT; branch_taken_i = 1'b0;
        check("EXEC_MULT: no PC write", 1'b0, 1'b0);

        // EXEC_BRANCH with branch NOT taken: PC must not update
        // (control_fsm already routes back to FETCH regardless,
        // where the PC will normally advance next cycle)
        current_state_i = EXEC_BRANCH; branch_taken_i = 1'b0;
        check("EXEC_BRANCH, not taken: no PC write", 1'b0, 1'b0);

        // EXEC_BRANCH with branch taken: PC must update to the
        // branch target (sel=1)
        current_state_i = EXEC_BRANCH; branch_taken_i = 1'b1;
        check("EXEC_BRANCH, taken: PC write, sel=target", 1'b1, 1'b1);

        // EXEC_JUMP: PC always updates to jump target regardless
        // of branch_taken_i (which is irrelevant here)
        current_state_i = EXEC_JUMP; branch_taken_i = 1'b0;
        check("EXEC_JUMP, branch_taken=0: PC write, sel=target", 1'b1, 1'b1);

        current_state_i = EXEC_JUMP; branch_taken_i = 1'b1;
        check("EXEC_JUMP, branch_taken=1: PC write, sel=target", 1'b1, 1'b1);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("PC_CONTROL_V2 TESTBENCH: PASS");
            $display("PC write-enable and source-select correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("PC_CONTROL_V2 TESTBENCH: FAIL");
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
