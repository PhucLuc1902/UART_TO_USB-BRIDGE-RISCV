# Makefile for PicoRV32 dual-core firmware
# Builds
#   firmware0.mem  (for core 0 UART + mailbox)
#   firmware1.mem  (for core 1 mailbox sender)

# Adjust this if your toolchain prefix is different
TOOLCHAIN_PREFIX = riscv64-unknown-elf-

CC      = $(TOOLCHAIN_PREFIX)gcc
OBJCOPY = $(TOOLCHAIN_PREFIX)objcopy

CFLAGS  = -march=rv32i -mabi=ilp32 -Os -ffreestanding -nostdlib -Wall -Wextra
LDFLAGS = -Wl,-Bstatic,-T,sections.ld,--strip-debug

# Default target
all: firmware0.mem firmware1.mem

# New firmware with GPIO support
new: firmware0_new.mem firmware1_new.mem

# Simple test target
simple_test.mem: simple_test.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 $< $@

simple_test.elf: simple_start.o simple_test.o sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ simple_start.o simple_test.o

simple_start.o: simple_start.S
	$(CC) $(CFLAGS) -c -o $@ $<

simple_test.o: simple_test.c
	$(CC) $(CFLAGS) -c -o $@ $<

# ---------- Core 0 firmware ----------

firmware0.elf: start.o firmware0.o sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.o firmware0.o

firmware0.mem: firmware0.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --reverse-bytes=4 --remove-section=.comment $< $@

# ---------- Core 1 firmware ----------

firmware1.elf: start.o firmware1.o sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.o firmware1.o

firmware1.mem: firmware1.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --reverse-bytes=4 --remove-section=.comment $< $@

# ---------- Common object files ----------

start.o: start.S
	$(CC) $(CFLAGS) -c -o $@ $<

firmware0.o: firmware0.c
	$(CC) $(CFLAGS) -c -o $@ $<

firmware1.o: firmware1.c
	$(CC) $(CFLAGS) -c -o $@ $<

# ---------- New firmware with GPIO ----------

firmware0_new.elf: start.o firmware0_new.o sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.o firmware0_new.o

firmware0_new.mem: firmware0_new.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --reverse-bytes=4 --remove-section=.comment $< $@

firmware1_new.elf: start.o firmware1_new.o sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ start.o firmware1_new.o

firmware1_new.mem: firmware1_new.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --reverse-bytes=4 --remove-section=.comment $< $@

firmware0_new.o: firmware0_new.c
	$(CC) $(CFLAGS) -c -o $@ $<

firmware1_new.o: firmware1_new.c
	$(CC) $(CFLAGS) -c -o $@ $<

# ---------- Housekeeping ----------

clean:
	rm -f *.o *.elf *.mem *.bin

test: simple_test.mem

# Ultra-minimal test - pure assembly like your working version
minimal.mem: minimal.elf
	$(OBJCOPY) -O verilog --verilog-data-width=4 --change-section-address .memory=0 $< $@

minimal.elf: minimal.o sections.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ minimal.o

minimal.o: minimal.S
	$(CC) $(CFLAGS) -c -o $@ $<

minimal_test: minimal.mem

.PHONY: all clean
