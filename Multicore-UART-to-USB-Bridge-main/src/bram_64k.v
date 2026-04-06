/*
// 64 KiB BRAM, sync read, byte writes, $readmemh init (firmware.mem)
module bram_64k #(
    parameter INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg  [31:0] rdata,
    output reg         ready
);
    localparam WORDS = 16384; // 64k / 4
    reg [31:0] mem [0:WORDS-1];
    initial if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    always @(posedge clk) begin
        if (!rstn) ready <= 1'b0;
        else begin
            ready <= 1'b0;
            if (valid && !ready) begin
                if (wstrb[0]) mem[addr[15:2]][7:0]   <= wdata[7:0];
                if (wstrb[1]) mem[addr[15:2]][15:8]  <= wdata[15:8];
                if (wstrb[2]) mem[addr[15:2]][23:16] <= wdata[23:16];
                if (wstrb[3]) mem[addr[15:2]][31:24] <= wdata[31:24];
                rdata <= mem[addr[15:2]]; // 1-cycle sync read
                ready <= 1'b1;
            end
        end
    end
endmodule
*/
// 64 KiB BRAM, sync read, byte writes, $readmemh init (firmware.mem)
module bram_64k #(
    parameter INIT_FILE = ""
)(
    input  wire        clk,
    input  wire        rstn,
    input  wire        valid,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    input  wire [3:0]  wstrb,
    output reg  [31:0] rdata,
    output reg         ready
);
    localparam WORDS = 16384; // 64k / 4
    reg [31:0] mem [0:WORDS-1];
    initial if (INIT_FILE != "") $readmemh(INIT_FILE, mem);

    always @(posedge clk) begin
        if (!rstn) begin
            ready <= 1'b0;
            rdata <= 32'h0;
        end else begin
            ready <= 1'b0;
            if (valid && !ready) begin
                // Write operation
                if (|wstrb) begin  // If any write strobe is active
                    if (wstrb[0]) mem[addr[15:2]][7:0]   <= wdata[7:0];
                    if (wstrb[1]) mem[addr[15:2]][15:8]  <= wdata[15:8];
                    if (wstrb[2]) mem[addr[15:2]][23:16] <= wdata[23:16];
                    if (wstrb[3]) mem[addr[15:2]][31:24] <= wdata[31:24];
                end
                // Read operation (always happens)
                rdata <= mem[addr[15:2]];
                ready <= 1'b1;
            end
        end
    end
endmodule
