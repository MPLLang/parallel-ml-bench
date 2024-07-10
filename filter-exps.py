#!/usr/bin/env python3

import sys
import json

def main():
    if len(sys.argv) != 4:
        print(f'{sys.argv[0]} input.json output.json exps_to_run.txt', file=sys.stderr)
        exit(1)

    # parse args
    exp_infile = sys.argv[1]
    exp_outfile = sys.argv[2]
    exps_to_run_file = sys.argv[3]

    # Read newline-delimited list of experiments
    with open(exps_to_run_file, 'r') as fh:
        exps_to_keep = [exp for exp in [line.strip() for line in fh]
                        if exp and not exp.startswith('#')]

    # read input json
    with open(exp_infile, 'r') as fh:
        data = json.load(fh)

    # filter specs to only those in exps_to_keep
    data['specs'] = [spec for spec in data['specs']
                     if len(spec['tag']) == 1 and spec['tag'][0] in exps_to_keep]

    # write out filtered json
    with open(exp_outfile, 'w') as fh:
        json.dump(data, fh)

    # now make sure there aren't mislabeled input experiments
    for spec in data['specs']:
        exps_to_keep.remove(spec['tag'][0])
    if exps_to_keep:
        print(f'Couldn\'t find experiments: {exps_to_keep}', file=sys.stderr)

if __name__ == '__main__':
    main()
