/* sections.lds - simple linker script for bare-metal PicoRV32
 *
 * One flat memory region called "mem" starting at 0x00000000.
 * We place everything (.text, .data, .bss, etc.) into a single
 * output section called .memory.
 */

MEMORY
{
    /* 64 KiB total memory for each core (adjust if you like) */
    mem : ORIGIN = 0x00000000, LENGTH = 0x00010000
}

/* Symbols we want to see from C/assembly */
PROVIDE(_stack_top = ORIGIN(mem) + LENGTH(mem));

SECTIONS
{
    .memory :
    {
        /* start of image */
        . = 0x00000000;

        /* put startup code (start.o) first */
        KEEP(start*(.text));

        /* then the rest of the code and constants */
        *(.text*)
        *(.rodata*)
        *(.srodata*)

        /* any explicit data / bss / common */
        *(.data*)
        *(.sdata*)
        *(.bss*)
        *(.sbss*)
        *(COMMON)

        /* end symbol (optional, but sometimes handy) */
        end = .;

        /* align to word boundary */
        . = ALIGN(4);
    } > mem
}
