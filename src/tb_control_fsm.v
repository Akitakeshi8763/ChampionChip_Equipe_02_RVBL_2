module testbench();

    // =========================================================
    // DUT I/O
    // =========================================================
    reg clk_i;
    reg rst_i;
    reg [3:0] instr_type_i;
    reg mult_done_i;

    wire [3:0] current_state_o;

    integer errors;

    // =========================================================
    // STATE / TYPE ENCODINGS (mirrored from Control_unit.v for
    // readable expected-value checks in this testbench)
    // =========================================================
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

    localparam TYPE_ALU_REG = 4'b0000;
    localparam TYPE_ALU_IMM = 4'b0001;
    localparam TYPE_LOAD    = 4'b0010;
    localparam TYPE_STORE   = 4'b0011;
    localparam TYPE_BRANCH  = 4'b0100;
    localparam TYPE_JAL     = 4'b0101;
    localparam TYPE_JALR    = 4'b0110;
    localparam TYPE_LUI     = 4'b0111;
    localparam TYPE_AUIPC   = 4'b1000;
    localparam TYPE_SYSTEM  = 4'b1001;
    localparam TYPE_MULT    = 4'b1010;
    localparam TYPE_CRC     = 4'b1011;
    localparam TYPE_INVALID = 4'b1111; // not a defined type -> exercises default case

    // =========================================================
    // DUT
    // =========================================================
    control_fsm dut (
        .clk_i(clk_i),
        .rst_i(rst_i),
        .instr_type_i(instr_type_i),
        .mult_done_i(mult_done_i),
        .current_state_o(current_state_o)
    );

    // =========================================================
    // CLOCK: 10ns period
    // =========================================================
    initial clk_i = 0;
    always #5 clk_i = ~clk_i;

    // =========================================================
    // Helper task: advance one clock edge and check state
    // =========================================================
    task check_state;
        input [8*32-1:0] label; // string label for $display, up to 32 chars
        input [3:0] expected;
        begin
            @(posedge clk_i);
            #1; // small delta to let the state register settle
            if (current_state_o !== expected) begin
                $display("FAIL: %0s expected=%b got=%b", label, expected, current_state_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> state=%b", label, current_state_o);
            end
        end
    endtask

    // =========================================================
    // TESTS
    // =========================================================
    initial begin

        errors = 0;
        rst_i = 1;
        instr_type_i = TYPE_ALU_REG;
        mult_done_i = 0;

        // -----------------------------------------------------
        // RESET
        // FSM must land in FETCH on reset, asynchronously
        // -----------------------------------------------------
        #2;
        if (current_state_o !== FETCH) begin
            $display("FAIL: async reset expected=FETCH(%b) got=%b", FETCH, current_state_o);
            errors = errors + 1;
        end
        else begin
            $display("PASS: async reset -> FETCH");
        end

        @(posedge clk_i);
        #1;
        rst_i = 0;

        // -----------------------------------------------------
        // FETCH -> DECODE (unconditional)
        // -----------------------------------------------------
        check_state("FETCH->DECODE", DECODE);

        // -----------------------------------------------------
        // DECODE -> EXEC_ALU for TYPE_ALU_REG
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG;
        check_state("DECODE(ALU_REG)->EXEC_ALU", EXEC_ALU);

        // -----------------------------------------------------
        // EXEC_ALU -> WRITEBACK -> FETCH (full ALU round trip)
        // -----------------------------------------------------
        check_state("EXEC_ALU->WRITEBACK", WRITEBACK);
        check_state("WRITEBACK->FETCH", FETCH);

        // -----------------------------------------------------
        // DECODE -> EXEC_ALU for TYPE_ALU_IMM
        // -----------------------------------------------------
        check_state("FETCH->DECODE (2)", DECODE);
        instr_type_i = TYPE_ALU_IMM;
        check_state("DECODE(ALU_IMM)->EXEC_ALU", EXEC_ALU);
        check_state("EXEC_ALU->WRITEBACK (2)", WRITEBACK);
        check_state("WRITEBACK->FETCH (2)", FETCH);

        // -----------------------------------------------------
        // DECODE -> EXEC_ALU for TYPE_LUI
        // -----------------------------------------------------
        check_state("FETCH->DECODE (3)", DECODE);
        instr_type_i = TYPE_LUI;
        check_state("DECODE(LUI)->EXEC_ALU", EXEC_ALU);
        check_state("EXEC_ALU->WRITEBACK (3)", WRITEBACK);
        check_state("WRITEBACK->FETCH (3)", FETCH);

        // -----------------------------------------------------
        // DECODE -> EXEC_ALU for TYPE_AUIPC
        // -----------------------------------------------------
        check_state("FETCH->DECODE (4)", DECODE);
        instr_type_i = TYPE_AUIPC;
        check_state("DECODE(AUIPC)->EXEC_ALU", EXEC_ALU);
        check_state("EXEC_ALU->WRITEBACK (4)", WRITEBACK);
        check_state("WRITEBACK->FETCH (4)", FETCH);

        // -----------------------------------------------------
        // LOAD path: FETCH->DECODE->EXEC_LOAD->MEM_LOAD->
        //            LOAD_CAPTURE->WRITEBACK->FETCH
        // -----------------------------------------------------
        check_state("FETCH->DECODE (5)", DECODE);
        instr_type_i = TYPE_LOAD;
        check_state("DECODE(LOAD)->EXEC_LOAD", EXEC_LOAD);
        check_state("EXEC_LOAD->MEM_LOAD", MEM_LOAD);
        check_state("MEM_LOAD->LOAD_CAPTURE", LOAD_CAPTURE);
        check_state("LOAD_CAPTURE->WRITEBACK", WRITEBACK);
        check_state("WRITEBACK->FETCH (5)", FETCH);

        // -----------------------------------------------------
        // STORE path: FETCH->DECODE->EXEC_STORE->MEM_STORE->FETCH
        // (store has no writeback stage)
        // -----------------------------------------------------
        check_state("FETCH->DECODE (6)", DECODE);
        instr_type_i = TYPE_STORE;
        check_state("DECODE(STORE)->EXEC_STORE", EXEC_STORE);
        check_state("EXEC_STORE->MEM_STORE", MEM_STORE);
        check_state("MEM_STORE->FETCH", FETCH);

        // -----------------------------------------------------
        // BRANCH path: FETCH->DECODE->EXEC_BRANCH->FETCH
        // -----------------------------------------------------
        check_state("FETCH->DECODE (7)", DECODE);
        instr_type_i = TYPE_BRANCH;
        check_state("DECODE(BRANCH)->EXEC_BRANCH", EXEC_BRANCH);
        check_state("EXEC_BRANCH->FETCH", FETCH);

        // -----------------------------------------------------
        // JAL path: FETCH->DECODE->EXEC_JUMP->WRITEBACK->FETCH
        // -----------------------------------------------------
        check_state("FETCH->DECODE (8)", DECODE);
        instr_type_i = TYPE_JAL;
        check_state("DECODE(JAL)->EXEC_JUMP", EXEC_JUMP);
        check_state("EXEC_JUMP->WRITEBACK", WRITEBACK);
        check_state("WRITEBACK->FETCH (6)", FETCH);

        // -----------------------------------------------------
        // JALR path: same shape as JAL
        // -----------------------------------------------------
        check_state("FETCH->DECODE (9)", DECODE);
        instr_type_i = TYPE_JALR;
        check_state("DECODE(JALR)->EXEC_JUMP", EXEC_JUMP);
        check_state("EXEC_JUMP->WRITEBACK (2)", WRITEBACK);
        check_state("WRITEBACK->FETCH (7)", FETCH);

        // -----------------------------------------------------
        // MULT path with mult_done_i held low: FSM must STALL
        // in EXEC_MULT until mult_done_i is asserted
        // -----------------------------------------------------
        check_state("FETCH->DECODE (10)", DECODE);
        instr_type_i = TYPE_MULT;
        mult_done_i = 0;
        check_state("DECODE(MULT)->EXEC_MULT", EXEC_MULT);
        // Hold mult_done_i low for a few cycles; FSM must stay put
        check_state("EXEC_MULT stall (mult_done=0) #1", EXEC_MULT);
        check_state("EXEC_MULT stall (mult_done=0) #2", EXEC_MULT);
        check_state("EXEC_MULT stall (mult_done=0) #3", EXEC_MULT);
        // Now assert mult_done_i; FSM should advance to WRITEBACK
        mult_done_i = 1;
        check_state("EXEC_MULT->WRITEBACK (mult_done=1)", WRITEBACK);
        mult_done_i = 0;
        check_state("WRITEBACK->FETCH (8)", FETCH);

        // -----------------------------------------------------
        // CRC path: FETCH->DECODE->EXEC_CRC->WRITEBACK->FETCH
        // -----------------------------------------------------
        check_state("FETCH->DECODE (11)", DECODE);
        instr_type_i = TYPE_CRC;
        check_state("DECODE(CRC)->EXEC_CRC", EXEC_CRC);
        check_state("EXEC_CRC->WRITEBACK", WRITEBACK);
        check_state("WRITEBACK->FETCH (9)", FETCH);

        // -----------------------------------------------------
        // SYSTEM path: FETCH->DECODE->EXEC_SYSTEM->FETCH
        // -----------------------------------------------------
        check_state("FETCH->DECODE (12)", DECODE);
        instr_type_i = TYPE_SYSTEM;
        check_state("DECODE(SYSTEM)->EXEC_SYSTEM", EXEC_SYSTEM);
        check_state("EXEC_SYSTEM->FETCH", FETCH);

        // -----------------------------------------------------
        // INVALID instr_type_i during DECODE: must default to
        // FETCH rather than lock up or go to an undefined state.
        // This is an edge case a malformed/unsupported opcode
        // could trigger, so DV explicitly checks it.
        // -----------------------------------------------------
        check_state("FETCH->DECODE (13)", DECODE);
        instr_type_i = TYPE_INVALID;
        check_state("DECODE(INVALID)->FETCH (default case)", FETCH);

        // -----------------------------------------------------
        // Mid-instruction reset: assert rst_i while FSM is
        // mid-sequence (e.g. inside EXEC_LOAD) and confirm it
        // snaps back to FETCH immediately, not on next clock.
        // -----------------------------------------------------
        instr_type_i = TYPE_LOAD;
        check_state("FETCH->DECODE (14)", DECODE);
        check_state("DECODE(LOAD)->EXEC_LOAD (2)", EXEC_LOAD);
        rst_i = 1;
        #2; // async reset should take effect without waiting for a clock edge
        if (current_state_o !== FETCH) begin
            $display("FAIL: mid-sequence async reset expected=FETCH got=%b", current_state_o);
            errors = errors + 1;
        end
        else begin
            $display("PASS: mid-sequence async reset -> FETCH");
        end
        rst_i = 0;

        // -----------------------------------------------------
        // FINAL RESULT
        // -----------------------------------------------------
        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("CONTROL_FSM TESTBENCH: PASS");
            $display("All FSM transitions verified correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("CONTROL_FSM TESTBENCH: FAIL");
            $display("Number of errors = %0d", errors);
            $display("========================================");
        end

        $finish;
    end

    // =========================================================
    // WAVEFORM
    // =========================================================
    initial begin
        $dumpfile("testbench.vcd");
        $dumpvars(0, testbench);
    end

endmodule
