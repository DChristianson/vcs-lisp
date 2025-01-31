#
# Generate Sprite graphics for the VCS
# can generate 8 bit, 24, or 48 bit sprites
# 8 bit supports converting higher res images
# by also manipulating control and hmov registers
#

import hashlib
import sys
import subprocess
import os
from os import path
import glob
from PIL import Image
import itertools
from collections import namedtuple
import queue
from dataclasses import dataclass, field
import argparse
from io import BytesIO
import base64
import json
 
explicit_zero = False

def pairwise(iterable):
    a, b = itertools.tee(iterable)
    next(b, None)
    return zip(a, b)

def chunker(iterable, n):
    args = [iter(iterable)] * n
    return itertools.zip_longest(*args)

def aseprite_save_as(input, output):
    print(f'converting: {input} -> {output}')
    out = subprocess.run([f'aseprite', '-b', input, '--save-as', output])
    out.check_returncode()


def is_black(pixel):
    return (sum(pixel[0:2]) / 3.0) < 128 and (len(pixel) < 4 or pixel[3] < 10)

def bit(pixel):
    return 0 if is_black(pixel) else 1

def bits2int(bits):
    return int(''.join([str(bit) for bit in bits]), 2)

def int2bas(i):
    return '%' + format(i, '#010b')[2:]

def int2asm(i):
    return '$' + hex(i)[2:]

def int2arr(i):
    for b in range(0, 8):
        yield i & 1
        i = i >> 1

def anybits(bits):
    return 1 if sum(bits) > 0 else 0

def reduce_bits(bits, n):
    return [anybits(chunk) for chunk in chunker(bits, n)]

def complement(n, b):
    if n >= 0:
        return n
    return b + n

def hmove(n):
    return complement(-n, b=16) * 16

CompressedBits = namedtuple('CompressedBits', ['scale', 'start_index', 'end_index', 'bits'])

def get_bounds(bits):
    start_index = len(bits)
    end_index = -1
    for i, b in enumerate(bits):
        if 0 == b:
            continue
        if i < start_index:
            start_index = i
        if i > end_index:
            end_index = i
    return start_index, end_index

# compress an array of bits to a single byte at single, double or quad resolution
# return tuple of 
def compress8(bits):
    start_index, end_index = get_bounds(bits)
    bits = bits[start_index:end_index + 1]
    bit_length = len(bits)
    if (bit_length <= 8):
        return CompressedBits(1, start_index, end_index, bits)
    if (bit_length <= 16):
        pad = bit_length % 2
        bits = bits + ([0] * pad)
        end_index += pad
        return CompressedBits(2, start_index, end_index, reduce_bits(bits, 2))
    pad = 4 - bit_length % 4
    bits = bits + ([0] * pad)
    end_index += pad
    return CompressedBits(4, start_index, end_index, reduce_bits(bits, 4))

def nusize(i):
    if i == 1:
        return 0
    return i + 3

def paddings(a):
    nbits = len(a.bits)
    pad = 8 - nbits
    for lpad in range(0, pad + 1):
        rpad = pad - lpad
        bits = [0] * lpad + a.bits + [0] * rpad
        start_index = a.start_index - lpad * a.scale
        end_index = a.start_index + 8 * a.scale
        yield start_index, end_index, bits

def is_legal_hmove(i):
    return i < 8 and i > -9

@dataclass(order=True)
class SolutionItem:
    priority: int
    steps: object = field(compare=False)
    frontier: object = field(compare=False)

def find_offset_solution(compressedbits, solve_left=True, solve_right=False):
    solutions = queue.PriorityQueue()
    base_priority = 10 * (len(compressedbits) - 1)
    max_depth = len(compressedbits)

    leading_steps = []
    while len(compressedbits) > 0:
        first_nonzero_row = compressedbits[0]
        compressedbits = compressedbits[1:]
        if len(first_nonzero_row.bits) > 0:
            break
        leading_steps.append((0, 0, (0, 0, [0] * 8)))

    for a in paddings(first_nonzero_row):
        # prefix = list(itertools.takewhile(lambda b: b < 1, a[2]))
        # cost = base_priority + len(prefix)
        cost = base_priority
        solutions.put(SolutionItem(cost, leading_steps + [(0, 0, a)], compressedbits))

    while not solutions.empty():
        item = solutions.get()
        _, _, a = item.steps[-1]
        b = item.frontier[0]
        max_depth = min(max_depth, len(item.frontier))
        if len(b.bits) == 0:
            candidates = [(a[0], a[1], [0] * 8)]
        else:
            candidates = paddings(b)
        for candidate in candidates:
            lmove = candidate[0] - a[0]
            rmove = candidate[1] - a[1]
            if solve_left and not is_legal_hmove(lmove):
                continue
            if solve_right and not is_legal_hmove(rmove):
                continue
            next_step = (lmove, rmove, candidate)
            next_solution = item.steps + [next_step]
            if len(item.frontier) == 1:
                return next_solution
            else:
                # if we want to keep on one side
                # prefix = list(itertools.takewhile(lambda b: b < 1, candidate[2]))
                # cost = item.priority + len(prefix)
                # if want to minimize HMOV...
                cost = item.priority + abs(lmove) #(abs(abs(lmove) - abs(rmove)) ** 2)
                solutions.put(SolutionItem(cost, next_solution, item.frontier[1:]))
    raise Exception(f'cannot find solution at depth {max_depth}')

def bitb(b):
    return '1' if b > 0 else '.'

def asmfmt(name, vars, symbols, fp):
    fp.write(f'{name.upper()}\n')
    for i, col in enumerate(vars):
        if symbols is not None:
            fp.write(f'{symbols[i]}\n')
        value = ','.join([int2asm(word) for word in reversed(col)])
        fp.write(f'    byte {value}; {len(col)}\n')

def basfmt(name, vars, symbols, fp):
    fp.write(f'{name}:\n')
    for n, col in enumerate(vars):
        if symbols is not None:
            fp.write(f'{symbols[n]}\n')
        for i in col:
            fp.write(f'    {int2bas(i)}\n')

def make_transparent(image):
    rgba = image.convert("RGBA")
    data = rgba.load()
    width, height = image.size
    for y in range(height):
        for x in range(width):
            if data[x, y] == (0, 0, 0, 255):
                data[x, y] = (255, 255, 255, 0)
            # elif data[x, y] == (255, 255, 255, 255):
            #     data[x, y] = (0, 0, 0, 255)
    return rgba

def urlfmt(name, vars, symbols, fp):
    images = []
    for n, col in enumerate(vars):
        meta = {}
        if symbols is not None:
            meta['symbol'] = symbols[n]
        buffer = bytes([i.to_bytes(1, 'big')[0] for i in col])
        image = make_transparent(Image.frombytes('1', (8, len(col)), buffer))
        mem = BytesIO() 
        image.save(mem, 'png')
        data64 = str(base64.b64encode(mem.getvalue()), 'UTF-8')
        meta['src'] = 'data:image/png;base64,' + data64
        images.append(meta)
    if len(images) > 1:
        json.dump({'name': name, 'images': images}, fp, indent=4)
    else:
        json.dump({'name': name, **images[0]}, fp, indent=4)
    fp.write('\n')

def pngfmt(name, vars, symbols, fp):
    nvars = len(vars)
    for n, col in enumerate(vars):
        filename = f'{name}_{n}' if nvars > 1 else name
        if symbols is not None:
            filename = symbols[n]
        buffer = bytes([i.to_bytes(1, 'big')[0] for i in col])
        image = make_transparent(Image.frombytes('1', (8, len(col)), buffer))
        path = f'data/{filename}.png'
        image.save(path, 'png')
        fp.write(f'saving {path}\n')

formats = {
    'asm': asmfmt,
    'bas': basfmt,
    'url': urlfmt,
    'png': pngfmt,
}

# find offsets for a missile (enam)
def emit_varmissile(varname, image, fp, reverse=False, mirror=False, fmt=asmfmt, debug=False):
    width, _ = image.size
    if not image.mode == 'RGBA':
        image = image.convert(mode='RGBA')
    data = image.getdata()
    rows = chunker(map(bit, data), width)
    if reverse:
        rows = [tuple(reversed(row)) for row in rows]
    if mirror:
        rows = reversed(list(rows))

    bounds = list([get_bounds(row) for row in rows])
    offsets = [0] * len(bounds)
    enable = [0] * len(bounds)

    last_start_index = -1
    last_start_row = -1
    for i, (start_index, end_index) in enumerate(bounds):
        if start_index > end_index:
            continue
        if last_start_row == -1:
            last_start_index = start_index 
        if start_index < end_index:
            enable[i] = 2
        dx = start_index - last_start_index
        dy = i - last_start_row
        ix = float(dx) / dy
        D = 0
        while True:
            last_start_row += 1
            if last_start_row == i:
                offsets[i] = dx
                last_start_index = start_index
                break
            D += ix
            step = int(D)
            if step != 0:
                offsets[last_start_row] = step
                dx -= step
                D = D - step

    ctrl = list([hmove(offset) + size for offset, size in zip(offsets, enable)])

    # write output
    for name, col in [('ctrl', ctrl)]:
        fmt(f'{varname}_{name}', [col], None, fp)

    if debug:
        # diagnostic output
        cumulative_offset = 0
        for (start_index, end_index), offset, enable in zip(bounds, offsets, enable):
            char = '*' if enable > 0 else '.'
            pad = ' ' * (24 + cumulative_offset)
            fp.write(f';  {offset:03d}: {pad}{char} - ({start_index}:{end_index})\n')
            cumulative_offset += offset
 

# variable resolution sprite
def emit_varsprite8(varname, image, fp, reverse=False, mirror=False, fmt=asmfmt, debug=False):
    width, _ = image.size
    if not image.mode == 'RGBA':
        image = image.convert(mode='RGBA')
    data = image.getdata()
    rows = chunker(map(bit, data), width)
    if reverse:
        rows = [tuple(reversed(row)) for row in rows]
    if mirror:
        rows = reversed(list(rows))

    compressedbits = list([compress8(list(row)) for row in rows])
    solution = find_offset_solution(compressedbits, solve_left=True)

    left_delta = list([step[0] for step in solution[1:]] + [0])
    padded_bits = list([step[2][2] for step in solution])

    nusizes = list([ nusize(cb.scale) for cb in compressedbits])
    ctrl = list([hmove(offset) + size for offset, size in zip(left_delta, nusizes)])
    graphics = list([bits2int(bits) for bits in padded_bits])

    # write output
    for name, col in [('ctrl', ctrl), ('graphics', graphics)]:
        fmt(f'{varname}_{name}', [col], None, fp)

    if debug:
        # diagnostic output
        cumulative_offset = 0
        for offset, scale, bits in zip(left_delta, [cb.scale for cb in compressedbits], padded_bits):
            pad = ' ' * (24 + cumulative_offset)
            fp.write(f'; {offset:03d}: {pad}{"".join([bitb(b) * scale for b in bits])}\n')
            cumulative_offset += offset
 
# multi-player sprite
def emit_spriteMulti(varname, image, fp, bits=24, fmt=asmfmt, symbols=None):
    width, height = image.size
    if not image.mode == 'RGBA':
        image = image.convert(mode='RGBA')
    data = image.getdata()
    cols = int(bits / 8)
    vars = []
    for i in range(0, cols):
        vars.append([])
    for i, word in enumerate([bits2int(chunk) for chunk in chunker(map(bit, data), 8)]):
        vars[i % cols].append(word)
    fmt(varname, vars, symbols, fp)

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Generate 6502 assembly for sprite graphics')
    parser.add_argument('--format', type=str, choices=['asm', 'bas', 'url', 'png'], default='asm')
    parser.add_argument('--reverse', type=bool, default=False)
    parser.add_argument('--mirror', type=bool, default=False)
    parser.add_argument('--debug', type=bool, default=False)
    parser.add_argument('--bits', type=int, choices=[1] + list(range(8, 8 * 32 + 1, 8)), default=8)
    parser.add_argument('--tile_y', type=int, default=-1)
    parser.add_argument('--tile_x', type=int, default=-1)
    parser.add_argument('--symfile', type=str, default=None)
    parser.add_argument('filenames', nargs='*')

    args = parser.parse_args()

    sprites = {}
    
    for filename in args.filenames:
        spritename, ext = os.path.splitext(path.basename(filename))
        aseprite_save_as(filename, f'data/{spritename}_001.png')
        sprites[spritename] = sorted(list(glob.glob(f'data/{spritename}_*.png')))

    symbols = None
    if args.symfile is not None:
        with open(args.symfile) as fp:
            symbols = list([line.strip() for line in fp.readlines()])

    fmt = formats[args.format]
    out = sys.stdout
    seen = {}
    for spritename, files in sprites.items():
        for i, filename in enumerate(files):
            with Image.open(filename, 'r') as base_image:
                width, height = base_image.size
                images = []
                if args.tile_x > 0 or args.tile_y > 0:
                    if args.tile_x <= 0:
                        args.tile_x = width
                    if args.tile_y <= 0:
                        args.tile_y = height
                    byteswide = int(max(8, args.tile_x) / 8)
                    for r in range(0, height, args.tile_y):
                        for s in range(0, width, args.tile_x):
                            box = (s, r, s + args.tile_x, r + args.tile_y)
                            print(box, byteswide, len(symbols))
                            i = base_image.crop(box)
                            if args.tile_x < 8:
                                args.bits = 8
                                i_x = Image.new('RGBA', (8, args.tile_y), (0, 0, 0, 0))
                                i_x.paste(i, (8 - args.tile_x, 0))
                                i = i_x
                            print(i.size, symbols[0:byteswide])
                            images.append((i, symbols[0:byteswide]))
                            symbols = symbols[byteswide:]
                else:
                    images.append((base_image, symbols))
                for image, symbols in images:
                    varname = f'{spritename}_{i}'
                    if len(symbols) == 1:
                        varname = symbols[0]
                        symbols = None
                    md5 = hashlib.md5(image.tobytes())
                    digest = md5.hexdigest()
                    if digest not in seen.keys():
                        seen[digest] = varname
                    else:
                        out.write(f'{varname} = {seen[digest]}\n')
                        continue
                    if args.bits >= 8:
                        emit_spriteMulti(varname, image, out, bits=args.bits, fmt=fmt, symbols=symbols)
                    elif args.bits == 1:
                        emit_varmissile(varname, image, out, reverse=args.reverse, mirror=args.mirror, fmt=fmt, debug=args.debug)
                    else:
                        emit_varsprite8(varname, image, out, reverse=args.reverse, mirror=args.mirror, fmt=fmt, debug=args.debug)

