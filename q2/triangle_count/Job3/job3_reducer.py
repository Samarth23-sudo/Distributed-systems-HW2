#!/usr/bin/env python3
import sys

current = None
witnesses = []
has_edge = False

for line in sys.stdin:
    key, val = line.strip().split("\t", 1)
    if current == key:
        if val == "E":
            has_edge = True
        elif val.startswith("W|"):
            witnesses.append(val[2:])
    else:
        if current is not None and has_edge:
            v, w = current.split(",")
            for u in witnesses:
                print(f"G\t1")
                print(f"V\t{u}\t1")
                print(f"V\t{v}\t1")
                print(f"V\t{w}\t1")
        current = key
        witnesses = []
        has_edge = (val == "E")
        if val.startswith("W|"):
            witnesses.append(val[2:])

if current is not None and has_edge:
    v, w = current.split(",")
    for u in witnesses:
        print(f"G\t1")
        print(f"V\t{u}\t1")
        print(f"V\t{v}\t1")
        print(f"V\t{w}\t1")

