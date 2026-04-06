// start.S - minimal startup for PicoRV32 bare metal
// Linked at address 0x00000000 by sections.lds

    .section .text
    .globl _start
    .globl main
    .globl trap_handler
    .extern _stack_top

_start:
    // Set stack pointer to top of memory (word-aligned)
    la   sp, _stack_top
    andi sp, sp, -4  // Ensure word alignment

    // call C main()
    jal  ra, main

1:
    // if main ever returns, just loop forever
    j    1b

// Simple trap handler - just loop forever to indicate trap occurred
trap_handler:
    // You could add debug output here if you have UART access
    j    trap_handler
