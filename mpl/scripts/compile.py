#!/usr/bin/python2

import argparse, sys, os, json, subprocess, errno

def getGitRoot():
  return subprocess.Popen(['git', 'rev-parse', '--show-toplevel'],
    stdout=subprocess.PIPE).communicate()[0].rstrip()

def ensureDirs(path):
  d = os.path.dirname(path)
  if d == "":
    return
  if not os.path.exists(d):
    try:
      os.makedirs(d)
    except OSError as exc: # Guard against race condition
      if exc.errno != errno.EEXIST:
        raise

# scripty part =============================================================

if __name__ == "__main__":

  def eprint(msg):
    sys.stderr.write("[ERR] " + msg + "\n")
  def die():
    sys.exit(1)

  parser = argparse.ArgumentParser(add_help=False)
  required = parser.add_argument_group('required arguments')
  optional = parser.add_argument_group('optional arguments')

  optional.add_argument('-h', '--help',
    action = 'help',
    default = argparse.SUPPRESS,
    help = 'show this help message and exit'
  )
  optional.add_argument('-v', '--verbose',
    dest = 'verbose',
    action = 'store_true',
    help = 'be more verbose'
  )

  optional.add_argument(
    dest = 'flags',
    nargs = argparse.REMAINDER
  )

  required.add_argument('-b', '--benchmark',
    required = True,
    dest = 'benchmark',
    metavar = 'BENCHMARK',
    help = 'name of the benchmark in bench/'
  )
  required.add_argument('-c', '--config',
    required = True,
    dest = 'config',
    metavar = 'CONFIG',
    help = 'name of compiler config (one of CONFIG.json in config/)'
  )
  required.add_argument('-o', '--output',
    required = True,
    dest = 'output',
    metavar = 'PATH',
    help = 'output path'
  )
  args = parser.parse_args()

  def vprint(msg):
    if args.verbose:
      sys.stdout.write("[INFO] " + msg + "\n")

  root = getGitRoot()
  # vprint("git root: " + root)

  def relativePath(path):
    return os.path.join(root, "mpl", path)

  sourceMLB = relativePath("bench/{}/{}.mlb".format(args.benchmark, args.benchmark))
  if not os.path.isfile(sourceMLB):
    eprint("no such file: {}".format(sourceMLB))
    die()

  configFile = relativePath("config/{}.json".format(args.config))
  if not os.path.isfile(configFile):
    eprint("no such file: {}".format(configFile))
    die()

  try:
    with open(configFile, 'r') as f:
      config = json.loads(f.read())
  except:
    eprint("could not load " + configFile)
    die()

  ensureDirs(args.output)

  flags = args.flags[1:] if len(args.flags) > 0 and args.flags[0] == "--" else args.flags

  compilerPath = config["compiler"]
  if "mpl-switch-commit" in config:
    commit = config["mpl-switch-commit"]
    compilerPath = os.path.join(
      os.path.expanduser("~"),
      ".mpl",
      "versions",
      commit,
      "bin",
      compilerPath
    )
    if not os.path.exists(compilerPath):
      eprint("cannot find {}\n  maybe you need to run ../scripts/install_mpls ?".format(compilerPath))
      die()

  cmd = \
    [
      compilerPath,
      "-mlb-path-var", "COMPAT " + config["compat"]
    ] + \
    flags + \
    config["flags"] + \
    [
      "-output", args.output,
      sourceMLB
    ]

  # as if we had typed into the shell. probably not quite correct for
  # weird argument situations
  cmdStr = " ".join([("'{}'".format(x) if ' ' in x else x) for x in cmd])
  vprint(cmdStr)

  compileProcess = \
    subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  out, err = compileProcess.communicate()

  if compileProcess.returncode == 0:
    vprint("compilation succeeded")
  else:
    sys.stderr.write(out + "\n" + err + "\n")
    vprint("compilation failed")
    die()
