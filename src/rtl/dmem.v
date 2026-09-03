module dmem #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    // 8kB capacity translates to 2048 words of 32-bits (4 bytes each)[cite: 1]
    parameter DEPTH = 2048 
)(
    input  wire              clk_i,
    input  wire [ADDR_W-1:0] address_i,
    input  wire              we_i,
    input  wire              oe_i,
    input  wire [3:0]        bw_i,
    input  wire [DATA_W-1:0] data_i,
    output reg  [DATA_W-1:0] data_o
);

    // Define the SRAM array
    reg [DATA_W-1:0] ram [0:DEPTH-1];
    
    // Convert the aligned 32-bit byte address into a word index.
    wire [ADDR_W-3:0] word_addr = address_i[ADDR_W-1:2];

    // Synchronous Write with Byte-Masking[cite: 1]
    // Memory is updated only on the rising edge of the clock[cite: 1].
    always @(posedge clk_i) begin
        if (we_i) begin
            // Independent byte-lane writing enforced by the 4-bit mask[cite: 1]
            if (bw_i[0]) ram[word_addr][7:0]   <= data_i[7:0];
            if (bw_i[1]) ram[word_addr][15:8]  <= data_i[15:8];
            if (bw_i[2]) ram[word_addr][23:16] <= data_i[23:16];
            if (bw_i[3]) ram[word_addr][31:24] <= data_i[31:24];
        end
    end

    // Synchronous Read[cite: 1]
    // The read operation is clocked, meaning the data will only appear 
    // on data_o after the clock edge[cite: 1].
    always @(posedge clk_i) begin
        if (oe_i) begin
            data_o <= ram[word_addr];
        end else begin
            data_o <= DATA_W'b0;
        end
    end

endmodule