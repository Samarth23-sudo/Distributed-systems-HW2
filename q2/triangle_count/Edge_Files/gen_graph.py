#!/usr/bin/env python3
import random
import sys

if len(sys.argv) != 4:
   print("Usage: python3 gen_graph.py <num_vertices> <num_edges> <outfiles>")
   sys.exit(1)

V = int(sys.argv[1])
E = int(sys.argv[2])
outfile = sys.argv[3]

edges = set()

with open(outfile, "w") as f:
     while len(edges) < E:
        u = random.randint(1, V)
        v = random.randint(1, V)
        if u == v:
          continue
        if u > v:
          u,v = v,u
        if (u,v) in edges:
          continue
        edges.add((u,v))
        f.write(f"{u} {v}\n")

print(f"Generated graph with {V} vertices and {len(edges)} edges in {outfile}")
