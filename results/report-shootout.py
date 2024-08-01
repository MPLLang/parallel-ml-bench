#!/usr/bin/python3

import math
import json
import sys
import re
import copy
import os
import argparse
import subprocess
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument('input_file', nargs='?', metavar='RESULTS_FILE')
args = parser.parse_args()

def getGitRoot():
    data = subprocess.Popen(['git', 'rev-parse', '--show-toplevel'],
        stdout=subprocess.PIPE).communicate()[0].rstrip()
    return "".join(chr(x) for x in data)

def json_careful_loads(s):
    try:
        return json.loads(s)
    except Exception as e:
        sys.stderr.write("[ERR] Error while parsing json: {}\n".format(e))
        sys.exit(1)

def json_careful_readlines(f):
    return [ json_careful_loads(line.rstrip('\n')) for line in f ]

def reCompile(exp):
    return re.compile(exp, re.MULTILINE)

def parseTimes(stdout):
    pat = reCompile(r"^time\s+(\d+.\d+).*$")
    return [float(x) for x in pat.findall(stdout)]

def renameConfig(c):
    return c

def renameTag(row):
    t = row['tag'].rstrip('-ng')
    return t

foundTags = set()
foundProcs = set()

def parseStats(row):
    newRow = copy.deepcopy(row)
    newRow['procs']  = int(newRow.get('procs', '1'))
    newRow['config'] = renameConfig(row['config'])
    newRow['tag']    = renameTag(row)
    foundTags.add(newRow['tag'])
    foundProcs.add(newRow['procs'])
    tms = parseTimes(newRow['stdout'] + '\n' + newRow['stderr'])
    newRow['avgtime'] = sum(tms) / len(tms) if tms else None
    return newRow

def findTrials(data, config, tag, procs):
    result = []
    for row in data:
        if (row['config'] == config and \
                row['tag'] == tag and \
                row['procs'] == procs):
            result.append(row)
    return result

def averageTime(data, config, tag, procs, checkExpType=True):
    trials = [ r for r in findTrials(data, config, tag, procs) if (not checkExpType) or 'exp' not in r or (r['exp'] == 'time') ]
    tms = [ r['avgtime'] for r in trials if 'avgtime' in r ]
    try:
        return tms[-1]
    except:
        return None

def defaultAlign(i):
    return "r" if i == 0 else "l"

def sigfigs(n, d=3):
    'Format n as a string with d significant figures'
    if n == 0.0:
        return f'{n:0.0{d}f}'
    else:
        intdigs = max(0, int(math.log10(n)))
        floatdigs = max(0, d - intdigs)
        return f'{n:0.0{floatdigs}f}'

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

def mostRecentResultsFile():
    d = os.path.abspath(os.path.dirname(__file__))
    files = (os.path.join(d, f) for f in os.listdir(d) if f.endswith('.json'))
    # (file, creation time) iterable
    files_cts = ((f, os.stat(f).st_ctime) for f in files)
    # Get the most recent file by max creation time
    most_recent_f, _ = max(files_cts, key=lambda x: x[1])
    return most_recent_f

def loadData():
    if args.input_file:
        timingsFile = args.input_file
    else:
        print("[INFO] no results file argument; finding most recent")
        timingsFile = mostRecentResultsFile()
    
    print("[INFO] reading {}\n".format(timingsFile))
    with open(timingsFile, 'r') as data:
        resultsData = json_careful_readlines(data)
    D = [ parseStats(row) for row in resultsData ]
    P = sorted(list(foundProcs))
    return D, P

# ============================================================================

def report_shootout(D, P, exp):
    shootout = [
        ("pcall-hb", "mpl-hb-one", exp),
        ("spork-hb-2way", "mpl-spork-2way-one", exp),
        ("spork-hb-3way", "mpl-spork-3way-one", exp),
        ("pcall-manual", "mpl", exp),
        ("spork-manual", "mpl-spork-manual", exp)
        #("sporkalt-1", "mpl-spork-alt-one", exp),
        #("sporksam-1", "mpl-spork-sam-one", exp),
        #("pcall-4", "mpl-hb-small", exp),
        #("spork2-4", "mpl-spork-2way-small", exp),
        #("spork3-4", "mpl-spork-3way-small", exp),
        #("sporkalt-4", "mpl-spork-alt-small", exp),
        #("sporksam-4", "mpl-spork-sam-small", exp),
    ]
    
    headers1 = [exp, *[f'T({p})' for p in P]]
    tt = [headers1, "="]
    for name, config, tag in shootout:
        this_times = [averageTime(D, config, tag, p) for p in P]
        thisRow = [name] + [sigfigs(t) if t is not None else "--" for t in this_times]
        tt.append(thisRow)
    
    print(table(tt, defaultAlign))
    print("")

if __name__ == '__main__':
    D, P = loadData()
    tags = sorted(set(row['tag'] for row in D))
    for exp in tags:
        report_shootout(D, P, exp)
