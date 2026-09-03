module imem #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    // 4MB capacity translates to 1,048,576 words of 32-bits (4 bytes each)
    parameter DEPTH = 1048576, 
    parameter INIT_FILE = "firmware.hex"
)(
    input  wire [ADDR_W-1:0] address_i,
    input  wire              oe_i,
    output reg  [DATA_W-1:0] data_o
);

    // Define the ROM array
    reg [DATA_W-1:0] rom [0:DEPTH-1];

    // Initialize the ROM with the compiled assembly firmware
    initial begin
        $readmemh(INIT_FILE, rom);
    end

    // Convert the aligned 32-bit byte address into a word index.
    // The decoder already zeroed the bottom 2 bits, but we drop them 
    // here to access the correct 32-bit array index.
    wire [ADDR_W-3:0] word_addr = address_i[ADDR_W-1:2];

    // Combinational read: instruction is returned upon address & oe_i
    always @(*) begin
        if (oe_i) begin
            data_o = rom[word_addr];
        end else begin
            data_o = DATA_W'b0;
        end
    end

endmodule