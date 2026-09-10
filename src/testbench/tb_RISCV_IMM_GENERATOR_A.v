module testbench();

    reg [31:0] i_Instruction;
    wire [31:0] o_Immediate;

    integer errors;

    RISCV_IMM_GENERATOR_A dut (
        .i_Instruction(i_Instruction),
        .o_Immediate(o_Immediate)
    );

    task check;
        input [8*32-1:0] label;
        input [31:0] expected;
        begin
            #1;
            if (o_Immediate !== expected) begin
                $display("FAIL: %0s expected=%h got=%h", label, expected, o_Immediate);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> imm=%h", label, o_Immediate);
            end
        end
    endtask

    initial begin
        errors = 0;

        // -----------------------------------------------------
        // I-type: ADDI x1, x2, 5  (positive immediate, default case)
        // imm[11:0]=000000000101 rs1=00010 funct3=000 rd=00001 opcode=0010011
        // -----------------------------------------------------
        i_Instruction = 32'b000000000101_00010_000_00001_0010011;
        check("I-type ADDI imm=5", 32'd5);

        // -----------------------------------------------------
        // I-type: ADDI x1, x2, -1 (all-ones immediate, sign-extended)
        // imm[11:0]=111111111111
        // -----------------------------------------------------
        i_Instruction = 32'b111111111111_00010_000_00001_0010011;
        check("I-type ADDI imm=-1 (sign ext)", 32'hFFFFFFFF);

        // -----------------------------------------------------
        // I-type: LW x5, -2048(x6)  (most negative 12-bit imm)
        // imm[11:0]=100000000000 -> -2048
        // -----------------------------------------------------
        i_Instruction = 32'b100000000000_00110_010_00101_0000011;
        check("I-type LW imm=-2048 (min)", 32'hFFFFF800);

        // -----------------------------------------------------
        // I-type: max positive 12-bit imm = 2047
        // imm[11:0]=011111111111
        // -----------------------------------------------------
        i_Instruction = 32'b011111111111_00010_000_00001_0010011;
        check("I-type imm=2047 (max positive)", 32'd2047);

        // -----------------------------------------------------
        // S-type: SW x2, 10(x1)
        // imm[11:5]=0000000 rs2=00010 rs1=00001 funct3=010 imm[4:0]=01010 opcode=0100011
        // Full imm = 0000000_01010 = 10
        // -----------------------------------------------------
        i_Instruction = 32'b0000000_00010_00001_010_01010_0100011;
        check("S-type SW imm=10", 32'd10);

        // -----------------------------------------------------
        // S-type: SW with negative offset -4
        // -4 in 12-bit two's complement = 111111111100
        // imm[11:5]=1111111 imm[4:0]=11100
        // -----------------------------------------------------
        i_Instruction = 32'b1111111_00010_00001_010_11100_0100011;
        check("S-type SW imm=-4 (sign ext)", 32'hFFFFFFFC);

        // -----------------------------------------------------
        // B-type: BEQ x1, x2, +8
        // Branch imm encodes a multiple of 2, bit0 always 0.
        // +8 -> imm[12]=0 imm[11]=0 imm[10:5]=000000 imm[4:1]=0100 (then <<1)
        // Instruction bit layout: [31]=imm[12] [30:25]=imm[10:5]
        // [11:8]=imm[4:1] [7]=imm[11]
        // For imm=8 (0b0000_0000_1000): imm[12]=0,imm[11]=0,
        // imm[10:5]=000000, imm[4:1]=0100
        // -----------------------------------------------------
        i_Instruction = {1'b0, 6'b000000, 5'b00010, 5'b00001, 3'b000, 4'b0100, 1'b0, 7'b1100011};
        check("B-type BEQ imm=+8", 32'd8);

        // -----------------------------------------------------
        // B-type: negative branch offset -8
        // imm=-8 = 12'b111111111000 (13-bit signed form with
        // implicit bit0=0): imm[12]=1 imm[11]=1 imm[10:5]=111111
        // imm[4:1]=1100
        // -----------------------------------------------------
        i_Instruction = {1'b1, 6'b111111, 5'b00010, 5'b00001, 3'b000, 4'b1100, 1'b1, 7'b1100011};
        check("B-type BEQ imm=-8 (sign ext)", 32'hFFFFFFF8);

        // -----------------------------------------------------
        // U-type: LUI x1, 0x12345
        // imm[31:12]=0x12345, lower 12 bits always 0
        // -----------------------------------------------------
        i_Instruction = {20'h12345, 5'b00001, 7'b0110111};
        check("U-type LUI imm=0x12345000", 32'h12345000);

        // -----------------------------------------------------
        // U-type: AUIPC x2, 0xFFFFF (all ones upper -> tests no
        // accidental sign extension corrupts the lower 12 bits,
        // which must always read exactly 0)
        // -----------------------------------------------------
        i_Instruction = {20'hFFFFF, 5'b00010, 7'b0010111};
        check("U-type AUIPC imm=0xFFFFF000", 32'hFFFFF000);

        // -----------------------------------------------------
        // J-type: JAL x1, +16
        // imm[20]=0 imm[19:12]=00000000 imm[11]=0 imm[10:1]=0001000 -> wait,
        // build directly: for imm=16 (0b0..010000), with implicit
        // bit0=0: imm[20]=0 imm[19:12]=0 imm[11]=0 imm[10:1]=0000001000
        // Instruction encoding: [31]=imm[20] [30:21]=imm[10:1]
        // [20]=imm[11] [19:12]=imm[19:12]
        // -----------------------------------------------------
        i_Instruction = {1'b0, 10'b0000001000, 1'b0, 8'b00000000, 5'b00001, 7'b1101111};
        check("J-type JAL imm=+16", 32'd16);

        // -----------------------------------------------------
        // J-type: JAL with negative offset -16
        // imm=-16: imm[20]=1 imm[19:12]=11111111 imm[11]=1
        // imm[10:1]=1111111000
        // -----------------------------------------------------
        i_Instruction = {1'b1, 10'b1111111000, 1'b1, 8'b11111111, 5'b00001, 7'b1101111};
        check("J-type JAL imm=-16 (sign ext)", 32'hFFFFFFF0);

        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("RISCV_IMM_GENERATOR_A TESTBENCH: PASS");
            $display("All I/S/B/U/J immediate encodings correct.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("RISCV_IMM_GENERATOR_A TESTBENCH: FAIL");
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
