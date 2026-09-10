module testbench();

    // =========================================================
    // DUT I/O
    // =========================================================
    reg [3:0] instr_type_i;
    reg [2:0] funct3_i;
    reg [6:0] funct7_i;

    wire [3:0] alu_sel_o;
    wire [3:0] mult_sel_o;
    wire [3:0] crc_sel_o;

    integer errors;

    // =========================================================
    // INSTRUCTION TYPES (mirrored from Control_unit.v)
    // =========================================================
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

    // =========================================================
    // GROUND-TRUTH ALU OPCODES
    // Taken directly from `c_ALU_OP_* macros in
    // Datapath_modules.v (RISCV_ALU_4bit), NOT from the Block
    // Guide's Table 9 -- this repo's actual RTL uses a different
    // encoding than the guide's documented table, and DV must
    // check against what the silicon will actually execute.
    // =========================================================
    localparam ALU_ADD    = 4'b0000; // implicit: falls to `default` in RISCV_ALU_4bit
    localparam ALU_SUB    = 4'b0001;
    localparam ALU_AND    = 4'b0010;
    localparam ALU_OR     = 4'b0011;
    localparam ALU_XOR    = 4'b0100;
    localparam ALU_SLL    = 4'b0101;
    localparam ALU_SRL    = 4'b0110;
    localparam ALU_SRA    = 4'b0111;
    localparam ALU_SLT    = 4'b1000;
    localparam ALU_SLTU   = 4'b1001;
    localparam ALU_PASS_B = 4'b1010;

    // =========================================================
    // DUT
    // =========================================================
    operation_decoder dut (
        .instr_type_i(instr_type_i),
        .funct3_i(funct3_i),
        .funct7_i(funct7_i),
        .alu_sel_o(alu_sel_o),
        .mult_sel_o(mult_sel_o),
        .crc_sel_o(crc_sel_o)
    );

    // =========================================================
    // Helper task
    // =========================================================
    task check_alu_sel;
        input [8*32-1:0] label;
        input [3:0] expected;
        begin
            #1;
            if (alu_sel_o !== expected) begin
                $display("FAIL: %0s expected alu_sel_o=%h got=%h", label, expected, alu_sel_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> alu_sel_o=%h", label, alu_sel_o);
            end
        end
    endtask

    task check_mult_sel;
        input [8*32-1:0] label;
        input [3:0] expected;
        begin
            #1;
            if (mult_sel_o !== expected) begin
                $display("FAIL: %0s expected mult_sel_o=%h got=%h", label, expected, mult_sel_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> mult_sel_o=%h", label, mult_sel_o);
            end
        end
    endtask

    task check_crc_sel;
        input [8*32-1:0] label;
        input [3:0] expected;
        begin
            #1;
            if (crc_sel_o !== expected) begin
                $display("FAIL: %0s expected crc_sel_o=%h got=%h", label, expected, crc_sel_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> crc_sel_o=%h", label, crc_sel_o);
            end
        end
    endtask

    // =========================================================
    // TESTS
    // =========================================================
    initial begin
        errors = 0;
        instr_type_i = TYPE_ALU_REG;
        funct3_i = 3'b000;
        funct7_i = 7'b0000000;

        // -----------------------------------------------------
        // TYPE_ALU_REG: ADD (funct3=000, funct7=0000000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b000; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG ADD", ALU_ADD);

        // -----------------------------------------------------
        // TYPE_ALU_REG: SUB (funct3=000, funct7=0100000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b000; funct7_i = 7'b0100000;
        check_alu_sel("ALU_REG SUB", ALU_SUB);

        // -----------------------------------------------------
        // TYPE_ALU_REG: SLL (funct3=001)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b001; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG SLL", ALU_SLL);

        // -----------------------------------------------------
        // TYPE_ALU_REG: SLT (funct3=010)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b010; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG SLT", ALU_SLT);

        // -----------------------------------------------------
        // TYPE_ALU_REG: SLTU (funct3=011)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b011; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG SLTU", ALU_SLTU);

        // -----------------------------------------------------
        // TYPE_ALU_REG: XOR (funct3=100)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b100; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG XOR", ALU_XOR);

        // -----------------------------------------------------
        // TYPE_ALU_REG: SRL (funct3=101, funct7=0000000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b101; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG SRL", ALU_SRL);

        // -----------------------------------------------------
        // TYPE_ALU_REG: SRA (funct3=101, funct7=0100000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b101; funct7_i = 7'b0100000;
        check_alu_sel("ALU_REG SRA", ALU_SRA);

        // -----------------------------------------------------
        // TYPE_ALU_REG: OR (funct3=110)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b110; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG OR", ALU_OR);

        // -----------------------------------------------------
        // TYPE_ALU_REG: AND (funct3=111)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_REG; funct3_i = 3'b111; funct7_i = 7'b0000000;
        check_alu_sel("ALU_REG AND", ALU_AND);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: ADDI (funct3=000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b000; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM ADDI", ALU_ADD);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: SLTI (funct3=010)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b010; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM SLTI", ALU_SLT);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: SLTIU (funct3=011)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b011; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM SLTIU", ALU_SLTU);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: XORI (funct3=100)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b100; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM XORI", ALU_XOR);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: ORI (funct3=110)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b110; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM ORI", ALU_OR);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: ANDI (funct3=111)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b111; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM ANDI", ALU_AND);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: SLLI (funct3=001)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b001; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM SLLI", ALU_SLL);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: SRLI (funct3=101, funct7=0000000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b101; funct7_i = 7'b0000000;
        check_alu_sel("ALU_IMM SRLI", ALU_SRL);

        // -----------------------------------------------------
        // TYPE_ALU_IMM: SRAI (funct3=101, funct7=0100000)
        // -----------------------------------------------------
        instr_type_i = TYPE_ALU_IMM; funct3_i = 3'b101; funct7_i = 7'b0100000;
        check_alu_sel("ALU_IMM SRAI", ALU_SRA);

        // -----------------------------------------------------
        // Address-calculation types: LOAD, STORE, BRANCH, JAL,
        // JALR, AUIPC must all select ADD
        // -----------------------------------------------------
        instr_type_i = TYPE_LOAD;   check_alu_sel("LOAD addr calc",   ALU_ADD);
        instr_type_i = TYPE_STORE;  check_alu_sel("STORE addr calc",  ALU_ADD);
        instr_type_i = TYPE_BRANCH; check_alu_sel("BRANCH addr calc", ALU_ADD);
        instr_type_i = TYPE_JAL;    check_alu_sel("JAL addr calc",    ALU_ADD);
        instr_type_i = TYPE_JALR;   check_alu_sel("JALR addr calc",   ALU_ADD);
        instr_type_i = TYPE_AUIPC;  check_alu_sel("AUIPC addr calc",  ALU_ADD);

        // -----------------------------------------------------
        // TYPE_LUI: must select PASS_B so the immediate passes
        // straight through the ALU to the destination register
        // -----------------------------------------------------
        instr_type_i = TYPE_LUI;
        check_alu_sel("LUI pass-through", ALU_PASS_B);

        // -----------------------------------------------------
        // TYPE_MULT: mult_sel_o mapping (MUL/MULH/MULHSU/MULHU)
        // -----------------------------------------------------
        instr_type_i = TYPE_MULT; funct3_i = 3'b000;
        check_mult_sel("MULT: MUL",    4'h0);
        instr_type_i = TYPE_MULT; funct3_i = 3'b001;
        check_mult_sel("MULT: MULH",   4'h1);
        instr_type_i = TYPE_MULT; funct3_i = 3'b010;
        check_mult_sel("MULT: MULHSU", 4'h2);
        instr_type_i = TYPE_MULT; funct3_i = 3'b011;
        check_mult_sel("MULT: MULHU",  4'h3);

        // -----------------------------------------------------
        // TYPE_CRC: crc_sel_o mapping (CRCB/CRCH/CRCW)
        // -----------------------------------------------------
        instr_type_i = TYPE_CRC; funct3_i = 3'b000;
        check_crc_sel("CRC: CRCB", 4'h0);
        instr_type_i = TYPE_CRC; funct3_i = 3'b001;
        check_crc_sel("CRC: CRCH", 4'h1);
        instr_type_i = TYPE_CRC; funct3_i = 3'b010;
        check_crc_sel("CRC: CRCW", 4'h2);

        // -----------------------------------------------------
        // FINAL RESULT
        // -----------------------------------------------------
        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("OPERATION_DECODER TESTBENCH: PASS");
            $display("All opcode mappings match RISCV_ALU_4bit.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("OPERATION_DECODER TESTBENCH: FAIL");
            $display("Number of errors = %0d", errors);
            $display("Root cause: alu_sel_o encoding in operation_decoder");
            $display("does not match the c_ALU_OP_* macros actually used");
            $display("by RISCV_ALU_4bit in Datapath_modules.v. Every code");
            $display("is offset by +1 relative to what the ALU expects,");
            $display("except ADD (accidentally lands on ALU's default");
            $display("case) and PASS_B (decoder sends 4'h0, which the ALU");
            $display("also has no case for, so LUI silently becomes ADD).");
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
