#!/usr/bin/env python3

import sys
import json

def main():
    if len(sys.argv) != 3:
        print(f'{sys.argv[0]} input.json output.json', file=sys.stderr)
        exit(1)

    # parse args
    exp_infile = sys.argv[1]
    exp_outfile = sys.argv[2]

    # read input json
    with open(exp_infile, 'r') as fh:
        # Delete commented-out lines
        lines = []
        for line in fh:
            line = line.rstrip('\n')
            ci = line.find('//')
            if ci != -1:
                line = line[:ci]
            lines.append(line)
        data = json.loads('\n'.join(lines))

    exps_to_keep = data['exps-to-run']

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
