
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


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module top (

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


endmodule
