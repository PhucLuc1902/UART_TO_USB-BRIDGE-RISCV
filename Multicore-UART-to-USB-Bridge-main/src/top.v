// top_dualcore.v - Arty Z7-20, TWO PicoRV32 cores + BRAM + UART + mailbox
// External reset on BTN0 (active-high). Uses 2-FF reset synchronizer and POR counter.

module top #(
    parameter CLK_HZ = 125000000,
    parameter BAUD   = 115200
)(
    input  wire clk,       // 125 MHz PL clock
    input  wire rst_btn,   // BTN0 active-high (pressed = 1)
    input  wire uart_rx,
    input  wire btn2,
    output wire uart_tx
);

    // --------------------------------------------------------------------
    // Reset generator (same as before)
    // --------------------------------------------------------------------
    wire rst_ext_n = ~rst_btn;

    reg [1:0] rst_sync;
    always @(posedge clk or negedge rst_ext_n) begin
        if (!rst_ext_n)
            rst_sync <= 2'b00;
        else
            rst_sync <= {rst_sync[0], 1'b1};
    end

    reg [15:0] por_cnt  = 16'd0;
    reg        por_done = 1'b0;
    always @(posedge clk or negedge rst_ext_n) begin
        if (!rst_ext_n) begin
            por_cnt  <= 16'd0;
            por_done <= 1'b0;
        end else if (!por_done) begin
            por_cnt  <= por_cnt + 16'd1;
            por_done <= &por_cnt;
        end
    end

    // internal active-low reset for both cores + peripherals
    wire rstn_int = rst_sync[1] & por_done;

    // --------------------------------------------------------------------
    // Core 0 bus (with UART + BRAM0 + mailbox0 + BTN2)
    // --------------------------------------------------------------------
    wire        mem0_valid;
    wire        mem0_instr;
    wire        mem0_ready;
    wire [31:0] mem0_addr;
    wire [31:0] mem0_wdata;
    wire [3:0]  mem0_wstrb;
    wire [31:0] mem0_rdata;

    // Core 1 bus (BRAM1 + mailbox1)
    // --------------------------------------------------------------------
    wire        mem1_valid;
    wire        mem1_instr;
    wire        mem1_ready;
    wire [31:0] mem1_addr;
    wire [31:0] mem1_wdata;
    wire [3:0]  mem1_wstrb;
    wire [31:0] mem1_rdata;

    // --------------------------------------------------------------------
    // PicoRV32 core 0  (talks to UART + mailbox + BRAM0 + BTN2)
    // --------------------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS      (0),
        .ENABLE_COUNTERS64    (0),
        .ENABLE_REGS_DUALPORT (0),
        .LATCHED_MEM_RDATA    (0),
        .TWO_STAGE_SHIFT      (1),
        .BARREL_SHIFTER       (0),
        .TWO_CYCLE_COMPARE    (0),
        .TWO_CYCLE_ALU        (0),
        .COMPRESSED_ISA       (0),
        .REGS_INIT_ZERO       (1),           // <<< thêm để tránh X trong mô phỏng
        .PROGADDR_RESET       (32'h0000_0000)
    ) cpu0 (
        .clk       (clk),
        .resetn    (rstn_int),
        .mem_valid (mem0_valid),
        .mem_instr (mem0_instr),
        .mem_ready (mem0_ready),
        .mem_addr  (mem0_addr),
        .mem_wdata (mem0_wdata),
        .mem_wstrb (mem0_wstrb),
        .mem_rdata (mem0_rdata),
        .irq       (32'b0),
        .eoi       ()
    );

    // --------------------------------------------------------------------
    // PicoRV32 core 1  (no UART, its own BRAM + mailbox)
    // --------------------------------------------------------------------
    picorv32 #(
        .ENABLE_COUNTERS      (0),
        .ENABLE_COUNTERS64    (0),
        .ENABLE_REGS_DUALPORT (0),
        .LATCHED_MEM_RDATA    (0),
        .TWO_STAGE_SHIFT      (1),
        .BARREL_SHIFTER       (0),
        .TWO_CYCLE_COMPARE    (0),
        .TWO_CYCLE_ALU        (0),
        .COMPRESSED_ISA       (0),
        .REGS_INIT_ZERO       (1),           // <<< thêm cho core1 luôn
        .PROGADDR_RESET       (32'h0000_0000)
    ) cpu1 (
        .clk       (clk),
        .resetn    (rstn_int),
        .mem_valid (mem1_valid),
        .mem_instr (mem1_instr),
        .mem_ready (mem1_ready),
        .mem_addr  (mem1_addr),
        .mem_wdata (mem1_wdata),
        .mem_wstrb (mem1_wstrb),
        .mem_rdata (mem1_rdata),
        .irq       (32'b0),
        .eoi       ()
    );

    // --------------------------------------------------------------------
    // Address decode
    //
    // Core0:
    //   0x0000_0000 - 0x0000_FFFF : BRAM0
    //   0x1000_0000              : UART (data/status)
    //   0x2000_0000 - 0x2000_0004: mailbox (core1 <-> core0)
    //   0x3000_0000              : BTN2 (read-only)
    //
    // Core1:
    //   0x0000_0000 - 0x0000_FFFF : BRAM1
    //   0x2000_0000 - 0x2000_0004: mailbox
    // --------------------------------------------------------------------
    wire sel0_bram = mem0_valid && (mem0_addr[31:16] == 16'h0000);
    wire sel0_uart = mem0_valid && (mem0_addr[31:12] == 20'h10000);
    wire sel0_mb   = mem0_valid && (mem0_addr[31:12] == 20'h20000);
    wire sel0_btn  = mem0_valid && (mem0_addr[31:12] == 20'h30000); // 0x3000_0xxx

    wire sel1_bram = mem1_valid && (mem1_addr[31:16] == 16'h0000);
    wire sel1_mb   = mem1_valid && (mem1_addr[31:12] == 20'h20000);

    // --------------------------------------------------------------------
    // BRAM0 (core0 program/data) - INIT_FILE "firmware0_new.mem"
    // --------------------------------------------------------------------
    wire        bram0_ready;
    wire [31:0] bram0_rdata;

    bram_64k #(.INIT_FILE("firmware0_new.mem")) bram0 (
        .clk   (clk),
        .rstn  (rstn_int),
        .valid (sel0_bram),
        .addr  (mem0_addr),
        .wdata (mem0_wdata),
        .wstrb (mem0_wstrb),
        .rdata (bram0_rdata),
        .ready (bram0_ready)
    );

    // --------------------------------------------------------------------
    // BRAM1 (core1 program/data) - INIT_FILE "firmware1_new.mem"
    // --------------------------------------------------------------------
    wire        bram1_ready;
    wire [31:0] bram1_rdata;

    bram_64k #(.INIT_FILE("firmware1_new.mem")) bram1 (
        .clk   (clk),
        .rstn  (rstn_int),
        .valid (sel1_bram),
        .addr  (mem1_addr),
        .wdata (mem1_wdata),
        .wstrb (mem1_wstrb),
        .rdata (bram1_rdata),
        .ready (bram1_ready)
    );

    // --------------------------------------------------------------------
    // UART core (exactly same as your working single-core design)
    // --------------------------------------------------------------------
    wire       u_tx_busy;
    wire [7:0] u_rx_data;
    wire       u_rx_valid;
    reg        u_tx_start;
    reg  [7:0] u_tx_data;

    uart_simple #(
        .CLK_HZ(CLK_HZ),
        .BAUD  (BAUD)
    ) UART (
        .clk      (clk),
        .rstn     (rstn_int),
        .rx       (uart_rx),
        .tx       (uart_tx),
        .tx_data  (u_tx_data),
        .tx_start (u_tx_start),
        .tx_busy  (u_tx_busy),
        .rx_data  (u_rx_data),
        .rx_valid (u_rx_valid)
    );

    // --------------------------------------------------------------------
    // UART MMIO regs (only for core0)
    //   0x1000_0000 : TXDATA/RXDATA
    //   0x1000_0004 : STATUS (bit0 = TX_READY, bit1 = RX_VALID)
    // --------------------------------------------------------------------
    reg [7:0] rx_hold;
    reg       rx_has_byte;

    always @(posedge clk) begin
        if (!rstn_int) begin
            rx_hold     <= 8'h00;
            rx_has_byte <= 1'b0;
        end else begin
            if (u_rx_valid) begin
                rx_hold     <= u_rx_data;
                rx_has_byte <= 1'b1;
            end
            // read of RXDATA clears the flag
            if (sel0_uart && (mem0_wstrb == 4'b0000) &&
                (mem0_addr[3:0] == 4'h0) && mem0_valid && mem0_ready)
                rx_has_byte <= 1'b0;
        end
    end

    reg [31:0] uart_rdata;
    reg        uart_ready;

    always @(posedge clk) begin
        if (!rstn_int) begin
            uart_ready <= 1'b0;
            u_tx_start <= 1'b0;
            u_tx_data  <= 8'h00;
        end else begin
            uart_ready <= 1'b0;
            u_tx_start <= 1'b0;
            if (sel0_uart && !uart_ready) begin
                if (mem0_wstrb != 4'b0000) begin
                    // write
                    if (mem0_addr[3:0] == 4'h0) begin
                        if (!u_tx_busy) begin
                            u_tx_data  <= mem0_wdata[7:0];
                            u_tx_start <= 1'b1;
                            uart_ready <= 1'b1;
                        end
                    end else begin
                        uart_ready <= 1'b1;
                    end
                end else begin
                    // read
                    if (mem0_addr[3:0] == 4'h0) begin
                        uart_rdata <= {24'h0, rx_hold};
                        uart_ready <= 1'b1;
                    end else if (mem0_addr[3:0] == 4'h4) begin
                        uart_rdata <= {30'h0, rx_has_byte, ~u_tx_busy};
                        uart_ready <= 1'b1;
                    end else begin
                        uart_rdata <= 32'h0;
                        uart_ready <= 1'b1;
                    end
                end
            end
        end
    end

    // --------------------------------------------------------------------
    // Simple 2-way mailbox between cores, mapped at 0x2000_0000
    //
    //  For BOTH cores:
    //    0x2000_0000 : MAILBOX_DATA (incoming data)
    //                  - read:  returns message from the *other* core and clears valid
    //                  - write: sends a message TO the other core
    //    0x2000_0004 : MAILBOX_STATUS
    //                  - bit0 = incoming_valid (1 = unread message available)
    //                  - other bits = 0
    // --------------------------------------------------------------------
    reg [31:0] core0_in_data;   // data waiting for core0 (written by core1)
    reg        core0_in_valid;

    reg [31:0] core1_in_data;   // data waiting for core1 (written by core0)
    reg        core1_in_valid;

    reg [31:0] mb0_rdata;
    reg        mb0_ready;

    reg [31:0] mb1_rdata;
    reg        mb1_ready;

    always @(posedge clk) begin
        if (!rstn_int) begin
            core0_in_data  <= 32'h0;
            core0_in_valid <= 1'b0;
            core1_in_data  <= 32'h0;
            core1_in_valid <= 1'b0;
            mb0_rdata      <= 32'h0;
            mb0_ready      <= 1'b0;
            mb1_rdata      <= 32'h0;
            mb1_ready      <= 1'b0;
        end else begin
            // default: not ready until we handle a transaction
            mb0_ready <= 1'b0;
            mb1_ready <= 1'b0;

            // ---------- Core0 mailbox port ----------
            if (sel0_mb && !mb0_ready) begin
                if (mem0_wstrb != 4'b0000) begin
                    // write from core0: send to core1
                    if (mem0_addr[3:0] == 4'h0) begin
                        core1_in_data  <= mem0_wdata;
                        core1_in_valid <= 1'b1;
                    end
                    mb0_ready <= 1'b1;
                end else begin
                    // read from core0
                    if (mem0_addr[3:0] == 4'h0) begin
                        mb0_rdata      <= core0_in_data;
                        core0_in_valid <= 1'b0;       // consume
                        mb0_ready      <= 1'b1;
                    end else if (mem0_addr[3:0] == 4'h4) begin
                        mb0_rdata      <= {31'h0, core0_in_valid};
                        mb0_ready      <= 1'b1;
                    end else begin
                        mb0_rdata      <= 32'h0;
                        mb0_ready      <= 1'b1;
                    end
                end
            end

            // ---------- Core1 mailbox port ----------
            if (sel1_mb && !mb1_ready) begin
                if (mem1_wstrb != 4'b0000) begin
                    // write from core1: send to core0
                    if (mem1_addr[3:0] == 4'h0) begin
                        core0_in_data  <= mem1_wdata;
                        core0_in_valid <= 1'b1;
                    end
                    mb1_ready <= 1'b1;
                end else begin
                    // read from core1
                    if (mem1_addr[3:0] == 4'h0) begin
                        mb1_rdata      <= core1_in_data;
                        core1_in_valid <= 1'b0;       // consume
                        mb1_ready      <= 1'b1;
                    end else if (mem1_addr[3:0] == 4'h4) begin
                        mb1_rdata      <= {31'h0, core1_in_valid};
                        mb1_ready      <= 1'b1;
                    end else begin
                        mb1_rdata      <= 32'h0;
                        mb1_ready      <= 1'b1;
                    end
                end
            end
        end
    end

    // --------------------------------------------------------------------
    // Simple button register for Core0 (BTN2 mapped at 0x3000_0000)
    // --------------------------------------------------------------------
    reg        btn_ready;
    reg [31:0] btn_rdata;
    reg        btn2_ff1, btn2_ff2;

    always @(posedge clk) begin
        if (!rstn_int) begin
            btn2_ff1  <= 1'b0;
            btn2_ff2  <= 1'b0;
            btn_ready <= 1'b0;
            btn_rdata <= 32'h0;
        end else begin
            // 2-FF synchronizer for btn2
            btn2_ff1 <= btn2;
            btn2_ff2 <= btn2_ff1;

            btn_ready <= 1'b0;
            if (sel0_btn) begin
                // read-only register: bit0 = trạng thái BTN2 đã sync
                if (mem0_wstrb == 4'b0000) begin
                    btn_rdata <= {31'b0, btn2_ff2};
                end
                btn_ready <= 1'b1;
            end
        end
    end

    // --------------------------------------------------------------------
    // Return path muxes for each core
    // --------------------------------------------------------------------
    assign mem0_ready = sel0_bram ? bram0_ready :
                        sel0_uart ? uart_ready  :
                        sel0_mb   ? mb0_ready   :
                        sel0_btn  ? btn_ready   :
                        (mem0_valid ? 1'b1 : 1'b0);

    assign mem0_rdata = sel0_bram ? bram0_rdata :
                        sel0_uart ? uart_rdata  :
                        sel0_mb   ? mb0_rdata   :
                        sel0_btn  ? btn_rdata   :
                        32'h0000_0000;

    assign mem1_ready = sel1_bram ? bram1_ready :
                        sel1_mb   ? mb1_ready   :
                        (mem1_valid ? 1'b1 : 1'b0);

    assign mem1_rdata = sel1_bram ? bram1_rdata :
                        sel1_mb   ? mb1_rdata   :
                        32'h0000_0000;

endmodule
