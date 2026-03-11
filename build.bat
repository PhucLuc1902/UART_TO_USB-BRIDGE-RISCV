@echo off
setlocal

rem === PATH tới thư mục bin của toolchain ===
set PATH=D:\RISCV\SysGCC\bin;%PATH%

echo [1] Compile C -> firmware1.elf
riscv64-unknown-elf-gcc ^
  -march=rv32i -mabi=ilp32 ^
  -Os -ffreestanding -nostdlib -nostartfiles ^
  -Wl,-Bstatic,-Ttext=0x00000000,-Tdata=0x00001000 ^
  -o firmware1.elf firmware1.c -lgcc

if errorlevel 1 (
  echo Compile error
  pause
  exit /b 1
)

echo [2] ELF -> BIN
riscv64-unknown-elf-objcopy -O binary firmware1.elf firmware1.bin

if errorlevel 1 (
  echo Objcopy error
  pause
  exit /b 1
)

echo [3] BIN -> MEM (Verilog $readmemh format)
python bin2mem.py firmware1.bin firmware1.mem

if errorlevel 1 (
  echo Python / mem convert error
  pause
  exit /b 1
)

echo [OK] Done. Created firmware1.mem
pause
