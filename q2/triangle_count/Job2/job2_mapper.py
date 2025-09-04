#!/usr/bin/env python3
import sys

degfile = "deg_out.txt"
if len(sys.argv) > 1:
   degfile = sys.argv[1]


deg = {}
with open(degfile) as f:
    for line in f:
        v, d = line.strip().split()
        deg[v] = int(d)

for line in sys.stdin:
    u, v = line.strip().split()
    du, dv = deg[u], deg[v]

    
    if (du < dv) or (du == dv and u < v):
        a, b = u, v
    else:
        a, b = v, u

    print(f"{a}\t{b}")

