#!/usr/bin/env python3
"""
Merge the QC reports either side of dehosting into one row. The before-filtering
columns are taken from the pre-dehosting report, so they still describe the raw
input, and the after-filtering columns from the post-dehosting report, so they
describe the reads the pipeline publishes.
"""

import argparse
import csv
import sys


def read_report(report_path):
    with open(report_path, 'r') as f:
        return next(csv.DictReader(f))


def main(args):
    pre_dehosting = read_report(args.pre_dehosting)
    post_dehosting = read_report(args.post_dehosting)

    combined = {'sample_id': pre_dehosting['sample_id']}
    for column in pre_dehosting:
        if column.endswith('_before_filtering'):
            combined[column] = pre_dehosting[column]
    for column in post_dehosting:
        if column.endswith('_after_filtering'):
            combined[column] = post_dehosting[column]

    writer = csv.DictWriter(sys.stdout, fieldnames=list(pre_dehosting),
                            dialect='unix', quoting=csv.QUOTE_MINIMAL)
    writer.writeheader()
    writer.writerow(combined)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--pre-dehosting', required=True)
    parser.add_argument('--post-dehosting', required=True)
    args = parser.parse_args()
    main(args)
