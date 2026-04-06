// uart_simple.v - Tiny 8N1 UART with TX+RX (115200 default)
module uart_simple #(
    parameter integer CLK_HZ = 125_000_000,
    parameter integer BAUD   = 115200
)(
    input  wire clk,
    input  wire rstn,
    input  wire rx,
    output wire tx,
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output wire       tx_busy,
    output reg  [7:0] rx_data,
    output reg        rx_valid
);
    // -------- TX (1x baud) --------
    localparam integer TX_DIV = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer TX_DIV_BITS = $clog2(TX_DIV);
    reg [TX_DIV_BITS-1:0] tx_cnt = 0;
    reg tx_tick;
    always @(posedge clk) begin
        if (!rstn) begin tx_cnt <= 0; tx_tick <= 1'b0; end
        else begin
            if (tx_cnt == TX_DIV-1) begin tx_cnt <= 0; tx_tick <= 1'b1; end
            else begin tx_cnt <= tx_cnt + 1'b1; tx_tick <= 1'b0; end
        end
    end
    reg [3:0]  tx_bitpos = 0;
    reg [9:0]  tx_shift  = 10'h3FF;  // idle high
    reg        tx_busy_r = 1'b0;
    assign tx      = tx_shift[0];
    assign tx_busy = tx_busy_r;
    always @(posedge clk) begin
        if (!rstn) begin tx_shift <= ~10'b0; tx_bitpos <= 0; tx_busy_r <= 1'b0; end
        else begin
            if (!tx_busy_r) begin
                if (tx_start) begin
                    tx_shift  <= {1'b1, tx_data, 1'b0}; // stop,8b,start
                    tx_bitpos <= 0; tx_busy_r <= 1'b1;
                end
            end else if (tx_tick) begin
                tx_shift  <= {1'b1, tx_shift[9:1]};
                tx_bitpos <= tx_bitpos + 1'b1;
                if (tx_bitpos == 4'd9) tx_busy_r <= 1'b0;
            end
        end
    end

    // -------- RX (16x oversampling) --------
    localparam integer RX_OVERSAMPLE = 16;
    localparam integer RX_DIV = (CLK_HZ + (BAUD*RX_OVERSAMPLE)/2) / (BAUD*RX_OVERSAMPLE);
    localparam integer RX_DIV_BITS = $clog2(RX_DIV);
    reg [RX_DIV_BITS-1:0] rx_cnt = 0; reg rx_tick;
    always @(posedge clk) begin
        if (!rstn) begin rx_cnt <= 0; rx_tick <= 1'b0; end
        else begin
            if (rx_cnt == RX_DIV-1) begin rx_cnt <= 0; rx_tick <= 1'b1; end
            else begin rx_cnt <= rx_cnt + 1'b1; rx_tick <= 1'b0; end
        end
    end
    reg [3:0] rx_oversample = 0; reg [2:0] rx_bitpos = 0;
    reg [7:0] rx_shift = 0; reg rx_busy_r = 1'b0;
    reg rx_sync1, rx_sync2;        // sync to clk
    always @(posedge clk) begin rx_sync1 <= rx; rx_sync2 <= rx_sync1; end

    always @(posedge clk) begin
        if (!rstn) begin rx_valid <= 1'b0; rx_busy_r <= 1'b0; rx_oversample <= 0; rx_bitpos <= 0; end
        else begin
            rx_valid <= 1'b0; // one-cycle pulse
            if (!rx_busy_r) begin
                if (rx_sync2 == 1'b0) begin rx_busy_r <= 1'b1; rx_oversample <= 0; rx_bitpos <= 0; end
            end else if (rx_tick) begin
                rx_oversample <= rx_oversample + 1'b1;
                if (rx_bitpos == 0) begin
                    if (rx_oversample == 4'd7) begin
                        if (rx_sync2 == 1'b0) begin rx_bitpos <= 1; rx_oversample <= 0; end
                        else rx_busy_r <= 1'b0; // false start
                    end
                end else if (rx_bitpos >= 1 && rx_bitpos <= 8) begin
                    if (rx_oversample == 4'd15) begin
                        rx_shift <= {rx_sync2, rx_shift[7:1]};
                        rx_bitpos <= rx_bitpos + 1'b1; rx_oversample <= 0;
                    end
                end else if (rx_bitpos == 9) begin
                    if (rx_oversample == 4'd15) begin
                        rx_data <= rx_shift; rx_valid <= 1'b1; rx_busy_r <= 1'b0;
                    end
                end
            end
        end
    end
endmodule
