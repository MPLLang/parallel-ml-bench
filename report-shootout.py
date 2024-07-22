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
    print("found {}".format(newTag))
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
  trials = [ r for r in findTrials(data, config, tag, procs) if (not checkExpType) or 'exp' not in r or (r['exp'] == 'time') ]
  tms = [ r['avgtime'] for r in trials if 'avgtime' in r ]
  try:
    return tms[-1]
  except:
    return None

def averageSpace(data, config, tag, procs, checkExpType=True):
  trials = [ r for r in findTrials(data, config, tag, procs) if (not checkExpType) or 'exp' not in r or (r['exp'] == 'space') ]
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

def stripANSI(x):
  l = 0
  esc = False
  for c in x:
    if esc and x == 'm':
      esc = False
    elif x == '\033':
      esc = True
    elif not esc:
      l += 1
  return l

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
      #rw = len(row[i])
      rw = stripANSI(row[i])
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
  print("[INFO] no results file argument; finding most recent")
  try:
    mostRecent = mostRecentResultsFile()
  except Exception as e:
    print(e)
    print("[ERR] could not find most recent results file\n " + \
          "  check that these are formatted as 'YYMMSS-hhmmss'")
    sys.exit(1)
  timingsFile = os.path.join(ROOT, 'results', mostRecent)

print("[INFO] reading {}\n".format(timingsFile))
with open(timingsFile, 'r') as data:
  resultsData = json_careful_readlines(data)
D = [ parseStats(row) for row in resultsData ]
P = sorted(list(foundProcs))
maxp = max(p for p in foundProcs if p <= 72)
orderedTags = sorted(list(foundTags), key=displayTag)


# ===========================================================================

def filterSome(xs):
  return [x for x in xs if x is not None]

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

def report_shootout(exp):
    shootout = [
        ("mlton", "mlton", exp),
        ("pcall-1", "mpl-hb-one", exp),
        ("spork2-1", "mpl-spork-2way-one", exp),
        ("spork3-1", "mpl-spork-3way-one", exp),
        ("pcall-4", "mpl-hb-small", exp),
        ("spork2-4", "mpl-spork-2way-small", exp),
        ("spork3-4", "mpl-spork-3way-small", exp)
    ]
    # try:
    #   shootoutBaseline = \
    #     min(filterSome(
    #       [tm(averageTime(D, config, tag, 1)) for name,config,tag in shootout]
    #     ))
    # except:
    #   shootoutBaseline = None
    
    headers1 = [exp, *[f'T({p})' for p in P], 'T(1)/mlton', *[f'mlton/T({p})' for p in P if p != 1]]
    tt = [headers1, "="]
    mlton_time = averageTime(D, "mlton", exp, 1)
    for name, config, tag in shootout:
      this_times = [averageTime(D, config, tag, p) for p in P]
      thisRow = [
        *[tm(t) for t in this_times],
        tm(averageTime(D, config, tag, 1) / mlton_time),
        *[(tm(mlton_time / t) if t else "--") for p, t in zip(P, this_times) if p != 1]
      ]
      thisRow = [name] + [str(x) if x is not None else "--" for x in thisRow]
      tt.append(thisRow)
    
    #print(f"{exp} SHOOTOUT")
    print(table(tt, defaultAlign))
    print("")

if __name__ == '__main__':
    with open('exps_to_run.txt', 'r') as fh:
        for exp in fh:
            if not exp.startswith('#'):
                report_shootout(exp.strip())
