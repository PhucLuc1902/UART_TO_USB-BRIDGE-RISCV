
// Core0: UART + BTN0 "Hi!"
// Sau đó mỗi lần nhấn BTN2 (bit0 BTN_REG) thì in "Hi!\r\n"

#include <stdint.h>


#define UART_BASE       0x10000000u
#define UART_REG_DATA   (*(volatile uint32_t *)(UART_BASE + 0x0))
#define UART_REG_STATUS (*(volatile uint32_t *)(UART_BASE + 0x4))
#define UART_TX_READY   (1u << 0)   // bit0

#define BTN_BASE        0x30000000u
#define BTN_REG         (*(volatile uint32_t *)(BTN_BASE + 0x0)) // bit0 = BTN2

static void uart_putc(char c) {
    // Đợi cho tới khi TX thật sự rảnh
    while ((UART_REG_STATUS & UART_TX_READY) == 0) {
        // busy-wait
    }
    UART_REG_DATA = (uint32_t)(uint8_t)c;
}

static void uart_puts(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

// Delay để debounce nút 
static void delay_cycles(volatile unsigned int n) {
    while (n--) {
        __asm__ volatile ("nop");
    }
}

//--------------------------------------------------------------------
// main
//--------------------------------------------------------------------
int main(void) {
    // Banner khởi động 
    uart_puts("Core0: Hello from PicoRV32 Single-core!\r\n");
    uart_puts("Core0: Press BTN0 to print Hi!...\r\n");

    unsigned int last_b = (BTN_REG & 1u) ? 1u : 0u;

    for (;;) {
        // Đọc BTN2: bit0 của BTN_REG
        unsigned int cur_b = (BTN_REG & 1u) ? 1u : 0u;

        // Phát hiện cạnh lên: 0 -> 1
        if (cur_b && !last_b) {
            // In "Hi!\r\n"
            uart_puts("Hi!\r\n");

            // Debounce đơn giản
            delay_cycles(50000);
        }

        last_b = cur_b;
    }

    // Không bao giờ tới đây
    return 0;
}
