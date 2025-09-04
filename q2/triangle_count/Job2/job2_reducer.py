#!/usr/bin/env python3
import sys

current = None
neighbors = []

for line in sys.stdin:
    u, v = line.strip().split()
    if current == u:
        neighbors.append(v)
    else:
        if current is not None:
            print(f"{current}\t{','.join(sorted(neighbors))}")
        current = u
        neighbors = [v]

if current is not None:
    print(f"{current}\t{','.join(sorted(neighbors))}")

