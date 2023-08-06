import random
import math


r = random.Random(17)


# generate maze of length n
def generate_simple(n):
    m = [0] * n
    nodes = [(i, r.random()) for i in range(1, n-1)]
    nodes = [i for (i, r) in sorted(nodes, key= lambda x: x[1])]
    current = 0
    while len(nodes) > 0:
        next = nodes.pop()
        value = abs(next - current)
        m[current] = value
        current = next
    value = n - 1 - current
    m[current] = value
    return m

# generate maze of length n
def generate_stack(n, d=9):
    d = n - 2 if n < d + 1 else d 
    v = [0] * n
    scores = [1] * n
    stack = [0]
    while len(stack) > 0:
        current = stack.pop()
        selected = None
        selected_score = 0
        selected_cells = []
        for j in range(1, d + 1):
            score = r.random()
            cells = []
            down_candidate = current - j
            if down_candidate >=0 and 0 == v[down_candidate]:
                cells.append(down_candidate)
                score += scores[down_candidate]
                scores[down_candidate] += 1
            up_candidate = current + j
            if up_candidate < n and 0 == v[up_candidate]:
                cells.append(up_candidate)
                score += scores[up_candidate]
                scores[up_candidate] += 1
            if score > selected_score:
                selected = j
                selected_score = score
                selected_cells = cells
        v[current] = selected
        for c in selected_cells:
            stack.append(c)
    v[-1] = 0
    return v

for i in range(5, 16):
    for j in range(0, 3):
        print(generate_stack(i))



