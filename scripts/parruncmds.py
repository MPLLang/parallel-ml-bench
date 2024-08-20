#!/usr/bin/env python3

import sys
import signal
import socket
import time
import threading
import subprocess
import multiprocessing
import os
import tempfile
import argparse
import json
import random
from datetime import datetime

def mk_randomstr(n=10):
    'returns a string of random letters of length n'
    alpha = list(chr(i) for i in range(ord('a'), ord('z') + 1))
    return ''.join(random.choice(alpha) for _ in range(n))

NCPU = multiprocessing.cpu_count()
MAX_COSCHEDULED_EXPS = NCPU // 6

def getGitRoot():
  return subprocess.Popen(['git', 'rev-parse', '--show-toplevel'],
    stdout=subprocess.PIPE).communicate()[0].decode('utf-8').rstrip()

_currentChildren = [None for _ in range(NCPU)]

def _signalHandler(signal, frame):
    global _currentChildren
    sys.stderr.write("[ERR] Interrupted.\n")
    if _currentChildren:
        for i in range(len(_currentChildren)):
            child = _currentChildren[i]
            if child:
                child.kill()
    sys.exit(1)
signal.signal(signal.SIGINT, _signalHandler)

def _killer():
    global _currentChildren
    if _currentChildren:
        for child in _currentChildren:
            try:
                child.kill()
            except Exception as e:
                sys.stderr.write("[WARN] Error while trying to kill process {}: {}\n".format(child.pid, str(e)))

def runcmd(i, childidx, rows, fd, aff, timeout=600.0, silent=False):
    #os.sched_setaffinity(aff)
    row = rows[i].copy()
    row['host'] = socket.gethostname()
    row['timestamp'] = datetime.now().strftime("%y-%m-%d %H:%M:%S.%f")
    cmd = row['cmd']
    affstr = ''
    for c in aff:
        affstr += f'{c},'
    affstr = affstr.rstrip(',')
    cwd = row['cwd'] if 'cwd' in row else None
    subproc = subprocess.Popen(
        f'taskset -c {affstr} {cmd}',
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=cwd)
    _currentChildren[childidx] = subproc
  
    row['stdout'] = ''
    row['stderr'] = ''
    ts = time.time()
    try:
        stdout, stderr = subproc.communicate(timeout=timeout)
        row['stdout'] = stdout.decode('utf-8')
        row['stderr'] = stderr.decode('utf-8')
    finally:
        row['elapsed'] = time.time() - ts
    row['returncode'] = subproc.returncode
    with open(fd, mode='x') as fh:
        json.dump(row, fh)    

def runcmds(TMPDIR, rows, timeout=600.0, silent=False):
    global _currentChildren
    
    rows_sorted_by_procs = list(sorted(rows, key=lambda r: int(r['procs'])))
    cmds = []
    procs_used = 0
    row_idx = 0
    affinity = os.sched_getaffinity(os.getpid())
    while row_idx < len(rows):
        aff = affinity.copy()
        pool = []
        for i in range(row_idx, len(rows)):
            procs = int(rows_sorted_by_procs[i]['procs'])
            if procs > len(aff) or len(pool) >= MAX_COSCHEDULED_EXPS:
                row_idx = i
                break
            if i == len(rows) - 1:
                row_idx = i + 1
            cmd = rows_sorted_by_procs[i]['cmd']
            paff = {aff.pop() for _ in range(procs)}
            print(f'[{i+1}/{len(rows)}] {cmd}', file=sys.stderr, flush=True)
            
            fp = os.path.join(TMPDIR, f'results_{i}')
            p = multiprocessing.Process(
                target=runcmd,
                args=(i, len(pool), rows_sorted_by_procs, fp, paff))
            pool.append((fp, p))
        _currentChildren[:len(pool)] = [p for fd, p in pool]
        for fp, p in pool:
            p.start()
        for fp, p in pool:
            try:
                p.join()
                with open(fp) as fh:
                    yield json.load(fh)
            except Exception as e:
                print(e, file=sys.stderr, flush=True)
                if p.is_alive():
                    p.terminate()

# scripty part =============================================================

def main(TMPDIR):
    parser = argparse.ArgumentParser()
    parser.add_argument('-t', '--timeout', type=float, default=300.0, dest='timeout')
    parser.add_argument('-s', '--silent', action='store_true', dest='silent')
    parser.add_argument('-o', '--output', type=argparse.FileType('a'), default=sys.stdout, dest='output')
    parser.add_argument('-b', '--bare', action = 'store_true', dest = 'bare')
    parser.add_argument('-c', '--compile', action = 'store_true', dest = 'compile')
    args = parser.parse_args()
  
    root = getGitRoot()
  
    if args.bare:
        rows = [{'cmd':x.rstrip('\n')} for x in sys.stdin]
    else:
        rows = [ json.loads(x) for x in sys.stdin ]
  
    if args.compile:
        binsToMake = set()
        for r in rows:
            binFile = '{}.{}.bin'.format(r['bench'], r['config'])
            suffix = os.path.join('bin', binFile)
            prefix = root
            if 'cwd' in r:
                prefix = os.path.join(prefix, r['cwd'])
            if not os.path.isfile(os.path.join(prefix, suffix)):
                binsToMake.add((prefix, binFile))
            else:
                sys.stderr.write("Missing file " + os.path.join(prefix, suffix) + "\n")
        
        places = set(prefix for (prefix, _) in binsToMake)
        
        for place in places:
            binsToMakeHere = filter(lambda prefixb: prefixb[0] == place, binsToMake)
            binsToMakeHere = list(map(lambda prefixb: prefixb[1], binsToMakeHere))
            if len(binsToMakeHere) == 0:
                continue
            
            sys.stderr.write("[WARN] missing binaries in {}:\n".format(place))
            for b in binsToMakeHere:
                sys.stderr.write("  " + b + "\n")
            
            jobs = max(4, NCPU//2)
            cmd = "make -C {} -j {} ".format(place, jobs) + (" ".join(binsToMakeHere))
            sys.stderr.write("[INFO] " + cmd + "\n")
            
            output = None
            shouldQuit = False
            try:
                output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
            except subprocess.CalledProcessError as e:
                output = e.output
                shouldQuit = True
            output = output.decode('utf-8')
            sys.stderr.write(output + "\n")
            if shouldQuit:
                sys.exit(1)
  
    for result in runcmds(TMPDIR, rows, timeout=args.timeout, silent=args.silent):
        s = '{}\n'.format(json.dumps(result))
        args.output.write(s)
        if not args.silent:
            sys.stderr.write(result['cmd'] + '\n')
            sys.stderr.write(result['stdout'] + '\n')
            sys.stderr.write(result['stderr'] + '\n')

if __name__ == "__main__":
    TMPDIR = f'.tmp_runcmds_{mk_randomstr()}'
    os.mkdir(TMPDIR)
    try:
        main(TMPDIR)
    finally:
        for fp in os.listdir(TMPDIR):
            os.remove(os.path.join(TMPDIR, fp))
        os.rmdir(TMPDIR)
