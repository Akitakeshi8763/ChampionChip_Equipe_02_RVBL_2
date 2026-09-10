module testbench();

    reg i_Write_Enable;
    reg [31:0] i_Instruction;
    wire [31:0] o_Data_Rs_1;
    wire [31:0] o_Data_Rs_2;
    reg [2:0] i_Write_Back_Sel;
    reg [31:0] i_Memory_Data;
    reg [31:0] i_ALU_Output;
    reg i_Clk;
    reg i_Rst;
    reg [31:0] i_CRC_Result;
    reg [31:0] i_Multiplier_Result;
    reg [31:0] i_ZERO;
    reg [31:0] i_PC_Plus_4;

    integer errors;

    RISCV_Register3bit_A dut (
        .i_Write_Enable(i_Write_Enable),
        .i_Instruction(i_Instruction),
        .o_Data_Rs_1(o_Data_Rs_1),
        .o_Data_Rs_2(o_Data_Rs_2),
        .i_Write_Back_Sel(i_Write_Back_Sel),
        .i_Memory_Data(i_Memory_Data),
        .i_ALU_Output(i_ALU_Output),
        .i_Clk(i_Clk),
        .i_Rst(i_Rst),
        .i_CRC_Result(i_CRC_Result),
        .i_Multiplier_Result(i_Multiplier_Result),
        .i_ZERO(i_ZERO),
        .i_PC_Plus_4(i_PC_Plus_4)
    );

    initial i_Clk = 0;
    always #5 i_Clk = ~i_Clk;

    function [31:0] mk_instr;
        input [4:0] rd;
        input [4:0] rs1;
        input [4:0] rs2;
        begin
            mk_instr = {7'b0, rs2, rs1, 3'b0, rd, 7'b0};
        end
    endfunction

    // Writes rd = <src selected by sel>, then reads it back via
    // a second instruction with rs1=rd.
    task write_and_check;
        input [8*40-1:0] label;
        input [4:0] rd;
        input [2:0] sel;
        input [31:0] expected;
        begin
            i_Write_Back_Sel = sel;
            i_Instruction = mk_instr(rd, 5'd0, 5'd0);
            i_Write_Enable = 1;
            @(negedge i_Clk);
            @(posedge i_Clk);
            #1;
            i_Write_Enable = 0;
            i_Instruction = mk_instr(5'd0, rd, 5'd0);
            #1;
            if (o_Data_Rs_1 !== expected) begin
                $display("FAIL: %0s expected=%h got=%h", label, expected, o_Data_Rs_1);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> x%0d=%h", label, rd, o_Data_Rs_1);
            end
        end
    endtask

    initial begin
        errors = 0;
        i_Write_Enable = 0;
        i_Write_Back_Sel = 0;
        i_Memory_Data = 0;
        i_ALU_Output = 0;
        i_CRC_Result = 0;
        i_Multiplier_Result = 0;
        i_ZERO = 0;
        i_PC_Plus_4 = 0;
        i_Instruction = 0;
        i_Rst = 1;

        @(posedge i_Clk);
        @(posedge i_Clk);
        i_Rst = 0;

        // -----------------------------------------------------
        // wb_sel=000 -> ALU result written back
        // -----------------------------------------------------
        i_ALU_Output = 32'hAAAA0001;
        write_and_check("wb_sel=000 (ALU) -> x5", 5'd5, 3'b000, 32'hAAAA0001);

        // -----------------------------------------------------
        // wb_sel=001 -> Memory (load) data written back
        // -----------------------------------------------------
        i_Memory_Data = 32'hBBBB0002;
        write_and_check("wb_sel=001 (Memory/LSU) -> x6", 5'd6, 3'b001, 32'hBBBB0002);

        // -----------------------------------------------------
        // wb_sel=010 -> Multiplier result written back
        // -----------------------------------------------------
        i_Multiplier_Result = 32'hCCCC0003;
        write_and_check("wb_sel=010 (Multiplier) -> x7", 5'd7, 3'b010, 32'hCCCC0003);

        // -----------------------------------------------------
        // wb_sel=011 -> CRC result written back
        // -----------------------------------------------------
        i_CRC_Result = 32'hDDDD0004;
        write_and_check("wb_sel=011 (CRC) -> x8", 5'd8, 3'b011, 32'hDDDD0004);

        // -----------------------------------------------------
        // wb_sel=100 -> PC+4 (return address) written back
        // (used for JAL/JALR destination register)
        // -----------------------------------------------------
        i_PC_Plus_4 = 32'h00400104;
        write_and_check("wb_sel=100 (PC+4) -> x1 (ra)", 5'd1, 3'b100, 32'h00400104);

        // -----------------------------------------------------
        // x0 write protection must still hold through this
        // wrapper (delegates to REGISTER_FILE internally)
        // -----------------------------------------------------
        i_ALU_Output = 32'hFFFFFFFF;
        write_and_check("x0 write-protected even via wrapper", 5'd0, 3'b000, 32'h00000000);

        // -----------------------------------------------------
        // Confirm previously-written registers persisted
        // correctly across all the above writes (no register
        // file corruption/aliasing between writes)
        // -----------------------------------------------------
        i_Instruction = mk_instr(5'd0, 5'd5, 5'd6);
        #1;
        if (o_Data_Rs_1 !== 32'hAAAA0001 || o_Data_Rs_2 !== 32'hBBBB0002) begin
            $display("FAIL: persistence check: x5/x6 corrupted -- got rs1=%h rs2=%h",
                o_Data_Rs_1, o_Data_Rs_2);
            errors = errors + 1;
        end
        else begin
            $display("PASS: persistence check: x5=%h x6=%h (no corruption)", o_Data_Rs_1, o_Data_Rs_2);
        end

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("RISCV_REGISTER3BIT_A TESTBENCH: PASS");
            $display("All 5 writeback sources route correctly.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("RISCV_REGISTER3BIT_A TESTBENCH: FAIL");
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
