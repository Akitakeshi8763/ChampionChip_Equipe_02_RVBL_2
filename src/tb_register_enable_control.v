module testbench();

    reg [3:0] current_state_i;
    wire a_write_o, b_write_o, aluout_write_o, mdr_write_o;

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

    register_enable_control dut (
        .current_state_i(current_state_i),
        .a_write_o(a_write_o),
        .b_write_o(b_write_o),
        .aluout_write_o(aluout_write_o),
        .mdr_write_o(mdr_write_o)
    );

    wire [3:0] bundle = {a_write_o, b_write_o, aluout_write_o, mdr_write_o};

    task check;
        input [8*32-1:0] label;
        input [3:0] expected; // {a,b,aluout,mdr}
        begin
            #1;
            if (bundle !== expected) begin
                $display("FAIL: %0s expected{a=%b,b=%b,aluout=%b,mdr=%b} got{a=%b,b=%b,aluout=%b,mdr=%b}",
                    label, expected[3],expected[2],expected[1],expected[0],
                    a_write_o,b_write_o,aluout_write_o,mdr_write_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> {a=%b,b=%b,aluout=%b,mdr=%b}",
                    label, a_write_o,b_write_o,aluout_write_o,mdr_write_o);
            end
        end
    endtask

    initial begin
        errors = 0;

        current_state_i = FETCH;
        check("FETCH: all idle", 4'b0000);

        current_state_i = DECODE;
        check("DECODE: A+B latch rs1/rs2", 4'b1100);

        current_state_i = EXEC_ALU;
        check("EXEC_ALU: ALUout latches result", 4'b0010);

        current_state_i = WRITEBACK;
        check("WRITEBACK: all idle (data already latched)", 4'b0000);

        current_state_i = EXEC_LOAD;
        check("EXEC_LOAD: ALUout latches computed address", 4'b0010);

        current_state_i = MEM_LOAD;
        check("MEM_LOAD: all idle (memory access in flight)", 4'b0000);

        current_state_i = LOAD_CAPTURE;
        check("LOAD_CAPTURE: MDR latches memory data", 4'b0001);

        current_state_i = EXEC_STORE;
        check("EXEC_STORE: ALUout latches computed address", 4'b0010);

        current_state_i = MEM_STORE;
        check("MEM_STORE: all idle (write in flight)", 4'b0000);

        current_state_i = EXEC_BRANCH;
        check("EXEC_BRANCH: all idle", 4'b0000);

        current_state_i = EXEC_JUMP;
        check("EXEC_JUMP: all idle", 4'b0000);

        current_state_i = EXEC_MULT;
        check("EXEC_MULT: all idle (multiplier has its own regs)", 4'b0000);

        current_state_i = EXEC_CRC;
        check("EXEC_CRC: all idle (combinational)", 4'b0000);

        current_state_i = EXEC_SYSTEM;
        check("EXEC_SYSTEM: all idle", 4'b0000);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("REGISTER_ENABLE_CONTROL TESTBENCH: PASS");
            $display("All pipeline-register enables correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("REGISTER_ENABLE_CONTROL TESTBENCH: FAIL");
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
