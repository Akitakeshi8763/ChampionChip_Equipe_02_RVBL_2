module testbench();

    reg [31:0] i_Data_Rd;
    reg [31:0] i_Instruction;
    reg i_Write_Enable;
    reg i_Clk;
    reg i_Rst;
    wire [31:0] o_Data_Rs_1;
    wire [31:0] o_Data_Rs_2;

    integer errors;

    // Default parameter p_DATA_MEM_SIZE = 2**10 = 1024
    // c_GP_INITIAL_VALUE = 0x10010000
    // c_SP_INITIAL_VALUE = 0x10010000 + 1024 - 4 = 0x100103FC
    localparam GP_INIT = 32'h10010000;
    localparam SP_INIT = 32'h100103FC;

    REGISTER_FILE dut (
        .i_Data_Rd(i_Data_Rd),
        .i_Instruction(i_Instruction),
        .i_Write_Enable(i_Write_Enable),
        .i_Clk(i_Clk),
        .i_Rst(i_Rst),
        .o_Data_Rs_1(o_Data_Rs_1),
        .o_Data_Rs_2(o_Data_Rs_2)
    );

    initial i_Clk = 0;
    always #5 i_Clk = ~i_Clk;

    // Build an instruction word with only rd/rs1/rs2 fields set
    function [31:0] mk_instr;
        input [4:0] rd;
        input [4:0] rs1;
        input [4:0] rs2;
        begin
            mk_instr = {7'b0, rs2, rs1, 3'b0, rd, 7'b0};
        end
    endfunction

    task check_rs;
        input [8*40-1:0] label;
        input [31:0] exp_rs1;
        input [31:0] exp_rs2;
        begin
            #1;
            if (o_Data_Rs_1 !== exp_rs1 || o_Data_Rs_2 !== exp_rs2) begin
                $display("FAIL: %0s expected(rs1=%h,rs2=%h) got(rs1=%h,rs2=%h)",
                    label, exp_rs1, exp_rs2, o_Data_Rs_1, o_Data_Rs_2);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> rs1=%h rs2=%h", label, o_Data_Rs_1, o_Data_Rs_2);
            end
        end
    endtask

    initial begin
        errors = 0;
        i_Write_Enable = 0;
        i_Data_Rd = 0;
        i_Rst = 1;
        i_Instruction = mk_instr(5'd0, 5'd0, 5'd0);

        @(posedge i_Clk);
        @(posedge i_Clk);
        i_Rst = 0;

        // -----------------------------------------------------
        // After reset: x0=0, sp(x2)=SP_INIT, gp(x3)=GP_INIT,
        // everything else = 0
        // -----------------------------------------------------
        i_Instruction = mk_instr(5'd0, 5'd0, 5'd1); // read x0, x1
        check_rs("Reset: x0=0, x1=0", 32'h0, 32'h0);

        i_Instruction = mk_instr(5'd0, 5'd2, 5'd3); // read x2(sp), x3(gp)
        check_rs("Reset: x2=SP_INIT, x3=GP_INIT", SP_INIT, GP_INIT);

        i_Instruction = mk_instr(5'd0, 5'd31, 5'd15);
        check_rs("Reset: x31=0, x15=0", 32'h0, 32'h0);

        // -----------------------------------------------------
        // Write to x5, then confirm it reads back (sync write,
        // async read: value visible immediately after the
        // clock edge that performs the write)
        // -----------------------------------------------------
        i_Write_Enable = 1;
        i_Data_Rd = 32'hCAFEBABE;
        i_Instruction = mk_instr(5'd5, 5'd0, 5'd0); // rd=x5
        @(posedge i_Clk);
        #1;
        i_Write_Enable = 0;
        i_Instruction = mk_instr(5'd0, 5'd5, 5'd0); // read x5
        check_rs("Write x5=0xCAFEBABE then read", 32'hCAFEBABE, 32'h0);

        // -----------------------------------------------------
        // x0 write protection: attempt to write x0, must remain 0
        // -----------------------------------------------------
        i_Write_Enable = 1;
        i_Data_Rd = 32'hFFFFFFFF;
        i_Instruction = mk_instr(5'd0, 5'd0, 5'd0); // rd=x0
        @(posedge i_Clk);
        #1;
        i_Write_Enable = 0;
        i_Instruction = mk_instr(5'd0, 5'd0, 5'd0); // read x0
        check_rs("x0 write-protected: stays 0 despite write attempt", 32'h0, 32'h0);

        // -----------------------------------------------------
        // Simultaneous read of rs1==rs2 (same register read twice)
        // -----------------------------------------------------
        i_Instruction = mk_instr(5'd0, 5'd5, 5'd5); // both point at x5
        check_rs("rs1==rs2==x5: both read same value", 32'hCAFEBABE, 32'hCAFEBABE);

        // -----------------------------------------------------
        // Write-enable low: a write attempt must NOT happen
        // -----------------------------------------------------
        i_Write_Enable = 0;
        i_Data_Rd = 32'h11111111;
        i_Instruction = mk_instr(5'd6, 5'd0, 5'd0); // rd=x6, but WE=0
        @(posedge i_Clk);
        #1;
        i_Instruction = mk_instr(5'd0, 5'd6, 5'd0);
        check_rs("Write_Enable=0: x6 remains 0", 32'h0, 32'h0);

        // -----------------------------------------------------
        // Reset again mid-operation: x5 (previously CAFEBABE)
        // must clear back to 0, sp/gp restored
        // -----------------------------------------------------
        i_Rst = 1;
        @(posedge i_Clk);
        i_Rst = 0;
        i_Instruction = mk_instr(5'd0, 5'd5, 5'd2);
        check_rs("Re-reset: x5 cleared, x2(sp) restored", 32'h0, SP_INIT);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("REGISTER_FILE TESTBENCH: PASS");
            $display("Reset defaults, x0 protection, R/W all correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("REGISTER_FILE TESTBENCH: FAIL");
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
