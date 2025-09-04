#!/usr/bin/env python3
import sys

for line in sys.stdin:
    u, v = line.strip().split()
    if u > v:
        u, v = v, u
    print(f"{u},{v}\tE")

