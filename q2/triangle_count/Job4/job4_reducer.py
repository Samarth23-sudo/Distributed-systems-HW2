#!/usr/bin/env python3
import sys

counts = {}

for line in sys.stdin:
    parts = line.strip().split("\t")
    if not parts:
       continue
    key = parts[0]
    if key == "G":
       counts["G"] = counts.get("G", 0) + int(parts[1])
    elif key == "V":
       v = parts[1]
       counts[v] = counts.get(v, 0) + int(parts[2])

print("total_triangles", counts["G"])
for v in sorted(k for k in counts if k != "G"):
    print(v, counts[v])
