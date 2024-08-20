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
import matplotlib
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser()
parser.add_argument('--input', nargs=1, metavar='RESULTS_FILE', default=None, required=False)
parser.add_argument('--csv', nargs='+', metavar='CSV_HEADERS', default=None, required=False)
parser.add_argument('--plot', nargs=1, metavar='PLOT_FILE', default=None, required=False)
args = parser.parse_args()

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

def std(tms):
  avg = sum(tms) / len(tms)
  return (sum((x - avg)**2 for x in tms) / (len(tms) - 1)) ** 0.5

def parseStats(row):
    newRow = copy.deepcopy(row)
    newRow['procs']  = int(newRow.get('procs', '1'))
    newRow['config'] = renameConfig(row['config'])
    newRow['tag']    = renameTag(row)
    tms = parseTimes(newRow['stdout'] + '\n' + newRow['stderr'])
    newRow['avgtime'] = sum(tms) / len(tms) if tms else None
    newRow['mintime'] = min(tms) if tms else None
    newRow['maxtime'] = max(tms) if tms else None
    newRow['stdtime'] = std(tms) if tms else None
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

def show(x):
    if x is None:
        return ""
    elif isinstance(x, str):
        return x
    elif isinstance(x, float):
        return sigfigs(x)
    elif isinstance(x, int):
        return str(x)
    elif isinstance(x, bool):
        return 'true' if x else 'false'
    else:
        raise ValueError(f"show() only takes a str, float, int, or bool arg: got {type(x)}")

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
    d = os.path.join(os.path.abspath(os.path.dirname(__file__)), 'results')
    files = (os.path.join(d, f) for f in os.listdir(d) if f.endswith('.json'))
    # (file, creation time) iterable
    files_cts = ((f, os.stat(f).st_ctime) for f in files)
    # Get the most recent file by max creation time
    most_recent_f, _ = max(files_cts, key=lambda x: x[1])
    return most_recent_f

def loadData():
    if args.input:
        if isinstance(args.input, list):
            args.input = args.input[0]
        timingsFile = args.input
    else:
        print("[INFO] no results file argument; finding most recent", file=sys.stderr)
        timingsFile = mostRecentResultsFile()
    
    print("[INFO] reading {}".format(timingsFile), file=sys.stderr)
    with open(timingsFile, 'r') as data:
        resultsData = json_careful_readlines(data)
    return [ parseStats(row) for row in resultsData ]

def retrieveAll(D, attr):
    return sorted(set(row[attr] for row in D))

# ============================================================================

def report_shootout(D, exp, procs, configs):    
    headers1 = [exp, *[f'T({p})' for p in procs]]
    tt = [headers1, "="]
    for config in configs:
        this_times = [averageTime(D, config, exp, p) for p in procs]
        thisRow = [config, *[show(t) if t is not None else "--" for t in this_times]]
        tt.append(thisRow)
    
    print("")
    print(table(tt, defaultAlign))

def report_shootouts(D):
    P = retrieveAll(D, 'procs')
    C = retrieveAll(D, 'config')
    for exp in retrieveAll(D, 'tag'):
        report_shootout(D, exp, P, C)

# ============================================================================

def report_csv(D):
    # Retrieve (ordered) set of attributes present across all rows
    attrs = args.csv
    # Print headers
    print(",".join(attrs))
    
    # Print rows
    for row in D:
        print(",".join(show(row.get(attr, "")) for attr in attrs))

# ============================================================================

def filter_data(D, **kwargs):
    for row in D:
        do_yield = True
        for k, v in kwargs.items():
            if row[k] != v:
                do_yield = False
                break
        if do_yield:
            yield row

def filter_data_first(D, **kwargs):
    for x in filter_data(D, **kwargs):
        return x
    return None

# def report_show_plot(D):
#     tags = retrieveAll(D, 'tag') # experiment names ('primes', etc)
#     configs = retrieveAll(D, 'config')
#     procs = retrieveAll(D, 'procs')
#     avgtimes = {
#         f'{config}-{p}': list(next(filter_data(D, procs=p, tag=tag, config=config))['avgtime'] for tag in tags)
#         for config in configs
#         for p in procs
#     }
    
#     x = np.arange(len(tags))  # the label locations
#     width = 0.25  # the width of the bars
#     multiplier = 0
    
#     fig, ax = plt.subplots()#layout='constrained')
    
#     for attribute, measurement in avgtimes.items():
#         offset = width * multiplier
#         rects = ax.bar(x + offset, measurement, width, label=attribute)
#         ax.bar_label(rects, padding=3)
#         multiplier += 1
    
#     # Add some text for labels, title and custom x-axis tick labels, etc.
#     ax.set_ylabel('Time (s)')
#     ax.set_title('Average times')
#     ax.set_xticks(x + width, tags)
#     ax.legend(loc='upper left', ncols=3)
#     ax.set_ylim(0, 250)

#     #plt.show()
#     plt.save('img.png')

def rename_exp(config):
    m = {
        'mpl-spork-simple-one': 'spork-simple',
        'mpl-spork-sam-one': 'spork-sam',
        'mpl-spork-alt-one': 'spork-alt',
        'mpl-spork-manual': 'spork-man',
        'mpl-spork-2way-one': 'spork-2way',
        'mpl-spork-3way-one': 'spork-3way',
        'mpl-hb-one': 'pcall',
        'mpl': 'pcall-man'
    }
    if config in m:
        return m[config]
    else:
        return config

def report_show_plot(D):
    labels = retrieveAll(D, 'tag') # experiment names ('primes', etc)
    configs = retrieveAll(D, 'config')
    PROCS = 1
    procs = [PROCS] # retrieveAll(D, 'procs')
    def get_times(p, config):
        ts = list(filter_data_first(D, procs=p, tag=tag, config=config) for tag in labels)
        return [(t['avgtime'] if t and t['avgtime'] else 0.0) for t in ts]
    data = [(p, config, get_times(p, config)) for config in configs for p in procs]
    means = np.array([t for p, config, t in data])
    for i in range(len(labels)):
        means[:, i] /= max(means[:, i])
    print(means)
    pc_labels = [f'{rename_exp(config)}-{p}' for (p, config, d) in data]
    
    x = np.arange(len(labels))  # the label locations
    width = 0.35 * 2 / len(pc_labels)  # the width of the bars

    def get_sort_idxs(xs):
        out = np.zeros([len(xs)])
        for i, r in enumerate(np.argsort(xs)):
            out[r] = i
        return out
    sort_idxs = np.array([get_sort_idxs([t[i] for p, c, t in data]) for i in range(len(labels))])
    print(sort_idxs)
    
    fig, ax = plt.subplots()
    fig.set_size_inches(30, 10)
    for i in range(len(pc_labels)):
        ts = means[i]
        print(sort_idxs[:,i])
        offsets = x + (sort_idxs[:,i] - (len(pc_labels) - 1)/2)*width
        ax.bar(offsets, ts, width, label=pc_labels[i])
    # i = 0
    # for p in procs:
    #     for exp_name in labels:
    #         ts = []
    #         for p2, config, 
    #         i += 1
    # for p, c, ts in data:
    #     pass
    
    # Add some text for labels, title and custom x-axis tick labels, etc.
    ax.set_ylabel('Times')
    ax.set_title('Times')
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.legend()
    
    #fig.tight_layout()
    plt.savefig(args.plot[0], dpi=100.0)

# ============================================================================

if __name__ == '__main__':
    D = loadData()
    if args.csv:
        report_csv(D)
    elif args.plot:
        report_show_plot(D)
    else:
        report_shootouts(D)

# repeat warmup cmd args bench tag affinity split grain config cwd procs compiler host timestamp stdout stderr elapsed returncode avgtime mintime maxtime stdtime
# cmd bench tag config cwd procs compiler avgtime mintime maxtime stdtime
