import random
import math
import heapq
from itertools import islice

def batched(iterable, n):
    # batched('ABCDEFG', 3) --> ABC DEF G
    if n < 1:
        raise ValueError('n must be at least one')
    it = iter(iterable)
    while batch := tuple(islice(it, n)):
        yield batch

r = random.Random(17)

# generate maze of length n, arbitrary distance
# picks a random ordering of all nodes
# does not attempt to resolve cycles
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

def backtrack(n, d, maze, solution, depth_map):
        current = solution[-1]
        maze[current] = None
        solution.pop()
        if len(solution) == 0:
            return None
        last = solution[-1]
        j = abs(last - current)
        current = last
        f = current + j
        if f < n and depth_map[f] > len(solution):
            depth_map[f] = n
        b = current - j
        if b > 0 and depth_map[b] > len(solution):
            depth_map[b] = n
        return current

def fill_blanks(n, d, partial, depth_map):
    filled = partial.copy()
    for i in range(1, n - 1):
        if filled[i] is not None:
            continue
        max_depth = depth_map[i] + 1
        while True:
            candidates = [x for x in range(1, d + 1) if ((i - x) <= 0 or depth_map[i - x] <= max_depth) and ((i + x) >= n or depth_map[i + x] <= max_depth)]
            if len(candidates) > 0:
                break
            # if we can't find a candidate, relax depth constraint 
            max_depth += 1
        filled[i] = candidates[r.randint(0, len(candidates) - 1)]
    filled[n - 1] = 0
    return filled


# generate maze of goal depth by random solution
# attempt
def generate_solutions(n, d):

    # solution candidates
    candidate_map = []
    for i in range(0, n):
        max_f = min(i + d, n - 1)
        min_b = max(0, i - d)
        candidates = sorted([(r.random(), x) for x in range(min_b, max_f + 1) if x != i])
        candidate_map.append(candidates)

    # seen 
    depth_map = [n] * n

    # current maze and solution
    maze = [None] * n
    counters = [0] * (n - 1)
    current = 0
    depth_map[current] = 1
    solution = [current]

    while current is not None:
        if current == n - 1:
            yield fill_blanks(n, d, maze, depth_map), solution
            current = backtrack(n, d, maze, solution, depth_map)
            continue
        else:
            i = counters[current]
            if i >= len(candidate_map[current]):
                counters[current] = 0
                current = backtrack(n, d, maze, solution, depth_map)
                continue
        # find candidate
        _, candidate = candidate_map[current][i]
        counters[current] = i = i + 1
        if depth_map[candidate] < n:
            continue
        j = abs(candidate - current)
        f = current + j
        b = current - j
        if f == n - 1:
            # short circuit if we see the candidate
            candidate = f

        # process candidate
        maze[current] = j
        solution.append(candidate)
        if f < n and depth_map[f] == n:
            depth_map[f] = len(solution)
        if b > 0 and depth_map[b] == n:
            depth_map[b] = len(solution)
        # move to next level
        current = candidate


def scramble_solutions(n, d, iterations, scramble=10):
    while iterations > 0:
        s = scramble
        for maze, solution in generate_solutions(n, d):
            yield maze, solution
            iterations -= 1
            s -= 1
            if s <= 0:
                break

# generate all possible mazes systematically
def all_combinations(n, d):
    m = ([1] * (n - 1)) + [0]
    while True:
        yield m.copy()
        c = 0
        i = n - 2
        while i >= 0:
            m[i] += 1
            if m[i] <= d:
                break
            m[i] = 1
            i -= 1
        if i < 0:
            break

# random jump from node to node until the end
# does not avoid cycles
# orphaned nodes are given random jump values
def generate_jump(n, d):
    m = [None] * n
    current = 0
    while current != n - 1:
        options = [i for i in range(current - d, current + d) if i > 0 and i < n and i != current and m[i] is None]
        if len(options) == 0:
            break
        next = options[r.randint(0, len(options) - 1)]
        m[current] = abs(next - current)
        current = next
    m[n - 1] = 0
    for i in range(0, n):
        if m[i] is None:
            m[i] = r.randint(1, d)
    return m


# bfs for solution
def solve(m):
    visited = set()
    n = len(m)
    current = 0
    queue = [[current]]
    while len(queue) > 0:
        v = queue.pop()
        current = v[-1]
        if current == n - 1:
            return v
        if current in visited:
            continue
        visited.add(current)
        d = m[current]
        forward = current + d
        if forward < n:
            queue = [v + [forward]] + queue
        backward = current - d
        if backward >=0:
            queue = [v + [backward]] + queue
    return None

# get all solutions
def solve_all(m):
    visited = set()
    n = len(m)
    current = 0
    solutions = []
    queue = [[current]]
    while len(queue) > 0:
        v = queue.pop()
        current = v[-1]
        if current == n - 1:
            solutions.append(v)
        if current in visited:
            continue
        visited.add(current)
        d = m[current]
        forward = current + d
        if forward == n - 1:
            solutions.append(v)
            continue
        if forward < n:
            queue.append(v + [forward])
        backward = current - d
        if backward >=0:
            queue.append(v + [backward])
    return solutions

def reachable(m):
    n = len(m)
    visited = set()
    current = 0
    queue = [current]
    while len(queue) > 0:
        current = queue.pop()
        if current in visited:
            continue
        visited.add(current)
        d = m[current]
        forward = current + d
        if forward < n:
            if forward in visited:
                print(current, forward)
            else:
                queue.append(forward)
        backward = current - d
        if backward >=0:
            if backward in visited:
                print(current, backward)
            else:
                queue.append(backward)
    print(visited)
        

# for i, (maze, solution) in enumerate(generate_solutions(16, 9)):
#     if i > 100:
#         break
#     print(i, maze, solution)
#     check = solve(maze)
#     if len(solution) > len(check):
#         raise Exception(f'computed solution {check} is shorter than offered {solution}')

# m = [2, 6, 4, 9, 5, 7, 2, 4, 8, 4, 3, 4, 2, 7, 5, 0]
# s = solve_all(m)
# print(m, s)
# reachable(m)

# em = generate_chain(16, 9)
# for e in em:
#     print(' '.join([str(d) for d in e]))


# for n in range(6, 17):
#     for _ in range(0, 10):
#         d = n - 2 if n < 10 else 9
#         m = generate_jump(n, d) #generate_tree(n, d)
#         s = solve(m)
#         i = interestingness(s, n) if s is not None else 0
#         print(len(m), m, s, i)
#         #print(generate_stack(i))



# interestingness of a maze and solution
def interestingness(maze, solution, max_distance, target_solution_length):
    map_size = len(maze)
    nodes_visited = len(solution)
    # nodes visited should be close to target solution length
    target_length_delta = abs(nodes_visited - target_solution_length)
    # do we have all the different jump distances in the maze
    distances_in_map = len(set([x for x in maze if x != 0]))
    # do we see runs of the same jump distance
    distance_changes = 0.0
    last_distance = maze[0]
    for i in range(1, map_size):
        next_distance = maze[i]
        if next_distance != last_distance:
            distance_changes += 1.0
        last_distance = next_distance
    # do we see the solution changing jump direction
    direction_changes = 0.0
    last_direction = 1
    for i in range(1, nodes_visited):
        next_direction = solution[i] - solution[i - 1]
        if next_direction * last_direction < 0:
            direction_changes += 1.0
        last_direction = next_direction
    # normalize all metrics and multiply
    x = direction_changes / (float(nodes_visited) / 2.0)
    y = 1.0 - float(target_length_delta) / float(target_solution_length)
    z = float(distances_in_map) / float(max_distance)
    q = float(distance_changes) / float(map_size - 1)
    return x * y * z * q

def solutions(series, max_distance, target_solution_length):
    for m in series:
        s = solve(m)
        if s is None:
            continue
        w = interestingness(m, s, max_distance, target_solution_length)
        if w == 0:
            continue
        yield (w, m, s)

def topk(k, series, limit=-1):
    i = 0
    pq = []
    for s in series:
        i += 1
        if len(pq) < k:
            heapq.heappush(pq, s)
        else:
            heapq.heappushpop(pq, s)
        if limit > 0 and i >= limit:
            break
    return pq

def byteify(m):
    for l, h in batched(m, 2):
        yield '$' + hex((h << 4) + l)[2:]

for n, d in [(6, 4), (8, 5), (10, 6)]:
    print(f'Maze {n} X {d}')
    for w, m, s in topk(32, solutions((m for m, _ in generate_solutions(n, d)), d, n)):
       #print(m, s)
       print('byte ' + ','.join((byteify(m))) + f' ; w: {w} sol: {len(s)}')
    print()


for n, d in [(12, 7), (14, 9), (16, 9)]:
    print(f'Maze {n} X {d}')
    for w, m, s in topk(32, solutions((m for m, _ in scramble_solutions(n, d, 100000, 100)), d, n)):
       #print(m, s)
       print('byte ' + ','.join((byteify(m))) + f' ; w: {w} sol: {len(s)}')
    print()


