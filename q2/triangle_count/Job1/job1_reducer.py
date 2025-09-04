#!/usr/bin/env python3
import sys

current = None
count = 0

for line in sys.stdin:
  key, val = line.strip().split()
  val = int(val)
  if current == key:
   count += val
  else:
   if current is not None:
     print(f"{current}\t{count}")
   current = key
   count = val

if current is not None:
   print(f"{current}\t{count}")
