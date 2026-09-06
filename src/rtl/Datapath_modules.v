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
    input wire i_Start,
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
                    if (i_Start) begin
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
    input wire [31:0] i_Instruction,
    output reg [31:0] o_Result
);

    wire [2:0] i_Funct3 = i_Instruction[14:12];

    /* Xicrc Extension Funct3 Encodings */
    localparam c_FUNCT3_CRCB = 3'b000; // CRC8
    localparam c_FUNCT3_CRCH = 3'b001; // CRC16
    localparam c_FUNCT3_CRCW = 3'b010; // CRC32

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
        case (i_Funct3)
            c_FUNCT3_CRCB: o_Result = w_CRC8_Result;
            c_FUNCT3_CRCH: o_Result = w_CRC16_Result;
            c_FUNCT3_CRCW: o_Result = w_CRC32_Result;
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



// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module top (

  input wire [31:0] i_Instruction,
  input wire [31:0] i_Memory_data,
  input wire i_PC_write_enable,
  output wire [31:0] o_Memory,
  input wire [31:0] i_ZERO,
  input wire i_write_enable,
  input wire [2:0] i_Write_Back_Sel,
  input wire [3:0] i_ALU_Op,
  input wire i_A_Sel,
  input wire i_B_Sel,
  input wire i_Start,
  output wire o_Branch_Taken,
  input wire i_MUX_Sel,
  input wire i_Rst,
  input wire i_Clk,
  input wire [2:0] i_Branch_Sel

);

//Internal Wires
 wire [31:0] w_1;
 wire [31:0] w_2;
 wire [31:0] w_3;
 wire [31:0] w_4;
 wire [31:0] w_7;
 wire [31:0] w_8;
 wire [31:0] w_9;
 wire [31:0] w_13;
 wire [31:0] w_17;
 wire [31:0] w_18;
 wire [31:0] w_20;
 wire [31:0] w_23;
 wire [31:0] w_24;
 wire [31:0] w_26;
 wire [31:0] w_28;

//Instances of Modules
RISCV_CRC blk3334_70 (
         .i_Start (i_Start),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_Register_Rs_1 (w_1),
         .i_Register_Rs_2 (w_2),
         .i_Instruction (w_3),
         .o_Result (w_4)
     );

RISCV_ALU_4bit blk3287_74 (
         .i_ALU_Op (i_ALU_Op [3:0]),
         .i_A_Sel (i_A_Sel),
         .i_B_Sel (i_B_Sel),
         .i_Register_Rs_1 (w_1),
         .i_Register_Rs_2 (w_2),
         .i_PC_Output (w_7),
         .i_Immediate (w_8),
         .o_Q (w_9)
     );

RISCV_IMM_GENERATOR_A blk3362_75 (
         .o_Immediate (w_8),
         .i_Instruction (w_3)
     );

RISCV_BRANCH_COMPARATOR_A blk3363_76 (
         .o_Branch_Taken (o_Branch_Taken),
         .i_Branch_Sel (i_Branch_Sel [2:0]),
         .i_Reg_A (w_1),
         .i_Reg_B (w_2)
     );

A_register blk2705_77 (
         .write_enable (i_write_enable),
         .reset (i_Rst),
         .clk (i_Clk),
         .data_out (w_1),
         .data_in (w_13)
     );

instruction_register blk2703_78 (
         .data_in (i_Instruction [31:0]),
         .write_enable (i_write_enable),
         .reset (i_Rst),
         .clk (i_Clk),
         .data_out (w_3)
     );

memorydata_register blk2704_79 (
         .data_in (i_Memory_data [31:0]),
         .write_enable (i_write_enable),
         .reset (i_Rst),
         .clk (i_Clk),
         .data_out (w_17)
     );

B_register blk2706_80 (
         .write_enable (i_write_enable),
         .reset (i_Rst),
         .clk (i_Clk),
         .data_out (w_2),
         .data_in (w_18)
     );

ALU_Out_Register blk2708_81 (
         .write_enable (i_write_enable),
         .reset (i_Rst),
         .clk (i_Clk),
         .data_in (w_9),
         .data_out (w_20)
     );

PROGRAM_COUNTER_A blk3367_83 (
         .i_PC_write_enable (i_PC_write_enable),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_Data (w_23),
         .o_PC_Output (w_24),
         .o_PC_Plus_4 (w_26)
     );

MUX2_32 blk1779_84 (
         .Z (o_Memory [31:0]),
         .S (i_MUX_Sel),
         .B (w_20),
         .A (w_24)
     );

old_PC_Register blk3485_88 (
         .write_enable (i_write_enable),
         .reset (i_Rst),
         .clk (i_Clk),
         .data_out (w_7),
         .data_in (w_24)
     );

MUX2_32 blk1779_89 (
         .S (i_MUX_Sel),
         .B (w_20),
         .Z (w_23),
         .A (w_26)
     );

RISCV_Register3bit_A blkProj14723_102 (
         .i_ZERO (i_ZERO [31:0]),
         .i_Write_Enable (i_write_enable),
         .i_Write_Back_Sel (i_Write_Back_Sel [2:0]),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_CRC_Result (w_4),
         .o_Data_Rs_1 (w_13),
         .i_Instruction (w_3),
         .i_Memory_Data (w_17),
         .o_Data_Rs_2 (w_18),
         .i_ALU_Output (w_20),
         .i_PC_Plus_4 (w_26),
         .i_Multiplier_Result (w_28)
     );

RISCV_Multiplier blk3040_104 (
         .i_Start (i_Start),
         .i_Rst (i_Rst),
         .i_Clk (i_Clk),
         .i_Multiplier (w_1),
         .i_Instruction (w_3),
         .i_Multiplicand (w_2),
         .o_Result (w_28)
     );


endmodule

