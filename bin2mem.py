# bin2mem.py
# usage: python bin2mem.py firmware0.bin firmware0.mem
import sys

if len(sys.argv) != 3:
    print("Usage: python bin2mem.py input.bin output.mem")
    sys.exit(1)

inp = sys.argv[1]
outp = sys.argv[2]

data = open(inp, "rb").read()
words = []

for i in range(0, len(data), 4):
    chunk = data[i:i+4]
    # pad cho đủ 4 byte
    if len(chunk) < 4:
        chunk += b'\x00' * (4 - len(chunk))
    w = chunk[0] | (chunk[1] << 8) | (chunk[2] << 16) | (chunk[3] << 24)
    words.append(w)

with open(outp, "w") as f:
    for w in words:
        f.write("%08x\n" % w)

print("Wrote", len(words), "words to", outp)
