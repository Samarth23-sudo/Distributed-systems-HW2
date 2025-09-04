#!/usr/bin/env python3
import sys, hashlib

# configurable number of reducers
NUM_REDUCERS = 8  

# open output files
files = [open(f"part-{i}.txt", "w") for i in range(NUM_REDUCERS)]

for line in sys.stdin:
    key = line.split()[0]   # key = first token
    h = int(hashlib.md5(key.encode()).hexdigest(), 16)
    rid = h % NUM_REDUCERS
    files[rid].write(line)

for f in files:
    f.close()

