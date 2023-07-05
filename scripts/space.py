import re
import sys

last = -1
free = 0
for line in sys.stdin:
    try:
        row = re.split(' +', line)
        line_number = int(row[1])
        addr = int(row[2], 16)
    except:
        continue
    if last < 0 and addr == 65536:
        continue
    if last > 0:
        delta = addr - last
        print(row[0], row[1], last, addr, delta, free)
        free += delta
    last = addr

print(free)
