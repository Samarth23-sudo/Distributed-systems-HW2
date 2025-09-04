#!/usr/bin/env python3
import sys
from itertools import combinations

for line in sys.stdin:
    parts = line.strip().split()
    if len(parts) < 2:
       continue
    u, neighs = parts[0], parts[1].split(",")
    for v, w in combinations(sorted(neighs), 2):
        print(f"{v},{w}\tW|{u}")
