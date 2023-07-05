
import math

def fp_conv(sign, exponent, mantissa, ep=4, mp=11, bias=14):
    if 0 == mantissa:
        return '0' * 16
    mbits = format(mantissa, 'b')
    diff = mp - len(mbits)
    if diff > 0:
        exponent -= diff
        mbits = mbits + ('0' * diff) 
    if diff < 0:
        exponent += diff
        mbits = mbits[0:mp]
    exponent += bias
    mbits = mbits[1:]
    sbits = '0' if sign > 0 else '1'
    ebits = format(exponent, f'0{ep}b')
    return '0' + sbits + ebits + mbits

def int2bits(i):
    sign = 1 if i > 0 else -1
    exponent = 0
    mantissa = i
    return fp_conv(sign, exponent, mantissa)

def float2bits(f):
    sign = 1 if f > 0 else -1
    mantissa, exponent = math.frexp(f)
    print(mantissa, exponent)
    mantissa = abs(int(mantissa * 1024))
    exponent -= 10
    return fp_conv(sign, exponent, mantissa)

def bits2float(bits, bias=14):
    sign = 1 if '0' == bits[1] else -1
    exponent = int(bits[2:6], 2) - bias
    mantissa = int('1' + bits[6:], 2)
    return sign * float(2.0 ** exponent) * float(mantissa)

for i in [-0.5, 0.5, 0, -1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 99]:
    bits = int2bits(int(i))
    f = bits2float(bits)
    print(f'{i} {bits} {f}')

for i in [-0.5, 0.5, 0, -1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 99]:
    bits = float2bits(i)
    f = bits2float(bits)
    print(f'{i} {bits} {f}')

# for i in range(0, 2 ** 14):
#     bits = format(i, f'016b')
#     if bits[2:6] in ['1111', '0000']:
#         continue
#     f = bits2float(bits)
#     print(f'{i} {bits} {f}')
