module lsu (
    // --------------------- Core Datapath side --------------------------------
    input  wire [31:0] core_data_o,     // store data from the Datapath (rs2 value)
    input  wire [31:0] core_address_o,  // effective address from the Datapath
    input  wire [2:0]  op_size_o,       // funct3 load/store operation selector
    
    // NEW: Explicit control signals required by the new overlapping encoding
    input  wire        read_en_o,       // 1 if load instruction
    input  wire        write_en_o,      // 1 if store instruction
    
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

        if (write_en_o) begin
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

        if (read_en_o) begin
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