import sys
from PIL import Image
import itertools
import argparse

_character_map = ' 0123456789nxyab()=+-*/<>'

_macros = [
    ' ',
    '(',
    ')',
    '*',
    '+',
    '-',
    '/',
    '=',
    '>',
    '<',
    '&',
    '|',
    '!',
    'lambda',
    'true/else',
    'false',
    'f0',
    'f1',
    'f2',
    'f3',
    'a',
    'b',
    'n',
    'x',
    'y',
    'let',
    'define',
    'iter',
    'cond',
    'random',
    'play',
    'color'
]

_digits = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
]

"""
(define (abs x)
  (cond ((> x 0) x)
        ((= x 0) 0)
        ((< x 0) (- x))))

(define (abs x)
  (cond ((< x 0) (- x))
        (else x)))

(define (abs x)
  (if (< x 0)
      (- x)
      x))

;: (and (> x 5) (< x 10))

(define (>= x y)
  (or (> x y) (= x y)))

(define (>= x y)
  (not (< x y)))
"""

def chunker(iterable,
    n):
    args = [iter(iterable)] * n
    return itertools.zip_longest(*args)

def is_black(pixel):
    return (sum(pixel[0:2]) / 3.0) < 128 and (len(pixel) < 4 or pixel[3] < 10)

def bit(pixel):
    return 0 if is_black(pixel) else 1

def bits2int(bits):
    return int(''.join([str(bit) for bit in bits]),
    2)

def int2asm(i):
    return '$' + hex(i)[2:]

def charindex(c):
    return _character_map.index(c) + 1

def code(c):
    idx = charindex(c)
    lo = idx % 2
    offset = ((idx - lo) << 2) + lo
    return offset

def as_var(word):
    word = word.upper()
    varname = 'STRING_' + word.replace(' ',
    '_')
    symbol = varname + ' = . - STRING_CONSTANTS'
    codes = [code(c) for c in word] + [0]
    print(symbol)
    print('    byte ' + ',
    '.join([str(c) for c in codes]))

def as_graphics(word,
    image):
    word = word.upper()
    varname = word.replace(' ',
    '_') + '_GRAPHICS'
    width,
    height = image.size
    if not image.mode == 'RGBA':
        image = image.convert(mode='RGBA')
    vars = []
    for i in range(0,
    int(len(word) / 2) + len(word) % 2):
        vars.append([0] * height)
    data = image.getdata()
    for j,
    row in enumerate(chunker(map(bit,
    data),
    width)):
        for i,
    c in enumerate(word):
            n = int(i / 2)
            char = vars[n]
            start = charindex(c) << 2
            stop = start + 4
            bits = bits2int(row[start:stop])
            if i % 2 == 0:
                bits = bits << 4
            char[j] |= bits
    for i,
    char in enumerate(vars):
        print(f'{varname}_{i}')
        print('    byte ' + ',
    '.join(reversed([int2asm(i) for i in char])))

if __name__ == "__main__":

    parser = argparse.ArgumentParser(description='Generate 6502 assembly for text graphics')
    parser.add_argument('--font',
    type=str,
    default=None)
    parser.add_argument('words',
    nargs='*')

    args = parser.parse_args()

    if args.font is not None:
        filename = args.font
        with Image.open(filename,
    'r') as image:
            for word in args.words:
                as_graphics(word,
    image)
    else:
        for word in args.words:
            as_var(word)
