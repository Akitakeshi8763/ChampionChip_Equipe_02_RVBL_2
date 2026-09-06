module address_decoder #(
    parameter ADDR_W = 32,
    // Base Addresses
    parameter IMEM_BASE = 32'h0040_0000,
    parameter DMEM_BASE = 32'h1001_0000,
    // Memory Sizes
    parameter IMEM_SIZE = 32'h0040_0000, // 4 MB 
    parameter DMEM_SIZE = 32'h0000_2000  // 8 kB
)(
    // --- Core (LSU) Inputs ---
    input  wire [ADDR_W-1:0] core_address_i,
    input  wire              core_we_i,
    input  wire              core_oe_i,
    input  wire [3:0]        core_bw_i,

    // --- IMEM Control Outputs ---
    output wire [ADDR_W-1:0] imem_address_o,
    output reg               imem_oe_o,
    

    // --- DMEM Control Outputs ---
    output wire [ADDR_W-1:0] dmem_address_o,
    output reg               dmem_we_o,
    output reg               dmem_oe_o,
    output wire [3:0]        dmem_bw_o,

    // --- External Mux Selection Outputs ---
    output reg               sel_o   
);

    assign imem_address_o = ((core_address_i - IMEM_BASE) & {{(ADDR_W-2){1'b1}}, 2'b00});
	assign dmem_address_o = ((core_address_i - DMEM_BASE) & {{(ADDR_W-2){1'b1}}, 2'b00});

    // Only DMEM receives the byte-write mask
    assign dmem_bw_o = core_bw_i;

    // 2. Control Routing & External Mux Selection
    always @(*) begin
        // DEFAULT STATES: Crucial to prevent latches
        imem_oe_o  = 1'b0;
        dmem_oe_o  = 1'b0;
        dmem_we_o  = 1'b0;
        sel_o = 1'b0;

        // Route based on MMIO ranges
        if ((core_address_i >= IMEM_BASE) && (core_address_i < (IMEM_BASE + IMEM_SIZE))) begin
            imem_oe_o  = core_oe_i;
            sel_o = 1'b1;
            // core_we_i is intentionally dropped here, IMEM cannot be written to.
        end 
        else if ((core_address_i >= DMEM_BASE) && (core_address_i < (DMEM_BASE + DMEM_SIZE))) begin
            dmem_oe_o  = core_oe_i;
            dmem_we_o  = core_we_i;
            sel_o = 1'b0;
        end
    end

endmodule