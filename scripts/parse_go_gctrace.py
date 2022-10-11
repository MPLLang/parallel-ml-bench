#!/usr/bin/python

import sys
import re

num = r'((\d+(\.\d+)?)|(\.\d+))'

def namedNum(name):
  return r'(?P<' + name + r'>' + num + r')'

pattern = r'\s+'.join([
  r'gc',
  namedNum('gc_num'),
  r'@' + namedNum('timestamp') + r's',
  namedNum('gc_percent') + r'\%' + r':',
  namedNum('clock_phase1') + r'\+' + namedNum('clock_phase2') + r'\+' + namedNum('clock_phase3'),
  'ms',
  'clock,',
  r'.*'
])
pattern = '^' + pattern + '$'
linematcher = re.compile(pattern)

def parseLine(line):
  m = linematcher.match(line)
  if m:
    return m.groupdict()
  return None

if len(sys.argv) < 2:
  sys.stderr.write("[ERROR] missing filename argument")
  exit(1)

with open(sys.argv[1],'r') as f:
  lines = [line for line in f]

data = [parseLine(line) for line in lines]
data = [x for x in data if x is not None]

pauses = [float(x['clock_phase1']) + float(x['clock_phase3']) for x in data]

def avg(xs):
  return sum(xs) / len(xs)

print("num gcs {}".format(len(pauses)))
print("minimum {}".format(min(pauses)))
print("average {}".format(avg(pauses)))
print("maximum {}".format(max(pauses)))
