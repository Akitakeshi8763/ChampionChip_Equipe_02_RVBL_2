module mem_ss #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    // Base Addresses[cite: 1]
    parameter IMEM_BASE = 32'h0040_0000,
    parameter DMEM_BASE = 32'h1001_0000,
    // Memory Sizes
    parameter IMEM_SIZE = 32'h0040_0000, // 4 MB 
    parameter DMEM_SIZE = 32'h0000_2000  // 8 kB
)(
    // --- System Clock ---
    input  wire              clk_i,

    // --- Core (LSU) Interface ---
    input  wire [ADDR_W-1:0] core_address_i,
    input  wire              core_we_i,
    input  wire              core_oe_i,
    input  wire [3:0]        core_bw_i,
    input  wire [DATA_W-1:0] core_data_i,  // Data from core to write to memory
    output reg  [DATA_W-1:0] core_data_o   // Data returned to core from memory
);

    // ==========================================
    // Internal Interconnect Wires
    // ==========================================
    
    // IMEM control and data paths
    wire [ADDR_W-1:0] imem_addr;
    wire              imem_oe;
    wire [DATA_W-1:0] imem_data_out;

    // DMEM control and data paths
    wire [ADDR_W-1:0] dmem_addr;
    wire              dmem_we;
    wire              dmem_oe;
    wire [3:0]        dmem_bw;
    wire [DATA_W-1:0] dmem_data_out;

    wire sel_o; // Select signal for external multiplexer (1: IMEM, 0: DMEM)

    // ==========================================
    // 1. Address Decoder (Control Routing)
    // ==========================================
    address_decoder #(
        .ADDR_W(ADDR_W),
        .IMEM_BASE(IMEM_BASE),
        .DMEM_BASE(DMEM_BASE),
        .IMEM_SIZE(IMEM_SIZE),
        .DMEM_SIZE(DMEM_SIZE)
    ) decoder_inst (
        // Inputs from Core
        .core_address_i(core_address_i),
        .core_we_i(core_we_i),
        .core_oe_i(core_oe_i),
        .core_bw_i(core_bw_i),
        
        // Routed IMEM Control
        .imem_address_o(imem_addr),
        .imem_oe_o(imem_oe),
        
        // Routed DMEM Control
        .dmem_address_o(dmem_addr),
        .dmem_we_o(dmem_we),
        .dmem_oe_o(dmem_oe),
        .dmem_bw_o(dmem_bw),

        .sel_o(sel_o) // External multiplexer selection signal
    );

    // ==========================================
    // 2. Instruction Memory (IMEM)
    // ==========================================
    imem #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH(1048576) // 4MB / 4 bytes per word
    ) imem_inst (
        .address_i(imem_addr),
        .oe_i(imem_oe),
        .data_o(imem_data_out)
    );

    // ==========================================
    // 3. Data Memory (DMEM)
    // ==========================================
    dmem #(
        .ADDR_W(ADDR_W),
        .DATA_W(DATA_W),
        .DEPTH(2048) // 8kB / 4 bytes per word
    ) dmem_inst (
        .clk_i(clk_i),
        .address_i(dmem_addr),
        .we_i(dmem_we),
        .oe_i(dmem_oe),
        .bw_i(dmem_bw),
        // Data input bypasses the decoder and goes straight from core to RAM
        .data_i(core_data_i), 
        .data_o(dmem_data_out)
    );

    // ==========================================
    // 4. Data Return Multiplexer (Data Routing)
    // ==========================================
    always @(*) begin
        // Default safe state to prevent latches
        core_data_o = 32'b0;

        if (sel_o == 1'b1) begin
            core_data_o = imem_data_out;
        end 
        else if (sel_o == 1'b0) begin
            core_data_o = dmem_data_out;
        end 
    end

endmodule