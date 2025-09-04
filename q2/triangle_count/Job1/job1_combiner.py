#!/usr/bin/env python3
import sys

counts = {}

# Read mapper output: "vertex \t 1"
for line in sys.stdin:
    parts = line.strip().split()
    if len(parts) != 2:
        continue
    k, v = parts
    v = int(v)
    counts[k] = counts.get(k, 0) + v

# Emit partial sums
for k, v in counts.items():
    print(f"{k}\t{v}")

