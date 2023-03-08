#!/usr/bin/python3

import json
import sys
import re
import copy
import os
import argparse
import subprocess
import numpy as np

def ensureFigDir():
  if not os.path.isdir("figures"):
    os.mkdir("figures")

def getGitRoot():
  data = subprocess.Popen(['git', 'rev-parse', '--show-toplevel'],
    stdout=subprocess.PIPE).communicate()[0].rstrip()
  return "".join(chr(x) for x in data)

ROOT = getGitRoot()

parser = argparse.ArgumentParser()
parser.add_argument('--no-plots', action='store_true', dest='no_plots')
parser.add_argument('input_file', nargs='?', metavar='RESULTS_FILE')
args = parser.parse_args()

BLUE = '\033[94m'
#GREEN = '\033[92m'
GREEN = '\033[38;2;20;139;20m'
#LIGHT_GREEN = '\033[38;2;138;226;52m'
LIGHT_GREEN = '\033[38;2;100;226;130m'
YELLOW = '\033[93m'
GRAY = '\033[38;2;151;155;147m'
RED = '\033[91m'
ENDC = '\033[0m'
BOLD = '\033[1m'
UNDERLINE = '\033[4m'

class colortext:
  def __init__(self, text, color, bold=True):
    self.text = text
    self.color = color
    self.bold = bold
  def __len__(self):
    return len(self.text)
  def __str__(self):
    return (BOLD if self.bold else "") + self.color + self.text + ENDC
def green(s):
  return colortext(s, GREEN)
def red(s):
  return colortext(s, RED)
def orange(s):
  return colortext(s, YELLOW, bold=True)
def blue(s):
  return colortext(s, BLUE)
def lightgreen(s):
  return colortext(s, LIGHT_GREEN, bold=True)
def gray(s):
  return colortext(s, GRAY, bold=False)

def bold(s):
  return colortext(s, GRAY, bold = True)

def json_careful_loads(s):
  try:
    return json.loads(s)
  except Exception as e:
    sys.stderr.write("[ERR] Error while parsing json: {}\n".format(e))
    sys.exit(1)

def json_careful_readlines(f):
  return [ json_careful_loads(line.rstrip('\n')) for line in f ]

def safeInsert(dict, key, value):
  if key not in dict:
    dict[key] = value
  else:
    sys.stderr.write("[WARN] Key {} is already in use; trying _{} instead.\n".format(key))
    safeInsert(dict, "_" + key, value)

def reCompile(exp):
  return re.compile(exp, re.MULTILINE)

# def parseCommaInteger(s):
#   return int(s.replace(",", ""))

# local reclaimed: 32859049984
# num local: 20999
# local gc time: 4541
# promo time: 8

def parseKiB(kibStr):
  return float(int(kibStr)) * 1024.0 / 1000.0

def parseBytesToKB(bytesStr):
  return float(int(bytesStr)) / 1000.0

def parseTimes(stdout):
  pat = reCompile(r"^time\s+(\d+.\d+).*$")
  return [float(x) for x in pat.findall(stdout)]

def parseMillisecToSec(ms):
  return float(int(ms)) / 1000.0

# sus marks: 1260000
# de checks: 0
# bytes pinned entangled: 0

# lgc count: 0
# lgc bytes reclaimed: 0
# lgc trace time(ms): 0
# lgc promo time(ms): 0
# lgc total time(ms): 0

# cgc count: 4999
# cgc bytes reclaimed: 44329304
# cgc time(ms): 841

# work time(ms): 128304
# idle time(ms): 170102

statsPatterns = \
  [ #("time", float, reCompile(r"^end-to-end\s+(\d+.\d+)s$"))
  #,
    ("space", parseKiB, reCompile(r"^\s*Maximum resident set size \(kbytes\): (\d+).*$"))
  , ("computed-average", float, reCompile(r"^average\s+(\d+.\d+).*$"))
  , ("pinned-entangled", parseBytesToKB, reCompile(r"^bytes pinned entangled: (\d+).*$"))
  , ("pinned-entangled-watermark", parseBytesToKB, reCompile(r"^bytes pinned entangled watermark: (\d+).*$"))
  , ("lgc-count", int, reCompile(r"^lgc count: (\d+)$"))
  , ("lgc-reclaimed", parseBytesToKB, reCompile(r"^lgc bytes reclaimed: (\d+)$"))
  , ("lgc-scope", parseBytesToKB, reCompile(r"^lgc bytes in scope: (\d+)$"))
  , ("lgc-time", parseMillisecToSec, reCompile(r"^lgc total time\(ms\): (\d+)$"))
  , ("cgc-count", int, reCompile(r"^cgc count: (\d+)$"))
  , ("cgc-reclaimed", parseBytesToKB, reCompile(r"^cgc bytes reclaimed: (\d+)$"))
  , ("cgc-scope", parseBytesToKB, reCompile(r"^cgc bytes in scope: (\d+)$"))
  , ("cgc-time", parseMillisecToSec, reCompile(r"^cgc time\(ms\): (\d+)$"))
  , ("work-time", parseMillisecToSec, reCompile(r"^work time\(ms\): (\d+)$"))
  , ("idle-time", parseMillisecToSec, reCompile(r"^idle time\(ms\): (\d+)$"))
  # , ("promo-time", int, reCompile(r"^promo time: (\d+)$"))
  # , ("root-reclaimed", parseBytesToKB, reCompile(r"^root cc reclaimed: (\d+)$"))
  # , ("internal-reclaimed", parseBytesToKB, reCompile(r"^internal cc reclaimed: (\d+)$"))
  # , ("num-root", int, reCompile(r"^num root cc: (\d+)$"))
  # , ("num-internal", int, reCompile(r"^num internal cc: (\d+)$"))
  # , ("root-time", int, reCompile(r"^root cc time: (\d+)$"))
  # , ("internal-time", int, reCompile(r"^internal cc time: (\d+)$"))
  # , ("working-set", parseCommaInteger, reCompile(r"^max bytes live: (.*) bytes$"))
  ]

def renameConfig(c):
  return c

def renameTag(row):
  t = row['tag']
  if (t != 'tangle') and (t != 'tangle-small') and (t != 'tangle-small2') and (t != 'tangle-small3'):
    return t
  pat = re.compile(r"-p-ent\s+(.*)")
  m = pat.search(row['args1'])
  if m:
    newTag = '{}-{}'.format(t, m.group(1))
    return newTag
  return t

def displayTag(t):
  sandmarkTags = ["binarytrees5","lu-decomp","game-of-life","nbody"]
  if t in sandmarkTags:
    return "SM:" + t
  if t == "delaunay-entangled":
    return "delaunay"
  if t == "delaunay":
    return "delaunay-disentangled"
  if t == "wc-entangled":
    return "wc"
  if t == "linefit-entangled":
    return "linefit"
  if t == "wc":
    return "wc-disentangled"
  if t == "linefit":
    return "linefit-disentangled"
  if t == "msort-ints":
    return "msort-int64"
  if t == "dedup-strings":
    return "hash-dedup"
  if t == "pfa-bst":
    return "persistent-arr"
  if t == "connectivity":
    return "reachability"
  if t == "low-d-decomp-boundary":
    return "ldd-boundary"
  if t == "bfs-find-hideg":
    return "find-influencers"
  return t


foundTags = set()
foundProcs = set()

def parseStats(row):
  newRow = copy.deepcopy(row)
  for (name, convert, pat) in statsPatterns:
    m = pat.search(newRow['stdout'] + newRow['stderr'])
    if m:
      safeInsert(newRow, name, convert(m.group(1)))
  newRow['procs'] = int(newRow.get('procs', '1'))
  newRow['config'] = renameConfig(row['config'])
  newRow['tag'] = renameTag(row)

  allOutput = newRow['stdout'] + newRow['stderr']
  if 'multi' in newRow:
    for i in range(1, int(newRow['multi'])):
      allOutput += newRow['stdout{}'.format(i)] + newRow['stderr{}'.format(i)]

  tms = parseTimes(allOutput)
  try:
    newRow['avgtime'] = sum(tms) / len(tms)
  except:
    newRow['avgtime'] = None

  if newRow['avgtime'] is None:
    try:
      newRow['avgtime'] = newRow['computed-average']
    except:
      pass
  elif 'computed-average' in newRow and \
       abs(newRow['computed-average'] - newRow['avgtime']) > 0.001:
    # sanity check: might as well check that the average reported by the
    # benchmark respects the average we compute here
    sys.stderr.write("[WARN] (tag={} config={} procs={}) computed-average ({}) and avgtime ({}) differ a bit.".format(newRow['tag'], newRow['config'], newRow['procs'], newRow['computed-average'], newRow['avgtime']))

  foundTags.add(newRow['tag'])
  foundProcs.add(newRow['procs'])

  return newRow

def findTrials(data, config, tag, procs):
  result = []
  for row in data:
    if (row['config'] == config and \
        row['tag'] == tag and \
        row['procs'] == procs):
      result.append(row)
  return result

# ======================================================================

def averageTime(data, config, tag, procs, checkExpType=True):
  trials = [ r for r in findTrials(data, config, tag, procs) if (not checkExpType) or (r['exp'] == 'time') ]
  tms = [ r['avgtime'] for r in trials if 'avgtime' in r ]
  try:
    return tms[-1]
  except:
    return None

def averageSpace(data, config, tag, procs, checkExpType=True):
  trials = [ r for r in findTrials(data, config, tag, procs) if (not checkExpType) or r['exp'] == 'space' ]
  sp = [ r['space'] for r in trials if 'space' in r ]

  try:
    sp = sp[-10:] if procs > 1 else sp[-1:]
    # sp = sp[-1:]
    return sum(sp) / len(sp)
  except:
    return None

def pinnedEntangled(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['pinned-entangled'] for r in trials if 'pinned-entangled' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def averageSpaceSingle(data, config, tag, procs):
  trials = [ r for r in findTrials(data, config, tag, procs) if r['exp'] == 'single-space' ]
  sp = [ r['space'] for r in trials if 'space' in r ]

  try:
    sp = sp[-10:] if procs > 1 else sp[-1:]
    # sp = sp[-1:]
    return sum(sp) / len(sp)
  except:
    return None

def pinnedEntangledSingle(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'single-space']
  ee = [ r['pinned-entangled'] for r in trials if 'pinned-entangled' in r ]
  try:
    return ee[-1]
  except:
    return None

def pinnedEntangledWatermark(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['pinned-entangled-watermark'] for r in trials if 'pinned-entangled-watermark' in r ]
  try:
    return ee[-1]  # note: do NOT divide by number of reps
  except:
    return None

def lgcCount(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['lgc-count'] for r in trials if 'lgc-count' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def lgcReclaimed(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['lgc-reclaimed'] for r in trials if 'lgc-reclaimed' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def lgcScope(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['lgc-scope'] for r in trials if 'lgc-scope' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def lgcTime(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['lgc-time'] for r in trials if 'lgc-time' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def cgcCount(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['cgc-count'] for r in trials if 'cgc-count' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def cgcReclaimed(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['cgc-reclaimed'] for r in trials if 'cgc-reclaimed' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def cgcScope(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['cgc-scope'] for r in trials if 'cgc-scope' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

def cgcTime(data, config, tag, procs):
  trials = [r for r in findTrials(data, config, tag, procs) if r['exp'] == 'space']
  ee = [ r['cgc-time'] for r in trials if 'cgc-time' in r ]
  try:
    return ee[-1] / 20.0
  except:
    return None

# ======================================================================

def tm(t):
  if t is None:
    return None
  if t == 0.0:
    return int(0)
  # if t > 10.0:
  #   return int(round(t))
  try:
    if t < 1.0:
      return round(t, 3)
    if t < 10.0:
      return round(t, 2)
    elif t < 100.0:
      return round(t, 1)
    else:
      return round(t)
  except TypeError:
    print ("[ERR] Got type error trying to round {}".format(repr(t)))
    return None

def ov(x):
  if x is None:
    return None
  return "{:.2f}".format(x)

def ovv(x):
  if x is None:
    return None
  return round(x, 2)

def rat(x):
  if x is None:
    return None
  if x >= 10.0:
    return str(int(round(x)))
  if x >= 1:
    return "{:.1f}".format(x)
  else:
    return "{:.2f}".format(x)

def sd(x, y):
  try:
    return x / y
  except:
    return None

def safemul(x, y):
  try:
    return x * y
  except:
    return None

def safeadd(x, y):
  try:
    return x + y
  except:
    return None

def su(x):
  if x is None:
    return None
  return str(int(round(x)))

def bu(x):
  if x is None:
    return None
  elif x < 1.0:
    return "{:.2f}".format(x)
  return "{:.1f}".format(x)

def noLeadZero(x):
  try:
    if "0" == x[:1]:
      return x[1:]
  except:
    pass
  return x

def sp(kb):
  if kb is None:
    return None
  if kb < 0.001:
    return "0"
  num = kb
  for unit in ['K','M','G']:
    if num < 100:
      if num < 1:
        return noLeadZero("%0.2f %s" % (num, unit))
      if num < 10:
        return noLeadZero("%1.1f %s" % (num, unit))
      return "%d %s" % (round(num), unit)
      # return "%d %s" % (int(round(num,-1)), unit)
    num = num / 1000
  return noLeadZero("%1.1f %s" % (num, 'T'))

def sfmt(xx):
  if xx is None:
    return "--"
  elif type(xx) is str:
    return xx
  elif xx < 0.01:
    return noLeadZero("{:.4f}".format(xx))
  elif xx < 0.1:
    return noLeadZero("{:.3f}".format(xx))
  elif xx < 1.0:
    return noLeadZero("{:.2f}".format(xx))
  elif xx < 10.0:
    return "{:.1f}".format(xx)
  else:
    return str(int(round(xx)))

def spg(kb):
  try:
    gb = kb / (1000.0 * 1000.0)
    if gb < .01:
      return round(gb, 4)
    elif gb < .1:
      return round(gb, 3)
    elif gb < 1.0:
      return round(gb, 2)
    elif gb < 10.0:
      return round(gb, 1)
    else:
      return round(gb, 0)
  except:
    return None

def spm(kb):
  try:
    mb = kb / (1000.0)
    if mb < .01:
      return round(mb, 4)
    elif mb < .1:
      return round(mb, 3)
    elif mb < 1.0:
      return round(mb, 2)
    elif mb < 10.0:
      return round(mb, 1)
    else:
      return round(mb, 0)
  except:
    return None

def makeBold(s):
  try:
    return "{\\bf " + s + "}"
  except Exception as e:
    sys.stderr.write("[WARN] " + str(e) + "\n")
    return "--"

def pcd(b, a):
  try:
    xx = int(round(100.0 * (b-a) / abs(a)))
    return xx
  except:
    return None

def fmtpcd(xx, highlight=True):
  try:
    xx = int(round(xx))
    result = ("+" if xx >= 0.0 else "") + ("{}\\%".format(xx))
    if highlight and (xx < 0):
      return makeBold(result)
    else:
      return result
  except Exception as e:
    sys.stderr.write("[WARN] " + str(e) + "\n")
    return "--"

def ov_to_latexpcd(ov, highlight=True):
  try:
    xx = int(round(100.0 * (ov-1.0)))
    result = ("+" if xx >= 0.0 else "") + ("{}\\%".format(xx))
    if highlight and (xx < 0):
      return makeBold(result)
    else:
      return result
  except Exception as e:
    sys.stderr.write("[WARN] " + str(e) + "\n")
    return "--"

def latexpcd(b, a, highlight=True):
  try:
    xx = pcd(b, a)
    result = ("+" if xx >= 0.0 else "") + ("{}\\%".format(xx))
    if highlight and (xx < 0):
      return makeBold(result)
    else:
      return result
  except Exception as e:
    sys.stderr.write("[WARN] " + str(e) + "\n")
    return "--"

def fmt(xx):
  if xx is None:
    return "--"
  elif type(xx) is str:
    return xx
  elif xx < 1.0:
    return noLeadZero("{:.3f}".format(xx))
  elif xx < 10.0:
    return "{:.2f}".format(xx)
  elif xx < 100.0:
    return "{:.1f}".format(xx)
  else:
    return str(int(round(xx)))

def geomean(iterable):
  try:
    a = np.array(iterable)
    return a.prod()**(1.0/len(a))
  except:
    return None

def average(iterable):
  try:
    a = np.array(iterable)
    return a.sum() * (1.0/len(a))
  except:
    return None

# =========================================================================

delimWidth = 2

def makeline(row, widths, align):
  bits = []
  i = 0
  while i < len(row):
    j = i+1
    while j < len(row) and (row[j] is None):
      j += 1
    availableWidth = int(sum(widths[i:j]) + delimWidth*(j-i-1))
    s = str(row[i])
    w = " " * (availableWidth - len(row[i]))
    aa = align(i)
    if aa == "l":
      ln = s + w
    elif aa == "r":
      ln = w + s
    elif aa == "c":
      ln = w[:len(w)/2] + s + w[len(w)/2:]
    else:
      raise ValueError("invalid formatter: {}".format(aa))
    bits.append(ln)
    i = j
  return (" " * delimWidth).join(bits)

def table(rows, align=None):
  numCols = max(len(row) for row in rows if not isinstance(row, str))

  widths = [0] * numCols
  for row in rows:
    # string rows are used for formatting
    if isinstance(row, str):
      continue

    i = 0
    while i < len(row):
      j = i+1
      while j < len(row) and (row[j] is None):
        j += 1
      # rw = len(stripANSI(str(row[i])))
      # rw = len(str(row[i]))
      rw = len(row[i])
      for k in range(i, j):
        w = (rw / (j-i)) + (1 if k < rw % (j-i) else 0)
        widths[k] = max(widths[k], w)
      i = j

  totalWidth = int(sum(widths) + delimWidth*(numCols-1))

  def aa(i):
    try:
      return align(i)
    except:
      return "l"

  output = []
  for row in rows:
    if row == "-" or row == "=":
      output.append(row * totalWidth)
      continue
    elif isinstance(row, str):
      raise ValueError("bad row: {}".format(row))
    output.append(makeline(row, widths, aa))

  return "\n".join(output)

# =========================================================================

def mostRecentResultsFile(suffix=""):
  try:
    files = os.listdir(os.path.join(str(ROOT), "results"))
  except Exception as e:
    print(e)
    raise e

  pattern = r'\d{6}-\d{6}'
  if suffix != "":
    pattern = pattern + "-" + suffix + "$"
  else:
    pattern = pattern + "$"
  # A bit of a hack. Filenames are ...YYMMDD-hhmmss, so lexicographic string
  # comparison is correct for finding the most recent (i.e. maximum) file
  mostRecent = max(p for p in files if re.match(pattern, p))
  return mostRecent

if args.input_file:
  timingsFile = args.input_file
else:
  print("[ERR] no results file given")
  sys.exit(1)

print("[INFO] reading {}\n".format(timingsFile))
with open(timingsFile, 'r') as data:
  resultsData = json_careful_readlines(data)
D = [ parseStats(row) for row in resultsData ]
P = sorted(list(foundProcs))
maxp = max(p for p in foundProcs if p <= 72)
orderedTags = sorted(list(foundTags), key=displayTag)

foundProcs = set()
foundTags = set()

def keepTag(t):
  return t in [
    'bfs-find-hideg',
    'centrality',
    'connectivity',
    'dedup-strings',
    'delaunay-entangled',
    'grep',
    'harris-linked-list',
    'interval-tree',
    'linden-pq',
    'linefit-entangled',
    'low-d-decomp-boundary',
    'max-indep-set',
    'mcss',
    'ms-queue',
    'msort-ints',
    'nearest-nbrs',
    'pfa-bst',
    'primes',
    'quant-synth',
    'quickhull',
    'range-query',
    'reverb',
    'seam-carve',
    'spanner',
    'tokens',
    'triangle-count',
    'wc-entangled'
    # 'wc',
    # 'wc-accum',
    # 'linefit',
    # 'linefit-accum',
    # 'sort-longs'
  ]


# nondetTags = [
#   'bfs',
#   'bfs-find-hideg',
#   'centrality',
#   'connectivity',
#   'dedup-strings',
#   'delaunay',
#   'delaunay-entangled',
#   'harris-linked-list',
#   'linden-pq',
#   'low-d-decomp',
#   'low-d-decomp-boundary',
#   'max-indep-set',
#   'ms-queue',
#   'pfa-bst',
#   'sk-net',
#   'spanner'
# ]

mplOnlyTags = [ t for t in orderedTags if keepTag(t) ]


mplCmpTags = [
  "primes",
  "dense-matmul",
  "raytracer",
  "tinykaboom",
  "msort-strings",
  "msort-ints",
  "nearest-nbrs",
  "quickhull",
  "reverb",
  "seam-carve",
  # "dedup-strings-entangled",
  "suffix-array",
  "grep",
  "bfs",
  # "bfs-find-hideg",
  "centrality",
  "low-d-decomp",
  # "low-d-decomp-boundary",
  "max-indep-set",
  "palindrome",
  "tokens",
  "nqueens",
  "triangle-count",
  "range-query",
  "delaunay",
  # "delaunay-entangled",
  "linefit",
  # "linefit-entangled",
  "linearrec",
  "bignum-add",
  "integrate",
  "sparse-mxv",
  "wc",
  # "wc-entangled",
  "mcss",
  # "connectivity-entangled",
  # "spanner-entangled",
  # "ms-queue",
  # "harris-linked-list",
  # "linden-pq",
  # "pfa-bst",
  # "sk-net",
  "interval-tree"
]

ocamlTags = {
  "tokens": "tokens",
  "msort-ints": "msort-ints",
  "primes": "primes",
  "raytracer": "raytracer",
  "lu-decomp": "lu-decomp",
  "msort-strings": "msort-strings",
  "dedup-strings": "dedup-strings",
  "nbody": "nbody",
  "game-of-life": "game-of-life",
  "binarytrees5": "binarytrees5",
  "sparse-mxv": "sparse-mxv",
  "wc-entangled": "wc-accum",
  "ms-queue": "ms-queue",
  "wc": "",
  "linefit": "",
  "linefit-entangled": "linefit-accum",
  "mcss": "mcss"
}

# map each MPL tag to the correct C++ tag for comparison
cppTags = {
  "bfs": "bfs",
  "bignum-add": "bignum-add",
  "delaunay": "delaunay",
  "grep": "grep",
  "integrate": "integrate",
  "linearrec": "linearrec",
  "linefit": "",
  "linefit-entangled": "linefit",
  "mcss": "mcss",
  "msort-ints": "msort",
  "nearest-nbrs": "nearest-nbrs",
  "primes": "primes",
  "quickhull": "quickhull",
  "sparse-mxv": "sparse-mxv",
  "tokens": "tokens",
  "wc": "",
  "wc-entangled": "wc",
  "dedup-strings": "dedup-strings",
  "ms-queue": "ms-queue"
}

javaTags = {
  "primes": "primes",
  "msort-ints": "sort-longs",
  "tokens": "tokens",
  "mcss": "mcss",
  "linefit": "linefit",
  "linefit-entangled": "linefit-accum",
  "wc": "",
  "wc-entangled": "wc-accum",
  "sparse-mxv": "sparse-mxv",
  "msort-strings": "msort-strings",
  "dedup-strings": "dedup-strings",
  "ms-queue": "ms-queue"
}

goTags = {
  "primes": "primes",
  "msort-ints": "msort",
  "tokens": "tokens",
  "mcss": "mcss",
  "linefit": "linefit",
  "wc": "",
  "linefit-entangled": "linefit-accum",
  "wc-entangled": "wc-accum",
  "sparse-mxv": "sparse-mxv",
  "msort-strings": "msort-strings",
  "dedup-strings": "dedup-strings",
  "ms-queue": "ms-queue"
}

sandmarkTags = [
  "binarytrees5",
  "game-of-life",
  "nbody",
  "lu-decomp"
]

# orderedTags = [ t for t in orderedTags if t not in sandmarkTags ]

# ===========================================================================

def filterSome(xs):
  return [x for x in xs if x is not None]

# def seqOverhead(tag):
#   return sd(averageTime(D, 'mpl-em', tag, 1),averageTime(D, 'mpl', tag, 1))
# def parOverhead(tag):
#   return sd(averageTime(D, 'mpl-em', tag, maxp),averageTime(D, 'mpl', tag, maxp))
# def seqSpaceOverhead(tag):
#   return sd(averageSpace(D, 'mpl-em', tag, 1),averageSpace(D, 'mpl', tag, 1))
# def parSpaceOverhead(tag):
#   return sd(averageSpace(D, 'mpl-em', tag, maxp),averageSpace(D, 'mpl', tag, maxp))

# print "geomean 1-core time overhead", geomean(filterSome([seqOverhead(t) for t in disentangledTags]))
# print "geomean {}-core time overhead".format(maxp), geomean(filterSome([parOverhead(t) for t in disentangledTags]))
# print "geomean 1-core space overhead", geomean(filterSome([seqSpaceOverhead(t) for t in disentangledTags]))
# print "geomean {}-core space overhead".format(maxp), geomean(filterSome([parSpaceOverhead(t) for t in disentangledTags]))

# ===========================================================================

# percent difference (b-a)/|a|
def color_pcd(b, a):
  try:
    xx = 100.0 * (b-a) / abs(a)
    result = ("+" if xx >= 0.0 else "") + ("{:.1f}%".format(xx))
    if xx >= 10.0:
      return red(result)
    elif xx >= 5.0:
      return orange(result)
    elif xx <= -10.0:
      return green(result)
    elif xx <= -5.0:
      return lightgreen(result)
    else:
      return gray(result)
  except:
    return None

# def sp(kb):
#   if kb is None:
#     return None
#   num = kb
#   for unit in ['K','M','G']:
#     if num < 1000:
#       return "%3.1f %s" % (num, unit)
#     num = num / 1000
#   return "%3.1f %s" % (num, 'T')

def defaultAlign(i):
  return "r" if i == 0 else "l"


# ============================================================================

sortShootout = [
  ("C++", "cpp", "msort"),
  ("MPL", "mpl-em", "msort-ints"),
  ("Java", "java", "sort-longs"),
  ("OCaml", "ocaml", "msort-ints"),
  ("Go", "go", "msort")
]

try:
  sortShootoutBaseline = \
    min(filterSome(
      [tm(averageTime(D, config, tag, 1)) for name,config,tag in sortShootout]
    ))
except:
  sortShootoutBaseline = None

headers1 = ['System', 'T(1)', 'T({})'.format(maxp), 'SelfSU', 'SU', 'R(1)', 'R({})'.format(maxp)]
tt = [headers1, "="]
for name, config, tag in sortShootout:
  t1 = tm(averageTime(D, config, tag, 1))
  tp = tm(averageTime(D, config, tag, maxp))
  r1 = spg(averageSpace(D, config, tag, 1))
  rp = spg(averageSpace(D, config, tag, maxp))
  thisRow = [
    t1,
    tp,
    su(sd(t1,tp)),
    su(sd(sortShootoutBaseline, tp)),
    r1,
    rp
  ]
  thisRow = [name] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("SORT SHOOTOUT")
# print(table(tt, defaultAlign))
# print("")

# ============================================================================

tokensShootout = [
  ("C++", "cpp", "tokens"),
  ("MPL", "mpl-em", "tokens"),
  ("Java", "java", "tokens"),
  ("OCaml", "ocaml", "tokens"),
  ("Go", "go", "tokens")
]

try:
  tokensShootoutBaseline = \
    min(filterSome(
      [tm(averageTime(D, config, tag, 1)) for name,config,tag in tokensShootout]
    ))
except:
  tokensShootoutBaseline = None

headers1 = ['System', 'T(1)', 'T({})'.format(maxp), 'SelfSU', 'SU', 'R(1)', 'R({})'.format(maxp)]
tt = [headers1, "="]
for name, config, tag in tokensShootout:
  t1 = tm(averageTime(D, config, tag, 1))
  tp = tm(averageTime(D, config, tag, maxp))
  r1 = spg(averageSpace(D, config, tag, 1))
  rp = spg(averageSpace(D, config, tag, maxp))
  thisRow = [
    t1,
    tp,
    su(sd(t1,tp)),
    su(sd(tokensShootoutBaseline, tp)),
    r1,
    rp
  ]
  thisRow = [name] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("TOKENS SHOOTOUT")
# print(table(tt, defaultAlign))
# print("")

# ============================================================================

primesShootout = [
  ("C++", "cpp", "primes"),
  ("MPL", "mpl-em", "primes"),
  ("Java", "java", "primes"),
  ("OCaml", "ocaml", "primes"),
  ("Go", "go", "primes")
]

try:
  primesShootoutBaseline = \
    min(filterSome(
      [tm(averageTime(D, config, tag, 1)) for name,config,tag in primesShootout]
    ))
except:
  primesShootoutBaseline = None

headers1 = ['System', 'T(1)', 'T({})'.format(maxp), 'SelfSU', 'SU', 'R(1)', 'R({})'.format(maxp)]
tt = [headers1, "="]
for name, config, tag in primesShootout:
  t1 = tm(averageTime(D, config, tag, 1))
  tp = tm(averageTime(D, config, tag, maxp))
  r1 = spg(averageSpace(D, config, tag, 1))
  rp = spg(averageSpace(D, config, tag, maxp))
  thisRow = [
    t1,
    tp,
    su(sd(t1,tp)),
    su(sd(primesShootoutBaseline, tp)),
    r1,
    rp
  ]
  thisRow = [name] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("PRIMES SHOOTOUT")
# print(table(tt, defaultAlign))
# print("")

# ============================================================================

headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
headers1 = ['Benchmark', 'O', 'M', 'O/M', 'O', 'M', 'O/M', 'O', 'M', 'O/M', 'O', 'M', 'O/M']
tt = [headers, "-", headers1, "="]
for tag in ocamlTags.keys():
  mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
  mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
  mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
  mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

  ot1 = tm(averageTime(D, 'ocaml', ocamlTags[tag], 1))
  otp = tm(averageTime(D, 'ocaml', ocamlTags[tag], maxp))
  or1 = spg(averageSpace(D, 'ocaml', ocamlTags[tag], 1))
  orp = spg(averageSpace(D, 'ocaml', ocamlTags[tag], maxp))

  thisRow = [
    ot1,
    mt1,
    ov(sd(ot1,mt1)),
    otp,
    mtp,
    ov(sd(otp,mtp)),
    or1,
    mr1,
    ov(sd(or1,mr1)),
    orp,
    mrp,
    ov(sd(orp,mrp))
  ]
  thisRow = [displayTag(tag)] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("OCAML COMPARISON")
# print(table(tt, defaultAlign))
# print("")

# ============================================================================

headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
headers1 = ['Benchmark', 'C', 'M', 'M/C', 'C', 'M', 'M/C', 'C', 'M', 'M/C', 'C', 'M', 'M/C']
tt = [headers, "-", headers1, "="]
for tag in sorted(cppTags.keys()):
  mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
  mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
  mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
  mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

  ct1 = tm(averageTime(D, 'cpp', cppTags[tag], 1))
  ctp = tm(averageTime(D, 'cpp', cppTags[tag], maxp))
  cr1 = spg(averageSpace(D, 'cpp', cppTags[tag], 1))
  crp = spg(averageSpace(D, 'cpp', cppTags[tag], maxp))

  thisRow = [
    ct1,
    mt1,
    ov(sd(mt1,ct1)),
    ctp,
    mtp,
    ov(sd(mtp,ctp)),
    cr1,
    mr1,
    ov(sd(mr1,cr1)),
    crp,
    mrp,
    ov(sd(mrp,crp))
  ]
  thisRow = [displayTag(tag)] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("C++ COMPARISON")
# print(table(tt, defaultAlign))
# print("")

# ============================================================================

headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
headers1 = ['Benchmark', 'J', 'M', 'J/M', 'J', 'M', 'J/M', 'J', 'M', 'J/M', 'J', 'M', 'J/M']
tt = [headers, "-", headers1, "="]
for tag in sorted(javaTags.keys()):
  mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
  mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
  mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
  mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

  jt1 = tm(averageTime(D, 'java', javaTags[tag], 1))
  jtp = tm(averageTime(D, 'java', javaTags[tag], maxp))
  jr1 = spg(averageSpace(D, 'java', javaTags[tag], 1))
  jrp = spg(averageSpace(D, 'java', javaTags[tag], maxp))

  thisRow = [
    jt1,
    mt1,
    ov(sd(jt1, mt1)),
    jtp,
    mtp,
    ov(sd(jtp, mtp)),
    jr1,
    mr1,
    ov(sd(jr1, mr1)),
    jrp,
    mrp,
    ov(sd(jrp, mrp))
  ]
  thisRow = [displayTag(tag)] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("JAVA COMPARISON")
# print(table(tt, defaultAlign))
# print("")

# ============================================================================

headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
headers1 = ['Benchmark', 'G', 'M', 'G/M', 'G', 'M', 'G/M', 'G', 'M', 'G/M', 'G', 'M', 'G/M']
tt = [headers, "-", headers1, "="]
for tag in sorted(goTags.keys()):
  mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
  mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
  mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
  mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

  jt1 = tm(averageTime(D, 'go', goTags[tag], 1))
  jtp = tm(averageTime(D, 'go', goTags[tag], maxp))
  jr1 = spg(averageSpace(D, 'go', goTags[tag], 1))
  jrp = spg(averageSpace(D, 'go', goTags[tag], maxp))

  thisRow = [
    jt1,
    mt1,
    ov(sd(jt1, mt1)),
    jtp,
    mtp,
    ov(sd(jtp, mtp)),
    jr1,
    mr1,
    ov(sd(jr1, mr1)),
    jrp,
    mrp,
    ov(sd(jrp, mrp))
  ]
  thisRow = [displayTag(tag)] + [str(x) if x is not None else "--" for x in thisRow]
  tt.append(thisRow)

# print("GO COMPARISON")
# print(table(tt, defaultAlign))
# print("")


# ============================================================================
# LaTeX figure: Language shootout (time comparison)
# ============================================================================

allShootoutTags = sorted([
  "primes",
  "msort-ints",
  "tokens",
  "mcss",
  "linefit-entangled",
  "sparse-mxv",
  "dedup-strings",
  "wc-entangled"
], key=displayTag)



def printFullShootoutTime():
  # proc1TimeRats = dict()
  maxPTimeRat = dict()
  # proc1SpaceRats = dict()
  # proc72SpaceRats = dict()

  def putMaxPTimeRat(config, xx):
    if xx is None:
      return
    if config not in maxPTimeRat:
      maxPTimeRat[config] = []
    maxPTimeRat[config].append(xx)



  header = list(map (lambda x : '', list (range (0, 13))))
  # headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
  headers1 = ['Benchmark', 'C', 'C/M', 'M', 'M/M', 'G', 'G/M','J', 'J/M', 'O', 'O/M']
  rows = ["=", headers1, "="]
  for tag in allShootoutTags:
    # orp = spg(averageSpace(D, 'ocaml', tag, maxp))
    # mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))
    # crp = spg(averageSpace(D, 'cpp', cppTags[tag], maxp))
    # jrp = spg(averageSpace(D, 'java', javaTags[tag], maxp))
    # grp = spg(averageSpace(D, 'go', goTags[tag], maxp))

    otp = tm(averageTime(D, 'ocaml', ocamlTags[tag], maxp))
    mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
    ctp = tm(averageTime(D, 'cpp', cppTags[tag], maxp))
    jtp = tm(averageTime(D, 'java', javaTags[tag], maxp))
    gtp = tm(averageTime(D, 'go', goTags[tag], maxp))

    putMaxPTimeRat('ocaml', ovv(sd(otp, mtp)))
    putMaxPTimeRat('cpp', ovv(sd(ctp, mtp)))
    putMaxPTimeRat('java', ovv(sd(jtp, mtp)))
    putMaxPTimeRat('go', ovv(sd(gtp, mtp)))

    row = \
      [ displayTag(tag)
      , fmt(ctp)
      , (fmt(ov(sd(ctp, mtp))))
      , fmt(mtp)
      , (fmt(ov(sd(mtp, mtp))))
      , fmt(gtp)
      , (fmt(ov(sd(gtp, mtp))))
      , fmt(jtp)
      , (fmt(ov(sd(jtp, mtp))))
      , fmt(otp)
      , (fmt(ov(sd(otp, mtp))))
      ]
    rows.append(row)
    # output.write(" & ".join([displayTag(tag)] + row))
    # output.write("  \\\\\n")

    # output.write("\\midrule\n")
  rows.append("-")
  row = [
    "geomean",
    "", str((fmt(ov(geomean(maxPTimeRat.get('cpp')))))),
    "", str((fmt(ov(1.0)))),
    "", str((fmt(ov(geomean(maxPTimeRat.get('go')))))),
    "", str((fmt(ov(geomean(maxPTimeRat.get('java')))))),
    "", str((fmt(ov(geomean(maxPTimeRat.get('ocaml'))))))
  ]
  rows.append(row)
    # output.write(" & ".join(["geomean"] + row))
    # output.write("  \\\\\n")
  print("\n Time comparison of MPL* v/s C, Go, Java, and Ocaml (similar to Figure 8)\n".format(maxp))
  print(table(rows, defaultAlign))
  # print("""\n
  # EXPERIMENTS: Cross Language. Comparable to the time comparison in Figure 8 (part) in paper""")
  # print("\n")
  # print("[INFO] wrote to {}".format(fullShootoutTable))


def printFullShootoutSpace():
  maxPSpaceRat = dict()

  def putMaxPSpaceRat(config, xx):
    if xx is None:
      return
    if config not in maxPSpaceRat:
      maxPSpaceRat[config] = []
    maxPSpaceRat[config].append(xx)

  # headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
  headers1 = ['Benchmark', 'C', 'C/M', 'M', 'M/M', 'G', 'G/M','J', 'J/M', 'O', 'O/M']
  rows = [headers1, "="]

  def averageSpaceCustom(D, l, tag, p):
    t = averageTime(D, l, tag, p)
    if t is None:
      return None
    else:
      return averageSpace(D, l, tag, p)
  # fullShootoutTable = "figures/full-shootout-space.tex"
  for tag in allShootoutTags:
    orp = spg(averageSpaceCustom(D, 'ocaml', ocamlTags[tag], maxp))
    mrp = spg(averageSpaceCustom(D, 'mpl-em', tag, maxp))
    crp = spg(averageSpaceCustom(D, 'cpp', cppTags[tag], maxp))
    jrp = spg(averageSpaceCustom(D, 'java', javaTags[tag], maxp))
    grp = spg(averageSpaceCustom(D, 'go', goTags[tag], maxp))

    # otp = tm(averageTime(D, 'ocaml', tag, maxp))
    # mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
    # ctp = tm(averageTime(D, 'cpp', cppTags[tag], maxp))
    # jtp = tm(averageTime(D, 'java', javaTags[tag], maxp))
    # gtp = tm(averageTime(D, 'go', goTags[tag], maxp))

    putMaxPSpaceRat('ocaml', ovv(sd(orp, mrp)))
    putMaxPSpaceRat('cpp', ovv(sd(crp, mrp)))
    putMaxPSpaceRat('java', ovv(sd(jrp, mrp)))
    putMaxPSpaceRat('go', ovv(sd(grp, mrp)))

    row = \
      [
      displayTag(tag)
      , fmt(crp)
      , (fmt(ov(sd(crp, mrp))))
      , fmt(mrp)
      , (fmt(ov(sd(mrp, mrp))))
      , fmt(grp)
      , (fmt(ov(sd(grp, mrp))))
      , fmt(jrp)
      , (fmt(ov(sd(jrp, mrp))))
      , fmt(orp)
      , (fmt(ov(sd(orp, mrp))))
      ]
    rows.append(row)
    # output.write(" & ".join([displayTag(tag)] + row))
    # output.write("  \\\\\n")

  # output.write("\\midrule\n")
  rows.append("-")
  row = [
    "geomean",
    "", (fmt(ov(geomean(maxPSpaceRat.get('cpp'))))),
    "", (fmt(ov(1.0))),
    "", (fmt(ov(geomean(maxPSpaceRat.get('go'))))),
    "", (fmt(ov(geomean(maxPSpaceRat.get('java'))))),
    "", (fmt(ov(geomean(maxPSpaceRat.get('ocaml')))))
  ]
  rows.append(row)
  print("\n Space comparison of MPL* v/s C, Go, Java, and Ocaml (similar to Figure 8)\n".format(maxp))
  print(table(rows, defaultAlign))
    # output.write(" & ".join(["geomean"] + row))
    # output.write("  \\\\\n")
  # print("[INFO] wrote to")



def doFullShootoutTime():
  # proc1TimeRats = dict()
  maxPTimeRat = dict()
  # proc1SpaceRats = dict()
  # proc72SpaceRats = dict()

  def putMaxPTimeRat(config, xx):
    if xx is None:
      return
    if config not in maxPTimeRat:
      maxPTimeRat[config] = []
    maxPTimeRat[config].append(xx)

  ensureFigDir()
  fullShootoutTable = "figures/full-shootout.tex"
  with open(fullShootoutTable, 'w') as output:
    for tag in allShootoutTags:
      # orp = spg(averageSpace(D, 'ocaml', tag, maxp))
      # mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))
      # crp = spg(averageSpace(D, 'cpp', cppTags[tag], maxp))
      # jrp = spg(averageSpace(D, 'java', javaTags[tag], maxp))
      # grp = spg(averageSpace(D, 'go', goTags[tag], maxp))

      otp = tm(averageTime(D, 'ocaml', ocamlTags[tag], maxp))
      mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
      ctp = tm(averageTime(D, 'cpp', cppTags[tag], maxp))
      jtp = tm(averageTime(D, 'java', javaTags[tag], maxp))
      gtp = tm(averageTime(D, 'go', goTags[tag], maxp))

      putMaxPTimeRat('ocaml', ovv(sd(otp, mtp)))
      putMaxPTimeRat('cpp', ovv(sd(ctp, mtp)))
      putMaxPTimeRat('java', ovv(sd(jtp, mtp)))
      putMaxPTimeRat('go', ovv(sd(gtp, mtp)))

      row = \
        [ fmt(ctp)
        , makeBold(fmt(ov(sd(ctp, mtp))))
        , fmt(mtp)
        , makeBold(fmt(ov(sd(mtp, mtp))))
        , fmt(gtp)
        , makeBold(fmt(ov(sd(gtp, mtp))))
        , fmt(jtp)
        , makeBold(fmt(ov(sd(jtp, mtp))))
        , fmt(otp)
        , makeBold(fmt(ov(sd(otp, mtp))))
        ]

      output.write(" & ".join([displayTag(tag)] + row))
      output.write("  \\\\\n")

    output.write("\\midrule\n")
    row = [
      "", makeBold(fmt(ov(geomean(maxPTimeRat.get('cpp'))))),
      "", makeBold(fmt(ov(1.0))),
      "", makeBold(fmt(ov(geomean(maxPTimeRat.get('go'))))),
      "", makeBold(fmt(ov(geomean(maxPTimeRat.get('java'))))),
      "", makeBold(fmt(ov(geomean(maxPTimeRat.get('ocaml')))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(fullShootoutTable))

# doFullShootoutTime()

# ============================================================================
# LaTeX figure: Language shootout (space comparison)
# ============================================================================

def doFullShootoutSpace():
  maxPSpaceRat = dict()

  def putMaxPSpaceRat(config, xx):
    if xx is None:
      return
    if config not in maxPSpaceRat:
      maxPSpaceRat[config] = []
    maxPSpaceRat[config].append(xx)

  ensureFigDir()
  fullShootoutTable = "figures/full-shootout-space.tex"
  with open(fullShootoutTable, 'w') as output:
    for tag in allShootoutTags:
      orp = spg(averageSpace(D, 'ocaml', ocamlTags[tag], maxp))
      mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))
      crp = spg(averageSpace(D, 'cpp', cppTags[tag], maxp))
      jrp = spg(averageSpace(D, 'java', javaTags[tag], maxp))
      grp = spg(averageSpace(D, 'go', goTags[tag], maxp))

      # otp = tm(averageTime(D, 'ocaml', tag, maxp))
      # mtp = tm(averageTime(D, 'mpl-em', tag, maxp))
      # ctp = tm(averageTime(D, 'cpp', cppTags[tag], maxp))
      # jtp = tm(averageTime(D, 'java', javaTags[tag], maxp))
      # gtp = tm(averageTime(D, 'go', goTags[tag], maxp))

      putMaxPSpaceRat('ocaml', ovv(sd(orp, mrp)))
      putMaxPSpaceRat('cpp', ovv(sd(crp, mrp)))
      putMaxPSpaceRat('java', ovv(sd(jrp, mrp)))
      putMaxPSpaceRat('go', ovv(sd(grp, mrp)))

      row = \
        [ fmt(crp)
        , makeBold(fmt(ov(sd(crp, mrp))))
        , fmt(mrp)
        , makeBold(fmt(ov(sd(mrp, mrp))))
        , fmt(grp)
        , makeBold(fmt(ov(sd(grp, mrp))))
        , fmt(jrp)
        , makeBold(fmt(ov(sd(jrp, mrp))))
        , fmt(orp)
        , makeBold(fmt(ov(sd(orp, mrp))))
        ]

      output.write(" & ".join([displayTag(tag)] + row))
      output.write("  \\\\\n")

    output.write("\\midrule\n")
    row = [
      "", makeBold(fmt(ov(geomean(maxPSpaceRat.get('cpp'))))),
      "", makeBold(fmt(ov(1.0))),
      "", makeBold(fmt(ov(geomean(maxPSpaceRat.get('go'))))),
      "", makeBold(fmt(ov(geomean(maxPSpaceRat.get('java'))))),
      "", makeBold(fmt(ov(geomean(maxPSpaceRat.get('ocaml')))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(fullShootoutTable))

# doFullShootoutSpace()

# ============================================================================
# LaTeX figure: OCaml comparison
# ============================================================================

def doOCamlComparison():
  proc1TimeRats = []
  proc72TimeRats = []
  proc1SpaceRats = []
  proc72SpaceRats = []

  ensureFigDir()
  ocamlComparisonTable = "figures/ocaml-space-time-comparison.tex"
  with open(ocamlComparisonTable, 'w') as output:
    for tag in ocamlTags.keys():
      or1 = spg(averageSpace(D, 'ocaml', tag, 1))
      orp = spg(averageSpace(D, 'ocaml', tag, maxp))
      mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
      mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

      ot1 = tm(averageTime(D, 'ocaml', tag, 1))
      otp = tm(averageTime(D, 'ocaml', tag, maxp))
      mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
      mtp = tm(averageTime(D, 'mpl-em', tag, maxp))

      proc1TimeRats.append(ovv(sd(ot1, mt1)))
      proc72TimeRats.append(ovv(sd(otp, mtp)))
      proc1SpaceRats.append(ovv(sd(or1, mr1)))
      proc72SpaceRats.append(ovv(sd(orp, mrp)))

      row = \
        [ fmt(ot1)
        , fmt(mt1)
        , makeBold(fmt(ov(sd(ot1, mt1))))
        , fmt(otp)
        , fmt(mtp)
        , makeBold(fmt(ov(sd(otp, mtp))))
        , sfmt(or1)
        , sfmt(mr1)
        , makeBold(fmt(ov(sd(or1, mr1))))
        , sfmt(orp)
        , sfmt(mrp)
        , makeBold(fmt(ov(sd(orp, mrp))))
        ]

      output.write(" & ".join([displayTag(tag)] + row))
      output.write("  \\\\\n")

    output.write("\\midrule\n")
    row = [
      "", "", makeBold(fmt(ov(geomean(proc1TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc1SpaceRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72SpaceRats))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(ocamlComparisonTable))

# doOCamlComparison()

# ============================================================================
# LaTeX figure: Java comparison
# ============================================================================

def doJavaComparison():
  proc1TimeRats = []
  proc72TimeRats = []
  proc1SpaceRats = []
  proc72SpaceRats = []

  ensureFigDir()
  javaComparisonTable = "figures/java-space-time-comparison.tex"
  with open(javaComparisonTable, 'w') as output:
    for tag in sorted(javaTags.keys()):
      or1 = spg(averageSpace(D, 'java', javaTags[tag], 1))
      orp = spg(averageSpace(D, 'java', javaTags[tag], maxp))
      mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
      mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

      ot1 = tm(averageTime(D, 'java', javaTags[tag], 1))
      otp = tm(averageTime(D, 'java', javaTags[tag], maxp))
      mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
      mtp = tm(averageTime(D, 'mpl-em', tag, maxp))

      proc1TimeRats.append(ovv(sd(ot1, mt1)))
      proc72TimeRats.append(ovv(sd(otp, mtp)))
      proc1SpaceRats.append(ovv(sd(or1, mr1)))
      proc72SpaceRats.append(ovv(sd(orp, mrp)))

      row = \
        [ fmt(ot1)
        , fmt(mt1)
        , makeBold(fmt(ov(sd(ot1, mt1))))
        , fmt(otp)
        , fmt(mtp)
        , makeBold(fmt(ov(sd(otp, mtp))))
        , sfmt(or1)
        , sfmt(mr1)
        , makeBold(fmt(ov(sd(or1, mr1))))
        , sfmt(orp)
        , sfmt(mrp)
        , makeBold(fmt(ov(sd(orp, mrp))))
        ]

      output.write(" & ".join([displayTag(tag)] + row))
      output.write("  \\\\\n")

    output.write("\\midrule\n")
    row = [
      "", "", makeBold(fmt(ov(geomean(proc1TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc1SpaceRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72SpaceRats))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(javaComparisonTable))

# doJavaComparison()

# ============================================================================
# LaTeX figure: Go comparison
# ============================================================================

def doGoComparison():
  proc1TimeRats = []
  proc72TimeRats = []
  proc1SpaceRats = []
  proc72SpaceRats = []

  ensureFigDir()
  goComparisonTable = "figures/go-space-time-comparison.tex"
  with open(goComparisonTable, 'w') as output:
    for tag in sorted(goTags.keys()):
      or1 = spg(averageSpace(D, 'go', goTags[tag], 1))
      orp = spg(averageSpace(D, 'go', goTags[tag], maxp))
      mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
      mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

      ot1 = tm(averageTime(D, 'go', goTags[tag], 1))
      otp = tm(averageTime(D, 'go', goTags[tag], maxp))
      mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
      mtp = tm(averageTime(D, 'mpl-em', tag, maxp))

      proc1TimeRats.append(ovv(sd(ot1, mt1)))
      proc72TimeRats.append(ovv(sd(otp, mtp)))
      proc1SpaceRats.append(ovv(sd(or1, mr1)))
      proc72SpaceRats.append(ovv(sd(orp, mrp)))

      row = \
        [ fmt(ot1)
        , fmt(mt1)
        , makeBold(fmt(ov(sd(ot1, mt1))))
        , fmt(otp)
        , fmt(mtp)
        , makeBold(fmt(ov(sd(otp, mtp))))
        , sfmt(or1)
        , sfmt(mr1)
        , makeBold(fmt(ov(sd(or1, mr1))))
        , sfmt(orp)
        , sfmt(mrp)
        , makeBold(fmt(ov(sd(orp, mrp))))
        ]

      output.write(" & ".join([displayTag(tag)] + row))
      output.write("  \\\\\n")

    output.write("\\midrule\n")
    row = [
      "", "", makeBold(fmt(ov(geomean(proc1TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc1SpaceRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72SpaceRats))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(goComparisonTable))

# doGoComparison()

# ============================================================================
# LaTeX figure: C++ comparison
# ============================================================================

def doCppComparison():
  proc1TimeRats = []
  proc72TimeRats = []
  proc1SpaceRats = []
  proc72SpaceRats = []
  # multiTimeRats = []

  ensureFigDir()
  cppComparisonTable = "figures/cpp-space-time-comparison.tex"
  with open(cppComparisonTable, 'w') as output:
    for tag in sorted(cppTags.keys()):
      cr1 = spg(averageSpace(D, 'cpp', cppTags[tag], 1))
      crp = spg(averageSpace(D, 'cpp', cppTags[tag], maxp))
      mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
      mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

      ct1 = tm(averageTime(D, 'cpp', cppTags[tag], 1))
      ctp = tm(averageTime(D, 'cpp', cppTags[tag], maxp))
      mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
      mtp = tm(averageTime(D, 'mpl-em', tag, maxp))

      proc1TimeRats.append(ovv(sd(mt1, ct1)))
      proc72TimeRats.append(ovv(sd(mtp, ctp)))
      proc1SpaceRats.append(ovv(sd(mr1, cr1)))
      proc72SpaceRats.append(ovv(sd(mrp, crp)))

      row = \
        [ fmt(ct1)
        , fmt(mt1)
        , makeBold(fmt(ov(sd(mt1, ct1))))
        , fmt(ctp)
        , fmt(mtp)
        , makeBold(fmt(ov(sd(mtp, ctp))))
        , sfmt(cr1)
        , sfmt(mr1)
        , makeBold(fmt(ov(sd(mr1, cr1))))
        , sfmt(crp)
        , sfmt(mrp)
        , makeBold(fmt(ov(sd(mrp, crp))))
        ]

      output.write(" & ".join([displayTag(tag)] + row))
      output.write("  \\\\\n")

    output.write("\\midrule\n")
    row = [
      "", "", makeBold(fmt(ov(geomean(proc1TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72TimeRats)))),
      "", "", makeBold(fmt(ov(geomean(proc1SpaceRats)))),
      "", "", makeBold(fmt(ov(geomean(proc72SpaceRats))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(cppComparisonTable))

# doCppComparison()

# ============================================================================
# LaTeX figure: MLton comparison
# ============================================================================

mltonCmpTags = sorted([
  tag for tag in mplOnlyTags
  if (averageTime(D, 'mpl-em', tag, maxp) is not None)
  and tag not in sandmarkTags
  and keepTag(tag)
], key=displayTag)


def ovToPctStr(x):
  try:
    epPct = 100.0 * x
    if x < 0.00001:
      return ""
    elif epPct > 99.999:
      return "100\\%"
    elif epPct > 99:
      return ">99\\%"
    elif epPct < 1:
      return "<1\\%"
    else:
      return str(int(round(epPct))) + "\\%"
  except:
    return "--"

def toPctStr(a, b):
  try:
    eep = float(a)
    rrp = float(b)
    epPct = 100.0 * (eep / rrp)
    if eep < 0.00001:
      return ""
    elif epPct > 99.999:
      return "100\\%"
    elif epPct > 99:
      return ">99\\%"
    elif epPct < 1:
      return "<1\\%"
    else:
      return str(int(round(epPct))) + "\\%"
  except:
    return "--"



def printMLtonComparison(mltonConfigName, includeEntanglement):
  headers = list(map (lambda x : '', list (range (0, 13))))
  tp = 'T({})'.format(maxp)
  spacep = 'R({})'.format(maxp)
  bup = 'R({})/R(s)'.format(maxp)
  entp = 'e({})'.format(maxp)
  headers[3] = 'Time (s)'
  headers[9] = 'Space (GB)'
  headers[-1] = '   Bytes Entangled'
  # headers = ['', 'T(1)', None, None, 'T({})'.format(maxp), None, None, 'R(1)', None, None, 'R({})'.format(maxp), None, None]
  headers1 = ['Benchmark', 'T(s)', 'T(1)', 'T(1)/T(s)', tp, '(' + tp+ '/T(s))', '|','R(s)', 'R(1)', 'R(1)/R(s)', spacep, bup,'|', entp]
  rows = [headers, '-', headers1, "="]

  ovRats = []
  suRats = []
  bu1Rats = []
  bupRats = []

  def doTag(tag):
    mltont = tm(averageTime(D, mltonConfigName, tag, 1))
    mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
    mtp = tm(averageTime(D, 'mpl-em', tag, maxp))

    mltonr = spg(averageSpace(D, mltonConfigName, tag, 1))
    mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
    mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

    pin = pinnedEntangled(D, 'mpl-em', tag, maxp)
    # pinW = pinnedEntangledWatermark(D, 'mpl-em', tag, maxp)
    epPctStr = toPctStr(pin, averageSpace(D, 'mpl-em', tag, maxp))
    # epwPctStr = toPctStr(pinW, averageSpace(D, 'mpl-em', tag, maxp))

    ovRats.append(ovv(sd(mt1, mltont)))
    suRats.append(ovv(sd(mltont, mtp)))
    bu1Rats.append(ovv(sd(mr1, mltonr)))
    bupRats.append(ovv(sd(mrp, mltonr)))

    row = [
      displayTag(tag),
      mltont,
      mt1,
      (str(fmt(ov(sd(mt1, mltont))))),
      mtp,
      (str(fmt(su(sd(mltont, mtp))))),
      '|',
      sfmt(mltonr),
      sfmt(mr1),
      (str(noLeadZero(fmt(bu(sd(mr1, mltonr)))))),
      sfmt(mrp),
      (str(noLeadZero(fmt(bu(sd(mrp, mltonr)))))),
    ]

    if includeEntanglement:
      row += [
        '|',
        sp(pin),
        # sp(pinW),
        # epPctStr
      ]

    row = [ fmt(x) for x in row ]
    return row

  for tag in mltonCmpTags:
    rows.append(doTag(tag))

  row = [
    "geomean", "", "", (fmt(ov(geomean(ovRats)))),
    "",     (fmt(su(geomean(suRats)))),
    "", "", "", (fmt(ov(geomean(bu1Rats)))),
    "",     (fmt(ov(geomean(bupRats))))
  ]
  rows.append("-")
  rows.append(row)
  print("\n MPL* v/s MLton (similar to Figure 5 and Section 4.1)\n".format(maxp))
  print(table(rows, defaultAlign))
  print("\n")
  print("\t\tT(s) denotes MLton time and T(1)/T({}) denote time taken by MPL* on one core and {} cores respectively.".format(maxp, maxp))
  print("\t\tR(s) denotes MLton space and R(1)/R({}) denote space consumed by MPL* on one core and {} cores respectively.".format(maxp, maxp))
  print("\t\tPlease refer to Fig. 5 and Section 4.1 in the paper for details. ".format(maxp, maxp))

  # and R(s) denote time and space taken by MLton to run the benchmark. T(1)/T({}) denote \
        # time taken by MPL ")
  print("\n \n\n")

  # print("[INFO] wrote to {}".format(mltonCmpTable))

def doMLtonComparison(mltonConfigName, includeEntanglement):
  ovRats = []
  suRats = []
  bu1Rats = []
  bupRats = []

  def doTag(tag, output):
    mltont = tm(averageTime(D, mltonConfigName, tag, 1))
    mt1 = tm(averageTime(D, 'mpl-em', tag, 1))
    mtp = tm(averageTime(D, 'mpl-em', tag, maxp))

    mltonr = spg(averageSpace(D, mltonConfigName, tag, 1))
    mr1 = spg(averageSpace(D, 'mpl-em', tag, 1))
    mrp = spg(averageSpace(D, 'mpl-em', tag, maxp))

    pin = pinnedEntangled(D, 'mpl-em', tag, maxp)
    # pinW = pinnedEntangledWatermark(D, 'mpl-em', tag, maxp)
    epPctStr = toPctStr(pin, averageSpace(D, 'mpl-em', tag, maxp))
    # epwPctStr = toPctStr(pinW, averageSpace(D, 'mpl-em', tag, maxp))

    ovRats.append(ovv(sd(mt1, mltont)))
    suRats.append(ovv(sd(mltont, mtp)))
    bu1Rats.append(ovv(sd(mr1, mltonr)))
    bupRats.append(ovv(sd(mrp, mltonr)))

    row = [
      mltont,
      mt1,
      makeBold(fmt(ov(sd(mt1, mltont)))),
      mtp,
      makeBold(fmt(su(sd(mltont, mtp)))),
      sfmt(mltonr),
      sfmt(mr1),
      makeBold(noLeadZero(fmt(bu(sd(mr1, mltonr))))),
      sfmt(mrp),
      makeBold(noLeadZero(fmt(bu(sd(mrp, mltonr))))),
    ]

    if includeEntanglement:
      row += [
        sp(pin),
        # sp(pinW),
        # epPctStr
      ]

    row = [ fmt(x) for x in row ]
    output.write(" & ".join([displayTag(tag)] + row))
    output.write("  \\\\\n")


  ensureFigDir()
  mltonCmpTable = "figures/{}-comparison.tex".format(mltonConfigName)
  with open(mltonCmpTable, 'w') as output:
    # for tag in (tag for tag in mltonCmpTags if tag not in nondetTags):
    #   doTag(tag, output)
    # output.write("\\midrule\n")
    # for tag in (tag for tag in mltonCmpTags if tag in nondetTags):
    #   doTag(tag, output)

    for tag in mltonCmpTags:
      doTag(tag, output)

    output.write("\\midrule\n")
    row = [
      "", "", makeBold(fmt(ov(geomean(ovRats)))),
      "",     makeBold(fmt(su(geomean(suRats)))),
      "", "", makeBold(fmt(ov(geomean(bu1Rats)))),
      "",     makeBold(fmt(ov(geomean(bupRats))))
    ]
    output.write(" & ".join(["geomean"] + row))
    output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(mltonCmpTable))

# doMLtonComparison('mlton', True)
# doMLtonComparison('mlton-tight', False)

# ============================================================================
# LaTeX figure: GC and Runtime Stats
# ============================================================================

def runtimeStats(procs):
  # ovRats = []
  # suRats = []
  # bu1Rats = []
  # bupRats = []

  def doTag(tag, output):
    r = averageSpace(D, 'mpl-em', tag, procs)
    lc = lgcCount(D, 'mpl-em', tag, procs)
    cc = cgcCount(D, 'mpl-em', tag, procs)
    lt = tm(lgcTime(D, 'mpl-em', tag, procs))
    ct = tm(cgcTime(D, 'mpl-em', tag, procs))
    lr = lgcReclaimed(D, 'mpl-em', tag, procs)
    cr = cgcReclaimed(D, 'mpl-em', tag, procs)
    ls = lgcScope(D, 'mpl-em', tag, procs)
    cs = cgcScope(D, 'mpl-em', tag, procs)

    row = [
      sp(r),
      lc,
      lt,
      sp(ls),
      sp(lr),
      cc,
      ct,
      sp(cs),
      sp(cr)
    ]

    row = [ fmt(x) for x in row ]
    output.write(" & ".join([displayTag(tag)] + row))
    output.write("  \\\\\n")

  ensureFigDir()
  runtimeStatsTable = "figures/runtime-stats-{}.tex".format(procs)
  with open(runtimeStatsTable, 'w') as output:
    # for tag in (tag for tag in mltonCmpTags if tag not in nondetTags):
    #   doTag(tag, output)
    # output.write("\\midrule\n")
    # for tag in (tag for tag in mltonCmpTags if tag in nondetTags):
    #   doTag(tag, output)

    for tag in mltonCmpTags:
      doTag(tag, output)

    # output.write("\\midrule\n")
    # row = [
    #   "", "", makeBold(fmt(ov(geomean(ovRats)))),
    #   "",     makeBold(fmt(su(geomean(suRats)))),
    #   "", "", makeBold(fmt(ov(geomean(bu1Rats)))),
    #   "",     makeBold(fmt(ov(geomean(bupRats))))
    # ]
    # output.write(" & ".join(["geomean"] + row))
    # output.write("  \\\\\n")
  print("[INFO] wrote to {}".format(runtimeStatsTable))

# runtimeStats(1)
# runtimeStats(maxp)

# ============================================================================
# LaTeX figure: GC and Runtime Stats, Summary
# ============================================================================

def printRuntimeStatsSummary():
  # ovRats = []
  # suRats = []
  # bu1Rats = []
  # bupRats = []

  gcRats = []
  gcLRecRats = []
  gcCRecRats = []

  totRec = [0]
  totCr = [0]
  totLr = [0]

  headers1 = ['Benchmark','Work', 'GC Work', 'Leaf', 'Intern', 'Tot', 'Leaf', 'Intern','Tot', 'Leaf', 'Intern']
  rows = [headers1, "="]

  def toPctStr(a, b):
    try:
      eep = float(a)
      rrp = float(b)
      epPct = 100.0 * (eep / rrp)
      if eep < 0.00001:
        return ""
      elif epPct > 99.999:
        return "100%"
      elif epPct > 99:
        return ">99%"
      elif epPct < 1:
        return "<1%"
      else:
        return str(int(round(epPct))) + "%"
    except:
      return "--"

  def doTag(tag):
    # r = averageSpace(D, 'mpl-em', tag, maxp)
    lc = lgcCount(D, 'mpl-em', tag, maxp)
    cc = cgcCount(D, 'mpl-em', tag, maxp)
    # lt = tm(lgcTime(D, 'mpl-em', tag, maxp))
    # ct = tm(cgcTime(D, 'mpl-em', tag, maxp))
    lr = lgcReclaimed(D, 'mpl-em', tag, maxp)
    cr = cgcReclaimed(D, 'mpl-em', tag, maxp)
    # ls = lgcScope(D, 'mpl-em', tag, maxp)
    # cs = cgcScope(D, 'mpl-em', tag, maxp)

    totCount = lc + cc
    lgcCountPct = toPctStr(lc, totCount)
    cgcCountPct = toPctStr(cc, totCount)

    gcLRecRats.append(sd(lr, lr+cr))
    gcCRecRats.append(sd(cr, lr+cr))

    totRec[0] += lr+cr
    totCr[0] += cr
    totLr[0] += lr

    try:
      totGC1 = lgcTime(D, 'mpl-em', tag, 1) + cgcTime(D, 'mpl-em', tag, 1)
      approxWork = tm(averageTime(D, 'mpl-em', tag, 1) - totGC1)
    except:
      approxWork = None

    try:
      totGCp = lgcTime(D, 'mpl-em', tag, maxp) + cgcTime(D, 'mpl-em', tag, maxp)
      pctGCWork = toPctStr(totGCp, approxWork)
      gcRats.append(sd(totGCp, approxWork))
    except:
      pctGCWork = None

    avgLGCtimeMilli = 1000.0 * lgcTime(D, 'mpl-em', tag, maxp) / lc
    avgCGCtimeMilli = 1000.0 * cgcTime(D, 'mpl-em', tag, maxp) / cc

    # throughput = gb/sec
    # lgcRecThrough = sd(sd(lr, lgcTime(D, 'mpl-em', tag, maxp)), 1000000.0)
    # cgcRecThrough = sd(sd(cr, cgcTime(D, 'mpl-em', tag, maxp)), 1000000.0)

    row = [
      displayTag(tag),
      approxWork,
      pctGCWork,
      avgLGCtimeMilli,
      avgCGCtimeMilli,
      totCount,
      lgcCountPct,
      cgcCountPct,
      sd(lr+cr, 1000.0),
      toPctStr(lr, lr+cr),
      toPctStr(cr, lr+cr)
    ]

    row = [ fmt(x) for x in row ]
    rows.append(row)
    # output.write(" & ".join([displayTag(tag)] + row))
    # output.write("  \\\\\n")

    # for tag in (tag for tag in mltonCmpTags if tag not in nondetTags):
    #   doTag(tag)
    # output.write("\\midrule\n")
    # for tag in (tag for tag in mltonCmpTags if tag in nondetTags):
    #   doTag(tag)

  for tag in mltonCmpTags:
    doTag(tag)

  rows.append("-")
  row = [
    "geomean",
    "", "", "", "", "", "", "", "",
    # makeBold(fmt(ovToPctStr(geomean(gcRats)))),
    # makeBold(fmt(ovToPctStr(geomean(gcLRecRats)))),
    # makeBold(fmt(ovToPctStr(geomean(gcCRecRats))))
    (fmt(toPctStr(totLr[0], totRec[0]))),
    (fmt(toPctStr(totCr[0], totRec[0])))
  ]
  rows.append(row)
  print(table(rows, defaultAlign))
# runtimeStatsSummary()

# ============================================================================
# PDF: Speedup plot
# ============================================================================

def printMplComparison():
  proc1TimeDiffs = []
  proc72TimeDiffs = []
  proc1SpaceDiffs = []
  proc72SpaceDiffs = []
  headers = ['Benchmark','T(1)', 'T*(1)', 'T(72)', 'T*(72)', 'R(1)', 'R*(1)', 'R(72)','R*(72)']
  rows = [headers, "="]
  for tag in sorted(mplCmpTags):

    if tag in sandmarkTags:
      continue

    # mlton = spg(averageSpace(DS, 'mlton', tag, 1))
    R_mpl1 = spg(averageSpace(D, 'mpl', tag, 1))
    R_mplp = spg(averageSpace(D, 'mpl', tag, maxp))
    R_mplcc1 = spg(averageSpace(D, 'mpl-em', tag, 1))
    R_mplccp = spg(averageSpace(D, 'mpl-em', tag, maxp))

    T_mpl1 = tm(averageTime(D, 'mpl', tag, 1))
    T_mplp = tm(averageTime(D, 'mpl', tag, maxp))
    T_mplcc1 = tm(averageTime(D, 'mpl-em', tag, 1))
    T_mplccp = tm(averageTime(D, 'mpl-em', tag, maxp))

    proc1TimeDiffs.append(pcd(T_mplcc1, T_mpl1))
    proc72TimeDiffs.append(pcd(T_mplccp, T_mplp))
    proc1SpaceDiffs.append(pcd(R_mplcc1, R_mpl1))
    proc72SpaceDiffs.append(pcd(R_mplccp, R_mplp))

    row = \
      [ displayTag(tag)
      , fmt(T_mpl1)
      , (latexpcd(T_mplcc1, T_mpl1, highlight=False))
      , fmt(T_mplp)
      , (latexpcd(T_mplccp, T_mplp, highlight=False))
      , sfmt(R_mpl1)
      , (latexpcd(R_mplcc1, R_mpl1, highlight=False))
      , sfmt(R_mplp)
      , (latexpcd(R_mplccp, R_mplp, highlight=False))
      ]

    rows.append(row)

  rows.append('-')
  row = [
    "geomean",
    "", makeBold(fmtpcd(average(proc1TimeDiffs), highlight=False)),
    "", makeBold(fmtpcd(average(proc72TimeDiffs), highlight=False)),
    "", makeBold(fmtpcd(average(proc1SpaceDiffs), highlight=False)),
    "", makeBold(fmtpcd(average(proc72SpaceDiffs), highlight=False))
  ]
  print(table(rows, defaultAlign))
  print("[INFO] wrote mpl comparison")

# doMplComparison()

# ============================================================================
# PDF: Speedup plot
# ============================================================================

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.axes_grid1.inset_locator import zoomed_inset_axes
from mpl_toolkits.axes_grid1.inset_locator import mark_inset
from matplotlib.ticker import MultipleLocator

usedFull = dict()
usedNoc = dict()

def getspeedup(tag, p):
  baseline = averageTime(D, 'mlton', tag, 1)
  try:
    return baseline / averageTime(D, 'mpl-em', tag, p)
  except Exception as e:
    sys.stderr.write('[WARN] error while plotting speedup for {} at P={}: {}\n'.format(tag, p, e))
    return None

def speedupPlot(outputName, tagsSortedBySpeedups, tagsSortedByName, offset):
  plt.figure(figsize=(7,7))
  # markers = ['o','v','^','<','>','s','*','d','D','+','x','|','','','','','']
  colors = ['blue', 'darkturquoise', 'darkgreen', 'darkviolet', 'red', 'goldenrod','dimgrey', 'brown']
  # 'black',
  markers = ['o','v','^','<','>','s','d']
  # ,'D','*','P','X'
  linestyles = ['solid', 'dashed','dashdot']

  # markers = ['.'] * len(speedupTags)
  procs = P

  fontSize = 22
  legendFontSize = 16
  markerSize = 14

  plt.plot([0,maxp+1], [0,maxp+1], marker="", color="grey", linewidth=0.8)
  lines = []
  for tag in tagsSortedByName:
    try:
      baseline = averageTime(D, 'mlton', tag, 1)
      speedups = list(map((lambda p: getspeedup(tag, p)), procs))

      i = offset + tagsSortedBySpeedups.index(tag)
      ci = i % len(colors)
      mi = i % len(markers)
      si = i % len(linestyles)

      if tuple((ci, mi, si)) in usedFull:
        otherTag = usedFull[tuple((ci, mi, si))]
        sys.stderr.write('[WARN] uh oh: {} and {} have same style\n'.format(tag, otherTag))
      else:
        usedFull[tuple((ci, mi, si))] = tag

      if tuple((mi, si)) in usedNoc:
        otherTag = usedNoc[tuple((mi, si))]
        if tuple((ci, mi, si)) not in usedFull:
          sys.stderr.write('[WARN] uh oh: {} and {} only differ by color\n'.format(tag, otherTag))
      else:
        usedNoc[tuple((mi, si))] = tag

      color = colors[ci]
      marker = markers[mi]
      linestyle = linestyles[si]
      # print("tag {} is index {}: {} {} {}".format(tag, i, color, marker, linestyle))
      lines.append(plt.plot(procs, speedups, linestyle=linestyle, marker=marker, markersize=markerSize, mec='black', mew=0.0, linewidth=1.3, color=color, alpha=0.8))
    except Exception as e:
      sys.stderr.write('[WARN] error while plotting speedup for {}: {}\n'.format(tag, e))

  # this sets the legend.
  font = {
    'size': legendFontSize,
    #'family' : 'normal',
    #'weight' : 'bold',
  }
  matplotlib.rc('font', **font)

  # make sure to use truetype fonts
  matplotlib.rcParams['pdf.fonttype'] = 42
  matplotlib.rcParams['ps.fonttype'] = 42

  # set legend position
  matplotlib.rcParams['legend.loc'] = 'upper left'

  # ticks = [1] + list(range(10, maxp+1, 10))
  # print(ticks)

  plt.xlabel('Processors', fontsize=fontSize)
  plt.ylabel('Speedup', fontsize=fontSize)
  # plt.yticks(ticks, fontsize=fontSize)
  # plt.xticks(ticks, fontsize=fontSize)
  plt.xlim(0, maxp + 2)
  plt.ylim(0, maxp + 2)
  plt.gca().grid(axis='both', linestyle='dotted')
  plt.gca().set_axisbelow(True)
  # plt.margins(y=10)

  if True:
    plt.legend(
      [b[0] for b in lines],
      map(displayTag, tagsSortedByName),
      # bbox_to_anchor=(-0.16,1.05),
      # loc='upper right',
      bbox_to_anchor=(-0.16,1.01),
      loc='upper right',
      ncol=1
    )

  ensureFigDir()
  # outputName = 'figures/mpl-speedups.pdf'
  plt.savefig(outputName, bbox_inches='tight')
  sys.stdout.write("[INFO] speedup plot saved to {}\n".format(outputName))
  plt.close()


def plotSpeedUp(d):
  speedupTags = sorted([
    tag for tag in mplOnlyTags
    if (averageTime(D, 'mpl-em', tag, maxp) is not None)
    and tag not in sandmarkTags
  ], key=displayTag)

  half = int(len(speedupTags)/2)
  groupATags = speedupTags[:half]
  groupBTags = speedupTags[half:]
  groupA = sorted(groupATags, key=(lambda tag: 1.0/getspeedup(tag, maxp)))
  groupB = sorted(groupBTags, key=(lambda tag: 1.0/getspeedup(tag, maxp)))

  sortedBySpeedups = list(sorted(speedupTags, key=(lambda tag: 1.0/getspeedup(tag, maxp))))

  speedupPlot(d + "mpl-speedups-1.pdf", groupA, groupATags, 0)
  speedupPlot(d + "mpl-speedups-2.pdf", groupB, groupBTags, len(groupA))
# groupA = sortedBySpeedups[::2]
# groupB = sortedBySpeedups[1::2]

# groupATags = [t for t in speedupTags if t in groupA]
# groupBTags = [t for t in speedupTags if t in groupB]

# speedupPlot("figures/mpl-speedups.pdf", sortedBySpeedups, speedupTags)
# speedupPlot("figures/mpl-speedups-1.pdf", groupA, groupATags, 0)
# speedupPlot("figures/mpl-speedups-2.pdf", groupB, groupBTags, len(groupA))


# ============================================================================
# PDF: Tangle plot
# ============================================================================



def reportTangle(plotType):
  plt.figure(figsize=(7,7))
  ax = plt.axes()
  colors = ['darkviolet', 'darkturquoise', 'goldenrod', 'darkgreen', 'red', 'blue', 'dimgrey', 'brown']
  markers = ['o','v','^','<','>','s','d']
  linestyles = ['solid', 'dashed','dashdot']
  fontSize = 28
  legendFontSize = 12
  markerSize = 15

  params = [
    '0.01','0.02','0.03','0.04','0.05','0.06','0.07','0.08','0.09',
    '0.1','0.13','0.15','0.2','0.25',
    '0.3','0.4','0.5','0.6','0.7','0.8','0.9','1.0']

  def ratEntangled(tag):
    try:
      pin = pinnedEntangledSingle(D, 'mpl-em', tag, maxp)
      return pin / averageSpaceSingle(D, 'mpl-em', tag, maxp)
    except Exception as e:
      # sys.stderr.write('[WARN] error on tangle ratEntangled({}): {}\n'.format(tag, e))
      return None

  def thisOverhead(a, b):
    try:
      baseline = averageTime(D, 'mpl-em', b, maxp)
      tm = averageTime(D, 'mpl-em', a, maxp)
      return tm / baseline
    except Exception as e:
      # sys.stderr.write('[WARN] error on tangle thisOverhead({}, {}): {}\n'.format(a, b, e))
      return None

  def tagger(version, p):
    return 'tangle{}-{}'.format(version, p)

  def doPlotting(ax):
    lines = []
    legendNames = []
    for i, version in enumerate(['-small3']):
      theseParams = [p for p in params if (ratEntangled(tagger(version, p)) is not None) and (thisOverhead(tagger(version, p), tagger(version, '0.0')) is not None)]
      if version == '-small':
        theseParams = list(filter(lambda p: p not in ["0.02", "0.05"], theseParams))
      X = [ratEntangled(tagger(version, p)) for p in theseParams]
      Y = [thisOverhead(tagger(version, p), tagger(version, '0.0')) for p in theseParams]
      ci = i % len(colors)
      mi = i % len(markers)
      si = i % len(linestyles)
      color = colors[ci]
      marker = markers[mi]
      linestyle = linestyles[si]
      lines.append(ax.plot(X, Y, linestyle=linestyle, marker=marker, markersize=markerSize, mec='black', mew=0.0, linewidth=1.3, color=color, alpha=0.8))
      # lines.append(plt.scatter(X, Y, marker=marker, color=color, alpha=0.8))
      legendNames.append('config{}'.format(i))
    return lines, legendNames

  lines, legendNames = doPlotting(ax)

  # bigX = [ratEntangled('tangle-{}'.format(p)) for p in params]
  # smallX = [ratEntangled('tangle-small-{}'.format(p)) for p in params]

  # bigY = [thisOverhead('tangle-{}'.format(p), 'tangle-0.0') for p in params]
  # smallY = [thisOverhead('tangle-small-{}'.format(p), 'tangle-small-0.0') for p in params]

  # lines = []
  # lines.append(plt.plot(bigX, bigY, linestyle='solid', marker='o', markersize=markerSize, mec='black', mew=0.0, linewidth=1.3, color='darkturquoise', alpha=0.8))
  # lines.append(plt.plot(smallX, smallY, linestyle='solid', marker='v', markersize=markerSize, mec='black', mew=0.0, linewidth=1.3, color='darkviolet', alpha=0.8))
  # legendNames = ['total size = 1.6 GB', 'total size = 800 MB']

  font = {
    'size': legendFontSize,
    #'family' : 'normal',
    #'weight' : 'bold',
  }
  matplotlib.rc('font', **font)

  # make sure to use truetype fonts
  matplotlib.rcParams['pdf.fonttype'] = 42
  matplotlib.rcParams['ps.fonttype'] = 42

  # set legend position
  matplotlib.rcParams['legend.loc'] = 'upper left'


  if plotType == 'log':
    xticks = [0.005 * (2.0 ** i) for i in range(0,8)] + [1.0]
    xlabels = [str(2**(i-1)) + '%' for i in range(0,8)] + ['100%']
    plt.gca().set_xscale('log', base=2)
    plt.xticks(xticks, labels=xlabels, fontsize=fontSize)
    plt.xlim(0.004, 1.0)
  elif plotType == 'linear':
    xticks = np.arange(0.0, 1.1, 0.25)
    xlabels = [str(int(i*25)) + '%' for i in range(0, 5)]
    plt.xticks(xticks, labels=xlabels, fontsize=fontSize)
    plt.xlim(0, 1)
  elif plotType == 'linear-zoom':
    xticks = np.arange(0.0, 0.25, 0.05)
    xlabels = [str(int(i*5)) + '%' for i in range(0, 5)]
    plt.ylim(0.9, 1.5)
    plt.xticks(xticks, labels=xlabels, fontsize=fontSize)
    plt.xlim(0, 0.2)
  else:
    print('[ERR] unknown plot type {}'.format(plotType))
    return

  yticks = np.arange(1.0, 3.0, 0.25)
  ylabels = ["%.2f" % x for x in yticks]

  plt.xlabel('Fraction of Memory Entangled', fontsize=fontSize)
  plt.ylabel('Overhead', fontsize=fontSize)
  plt.yticks(yticks, labels=ylabels, fontsize=fontSize)
  # plt.xticks(xticks, labels=xlabels, fontsize=fontSize)
  # plt.xlim(0.009, 1.0)
  # plt.ylim(0, 0.2)
  # ax.yaxis.set_major_locator(MultipleLocator(0.25))
  # ax.yaxis.set_minor_locator(MultipleLocator(0.1))
  plt.gca().grid(axis='both', which='major', linestyle='dotted')
  plt.gca().grid(axis='y', which='minor', visible=False)
  # ax.yaxis.grid(True, which='minor')
  plt.gca().set_axisbelow(True)
  # plt.margins(y=10)

  # if True:
  #   ax.legend(
  #     [b[0] for b in lines],
  #     # lines,
  #     legendNames,
  #     # bbox_to_anchor=(-0.16,1.05),
  #     # loc='upper right',
  #     bbox_to_anchor=(-0.1,1.01),
  #     loc='lower left',
  #     ncol=3
  #   )

  # if plotType == "linear":
  #   zx1 = 0.0
  #   zx2 = 0.11
  #   zy1 = 0.98
  #   zy2 = 1.22
  #   axins = zoomed_inset_axes(ax, 3, loc='lower right') # zoom = 3
  #   doPlotting(axins)
  #   axins.set_xlim(zx1, zx2)
  #   axins.set_ylim(zy1, zy2)
  #   # plt.xticks(visible=False)
  #   plt.xticks([0.0,0.1], visible=False)
  #   plt.yticks([1.0,1.2], visible=False)
  #   ax.yaxis.set_major_locator(MultipleLocator(0.2))
  #   ax.yaxis.set_minor_locator(MultipleLocator(0.1))
  #   plt.gca().grid(axis='both', which='major', linestyle='dotted')
  #   plt.gca().grid(axis='y', which='minor', visible=False)
  #   # plt.gca().set_axisbelow(False)
  #   mark_inset(ax, axins, loc1=2, loc2=4, fc="none", ec="0.5")

  ensureFigDir()
  outputName = 'figures/tangle-{}.pdf'.format(plotType)
  plt.savefig(outputName, bbox_inches='tight')
  sys.stdout.write("[INFO] output written to {}\n".format(outputName))
  plt.close()

# reportTangle('log')
# reportTangle('linear')
# reportTangle('linear-zoom')

# ============================================================================
# ============================================================================
# ============================================================================
