# junkyard script to scrape a DASM .lst file to see where space is being used

import re
import sys

reserved_labels = set(['ENDIF', 'REPEND', 'END', 'ASL', 'LSR', 'ROR', 'ROL', 'ROR', 'RTS', 'CLC', 'SEC', 'ENDM', 'TAX', 'PLA', 'TXA', 'TAY', 'TXS'])

line_pattern = r'^\s+\d+\s+([a-f0-9]+)\s+([^;=]*)(;.*)?$'
label_pattern = r'^([a-zA-Z][a-zA-Z0-9_]+)\s*$'
data_pattern = r'^(([a-f0-9][a-f0-9])( [a-f0-9][a-f0-9])*)([*]\s+\S+\s+(([#$%]*[a-f0-9]+)(,\s*[#$%]*[a-f0-9]+)*))?\s*'

current_label = ''
current_address = 'f000'
addresses = {current_label: set()}
data = {current_label: []}
for line in sys.stdin:
    m = re.match(line_pattern, line)
    if m:
        current_address =int(m.group(1), 16)
        n = re.match(label_pattern, m.group(2))
        if n:
            matched_label = n.group(1)
            if matched_label.upper() in reserved_labels:
                continue
            current_label = matched_label
            if current_label in addresses:
                raise Exception(f'saw {current_label} twice')
            addresses[current_label] = set()
            data[current_label] = []
        d = re.match(data_pattern, m.group(2))
        if d:
            if d.group(4):
                data_bytes = [i for i in d.group(5).split(',')]
            else:
                data_bytes = [int(i, 16) for i in d.group(1).split(' ')]
            data[current_label] += data_bytes
        addresses[current_label].add(current_address)

ordering = sorted([(label, min(address), max(address)) for label, address in addresses.items()], key = lambda x : x[1])

total = 0
last_end = 0xf000
for label, start, end in ordering:
    num_bytes = len(data[label])
    total += num_bytes
    gap = start - last_end
    print(f'{label}\t{hex(start)}:{hex(end)}\t{num_bytes}\t{gap}')
    last_end = start + num_bytes
print(total)