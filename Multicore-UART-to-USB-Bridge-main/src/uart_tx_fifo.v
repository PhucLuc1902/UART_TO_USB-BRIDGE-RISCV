// Simple UART TX FIFO buffer
// Stores up to 16 bytes to transmit
module uart_tx_fifo #(
    parameter DEPTH = 16,
    parameter ADDR_BITS = 4  // $clog2(DEPTH)
)(
    input  wire clk,
    input  wire rst,
    
    // Write interface (from CPU)
    input  wire [7:0] din,
    input  wire       wr_en,
    output wire       full,
    output wire       almost_full,
    
    // Read interface (to UART)
    output wire [7:0] dout,
    input  wire       rd_en,
    output wire       empty
);
    reg [7:0] mem [0:DEPTH-1];
    reg [ADDR_BITS-1:0] wr_ptr, rd_ptr;
    reg [ADDR_BITS:0] count;  // Extra bit to distinguish full/empty
    
    assign full = (count == DEPTH);
    assign almost_full = (count >= DEPTH - 2);
    assign empty = (count == 0);
    assign dout = mem[rd_ptr];
    
    always @(posedge clk) begin
        if (rst) begin
            wr_ptr <= 0;
            rd_ptr <= 0;
            count <= 0;
        end else begin
            // Handle simultaneous read and write
            case ({wr_en && !full, rd_en && !empty})
                2'b10: begin  // Write only
                    mem[wr_ptr] <= din;
                    wr_ptr <= wr_ptr + 1;
                    count <= count + 1;
                end
                2'b01: begin  // Read only
                    rd_ptr <= rd_ptr + 1;
                    count <= count - 1;
                end
                2'b11: begin  // Both read and write
                    mem[wr_ptr] <= din;
                    wr_ptr <= wr_ptr + 1;
                    rd_ptr <= rd_ptr + 1;
                    // count stays same
                end
                default: begin
                    // No operation
                end
            endcase
        end
    end
endmodule
