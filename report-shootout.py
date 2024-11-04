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

def renameConfig(config):
    m = {
        'mpl-spork-simple': 'spork-simple',
        'mpl-spork-sam': 'spork-sam',
        'mpl-spork-alt': 'spork-alt',
        'mpl-spork-manual': 'spork-man',
        'mpl-spork-2way': 'spork-2way',
        'mpl-spork-3way': 'spork-3way',
        'mpl-spork-3way-slow-exn': 'spork-3way-sx',
        'mpl-spork-3way-slow-exn-no-inl': 'spork-3way-sx-ni',
        'mpl-spork-2way-slow-exn-no-inl': 'spork-2way-sx-ni',
        'mpl-spork-split': 'spork-3way-s',
        'mpl-hb': 'pcall-hb',
        'mpl': 'pcall-man'
    }
    if config in m:
        return m[config]
    else:
        return config

def renameTag(row):
    t = row['tag'].rstrip('-ng')
    return t


parser = argparse.ArgumentParser()
parser.add_argument('--input', nargs=1, metavar='RESULTS_FILE', default=None, required=False)
parser.add_argument('--csv', nargs='+', metavar='CSV_HEADERS', default=None, required=False)
parser.add_argument('--plot', nargs=1, metavar='PLOT_FILE', default=None, required=False)
parser.add_argument('--figs', action='store_true', default=None, required=False)
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

def std(tms):
  if len(tms) < 2:
    return 0.0
  else:
    avg = sum(tms) / len(tms)
    return (sum((x - avg)**2 for x in tms) / (len(tms) - 1)) ** 0.5

def avg(tms):
  return sum(tms) / len(tms)

def median(tms):
  return (tms[(len(tms) - 1)//2] + tms[len(tms)//2]) / 2

def prod(tms):
  p = 1
  for tm in tms:
    p *= tm
  return p

def geomean(tms):
  return prod(tms) ** (1 / len(tms)) if tms else None

def parseStats(row):
    newRow = copy.deepcopy(row)
    newRow['procs']  = int(newRow.get('procs', '1'))
    newRow['config'] = renameConfig(row['config'])
    newRow['tag']    = renameTag(row)
    tms = parseTimes(newRow['stdout'] + '\n' + newRow['stderr'])
    newRow['avgtime'] = avg(tms) if tms else None
    newRow['mintime'] = min(tms) if tms else None
    newRow['maxtime'] = max(tms) if tms else None
    newRow['stdtime'] = std(tms) if tms else None
    return newRow

def findTrials(data, config, tag, procs):
    for row in data:
        if (row['config'] == config and \
                row['tag'] == tag and \
                row['procs'] == procs):
            yield row

def pctdev(data, config, tag, procs):
  r = next(findTrials(data, config, tag, procs))
  times = []
  for line in r['stdout'].split('\n'):
    if line.startswith('time ') and line.endswith('s'):
      times.append(float(line.lstrip('time ').rstrip('s')))
  return (max(times) - min(times)) / max(times)

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

ratios = []

def report_shootout(D, exp, procs, configs):    
    headers1 = [exp, *[f'T({p})' for p in procs]]
    tt = [headers1, "="]
    #t3way = None
    #t3wayni = None
    for config in configs:
        this_times = [averageTime(D, config, exp, p) for p in procs]
        thisRow = [config, *[show(t) if t is not None else "--" for t in this_times]]
        tt.append(thisRow)
        # if config == 'spork-3way':
        #   t3way = this_times
        # elif config == 'spork-3way-ni':
        #   t3wayni = this_times
    print("")
    #tt.append(['3way/ni', *[show(t3/t3ni) for t3, t3ni in zip(t3way, t3wayni)]])
    #ratios.append([t3/t3ni for t3, t3ni in zip(t3way, t3wayni)])
    print(table(tt, defaultAlign))

def report_shootouts(D):
    P = retrieveAll(D, 'procs')
    C = retrieveAll(D, 'config')
    for exp in retrieveAll(D, 'tag'):
        report_shootout(D, exp, P, C)
    #ratios_inverted = [[rats[i] for rats in ratios] for i in range(len(P))]
    #for ri in ratios_inverted:
    #  print(geomean(ri))
    #print(ratios_inverted)


# \begin{center}
# \begin{tabular}{ |c|c|c| } 
#  \hline
#  cell1 & cell2 & cell3 \\ 
#  cell4 & cell5 & cell6 \\ 
#  cell7 & cell8 & cell9 \\ 
#  \hline
# \end{tabular}
# \end{center}

def latex_table(headers, data):
  align = '|r|' + '|'.join('c' for _ in headers[1:]) + '|'
  rows = [[row[0], *[f'{x:0.3f}' for x in row[1:]]] for row in data]
  heading = ' & '.join(x for x in headers)
  contents = '\\\\\n  '.join(' & '.join(row) for row in rows)
  return f'''
\\begin{{tabular}}{{{align}}}
  \\hline
  {heading} \\\\
  \\hline
  {contents} \\\\
  \\hline
\\end{{tabular}}
  '''

# table 1: mlton(1) | us(1) | us(80) | overhead us(1)/mlton(1) | speedup mlton(1) / us(80) | speedup us(1) / us(80)
def report_table_1(D):
  P = retrieveAll(D, 'procs')
  minP, maxP = min(P), max(P)
  headers = [
    f'exp',
    f'mlton({minP})',
    f'spork-hb({minP})',
    f'spork-hb({maxP})',
    f'overhead $\\frac{{\\text{{spork-hb({minP})}}}}{{\\text{{mlton({minP})}}}}$',
    f'speedup $\\frac{{\\text{{mlton({minP})}}}}{{\\text{{spork-hb({maxP})}}}}$',
    f'speedup $\\frac{{\\text{{spork-hb({minP})}}}}{{\\text{{spork-hb({maxP})}}}}$'
  ]
  data = []
  for exp in retrieveAll(D, 'tag'):
    mltonMin = averageTime(D, 'mlton', exp, minP)
    usMin = averageTime(D, 'spork-3way', exp, minP)
    usMax = averageTime(D, 'spork-3way', exp, maxP)
    overheadUsMlton = usMin / mltonMin
    speedupMltonUs = mltonMin / usMax
    speedupUsUs = usMin / usMax
    data.append([exp, mltonMin, usMin, usMax, overheadUsMlton, speedupMltonUs, speedupUsUs])
  return latex_table(headers, data)

# table 2: table mpl-prev(1) | mpl-prev(80) | improvement us(1)/mpl-prev(1) | improvement us(80)/mpl-prev(80)
def report_table_2(D):
  P = retrieveAll(D, 'procs')
  minP, maxP = min(P), max(P)
  headers = [
    f'exp',
    f'pcall-hb({minP})',
    f'pcall-hb({maxP})',
    f'spork-hb({minP})',
    f'spork-hb({maxP})',
    f'improvement $\\frac{{\\text{{spork-hb({minP})}}}}{{\\text{{pcall-hb({minP})}}}}$',
    f'improvement $\\frac{{\\text{{spork-hb({maxP})}}}}{{\\text{{pcall-hb({maxP})}}}}$'
  ]
  data = []
  for exp in retrieveAll(D, 'tag'):
    pcallMin = averageTime(D, 'pcall-hb', exp, minP)
    pcallMax = averageTime(D, 'pcall-hb', exp, maxP)
    sporkMin = averageTime(D, 'spork-3way', exp, minP)
    sporkMax = averageTime(D, 'spork-3way', exp, maxP)
    data.append([exp, pcallMin, pcallMax, sporkMin, sporkMax, sporkMin / pcallMin, sporkMax / pcallMax])
  return latex_table(headers, data)

#figure 3: plot speedup plot mlton(1) / us(P), plotted across P
def report_plot_3(D, ticks=None):
  if ticks is None:
    ticks = retrieveAll(D, 'procs')
  tickmax = max(ticks)
  X = retrieveAll(D, 'tag')
  tickstr = ','.join(str(p) for p in ticks)

  cyclelist = '''
\\pgfplotscreateplotcyclelist{mymarklist}{
  red,mark=*\\\\
  green!70!black,mark=square*\\\\
  blue,mark=triangle*\\\\
  every mark/.append style={rotate=90},yellow!90!black,mark=triangle*\\\\
  every mark/.append style={rotate=180},magenta,mark=triangle*\\\\
  every mark/.append style={rotate=270},brown,mark=triangle*\\\\
  orange,mark=diamond*\\\\
  olive,mark=pentagon*\\\\
  cyan,densely dashed,mark=*\\\\
  lime,densely dashed,mark=square*\\\\
  pink,densely dashed,mark=triangle*\\\\
  every mark/.append style={rotate=90},purple,densely dashed,mark=triangle*\\\\
  every mark/.append style={rotate=180},teal,densely dashed,mark=triangle*\\\\
  every mark/.append style={rotate=270},violet,densely dashed,mark=triangle*\\\\
  gray,densely dashed,mark=diamond*\\\\
  black,densely dashed,mark=pentagon*\\\\
}'''.strip(' \n')

  postamble = '\\end{axis}\n\\end{tikzpicture}'

  def mkplot(title, baseline, uselegend, showystuff):
    ylabel = '\n,ylabel={Speedup}' if showystuff else ''
    preamble = f'''
\\begin{{tikzpicture}}
\\begin{{axis}}[
    title={{{title}}},
    xlabel={{Processors}}{ylabel},
    xmin=0, xmax={tickmax+1},
    ymin=0, ymax={tickmax+1},
    xtick={{{tickstr}}},
    ytick={{{tickstr}}},
    legend pos=outer north east,
    ymajorgrids=true,
    xmajorgrids=true,
    axis equal image,
    fill opacity=0.67,
    draw opacity=1.0,
    text opacity=1.0,
    cycle list name=mymarklist,
    mark options={{solid}}
%    grid style={{gray}},
]'''.strip(' \n')

    lines = [preamble]
    for exp in X:
      coords = []
      for p in ticks:
        t = averageTime(D, 'spork-3way', exp, p)
        base = averageTime(D, baseline, exp, 1)
        speedup = base/t
        coords.append(f'({p}, {speedup:0.3f})')
      coords = ''.join(coords)
      lines.append(f'% {exp}\n\\addplot+ coordinates\n  {{{coords}}};')
    xyline = f'\\addplot[no markers] coordinates {{(0,0) ({tickmax+1},{tickmax+1})}};'
    lines.append(xyline)
    if uselegend:
      legend = ','.join(X)
      lines.append(f'\\legend{{{legend}}}')
    lines.append(postamble)
    return '\n\n'.join(lines)
  return '\n\n'.join(
    [cyclelist,
     mkplot('Speedup vs MLton', 'mlton', False, True),
     mkplot('Self Speedup', 'spork-3way', True, False)])

#figure 4: overheads of NG vs manual tune
def report_table_4(D):
  P = retrieveAll(D, 'procs')
  minP, maxP = min(P), max(P)
  headers = [
    f'exp',
    f'pcall-grained({minP})',
    f'pcall-grained({maxP})',
    f'spork-hb({minP})',
    f'spork-hb({maxP})',
    f'overhead $\\frac{{\\text{{spork-hb({minP})}}}}{{\\text{{pcall-grained({minP})}}}}$',
    f'overhead $\\frac{{\\text{{spork-hb({maxP})}}}}{{\\text{{pcall-grained({maxP})}}}}$'
  ]
  data = []
  for exp in retrieveAll(D, 'tag'):
    pcallMin = averageTime(D, 'pcall-man', exp, minP)
    pcallMax = averageTime(D, 'pcall-man', exp, maxP)
    sporkMin = averageTime(D, 'spork-3way', exp, minP)
    sporkMax = averageTime(D, 'spork-3way', exp, maxP)
    data.append([exp, pcallMin, pcallMax, sporkMin, sporkMax, sporkMin / pcallMin, sporkMax / pcallMax])
  return latex_table(headers, data)

def report_figures(D):
  table1 = report_table_1(D)
  table2 = report_table_2(D)
  plot3 = report_plot_3(D, ticks=[1,10,20,30,40,50,60,70,80])
  table4 = report_table_4(D)
  print('TABLE 1')
  print(table1)
  print('')
  print('TABLE 2')
  print(table2)
  print('')
  print('PLOT 3')
  print(plot3)
  print('')
  print('TABLE 4')
  print(table4)


# ============================================================================

# def report_csv(D):
#     # Retrieve (ordered) set of attributes present across all rows
#     attrs = args.csv
#     # Print headers
#     print(",".join(attrs))
    
#     # Print rows
#     for row in D:
#         print(",".join(show(row.get(attr, "")) for attr in attrs))

def report_csv(D):
  P = retrieveAll(D, 'procs')
  C = retrieveAll(D, 'config')
  print('exp', 'config', *[f'T({p})' for p in P], sep=', ')
  for exp in retrieveAll(D, 'tag'):
    for config in C:
      ts = [averageTime(D, config, exp, p) for p in P]
      print(exp, config, *[f'{t:0.4f}' if t else '--' for t in ts], sep=', ')
        

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
    pc_labels = [f'{renameConfig(config)}-{p}' for (p, config, d) in data]
    
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
  elif args.figs:
    report_figures(D)
  else:
    #report_table(D)
    report_shootouts(D)

# repeat warmup cmd args bench tag affinity split grain config cwd procs compiler host timestamp stdout stderr elapsed returncode avgtime mintime maxtime stdtime
# cmd bench tag config cwd procs compiler avgtime mintime maxtime stdtime
