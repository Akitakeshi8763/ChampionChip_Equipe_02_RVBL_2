module testbench();

    reg [6:0] opcode_i;
    reg [2:0] funct3_i;
    reg [6:0] funct7_i;
    wire [3:0] instr_type_o;

    integer errors;

    // Mirrored TYPE encodings from Control_unit.v
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
    localparam TYPE_INVALID = 4'b1111;

    opcode_decoder dut (
        .opcode_i(opcode_i),
        .funct3_i(funct3_i),
        .funct7_i(funct7_i),
        .instr_type_o(instr_type_o)
    );

    task check;
        input [8*32-1:0] label;
        input [3:0] expected;
        begin
            #1;
            if (instr_type_o !== expected) begin
                $display("FAIL: %0s expected=%b got=%b", label, expected, instr_type_o);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s -> instr_type_o=%b", label, instr_type_o);
            end
        end
    endtask

    initial begin
        errors = 0;
        funct3_i = 3'b000;

        // -----------------------------------------------------
        // R-type ALU (opcode 0110011), plain funct7 -> ALU_REG
        // -----------------------------------------------------
        opcode_i = 7'b0110011; funct7_i = 7'b0000000;
        check("R-type plain -> ALU_REG", TYPE_ALU_REG);

        // -----------------------------------------------------
        // R-type with funct7=0000001 -> MULT (Zmmul extension)
        // -----------------------------------------------------
        opcode_i = 7'b0110011; funct7_i = 7'b0000001;
        check("R-type funct7=0000001 -> MULT", TYPE_MULT);

        // -----------------------------------------------------
        // R-type with funct7=1000000 -> CRC (Xicrc extension)
        // -----------------------------------------------------
        opcode_i = 7'b0110011; funct7_i = 7'b1000000;
        check("R-type funct7=1000000 -> CRC", TYPE_CRC);

        // -----------------------------------------------------
        // R-type with SUB's funct7 (0100000) -> still ALU_REG,
        // NOT mistaken for MULT/CRC (this is a real risk since
        // 0100000 sits between the other special funct7 values)
        // -----------------------------------------------------
        opcode_i = 7'b0110011; funct7_i = 7'b0100000;
        check("R-type funct7=0100000 (SUB) -> ALU_REG", TYPE_ALU_REG);

        // -----------------------------------------------------
        // I-type ALU immediate
        // -----------------------------------------------------
        opcode_i = 7'b0010011; funct7_i = 7'b0000000;
        check("ALU_IMM opcode", TYPE_ALU_IMM);

        // -----------------------------------------------------
        // Load
        // -----------------------------------------------------
        opcode_i = 7'b0000011; funct7_i = 7'b0000000;
        check("LOAD opcode", TYPE_LOAD);

        // -----------------------------------------------------
        // Store
        // -----------------------------------------------------
        opcode_i = 7'b0100011; funct7_i = 7'b0000000;
        check("STORE opcode", TYPE_STORE);

        // -----------------------------------------------------
        // Branch
        // -----------------------------------------------------
        opcode_i = 7'b1100011; funct7_i = 7'b0000000;
        check("BRANCH opcode", TYPE_BRANCH);

        // -----------------------------------------------------
        // JAL
        // -----------------------------------------------------
        opcode_i = 7'b1101111; funct7_i = 7'b0000000;
        check("JAL opcode", TYPE_JAL);

        // -----------------------------------------------------
        // JALR
        // -----------------------------------------------------
        opcode_i = 7'b1100111; funct7_i = 7'b0000000;
        check("JALR opcode", TYPE_JALR);

        // -----------------------------------------------------
        // LUI
        // -----------------------------------------------------
        opcode_i = 7'b0110111; funct7_i = 7'b0000000;
        check("LUI opcode", TYPE_LUI);

        // -----------------------------------------------------
        // AUIPC
        // -----------------------------------------------------
        opcode_i = 7'b0010111; funct7_i = 7'b0000000;
        check("AUIPC opcode", TYPE_AUIPC);

        // -----------------------------------------------------
        // SYSTEM (ECALL/EBREAK)
        // -----------------------------------------------------
        opcode_i = 7'b1110011; funct7_i = 7'b0000000;
        check("SYSTEM opcode", TYPE_SYSTEM);

        // -----------------------------------------------------
        // FENCE -- guide/RTL currently maps this to the SAME
        // type code as SYSTEM (4'b1001). Flagging this as a
        // DESIGN NOTE rather than a bug: FENCE and
        // ECALL/EBREAK are semantically different instructions
        // that will now be handled identically by the FSM
        // (both go to EXEC_SYSTEM). This may be intentional
        // (e.g. both treated as no-ops), but confirm intent.
        // -----------------------------------------------------
        opcode_i = 7'b0001111; funct7_i = 7'b0000000;
        check("FENCE opcode -> currently == SYSTEM type", TYPE_SYSTEM);

        // -----------------------------------------------------
        // Undefined/reserved opcode -> INVALID (default case)
        // -----------------------------------------------------
        opcode_i = 7'b1111111; funct7_i = 7'b0000000;
        check("Undefined opcode -> INVALID", TYPE_INVALID);

        opcode_i = 7'b0000000; funct7_i = 7'b0000000;
        check("Opcode=0 (all-zero instr) -> INVALID", TYPE_INVALID);

        // -----------------------------------------------------
        // FINAL RESULT
        // -----------------------------------------------------
        #10;
        if (errors == 0) begin
            $display("========================================");
            $display("OPCODE_DECODER TESTBENCH: PASS");
            $display("All opcode classifications correct.");
            $display("NOTE: FENCE and SYSTEM currently share the");
            $display("same instr_type_o encoding -- confirm this");
            $display("is intentional with the design team.");
            $display("========================================");
        end
        else begin
            $display("========================================");
            $display("OPCODE_DECODER TESTBENCH: FAIL");
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
