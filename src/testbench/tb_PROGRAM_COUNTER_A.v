module testbench();

    reg [31:0] i_Data;
    reg i_Clk;
    reg i_Rst;
    reg i_PC_write_enable;
    wire [31:0] o_PC_Output;
    wire [31:0] o_PC_Plus_4;

    integer errors;

    // Per Block Guide Table 13: IMEM base address = 0x00400000
    localparam PC_INIT = 32'h00400000;

    PROGRAM_COUNTER_A dut (
        .i_Data(i_Data),
        .i_Clk(i_Clk),
        .i_Rst(i_Rst),
        .i_PC_write_enable(i_PC_write_enable),
        .o_PC_Output(o_PC_Output),
        .o_PC_Plus_4(o_PC_Plus_4)
    );

    initial i_Clk = 0;
    always #5 i_Clk = ~i_Clk;

    task check;
        input [8*40-1:0] label;
        input [31:0] exp_pc;
        input [31:0] exp_pc4;
        begin
            #1;
            if (o_PC_Output !== exp_pc || o_PC_Plus_4 !== exp_pc4) begin
                $display("FAIL: %0s expected(pc=%h,pc+4=%h) got(pc=%h,pc+4=%h)",
                    label, exp_pc, exp_pc4, o_PC_Output, o_PC_Plus_4);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> pc=%h pc+4=%h", label, o_PC_Output, o_PC_Plus_4);
            end
        end
    endtask

    initial begin
        errors = 0;
        i_Data = 0;
        i_PC_write_enable = 0;
        i_Rst = 1;

        @(posedge i_Clk);
        #1;
        // -----------------------------------------------------
        // Reset: PC must land on the IMEM base address per the
        // Block Guide's System Memory Map (Table 13)
        // -----------------------------------------------------
        check("Reset: PC=IMEM base 0x00400000", PC_INIT, PC_INIT + 4);

        i_Rst = 0;

        // -----------------------------------------------------
        // write_enable=0: PC must hold steady across clock edges
        // even if i_Data changes (simulates the DECODE/EXEC/
        // WRITEBACK cycles where PC shouldn't move)
        // -----------------------------------------------------
        i_Data = 32'hDEADBEEF;
        @(posedge i_Clk);
        #1;
        check("write_enable=0: PC holds despite i_Data change", PC_INIT, PC_INIT + 4);

        @(posedge i_Clk);
        #1;
        check("write_enable=0 (2nd cycle): PC still holds", PC_INIT, PC_INIT + 4);

        // -----------------------------------------------------
        // write_enable=1: PC loads i_Data (normal PC+4 sequential
        // fetch, as would be driven by MUX2_32 selecting
        // o_PC_Plus_4 in the FETCH state)
        // -----------------------------------------------------
        @(negedge i_Clk); // set up inputs safely away from the edge
        i_Data = PC_INIT + 4;
        i_PC_write_enable = 1;
        @(posedge i_Clk);
        #1;
        i_PC_write_enable = 0;
        check("write_enable=1: PC advances to PC_INIT+4", PC_INIT + 4, PC_INIT + 8);

        // -----------------------------------------------------
        // Another sequential advance
        // -----------------------------------------------------
        @(negedge i_Clk);
        i_Data = PC_INIT + 8;
        i_PC_write_enable = 1;
        @(posedge i_Clk);
        #1;
        i_PC_write_enable = 0;
        check("Sequential advance to PC_INIT+8", PC_INIT + 8, PC_INIT + 12);

        // -----------------------------------------------------
        // Branch/jump target load: PC jumps to an arbitrary
        // non-sequential address (simulates MUX2_32 selecting
        // the ALU-computed branch target instead of PC+4)
        // -----------------------------------------------------
        @(negedge i_Clk);
        i_Data = 32'h00400100;
        i_PC_write_enable = 1;
        @(posedge i_Clk);
        #1;
        i_PC_write_enable = 0;
        check("Branch target load: PC jumps to 0x00400100", 32'h00400100, 32'h00400104);

        // -----------------------------------------------------
        // Mid-sequence async reset: PC must snap back to
        // PC_INIT immediately, not on the next clock edge
        // -----------------------------------------------------
        i_Rst = 1;
        #2;
        if (o_PC_Output !== PC_INIT) begin
            $display("FAIL: async reset mid-sequence expected pc=%h got=%h", PC_INIT, o_PC_Output);
            errors = errors + 1;
        end
        else begin
            $display("PASS: async reset mid-sequence -> pc=%h", o_PC_Output);
        end
        i_Rst = 0;

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("PROGRAM_COUNTER_A TESTBENCH: PASS");
            $display("Reset value, write-enable gating, PC+4 all correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("PROGRAM_COUNTER_A TESTBENCH: FAIL");
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
