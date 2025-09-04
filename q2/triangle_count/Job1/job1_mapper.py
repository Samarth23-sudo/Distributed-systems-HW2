#!/usr/bin/env python3
import sys

for line in sys.stdin:
  line = line.strip()
  if not line:
   continue
  u, v = line.split()
  print(f"{u}\t1")
  print(f"{v}\t1")
