#!/usr/bin/env python3
import random
import sys

# Usage: python3 gen_skewed_graph.py <num_vertices> <num_edges_to_attach> <outfile>
# Example: python3 gen_skewed_graph.py 100000 5 skewed_edges.txt

if len(sys.argv) != 4:
    print("Usage: python3 gen_skewed_graph.py <num_vertices> <edges_per_new_node> <outfile>")
    sys.exit(1)

V = int(sys.argv[1])              # number of vertices
m = int(sys.argv[2])              # edges to attach from each new node
outfile = sys.argv[3]

edges = []
nodes = [0] * m  # start with a small clique of m nodes

for new_node in range(m, V):
    # preferential attachment: choose targets proportional to degree
    targets = set()
    while len(targets) < m:
        target = random.choice(nodes)
        if target != new_node:
            targets.add(target)
    for t in targets:
        u, v = sorted((new_node+1, t+1))
        edges.append((u, v))
    nodes.extend(list(targets))
    nodes.extend([new_node] * m)

with open(outfile, "w") as f:
    for u, v in edges:
        f.write(f"{u} {v}\n")

print(f"Generated skewed graph with {V} vertices, {len(edges)} edges → saved to {outfile}")

