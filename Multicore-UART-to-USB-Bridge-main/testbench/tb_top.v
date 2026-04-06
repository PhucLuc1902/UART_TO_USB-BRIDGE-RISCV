`timescale 1ns/1ps

module tb_top;

    // --------------------------------------------------------
    // Parameters
    // --------------------------------------------------------
    localparam integer CLK_HZ      = 125_000_000;
    localparam integer BAUD        = 115200;
    localparam integer TX_DIV      = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer SIM_TIME_NS = 20_000_000;  // 20 ms cho chắc

    // --------------------------------------------------------
    // DUT I/O
    // --------------------------------------------------------
    reg  clk;
    reg  rst_btn;
    reg  uart_rx;
    reg  btn2;
    wire uart_tx;

    // --------------------------------------------------------
    // Instantiate DUT (top_dualcore)
    // --------------------------------------------------------
    top #(
        .CLK_HZ(CLK_HZ),
        .BAUD  (BAUD)
    ) dut (
        .clk     (clk),
        .rst_btn (rst_btn),
        .uart_rx (uart_rx),
        .btn2    (btn2),
        .uart_tx (uart_tx)
    );

    // --------------------------------------------------------
    // 125 MHz clock
    // --------------------------------------------------------
    initial clk = 1'b0;
    always #4 clk = ~clk;   // 8 ns period

    // --------------------------------------------------------
    // Reset + BTN2 stimulus
    // --------------------------------------------------------
    initial begin
        // Nếu dùng Icarus/Verilator thì 2 dòng này có ích,
        // Vivado XSIM sẽ bỏ qua hoặc cảnh báo, không ảnh hưởng
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        rst_btn = 1'b1;   // giữ reset (BTN0 nhấn)
        uart_rx = 1'b1;   // RX idle
        btn2    = 1'b0;

        // giữ reset 50 chu kỳ
        repeat (50) @(posedge clk);
        rst_btn = 1'b0;
        $display("%t : Reset released", $time);

        // ~40 us sau, pulse BTN2 (để firmware core0 có thể đọc)
        repeat (5000) @(posedge clk);
        btn2 = 1'b1;
        $display("%t : btn2 asserted", $time);
        repeat (2000) @(posedge clk);
        btn2 = 1'b0;
        $display("%t : btn2 deasserted", $time);

        // chạy tới hết SIM_TIME_NS
        #(SIM_TIME_NS);
        $display("%t : End of simulation", $time);
        $finish;
    end

    // ========================================================
    //  UART MONITOR (8N1) - decode byte + gộp word 32-bit
    // ========================================================
    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_BITS  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0] rx_state     = RX_IDLE;
    integer   baud_cnt     = 0;
    integer   bit_idx      = 0;
    reg [7:0] rx_shift     = 8'h00;
    reg       prev_uart_tx = 1'b1;

    integer   byte_count   = 0;
    reg [31:0] word_acc    = 32'h0;
    integer    word_index  = 0;

    always @(posedge clk) begin
        prev_uart_tx <= uart_tx;

        case (rx_state)
            RX_IDLE: begin
                // phát hiện cạnh xuống start bit
                if (prev_uart_tx == 1'b1 && uart_tx == 1'b0) begin
                    rx_state <= RX_START;
                    baud_cnt <= TX_DIV/2;
                    bit_idx  <= 0;
                end
            end

            RX_START: begin
                if (baud_cnt == 0) begin
                    rx_state <= RX_BITS;
                    baud_cnt <= TX_DIV - 1;
                end else
                    baud_cnt <= baud_cnt - 1;
            end

            RX_BITS: begin
                if (baud_cnt == 0) begin
                    rx_shift[bit_idx] <= uart_tx;
                    bit_idx <= bit_idx + 1;
                    baud_cnt <= TX_DIV - 1;

                    if (bit_idx == 7)
                        rx_state <= RX_STOP;
                end else
                    baud_cnt <= baud_cnt - 1;
            end

            RX_STOP: begin
                if (baud_cnt == 0) begin
                    byte_count <= byte_count + 1;

                    $display("%t : UART TX byte[%0d] = 0x%02x (%s)",
                             $time, byte_count-1, rx_shift,
                             (rx_shift >= 8'd32 && rx_shift < 8'd127) ? "ASCII" : "non-ASCII");

                    // gộp 4 byte thành 1 word, LSB trước
                    word_acc <= {rx_shift, word_acc[31:8]};

                    if ((byte_count % 4) == 3) begin
                        $display("           -> UART word[%0d] = 0x%08x  (bytes LSB->MSB: %02x %02x %02x %02x)",
                                 word_index,
                                 {rx_shift, word_acc[31:8]},
                                 word_acc[7:0], word_acc[15:8],
                                 word_acc[23:16], rx_shift);
                        word_index <= word_index + 1;
                    end

                    rx_state <= RX_IDLE;
                end else
                    baud_cnt <= baud_cnt - 1;
            end

            default: rx_state <= RX_IDLE;
        endcase
    end

    // ========================================================
    //  MAILBOX MONITOR - chứng minh Core1 gửi cho Core0 và ngược lại
    // ========================================================
    reg prev_core0_in_valid = 1'b0;
    reg prev_core1_in_valid = 1'b0;

    always @(posedge clk) begin
        if (!dut.rstn_int) begin
            prev_core0_in_valid <= 1'b0;
            prev_core1_in_valid <= 1'b0;
        end else begin
            // Core1 -> Core0 (core0_in_data/valid)
            if (!prev_core0_in_valid && dut.core0_in_valid) begin
                $display("%t : MAILBOX Core1 -> Core0 : 0x%08x",
                         $time, dut.core0_in_data);
            end
            // Core0 -> Core1 (core1_in_data/valid)
            if (!prev_core1_in_valid && dut.core1_in_valid) begin
                $display("%t : MAILBOX Core0 -> Core1 : 0x%08x",
                         $time, dut.core1_in_data);
            end

            prev_core0_in_valid <= dut.core0_in_valid;
            prev_core1_in_valid <= dut.core1_in_valid;
        end
    end

    // ========================================================
    //  BRAM DUMP - xác nhận firmware nạp đúng
    // ========================================================
    initial begin
        #10; // chờ BRAM chạy initial $readmemh
        $display("---- BRAM0 (firmware0_new.mem) dump ----");
        $display("bram0.mem[0] = 0x%08x", dut.bram0.mem[0]);
        $display("bram0.mem[1] = 0x%08x", dut.bram0.mem[1]);
        $display("bram0.mem[2] = 0x%08x", dut.bram0.mem[2]);

        $display("---- BRAM1 (firmware1_new.mem) dump ----");
        $display("bram1.mem[0] = 0x%08x", dut.bram1.mem[0]);
        $display("bram1.mem[1] = 0x%08x", dut.bram1.mem[1]);
        $display("bram1.mem[2] = 0x%08x", dut.bram1.mem[2]);
    end

endmodule
