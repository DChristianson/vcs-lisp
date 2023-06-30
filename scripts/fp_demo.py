


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

def bits2float(bits):
    sign = 1 if '0' == bits[1] else -1
    exponent = int(bits[2:6], 2) - 14
    mantissa = int('1' + bits[6:], 2)
    return sign * float(2.0 ** exponent) * float(mantissa)

for i in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 99]:
    b = format(i, 'b')
    bits = fp_conv(1, 0, i)
    f = bits2float(bits)
    print(f'{i} {b} {bits} {f}')

# for i in range(0, 2 ** 15):
#     bits = format(i, f'016b')
#     f = bits2float(bits)
#     print(f'{i} {bits} {f}')
