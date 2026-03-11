/* link.ld */
ENTRY(main)

SECTIONS
{
    /* Địa chỉ reset/PC của core bạn – sửa nếu khác */
    . = 0x00000000;

    .text : {
        *(.text*)
        *(.rodata*)
    }

    .data : {
        *(.data*)
    }

    .bss : {
        *(.bss*)
        *(COMMON)
    }
}
