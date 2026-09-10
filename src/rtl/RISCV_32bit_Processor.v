

//  ---------- INLCUDED BLOCK: MUX2_32  ---------- 
module MUX2_32 (
  input [31:0] A, 
  input [31:0] B, 
  input S, 
  output [31:0] Z
);
  assign Z = (S) ? B : A;
endmodule



//  ---------- INLCUDED BLOCK: REGISTER_FILE  ---------- 
module REGISTER_FILE # (
    parameter p_DATA_MEM_SIZE = 2**10
)(
    input [31:0] i_Data_Rd,
    input [31:0] i_Instruction,
    input i_Write_Enable,
    input i_Clk,
    input i_Rst,
    output [31:0] o_Data_Rs_1,
    output [31:0] o_Data_Rs_2  
);
    /* Constants */
    localparam c_SP_INDEX = 2;
    localparam c_GP_INDEX = 3;
    localparam c_GP_INITIAL_VALUE = 32'h1001_0000;
    localparam c_SP_INITIAL_VALUE = c_GP_INITIAL_VALUE + p_DATA_MEM_SIZE - 4;

    /* Instruction fields */
    wire [4:0] w_Select_Rd = i_Instruction[11:7];
    wire [4:0] w_Select_Rs_1 = i_Instruction[19:15];
    wire [4:0] w_Select_Rs_2 = i_Instruction[24:20];
  
    /* Registers Data */
    reg [31:0] r_Registers [0:31];
  
    integer i;
    always @(posedge i_Clk or posedge i_Rst) begin
        if(i_Rst) begin
            for(i = 0; i < 32; i = i + 1) begin
                case (i)
                    c_SP_INDEX: r_Registers[i] = c_SP_INITIAL_VALUE;
                    c_GP_INDEX: r_Registers[i] = c_GP_INITIAL_VALUE;
                    default:    r_Registers[i] = 32'h0;
                endcase
            end
        end
        else begin 
            if(i_Write_Enable && w_Select_Rd != 5'h0) begin
                r_Registers[w_Select_Rd] = i_Data_Rd;
            end
        end
    end
    
    assign o_Data_Rs_1 = r_Registers[w_Select_Rs_1];

    assign o_Data_Rs_2 = r_Registers[w_Select_Rs_2];

endmodule



//  ---------- INLCUDED BLOCK: instruction_register  ---------- 
module instruction_register (
    input wire clk,
    input wire reset,
  	input wire write_enable,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_out <= 32'b0;
    end else if (write_enable) begin
        data_out <= data_in;
    end
end

endmodule



//  ---------- INLCUDED BLOCK: memorydata_register  ---------- 
module memorydata_register (
    input wire clk,
    input wire reset,
  	input wire write_enable,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_out <= 32'b0;
    end else if (write_enable) begin
        data_out <= data_in;
    end
end

endmodule



//  ---------- INLCUDED BLOCK: A_register  ---------- 
module A_register (
    input wire clk,
    input wire reset,
  	input wire write_enable,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_out <= 32'b0;
    end else if (write_enable) begin
        data_out <= data_in;
    end
end

endmodule



//  ---------- INLCUDED BLOCK: B_register  ---------- 
module B_register (
    input wire clk,
    input wire reset,
  	input wire write_enable,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_out <= 32'b0;
    end else if (write_enable) begin
        data_out <= data_in;
    end
end

endmodule



//  ---------- INLCUDED BLOCK: ALU_Out_Register  ---------- 
module ALU_Out_Register (
    input wire clk,
    input wire reset,
  	input wire write_enable,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_out <= 32'b0;
    end else if (write_enable) begin
        data_out <= data_in;
    end
end

endmodule



//  ---------- INLCUDED BLOCK: RISCV_Multiplier  ---------- 
module RISCV_Multiplier (
    input wire i_Clk,
    input wire i_Rst,
    input wire i_Mul_Start,
    input wire [31:0] i_Instruction,
    input wire [31:0] i_Multiplier,    // rs1
    input wire [31:0] i_Multiplicand,  // rs2
    output wire [31:0] o_Result,
    output wire o_Done
);

    wire [2:0] i_Funct3 = i_Instruction[14:12];

    /* Opcodes for Funct3 */
    localparam F3_MUL    = 3'b000;
    localparam F3_MULH   = 3'b001;
    localparam F3_MULHSU = 3'b010;
    localparam F3_MULHU  = 3'b011;

    /* FSM States */
    localparam STATE_IDLE   = 2'b00;
    localparam STATE_MULT   = 2'b01;
    localparam STATE_ADJUST = 2'b10;
    localparam STATE_DONE   = 2'b11;

    /* Internal Registers */
    reg [1:0]  state;
    reg [4:0]  count;        // 5-bit counter (0 to 31)
    reg [63:0] prod_reg;     // Holds the 64-bit product and the shifting multiplier
    reg [31:0] m_reg;        // Holds the Multiplicand
    reg        result_sign;  // Tracks if the final product needs to be negative
    reg [2:0]  funct3_reg;   // Stores the instruction type

    /* 
     * Combinational Logic for Absolute Values 
     * Determines if inputs should be treated as signed based on Funct3
     */
    wire rs1_is_signed = (i_Funct3 == F3_MULH) || (i_Funct3 == F3_MULHSU);
    wire rs2_is_signed = (i_Funct3 == F3_MULH);

    // Extract the sign bit (bit 31) only if the instruction treats it as signed
    wire sign_rs1 = rs1_is_signed & i_Multiplier[31];
    wire sign_rs2 = rs2_is_signed & i_Multiplicand[31];

    // Convert to two's complement if negative, otherwise keep as is
    wire [31:0] abs_rs1 = sign_rs1 ? (~i_Multiplier + 1'b1) : i_Multiplier;
    wire [31:0] abs_rs2 = sign_rs2 ? (~i_Multiplicand + 1'b1) : i_Multiplicand;

    /* 
     * Combinational Logic for Shift-and-Add 
     * Uses a single 32-bit adder to save hardware space
     */
    wire [31:0] add_mux = prod_reg[0] ? m_reg : 32'd0;
    wire [32:0] adder_out = prod_reg[63:32] + add_mux;

    /* Multiplier FSM */
    always @(posedge i_Clk or posedge i_Rst) begin
        if (i_Rst) begin
            state       <= STATE_IDLE;
            count       <= 5'd0;
            prod_reg    <= 64'd0;
            m_reg       <= 32'd0;
            result_sign <= 1'b0;
            funct3_reg  <= 3'd0;
        end else begin
            case (state)
                STATE_IDLE: begin
                  if (i_Mul_Start) begin
                        // Load absolute values into registers
                        prod_reg    <= {32'd0, abs_rs1};
                        m_reg       <= abs_rs2;
                        // Calculate final sign (XOR the initial signs)
                        result_sign <= sign_rs1 ^ sign_rs2;
                        funct3_reg  <= i_Funct3;
                        count       <= 5'd0;
                        state       <= STATE_MULT;
                    end
                end
                
                STATE_MULT: begin
                    // Perform Add and Shift in one cycle
                    prod_reg <= {adder_out, prod_reg[31:1]};
                    count    <= count + 1'b1;
                    
                    // After 32 shifts, calculation is complete
                    if (count == 5'd31) begin
                        state <= STATE_ADJUST;
                    end
                end
                
                STATE_ADJUST: begin
                    // Apply two's complement to the 64-bit result if it should be negative
                    if (result_sign) begin
                        prod_reg <= ~prod_reg + 1'b1;
                    end
                    state <= STATE_DONE;
                end
                
                STATE_DONE: begin
                    // Return to IDLE automatically after pulsing o_Done for 1 cycle
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    /* Output Assignments */
    assign o_Done = (state == STATE_DONE);
    
    // Multiplex the upper or lower 32 bits based on the instruction
    assign o_Result = (funct3_reg == F3_MUL) ? prod_reg[31:0] : prod_reg[63:32];

endmodule



//  ---------- INLCUDED BLOCK: instruction_decoder  ---------- 
module instruction_decoder (
    instruction_i,
    opcode_o,
    funct3_o,
    funct7_o,
);

input wire [31:0] instruction_i;

output wire [6:0] opcode_o;
output wire [2:0] funct3_o;
output wire [6:0] funct7_o;

assign opcode_o = instruction_i[6:0];
assign funct3_o = instruction_i[14:12];
assign funct7_o = instruction_i[31:25];
  
endmodule



//  ---------- INLCUDED BLOCK: opcode_decoder  ---------- 
module opcode_decoder (
    opcode_i,
    funct3_i,
    funct7_i,
    instr_type_o
);

input wire [6:0] opcode_i;
input wire [2:0] funct3_i;
input wire [6:0] funct7_i;

output reg [3:0] instr_type_o;

always @(*) begin
    case (opcode_i)

        7'b0110011: begin
            if (funct7_i == 7'b0000001)
                instr_type_o = 4'b1010; // MULT
            else if (funct7_i == 7'b1000000)
                instr_type_o = 4'b1011; // CRC
            else
                instr_type_o = 4'b0000; // ALU register
        end

        7'b0010011:
            instr_type_o = 4'b0001; // ALU immediate

        7'b0000011:
            instr_type_o = 4'b0010; // LOAD

        7'b0100011:
            instr_type_o = 4'b0011; // STORE

        7'b1100011:
            instr_type_o = 4'b0100; // BRANCH

        7'b1101111:
            instr_type_o = 4'b0101; // JAL

        7'b1100111:
            instr_type_o = 4'b0110; // JALR

        7'b0110111:
            instr_type_o = 4'b0111; // LUI

        7'b0010111:
            instr_type_o = 4'b1000; // AUIPC

        7'b1110011:
            instr_type_o = 4'b1001; // SYSTEM
      
        7'b0001111:
            instr_type_o = 4'b1001; // FENCE / synchronization

        default:
            instr_type_o = 4'b1111; // INVALID

    endcase
end

endmodule



//  ---------- INLCUDED BLOCK: operation_decoder  ---------- 
module operation_decoder (
    instr_type_i,
    funct3_i,
    funct7_i,
    alu_sel_o,
    mult_sel_o,
    crc_sel_o
);

input wire [3:0] instr_type_i;
input wire [2:0] funct3_i;
input wire [6:0] funct7_i;

output reg [3:0] alu_sel_o;
output reg [3:0] mult_sel_o;
output reg [3:0] crc_sel_o;


/* INSTRUCTION TYPES */
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


always @(*) begin

    alu_sel_o  = 4'h0;
    mult_sel_o = 4'h0;
    crc_sel_o  = 4'h0;

    case (instr_type_i)

        /* REGISTER ALU */
        TYPE_ALU_REG: begin
            case (funct3_i)

                3'b000:
                    if (funct7_i == 7'b0100000)
                        alu_sel_o = 4'h2;   // SUB
                    else
                        alu_sel_o = 4'h1;   // ADD

                3'b001: alu_sel_o = 4'h6;  // SLL
                3'b010: alu_sel_o = 4'h9;  // SLT
                3'b011: alu_sel_o = 4'hA;  // SLTU
                3'b100: alu_sel_o = 4'h5;  // XOR

                3'b101:
                    if (funct7_i == 7'b0100000)
                        alu_sel_o = 4'h8;   // SRA
                    else
                        alu_sel_o = 4'h7;   // SRL

                3'b110: alu_sel_o = 4'h4;  // OR
                3'b111: alu_sel_o = 4'h3;  // AND

                default: alu_sel_o = 4'h0;

            endcase
        end


        /* IMMEDIATE ALU */
        TYPE_ALU_IMM: begin
            case (funct3_i)

                3'b000: alu_sel_o = 4'h1;  // ADDI
                3'b010: alu_sel_o = 4'h9;  // SLTI
                3'b011: alu_sel_o = 4'hA;  // SLTIU
                3'b100: alu_sel_o = 4'h5;  // XORI
                3'b110: alu_sel_o = 4'h4;  // ORI
                3'b111: alu_sel_o = 4'h3;  // ANDI
                3'b001: alu_sel_o = 4'h6;  // SLLI

                3'b101:
                    if (funct7_i == 7'b0100000)
                        alu_sel_o = 4'h8;   // SRAI
                    else
                        alu_sel_o = 4'h7;   // SRLI

                default: alu_sel_o = 4'h0;

            endcase
        end


        /* ADDRESS / TARGET CALCULATIONS */
        TYPE_LOAD,
        TYPE_STORE,
        TYPE_BRANCH,
        TYPE_JAL,
        TYPE_JALR,
        TYPE_AUIPC:
            alu_sel_o = 4'h1;              // ADD


        /* LUI: pass immediate through ALU */
        TYPE_LUI:
            alu_sel_o = 4'h0;              // PASS_B


        /* MULTIPLICATION */
        TYPE_MULT: begin
            case (funct3_i)
                3'b000: mult_sel_o = 4'h0; // MUL
                3'b001: mult_sel_o = 4'h1; // MULH
                3'b010: mult_sel_o = 4'h2; // MULHSU
                3'b011: mult_sel_o = 4'h3; // MULHU
                default: mult_sel_o = 4'h0;
            endcase
        end


        /* CRC */
        TYPE_CRC: begin
            case (funct3_i)
                3'b000: crc_sel_o = 4'h0;  // CRCB
                3'b001: crc_sel_o = 4'h1;  // CRCH
                3'b010: crc_sel_o = 4'h2;  // CRCW
                default: crc_sel_o = 4'h0;
            endcase
        end

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: control_fsm  ---------- 
module control_fsm (
    clk_i,
    rst_i,
    instr_type_i,
    mult_done_i,
    current_state_o
);

input wire clk_i;
input wire rst_i;
input wire mult_done_i;
input wire [3:0] instr_type_i;

output reg [3:0] current_state_o;

reg [3:0] next_state;


/* STATES */
localparam FETCH       = 4'b0000;
localparam DECODE      = 4'b0001;
localparam EXEC_ALU    = 4'b0010;
localparam WRITEBACK   = 4'b0011;
localparam EXEC_LOAD   = 4'b0100;
localparam MEM_LOAD    = 4'b0101;
localparam EXEC_STORE  = 4'b0110;
localparam MEM_STORE   = 4'b0111;
localparam EXEC_BRANCH = 4'b1000;
localparam EXEC_JUMP   = 4'b1001;
localparam EXEC_MULT   = 4'b1010;
localparam EXEC_CRC    = 4'b1011;
localparam EXEC_SYSTEM = 4'b1100;
localparam LOAD_CAPTURE = 4'b1101;

/* INSTRUCTION TYPES */
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


/* STATE REGISTER */
always @(posedge clk_i or posedge rst_i) begin
    if (rst_i)
        current_state_o <= FETCH;
    else
        current_state_o <= next_state;
end


/* NEXT-STATE LOGIC */
always @(*) begin

    case (current_state_o)

        FETCH:
            next_state = DECODE;

        DECODE: begin
            case (instr_type_i)

                TYPE_ALU_REG,
                TYPE_ALU_IMM,
                TYPE_LUI,
                TYPE_AUIPC:
                    next_state = EXEC_ALU;

                TYPE_LOAD:
                    next_state = EXEC_LOAD;

                TYPE_STORE:
                    next_state = EXEC_STORE;

                TYPE_BRANCH:
                    next_state = EXEC_BRANCH;

                TYPE_JAL,
                TYPE_JALR:
                    next_state = EXEC_JUMP;

                TYPE_MULT:
                    next_state = EXEC_MULT;

                TYPE_CRC:
                    next_state = EXEC_CRC;
              
                TYPE_SYSTEM:
                    next_state = EXEC_SYSTEM;

                default:
                    next_state = FETCH;

            endcase
        end

        EXEC_ALU:
            next_state = WRITEBACK;

        EXEC_MULT: begin
            if (mult_done_i)
                next_state = WRITEBACK;
            else
                next_state = EXEC_MULT;
        end
      
        EXEC_CRC:
            next_state = WRITEBACK;

        EXEC_LOAD:
            next_state = MEM_LOAD;

        MEM_LOAD:
            next_state = LOAD_CAPTURE;

        LOAD_CAPTURE:
            next_state = WRITEBACK;

        EXEC_STORE:
            next_state = MEM_STORE;

        MEM_STORE:
            next_state = FETCH;

        EXEC_BRANCH:
            next_state = FETCH;

        EXEC_JUMP:
            next_state = WRITEBACK;

        WRITEBACK:
            next_state = FETCH;
      
        EXEC_SYSTEM:
            next_state = FETCH;

        default:
            next_state = FETCH;

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: control_outputs  ---------- 
module control_outputs (
    current_state_i,
    ir_write_o,
    reg_write_o,
    oe_o,
    we_o,
    mult_start_o,
    load_en_o,
    store_en_o
);

input wire [3:0] current_state_i;

output reg ir_write_o;
output reg reg_write_o;
output reg oe_o;
output reg we_o;
output reg mult_start_o;
output reg load_en_o;
output reg store_en_o;


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


always @(*) begin

    ir_write_o   = 1'b0;
    reg_write_o  = 1'b0;
    oe_o         = 1'b0;
    we_o         = 1'b0;
    mult_start_o = 1'b0;
    load_en_o    = 1'b0;
    store_en_o   = 1'b0;

    case (current_state_i)

        FETCH: begin
            oe_o       = 1'b1;
            ir_write_o = 1'b1;
        end

        MEM_LOAD: begin
            oe_o      = 1'b1;
            load_en_o = 1'b1;
        end

        LOAD_CAPTURE: begin
            oe_o      = 1'b1;
            load_en_o = 1'b1;
        end

        MEM_STORE: begin
            we_o       = 1'b1;
            store_en_o = 1'b1;
        end

        EXEC_MULT: begin
            mult_start_o = 1'b1;
        end

        WRITEBACK: begin
            reg_write_o = 1'b1;
        end

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: alu_source_control  ---------- 
module alu_source_control (
    instr_type_i,
    alu_src_a_o,
    alu_src_b_o
);

input wire [3:0] instr_type_i;

output reg alu_src_a_o;
output reg alu_src_b_o;


/*
alu_src_a_o:
0 = rs1
1 = PC

alu_src_b_o:
0 = rs2
1 = immediate
*/


/* INSTRUCTION TYPES */
localparam TYPE_ALU_REG = 4'b0000;
localparam TYPE_ALU_IMM = 4'b0001;
localparam TYPE_LOAD    = 4'b0010;
localparam TYPE_STORE   = 4'b0011;
localparam TYPE_BRANCH  = 4'b0100;
localparam TYPE_JAL     = 4'b0101;
localparam TYPE_JALR    = 4'b0110;
localparam TYPE_LUI     = 4'b0111;
localparam TYPE_AUIPC   = 4'b1000;


always @(*) begin

    /* Default: rs1 and rs2 */
    alu_src_a_o = 1'b0;
    alu_src_b_o = 1'b0;

    case (instr_type_i)

        /* rs1 + rs2 */
        TYPE_ALU_REG: begin
            alu_src_a_o = 1'b0;
            alu_src_b_o = 1'b0;
        end


        /* rs1 + immediate */
        TYPE_ALU_IMM,
        TYPE_LOAD,
        TYPE_STORE,
        TYPE_JALR: begin
            alu_src_a_o = 1'b0;
            alu_src_b_o = 1'b1;
        end


        /* PC + immediate */
        TYPE_BRANCH,
        TYPE_JAL,
        TYPE_AUIPC: begin
            alu_src_a_o = 1'b1;
            alu_src_b_o = 1'b1;
        end


        /* LUI only needs the immediate on B */
        TYPE_LUI: begin
            alu_src_a_o = 1'b0;
            alu_src_b_o = 1'b1;
        end

        default: begin
            alu_src_a_o = 1'b0;
            alu_src_b_o = 1'b0;
        end

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: writeback_control  ---------- 
module writeback_control (
    instr_type_i,
    wb_sel_o
);

input wire [3:0] instr_type_i;

output reg [2:0] wb_sel_o;


/*
wb_sel_o:

000 = ALU result
001 = LSU / load data
010 = MULT result
011 = CRC result
100 = jump return address (PC + 4)
*/


localparam TYPE_ALU_REG = 4'b0000;
localparam TYPE_ALU_IMM = 4'b0001;
localparam TYPE_LOAD    = 4'b0010;
localparam TYPE_JAL     = 4'b0101;
localparam TYPE_JALR    = 4'b0110;
localparam TYPE_LUI     = 4'b0111;
localparam TYPE_AUIPC   = 4'b1000;
localparam TYPE_MULT    = 4'b1010;
localparam TYPE_CRC     = 4'b1011;


always @(*) begin

    /* Default = ALU result */
    wb_sel_o = 3'b000;

    case (instr_type_i)

        TYPE_ALU_REG,
        TYPE_ALU_IMM,
        TYPE_LUI,
        TYPE_AUIPC:
            wb_sel_o = 3'b000;   // ALU

        TYPE_LOAD:
            wb_sel_o = 3'b001;   // LSU / memory data

        TYPE_MULT:
            wb_sel_o = 3'b010;   // multiplier

        TYPE_CRC:
            wb_sel_o = 3'b011;   // CRC

        TYPE_JAL,
        TYPE_JALR:
            wb_sel_o = 3'b100;   // return address PC+4

        default:
            wb_sel_o = 3'b000;

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: lsu_control  ---------- 
module lsu_control (
    instr_type_i,
    funct3_i,
    lsu_op_o,
    lsu_valid_o
);

input wire [3:0] instr_type_i;
input wire [2:0] funct3_i;

output reg [2:0] lsu_op_o;
output reg lsu_valid_o;


/* INSTRUCTION TYPES */
localparam TYPE_LOAD  = 4'b0010;
localparam TYPE_STORE = 4'b0011;


always @(*) begin

    lsu_op_o    = 3'b000;
    lsu_valid_o = 1'b0;

    case (instr_type_i)

        TYPE_LOAD: begin
            lsu_op_o    = funct3_i;
            lsu_valid_o = 1'b1;
        end

        TYPE_STORE: begin
            lsu_op_o    = funct3_i;
            lsu_valid_o = 1'b1;
        end

        default: begin
            lsu_op_o    = 3'b000;
            lsu_valid_o = 1'b0;
        end

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: branch_control  ---------- 
module branch_control (
    instr_type_i,
    funct3_i,
    branch_sel_o,
    branch_valid_o
);

input wire [3:0] instr_type_i;
input wire [2:0] funct3_i;

output reg [2:0] branch_sel_o;
output reg branch_valid_o;

localparam TYPE_BRANCH = 4'b0100;

always @(*) begin

    branch_sel_o   = 3'b000;
    branch_valid_o = 1'b0;

    if (instr_type_i == TYPE_BRANCH) begin
        branch_sel_o   = funct3_i;
        branch_valid_o = 1'b1;
    end

end

endmodule



//  ---------- INLCUDED BLOCK: system_control  ---------- 
module system_control (
    instruction_i,
    system_op_o,
    system_valid_o
);

input wire [31:0] instruction_i;

output reg [1:0] system_op_o;
output reg system_valid_o;


/*
system_op_o:

00 = FENCE
01 = ECALL
10 = EBREAK
11 = invalid / unused
*/


always @(*) begin

    system_op_o    = 2'b11;
    system_valid_o = 1'b0;

    /* FENCE */
    if ((instruction_i[6:0] == 7'b0001111) &&
        (instruction_i[14:12] == 3'b000)) begin

        system_op_o    = 2'b00;
        system_valid_o = 1'b1;
    end

    /* ECALL */
    else if (instruction_i == 32'h00000073) begin

        system_op_o    = 2'b01;
        system_valid_o = 1'b1;
    end

    /* EBREAK */
    else if (instruction_i == 32'h00100073) begin

        system_op_o    = 2'b10;
        system_valid_o = 1'b1;
    end

end

endmodule



//  ---------- INLCUDED BLOCK: pc_control_v2  ---------- 
module pc_control_v2 (
    current_state_i,
    branch_taken_i,
    pc_write_o,
    pc_sel_o
);

input wire [3:0] current_state_i;
input wire branch_taken_i;

output reg pc_write_o;
output reg pc_sel_o;

localparam FETCH       = 4'b0000;
localparam EXEC_BRANCH = 4'b1000;
localparam EXEC_JUMP   = 4'b1001;

always @(*) begin

    pc_write_o = 1'b0;
    pc_sel_o   = 1'b0;

    case (current_state_i)

        FETCH: begin
            pc_write_o = 1'b1;
            pc_sel_o   = 1'b0;
        end

        EXEC_BRANCH: begin
            if (branch_taken_i) begin
                pc_write_o = 1'b1;
                pc_sel_o   = 1'b1;
            end
        end

        EXEC_JUMP: begin
            pc_write_o = 1'b1;
            pc_sel_o   = 1'b1;
        end

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: register_enable_control  ---------- 
module register_enable_control (
    current_state_i,
    a_write_o,
    b_write_o,
    aluout_write_o,
    mdr_write_o
);

input wire [3:0] current_state_i;

output reg a_write_o;
output reg b_write_o;
output reg aluout_write_o;
output reg mdr_write_o;


localparam FETCH       = 4'b0000;
localparam DECODE      = 4'b0001;
localparam EXEC_ALU    = 4'b0010;
localparam WRITEBACK   = 4'b0011;
localparam EXEC_LOAD   = 4'b0100;
localparam MEM_LOAD    = 4'b0101;
localparam EXEC_STORE  = 4'b0110;
localparam MEM_STORE   = 4'b0111;
localparam EXEC_BRANCH = 4'b1000;
localparam EXEC_JUMP   = 4'b1001;
localparam EXEC_MULT   = 4'b1010;
localparam EXEC_CRC    = 4'b1011;
localparam EXEC_SYSTEM = 4'b1100;
localparam LOAD_CAPTURE = 4'b1101;

always @(*) begin

    a_write_o      = 1'b0;
    b_write_o      = 1'b0;
    aluout_write_o = 1'b0;
    mdr_write_o    = 1'b0;

    case (current_state_i)

        DECODE: begin
            a_write_o = 1'b1;
            b_write_o = 1'b1;
        end

        EXEC_ALU: begin
            aluout_write_o = 1'b1;
        end

        EXEC_LOAD: begin
            aluout_write_o = 1'b1;
        end

        EXEC_STORE: begin
            aluout_write_o = 1'b1;
        end

        LOAD_CAPTURE: begin
            mdr_write_o = 1'b1;
        end

    endcase

end

endmodule



//  ---------- INLCUDED BLOCK: RISCV_ALU_4bit  ---------- 
/* ALU Operations */
`define c_ALU_OP_ADD    4'b0000
`define c_ALU_OP_SUB    4'b0001
`define c_ALU_OP_AND    4'b0010
`define c_ALU_OP_OR     4'b0011
`define c_ALU_OP_XOR    4'b0100
`define c_ALU_OP_SLL    4'b0101
`define c_ALU_OP_SRL    4'b0110
`define c_ALU_OP_SRA    4'b0111
`define c_ALU_OP_SLT    4'b1000
`define c_ALU_OP_SLTU   4'b1001
`define c_ALU_OP_PASS_B 4'b1010

module RISCV_ALU_4bit (
    input [31:0] i_Register_Rs_1,
    input [31:0] i_Register_Rs_2,
    input [31:0] i_PC_Output,
    input [31:0] i_Immediate,
    input [3:0] i_ALU_Op,        // Expanded from 3 bits to 4 bits
    input i_A_Sel,
    input i_B_Sel,
    output reg signed [31:0] o_Q
);
    wire signed [31:0] w_A_Mux;
    wire signed [31:0] w_B_Mux;

    assign w_A_Mux = (i_A_Sel) ? i_PC_Output : i_Register_Rs_1;
    assign w_B_Mux = (i_B_Sel) ? i_Immediate : i_Register_Rs_2; 

    always @ (*) begin
        case (i_ALU_Op)
            `c_ALU_OP_SUB:    o_Q = w_A_Mux - w_B_Mux;
            `c_ALU_OP_AND:    o_Q = w_A_Mux & w_B_Mux;
            `c_ALU_OP_OR:     o_Q = w_A_Mux | w_B_Mux;
            `c_ALU_OP_XOR:    o_Q = w_A_Mux ^ w_B_Mux;
            
            /* Shift Operations (use bottom 5 bits of B for 32-bit shifts) */
            `c_ALU_OP_SLL:    o_Q = w_A_Mux << w_B_Mux[4:0];
            
            /* $unsigned is required for SRL to prevent sign extension during shift */
            `c_ALU_OP_SRL:    o_Q = $unsigned(w_A_Mux) >> w_B_Mux[4:0];
            
            /* >>> performs arithmetic shift because w_A_Mux is declared as signed */
            `c_ALU_OP_SRA:    o_Q = w_A_Mux >>> w_B_Mux[4:0];
            
            /* Set Less Than Operations */
            `c_ALU_OP_SLT:    o_Q = (w_A_Mux < w_B_Mux) ? 32'd1 : 32'd0;
            
            /* $unsigned is required for SLTU to perform unsigned comparison */
            `c_ALU_OP_SLTU:   o_Q = ($unsigned(w_A_Mux) < $unsigned(w_B_Mux)) ? 32'd1 : 32'd0;
            
            /* Pass B Operation */
            `c_ALU_OP_PASS_B: o_Q = w_B_Mux;
            
            /* Default to ADD */
            default:          o_Q = w_A_Mux + w_B_Mux; 
        endcase
    end

endmodule



//  ---------- INLCUDED BLOCK: MUX8_32  ---------- 
module MUX8_32 (
  input [31:0] A, B, C, D, E, F, G, H,
  input [2:0] S,
  output reg [31:0] Z
);
  always @(*) begin
    case (S)
      3'b000: Z = A;
      3'b001: Z = B;
      3'b010: Z = C;
      3'b011: Z = D;
      3'b100: Z = E;
      3'b101: Z = F;
      3'b110: Z = G;
      3'b111: Z = H;
      default: Z = 32'b0; // Safety default
    endcase
  end
endmodule



//  ---------- INLCUDED BLOCK: RISCV_CRC  ---------- 
module RISCV_CRC (
    input wire i_Clk,
    input wire i_Rst,
    input wire i_Start,
    input wire [31:0] i_Register_Rs_1,
    input wire [31:0] i_Register_Rs_2,
    input wire [3:0] i_CRC_Sel,
    output reg [31:0] o_Result
);

    /* FSM Control Signal Encodings (from operation_decoder) */
    localparam c_OP_CRCB = 4'h0; // CRC8
    localparam c_OP_CRCH = 4'h1; // CRC16
    localparam c_OP_CRCW = 4'h2; // CRC32

    /* 
     * Placeholder signals for the actual combinatorial CRC calculation.
     * The provided documentation defines the routing but omits the 
     * specific polynomial generator (e.g., 0x04C11DB7 for CRC-32) 
     * and bit-reflection rules required to calculate the math.
     */
    wire [31:0] w_CRC8_Result;
    wire [31:0] w_CRC16_Result;
    wire [31:0] w_CRC32_Result;

    // Dummy assignments (Replace these lines with standard XOR tree logic)
    assign w_CRC8_Result  = (i_Register_Rs_1 ^ i_Register_Rs_2) & 32'h0000FFFF;
    assign w_CRC16_Result = (i_Register_Rs_1 ^ i_Register_Rs_2) & 32'h0000FFFF;
    assign w_CRC32_Result = (i_Register_Rs_1 ^ i_Register_Rs_2) & 32'h0000FFFF;

    /* Instruction Decoding Multiplexer */
    always @(*) begin
        case (i_CRC_Sel)
            c_OP_CRCB: o_Result = w_CRC8_Result;
            c_OP_CRCH: o_Result = w_CRC16_Result;
            c_OP_CRCW: o_Result = w_CRC32_Result;
            default:       o_Result = 32'd0;
        endcase
    end

endmodule



//  ---------- INLCUDED BLOCK: RISCV_IMM_GENERATOR_A  ---------- 
module RISCV_IMM_GENERATOR_A (
    input [31:0] i_Instruction,
    output reg [31:0] o_Immediate
);
    /* Instruction Opcodes */
    localparam c_OPCODE_JAL    = 7'b1101111;
    localparam c_OPCODE_BRANCH = 7'b1100011;
    localparam c_OPCODE_STORE  = 7'b0100011;
    localparam c_OPCODE_LUI    = 7'b0110111;
    localparam c_OPCODE_AUIPC  = 7'b0010111;

    wire [11:0] w_I_Type_Imm = i_Instruction[31:20];
    wire [11:0] w_S_Type_Imm = {i_Instruction[31:25], i_Instruction[11:7]};
    wire [12:0] w_B_Type_Imm = {i_Instruction[31], i_Instruction[7], i_Instruction[30:25], i_Instruction[11:8], 1'b0};
    wire [20:0] w_J_Type_Imm = {i_Instruction[31], i_Instruction[19:12], i_Instruction[20], i_Instruction[30:25], i_Instruction[24:21], 1'b0};
    wire [31:0] w_U_Type_Imm = {i_Instruction[31:12], 12'b0};
       
    always @ (*) begin
        case (i_Instruction[6:0])
            c_OPCODE_LUI, c_OPCODE_AUIPC:
                o_Immediate = w_U_Type_Imm;
            c_OPCODE_JAL: 
                o_Immediate = $signed(w_J_Type_Imm);
            c_OPCODE_BRANCH: 
                o_Immediate = $signed(w_B_Type_Imm);
            c_OPCODE_STORE: 
                o_Immediate = $signed(w_S_Type_Imm);
            default: 
                o_Immediate = $signed(w_I_Type_Imm);
        endcase
    end 

endmodule



//  ---------- INLCUDED BLOCK: RISCV_BRANCH_COMPARATOR_A  ---------- 
module RISCV_BRANCH_COMPARATOR_A (
    input signed [31:0] i_Reg_A,
    input signed [31:0] i_Reg_B,
    input [2:0] i_Branch_Sel,
    input i_Branch_Valid,
    output reg o_Branch_Taken
);   
    /* Branches */
    localparam c_BEQ  = 3'b000;
    localparam c_BNE  = 3'b001;
    localparam c_BLT  = 3'b100;
    localparam c_BGE  = 3'b101;
    localparam c_BLTU = 3'b110;
    localparam c_BGEU = 3'b111;
    
    wire w_Branch_Equal = (i_Reg_A == i_Reg_B);
    wire w_Branch_Less_Than_Signed = (i_Reg_A < i_Reg_B);
    
    /* Use $unsigned() to force Verilog to ignore the sign bit during comparison */
    wire w_Branch_Less_Than_Unsigned = ($unsigned(i_Reg_A) < $unsigned(i_Reg_B));

    always @ (*) begin
      if (!i_Branch_Valid) begin
            o_Branch_Taken = 1'b0;
      end else begin
          case (i_Branch_Sel)
              c_BEQ:  o_Branch_Taken = w_Branch_Equal;
              c_BNE:  o_Branch_Taken = !w_Branch_Equal;
              c_BLT:  o_Branch_Taken = w_Branch_Less_Than_Signed;
              c_BGE:  o_Branch_Taken = !w_Branch_Less_Than_Signed;
              c_BLTU: o_Branch_Taken = w_Branch_Less_Than_Unsigned;
              c_BGEU: o_Branch_Taken = !w_Branch_Less_Than_Unsigned;
              default: o_Branch_Taken = 1'b0;
          endcase
      end
    end

endmodule



//  ---------- INLCUDED BLOCK: PROGRAM_COUNTER_A  ---------- 
module PROGRAM_COUNTER_A (
    input [31:0] i_Data,
    input i_Clk,
    input i_Rst,
    input i_PC_write_enable,
    output [31:0] o_PC_Output, 
    output [31:0] o_PC_Plus_4
);
    localparam c_PC_INITIAL_VALUE = 32'h0040_0000;

    /* Program Counter (PC) */
    reg [31:0] r_PC_Output;

    always @(posedge i_Clk or posedge i_Rst) begin
        if(i_Rst) begin
            r_PC_Output <= c_PC_INITIAL_VALUE;
        end
      else if (i_PC_write_enable) begin
          	r_PC_Output <= i_Data;
        end
    end

    assign o_PC_Output = r_PC_Output;

    assign o_PC_Plus_4 = r_PC_Output + 4;
endmodule



//  ---------- INLCUDED BLOCK: old_PC_Register  ---------- 
module old_PC_Register (
    input wire clk,
    input wire reset,
  	input wire write_enable,
    input wire [31:0] data_in,
    output reg [31:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset) begin
        data_out <= 32'b0;
    end else if (write_enable) begin
        data_out <= data_in;
    end
end

endmodule



//  ---------- INLCUDED BLOCK: lsu  ---------- 
module lsu (
    // --------------------- Core Datapath side --------------------------------
    input  wire [31:0] core_data_o,     // store data from the Datapath (rs2 value)
    input  wire [31:0] core_address_o,  // effective address from the Datapath
    input  wire [2:0]  op_size_o,       // funct3 load/store operation selector
    
    // NEW: Explicit control signals required by the new overlapping encoding
    input  wire        load_en_i,       // 1 if load instruction
    input  wire        store_en_i,      // 1 if store instruction
    
    output reg  [31:0] core_data_i,     // load data returned to the Datapath

    // ------------------------ Memory side ------------------------------------
    output reg  [31:0] mem_data_i,      // write data sent toward memory
    output wire [31:0] mem_address_i,   // address forwarded toward memory
    output reg  [3:0]  byte_write_i,    // per-byte write enable
    input  wire [31:0] mem_data_o       // read data returned from memory
);

    // -------------------------------------------------------------------------
    // op_size_o encoding (Aligned with RV32I funct3)
    // -------------------------------------------------------------------------
    localparam [2:0] SIZE_B  = 3'b000; // LB / SB
    localparam [2:0] SIZE_H  = 3'b001; // LH / SH
    localparam [2:0] SIZE_W  = 3'b010; // LW / SW
    localparam [2:0] SIZE_BU = 3'b100; // LBU
    localparam [2:0] SIZE_HU = 3'b101; // LHU

    wire [1:0] byte_offset = core_address_o[1:0];
    assign mem_address_i = core_address_o;

    // ---------------------- Store path: core -> memory -----------------------
    always @(*) begin
        // Default assignments to prevent latches and unwanted memory writes
        mem_data_i   = 32'b0;
        byte_write_i = 4'b0000;

        if (store_en_i) begin
            case (op_size_o)
                SIZE_B: begin
                    mem_data_i   = {24'b0, core_data_o[7:0]} << (byte_offset * 8);
                    byte_write_i = 4'b0001 << byte_offset;
                end
                SIZE_H: begin
                    mem_data_i   = byte_offset[1] ? {core_data_o[15:0], 16'b0}
                                                  : {16'b0, core_data_o[15:0]};
                    byte_write_i = byte_offset[1] ? 4'b1100 : 4'b0011;
                end
                SIZE_W: begin
                    mem_data_i   = core_data_o;
                    byte_write_i = 4'b1111;
                end
                default: begin
                    mem_data_i   = 32'b0;
                    byte_write_i = 4'b0000;
                end
            endcase
        end
    end

    // ---------------------- Load path: memory -> core ------------------------
    always @(*) begin
        // Default assignment to prevent latches and output clean zeroes when inactive
        core_data_i = 32'b0;

        if (load_en_i) begin
            case (op_size_o)
                SIZE_B: begin
                    case (byte_offset)
                        2'b00: core_data_i = {{24{mem_data_o[7]}},  mem_data_o[7:0]};
                        2'b01: core_data_i = {{24{mem_data_o[15]}}, mem_data_o[15:8]};
                        2'b10: core_data_i = {{24{mem_data_o[23]}}, mem_data_o[23:16]};
                        2'b11: core_data_i = {{24{mem_data_o[31]}}, mem_data_o[31:24]};
                    endcase
                end
                SIZE_BU: begin
                    case (byte_offset)
                        2'b00: core_data_i = {24'b0, mem_data_o[7:0]};
                        2'b01: core_data_i = {24'b0, mem_data_o[15:8]};
                        2'b10: core_data_i = {24'b0, mem_data_o[23:16]};
                        2'b11: core_data_i = {24'b0, mem_data_o[31:24]};
                    endcase
                end
                SIZE_H: begin
                    core_data_i = byte_offset[1]
                                  ? {{16{mem_data_o[31]}}, mem_data_o[31:16]}
                                  : {{16{mem_data_o[15]}}, mem_data_o[15:0]};
                end
                SIZE_HU: begin
                    core_data_i = byte_offset[1]
                                  ? {16'b0, mem_data_o[31:16]}
                                  : {16'b0, mem_data_o[15:0]};
                end
                SIZE_W: begin
                    core_data_i = mem_data_o;
                end
                default: core_data_i = 32'b0;
            endcase
        end
    end

endmodule



// ---------- INCLUDED IP: RISCV_Register3bit_A ---------- 


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module RISCV_Register3bit_A (

  input wire i_Write_Enable,
  input wire [31:0] i_Instruction,
  output wire [31:0] o_Data_Rs_1,
  output wire [31:0] o_Data_Rs_2,
  input wire [2:0] i_Write_Back_Sel,
  input wire [31:0] i_Memory_Data,
  input wire [31:0] i_ALU_Output,
  input wire i_Clk,
  input wire i_Rst,
  input wire [31:0] i_CRC_Result,
  input wire [31:0] i_Multiplier_Result,
  input wire [31:0] i_ZERO,
  input wire [31:0] i_PC_Plus_4

);

//Internal Wires
 wire [31:0] w_1;

//Instances of Modules
REGISTER_FILE #(.p_DATA_MEM_SIZE(2**10)) blk2116_13 (
         .i_Write_Enable (i_Write_Enable),
         .i_Instruction (i_Instruction [31:0]),
         .o_Data_Rs_1 (o_Data_Rs_1 [31:0]),
         .o_Data_Rs_2 (o_Data_Rs_2 [31:0]),
         .i_Clk (i_Clk),
         .i_Rst (i_Rst),
         .i_Data_Rd (w_1)
     );

MUX8_32 blk3317_32 (
         .S (i_Write_Back_Sel [2:0]),
         .B (i_Memory_Data [31:0]),
         .A (i_ALU_Output [31:0]),
         .D (i_CRC_Result [31:0]),
         .C (i_Multiplier_Result [31:0]),
         .F (i_ZERO [31:0]),
         .G (i_ZERO [31:0]),
         .H (i_ZERO [31:0]),
         .E (i_PC_Plus_4 [31:0]),
         .Z (w_1)
     );


endmodule




// ---------- INCLUDED IP: FSM ---------- 


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module FSM (

  input wire [31:0] instruction_i,
  input wire CLK,
  input wire rst,
  output wire ir_write,
  output wire reg_write,
  output wire oe,
  output wire we,
  input wire branch_taken,
  output wire pc_write,
  output wire pc_sel,
  output wire alu_src_a,
  output wire alu_src_b,
  output wire [2:0] wb_sel,
  output wire [2:0] lsu_op,
  output wire lsu_valid,
  output wire [2:0] btanch_sel,
  output wire branch_valid,
  output wire [3:0] alu_sel_o,
  output wire [1:0] system_op,
  output wire system_valid,
  output wire mult_start_o,
  input wire mult_done_i,
  output wire a_write,
  output wire b_write,
  output wire aluout_write,
  output wire mdr_write,
  output wire [3:0] crc_sel,
  output wire load_en,
  output wire store_en

);

//Internal Wires
 wire [3:0] w_1;
 wire [2:0] w_2;
 wire [6:0] w_3;
 wire [6:0] w_10;
 wire [3:0] w_14;

//Instances of Modules
operation_decoder blk3103_80 (
         .alu_sel_o (alu_sel_o[3:0]),
         .crc_sel_o (crc_sel[3:0]),
         .instr_type_i (w_1),
         .funct3_i (w_2),
         .funct7_i (w_3)
     );

alu_source_control blk3154_81 (
         .alu_src_a_o (alu_src_a),
         .alu_src_b_o (alu_src_b),
         .instr_type_i (w_1)
     );

writeback_control blk3156_84 (
         .wb_sel_o (wb_sel[2:0]),
         .instr_type_i (w_1)
     );

lsu_control blk3157_88 (
         .lsu_op_o (lsu_op[2:0]),
         .lsu_valid_o (lsu_valid),
         .instr_type_i (w_1),
         .funct3_i (w_2)
     );

branch_control blk3158_91 (
         .branch_sel_o (btanch_sel[2:0]),
         .branch_valid_o (branch_valid),
         .instr_type_i (w_1),
         .funct3_i (w_2)
     );

opcode_decoder blk3099_98 (
         .instr_type_o (w_1),
         .opcode_i (w_10),
         .funct3_i (w_2),
         .funct7_i (w_3)
     );

system_control blk3212_100 (
         .instruction_i (instruction_i[31:0]),
         .system_op_o (system_op[1:0]),
         .system_valid_o (system_valid)
     );

instruction_decoder blk3098_103 (
         .instruction_i (instruction_i[31:0]),
         .funct3_o (w_2),
         .funct7_o (w_3),
         .opcode_o (w_10)
     );

pc_control_v2 blk3214_109 (
         .branch_taken_i (branch_taken),
         .pc_write_o (pc_write),
         .pc_sel_o (pc_sel),
         .current_state_i (w_14)
     );

control_fsm blk3109_116 (
         .clk_i (CLK),
         .rst_i (rst),
         .mult_done_i (mult_done_i),
         .instr_type_i (w_1),
         .current_state_o (w_14)
     );

register_enable_control blk3217_117 (
         .a_write_o (a_write),
         .b_write_o (b_write),
         .aluout_write_o (aluout_write),
         .mdr_write_o (mdr_write),
         .current_state_i (w_14)
     );

control_outputs blk3148_120 (
         .ir_write_o (ir_write),
         .reg_write_o (reg_write),
         .oe_o (oe),
         .we_o (we),
         .mult_start_o (mult_start_o),
         .load_en_o (load_en),
         .store_en_o (store_en),
         .current_state_i (w_14)
     );

RISCV_CRC blk3334_123 (

     );


endmodule




// ---------- INCLUDED IP: Datapath_Vers5 ---------- 


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module Datapath_Vers5 (

  input wire [31:0] i_Instruction,
  input wire [31:0] i_Memory_data,
  input wire i_PC_write_enable,
  output wire [31:0] o_Memory_Address,
  input wire [31:0] i_ZERO,
  input wire [2:0] i_Write_Back_Sel,
  input wire [3:0] i_ALU_Op,
  input wire i_A_Sel,
  input wire i_B_Sel,
  input wire i_Mul_Start,
  output wire o_Branch_Taken,
  input wire i_MUX_Sel,
  input wire i_Rst,
  input wire i_Clk,
  input wire [2:0] i_Branch_Sel,
  output wire o_mult_done,
  input wire i_IR_write_enable,
  input wire i_MDR_write_enable,
  input wire i_Register_write_enable,
  input wire i_registerB_write_enable,
  input wire i_registerA_write_enable,
  input wire i_ALUout_write_enable,
  input wire [3:0] i_CRC_Sel,
  input wire i_Branch_Valid,
  output wire [31:0] o_registerB_Rs2,
  output wire [31:0] o_instruction

);

//Internal Wires
 wire [31:0] w_1;
 wire [31:0] w_2;
 wire [31:0] w_3;
 wire [31:0] w_4;
 wire [31:0] w_5;
 wire [31:0] w_6;
 wire [31:0] w_7;
 wire [31:0] w_16;
 wire [31:0] w_17;
 wire [31:0] w_25;
 wire [31:0] w_28;
 wire [31:0] w_29;
 wire [31:0] w_31;
 wire [31:0] w_33;
 wire [31:0] w_34;

//Interface Assigns
assign o_registerB_Rs2 [31:0] = w_2;
assign o_instruction [31:0] = w_6;

//Instances of Modules
RISCV_ALU_4bit blk3287_74 (
         .i_ALU_Op (i_ALU_Op [3:0]),
         .i_A_Sel (i_A_Sel),
         .i_B_Sel (i_B_Sel),
         .i_Register_Rs_1 (w_1),
         .i_Register_Rs_2 (w_2),
         .i_PC_Output (w_3),
         .i_Immediate (w_4),
         .o_Q (w_5)
     );

RISCV_IMM_GENERATOR_A blk3362_75 (
         .o_Immediate (w_4),
         .i_Instruction (w_6)
     );

A_register blk2705_77 (
         .reset (i_Rst),
         .clk (i_Clk),
         .write_enable (i_registerA_write_enable),
         .data_out (w_1),
         .data_in (w_7)
     );

instruction_register blk2703_78 (
         .data_in (i_Instruction [31:0]),
         .reset (i_Rst),
         .clk (i_Clk),
         .write_enable (i_IR_write_enable),
         .data_out (w_6)
     );

memorydata_register blk2704_79 (
         .data_in (i_Memory_data [31:0]),
         .reset (i_Rst),
         .clk (i_Clk),
         .write_enable (i_MDR_write_enable),
         .data_out (w_16)
     );

B_register blk2706_80 (
         .reset (i_Rst),
         .clk (i_Clk),
         .write_enable (i_registerB_write_enable),
         .data_out (w_2),
         .data_in (w_17)
     );

ALU_Out_Register blk2708_81 (
         .reset (i_Rst),
         .clk (i_Clk),
         .write_enable (i_ALUout_write_enable),
         .data_in (w_5),
         .data_out (w_25)
     );

PROGRAM_COUNTER_A blk3367_83 (
         .i_PC_write_enable (i_PC_write_enable),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_Data (w_28),
         .o_PC_Output (w_29),
         .o_PC_Plus_4 (w_31)
     );

MUX2_32 blk1779_84 (
         .Z (o_Memory_Address [31:0]),
         .S (i_MUX_Sel),
         .B (w_25),
         .A (w_29)
     );

old_PC_Register blk3485_88 (
         .reset (i_Rst),
         .clk (i_Clk),
         .write_enable (i_IR_write_enable),
         .data_out (w_3),
         .data_in (w_29)
     );

MUX2_32 blk1779_89 (
         .S (i_MUX_Sel),
         .B (w_25),
         .Z (w_28),
         .A (w_31)
     );

RISCV_Register3bit_A blkProj14723_102 (
         .i_ZERO (i_ZERO [31:0]),
         .i_Write_Back_Sel (i_Write_Back_Sel [2:0]),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_Write_Enable (i_Register_write_enable),
         .o_Data_Rs_1 (w_7),
         .i_Instruction (w_6),
         .i_Memory_Data (w_16),
         .o_Data_Rs_2 (w_17),
         .i_ALU_Output (w_25),
         .i_PC_Plus_4 (w_31),
         .i_CRC_Result (w_33),
         .i_Multiplier_Result (w_34)
     );

RISCV_Multiplier blk3040_112 (
         .i_Mul_Start (i_Mul_Start),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .o_Done (o_mult_done),
         .i_Multiplier (w_1),
         .i_Instruction (w_6),
         .i_Multiplicand (w_2),
         .o_Result (w_34)
     );

RISCV_BRANCH_COMPARATOR_A blk3363_115 (
         .o_Branch_Taken (o_Branch_Taken),
         .i_Branch_Sel (i_Branch_Sel [2:0]),
         .i_Branch_Valid (i_Branch_Valid),
         .i_Reg_A (w_1),
         .i_Reg_B (w_2)
     );

RISCV_CRC blk3334_119 (
         .i_Start (i_Mul_Start),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_CRC_Sel (i_CRC_Sel [3:0]),
         .i_Register_Rs_1 (w_1),
         .i_Register_Rs_2 (w_2),
         .o_Result (w_33)
     );


endmodule




// ---------- INCLUDED IP: RISCV_LSU ---------- 


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module RISCV_LSU (

  input wire [31:0] core_data_o,
  input wire [31:0] core_address_o,
  input wire store_en_i,
  input wire load_en_i,
  input wire [2:0] op_size_o,
  input wire [31:0] mem_data_o,
  output wire [31:0] core_data_i,
  output wire [31:0] mem_data_i,
  output wire [31:0] mem_address_i,
  output wire [3:0] byte_write_i

);
//Instances of Modules
lsu blk4093_1 (
         .core_data_o (core_data_o [31:0]),
         .core_address_o (core_address_o [31:0]),
         .store_en_i (store_en_i),
         .load_en_i (load_en_i),
         .op_size_o (op_size_o[2:0]),
         .mem_data_o (mem_data_o[31:0]),
         .core_data_i (core_data_i[31:0]),
         .mem_data_i (mem_data_i[31:0]),
         .mem_address_i (mem_address_i[31:0]),
         .byte_write_i (byte_write_i[3:0])
     );


endmodule



// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module top (

  output wire [31:0] toRAM_data,
  output wire [3:0] toRAM_byte_write,
  output wire [31:0] toRAM_address,
  input wire [31:0] fromRAM_data,
  input wire i_Clk,
  input wire i_Rst,
  input wire [31:0] i_ZERO

);

//Internal Wires
 wire [31:0] w_1;
 wire w_2;
 wire w_3;
 wire w_4;
 wire w_5;
 wire w_6;
 wire w_7;
 wire w_8;
 wire w_9;
 wire [2:0] w_10;
 wire [2:0] w_11;
 wire [2:0] w_12;
 wire w_13;
 wire [3:0] w_14;
 wire w_15;
 wire w_16;
 wire w_17;
 wire w_18;
 wire w_19;
 wire [3:0] w_20;
 wire w_21;
 wire w_22;
 wire [31:0] w_23;
 wire [31:0] w_24;
 wire [31:0] w_25;

//Instances of Modules
FSM blkProj15107_26 (
         .CLK (i_Clk),
         .rst (i_Rst),
         .instruction_i (w_1),
         .branch_taken (w_2),
         .mult_done_i (w_3),
         .ir_write (w_4),
         .reg_write (w_5),
         .pc_write (w_6),
         .pc_sel (w_7),
         .alu_src_a (w_8),
         .alu_src_b (w_9),
         .wb_sel (w_10),
         .lsu_op (w_11),
         .btanch_sel (w_12),
         .branch_valid (w_13),
         .alu_sel_o (w_14),
         .mult_start_o (w_15),
         .a_write (w_16),
         .b_write (w_17),
         .aluout_write (w_18),
         .mdr_write (w_19),
         .crc_sel (w_20),
         .load_en (w_21),
         .store_en (w_22)
     );

RISCV_LSU blkProj15143_27 (
         .mem_data_i (toRAM_data [31:0]),
         .byte_write_i (toRAM_byte_write [3:0]),
         .mem_address_i (toRAM_address [31:0]),
         .mem_data_o (fromRAM_data [31:0]),
         .op_size_o (w_11),
         .load_en_i (w_21),
         .store_en_i (w_22),
         .core_data_o (w_23),
         .core_address_o (w_24),
         .core_data_i (w_25)
     );

Datapath_Vers5 blkProj15115_40 (
         .i_Clk (i_Clk),
         .i_Rst (i_Rst),
         .i_ZERO (i_ZERO [31:0]),
         .o_instruction (w_1),
         .o_Branch_Taken (w_2),
         .o_mult_done (w_3),
         .i_IR_write_enable (w_4),
         .i_Register_write_enable (w_5),
         .i_PC_write_enable (w_6),
         .i_MUX_Sel (w_7),
         .i_A_Sel (w_8),
         .i_B_Sel (w_9),
         .i_Write_Back_Sel (w_10),
         .i_Branch_Sel (w_12),
         .i_Branch_Valid (w_13),
         .i_ALU_Op (w_14),
         .i_Mul_Start (w_15),
         .i_registerA_write_enable (w_16),
         .i_registerB_write_enable (w_17),
         .i_ALUout_write_enable (w_18),
         .i_MDR_write_enable (w_19),
         .i_CRC_Sel (w_20),
         .o_registerB_Rs2 (w_23),
         .o_Memory_Address (w_24),
         .i_Instruction (w_25),
         .i_Memory_data (w_25)
     );


endmodule
