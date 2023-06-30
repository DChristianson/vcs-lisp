#
# convert lisp code into vcs lisp binary
#

import sys

_symbols = [
    '',
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
    'if',
    'f0',
    'f1',
    'f2',
    'f3',
    'a0',
    'a1',
    'a2',
    'a3',
    '0',
    '1',
    '2'
]

_quote = '"\''
_whitespace = ' \t\r\n'
_openclose = '()'
_comment = ';'

# 
class Null:

    def __new__(cls, *args, **kwargs):
        try:
            if not cls._instance:
                raise Exception()
        except:
            cls._instance = super(Null, cls).__new__(cls, *args, **kwargs)
        return cls._instance

    def isref(self):
        False
    
    def ref(self):
        return '%00000000'
    
class Digit:

    def __init__(self, value):
        self.value = value

    def isref(self):
        False
    
    def ref(self):
        return '%' + format(self.value, '08b')
    

#
class Symbol:

    def __init__(self, address, name):
        self.address = address
        self.token = name

    def isref(self):
        return False

    def ref(self):
        return '%' + format(0xc0 | self.address, '08b')

#
class Pair:

    def __init__(self, address):
        self.address = address
        self.car = Null()
        self.cdr = Null()

    def isref(self):
        return True

    def ref(self):
        return '%' + format(0x80 | self.address, '08b')

    def code(self):
        return f'byte {self.car.ref()},{self.cdr.ref()} ;{self.address}'

#
class Heap:

    def __init__(self, size):
        self.size = size
        self.cells = list([Pair(index * 2) for index in range(0, size)])
        for i in range(len(self.cells) - 1):
            self.cells[i].cdr = self.cells[i + 1]
        self.free = self.cells[0]
    
    def alloc(self):
        next = self.free
        self.free = next.cdr
        next.cdr = Null()
        self.size = self.size = 1
        return next

def tokenize(stream):
    for line in stream:
        quoted = False
        token = ''
        for i, c in enumerate(line):
            if quoted:
                if c in _quote:
                    quoted = False
                continue
            elif c in _quote:
                quoted = True
                if '' != token:
                    yield token
                    token = ''
                continue
            if c in _openclose:
                if '' != token:
                    yield token
                    token = ''
                yield str(c)
                continue
            if c in _whitespace:
                if '' != token:
                    yield token
                    token = ''
                continue
            if c in _comment:
                break
            token += c
        if '' != token:
            yield token
            token = ''

def parse(tokens):
    root = []
    stack = [root]
    for token in tokens:
        if '(' == token:
            l = []
            stack[-1].append(l)
            stack.append(l)
        elif ')' == token:
            stack.pop()
        else:
            stack[-1].append(token)
    return root

def compile_exp(exp, heap, symtab):
    if isinstance(exp, list):
        if len(exp) == 0:
            return Null()
        else:
            p = heap.alloc()
            p.car = compile_exp(exp[0], heap, symtab)
            p.cdr = compile_exp(exp[1:], heap, symtab)
            return p
    else:
        try:
            return symtab[exp]
        except:
            value = float(exp)
            p = heap.alloc()
            p.car = Digit((int(value) & 0x0fff) >> 8)
            p.cdr = Digit(int(value) & 0xff)
            return p

def compile_decl(decl, heap):
    symtab = dict({name: Symbol(i, name) for i, name in enumerate(_symbols)})
    args = decl[1]
    for i, arg in enumerate(args[1:]):
        symtab[arg] = symtab['a' + str(i)]
    body = decl[2]
    return args, compile_exp(body, heap, symtab)
        
ast = parse(tokenize(sys.stdin))

vars = {}
heap = Heap(32)
for node in ast:
    args, program = compile_decl(node, heap)
    vars[args[0]] = program.ref()

# emit program
indent = ' ' * 4 * 3
for var, ref in vars.items():
    print(f'{indent}lda #{ref}');
    print(f'{indent}sta {var}');

for pair in heap.cells:
    if pair.car == Null():
        break
    print(f'{indent}{pair.code()}')  
print('')

