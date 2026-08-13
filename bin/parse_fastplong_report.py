#!/usr/bin/env python3
"""
Convert a fastplong report pair into the single-sample QC csv used by this
pipeline. Reads and bases come from the json report; N50 and the length extremes
are only available in the html report, and read quality is only available as the
json's per-read mean quality histogram.
"""

import argparse
import csv
import json
import re
import sys


FIELDNAMES = [
    'sample_id',
    'reads',
    'bases',
    'n50',
    'longest',
    'shortest',
    'mean_length',
    'median_length',
    'mean_quality',
    'median_quality',
]

# HtmlReporter::formatNumber abbreviates anything above 1000, eg. '12.345000 K'.
UNIT_MULTIPLIERS = {'': 1, 'K': 10 ** 3, 'M': 10 ** 6, 'G': 10 ** 9, 'T': 10 ** 12, 'P': 10 ** 15}

BASIC_INFO_ROW = re.compile(
    r"<tr><td class='col1'>(?P<label>[^<]*)</td><td class='col2'>(?P<value>[^<]*)</td></tr>"
)


def parse_html_number(value):
    """Turn a formatNumber string such as '12.345000 K' back into an int."""
    match = re.fullmatch(r'\s*(-?[\d.]+)\s*([KMGTP]?)\s*', value)
    if match is None:
        raise ValueError(f"could not parse number from html value: {value!r}")

    return round(float(match.group(1)) * UNIT_MULTIPLIERS[match.group(2)])


def parse_basic_info(html_path, filtering_type='Before filtering'):
    """Collect the label/value rows of one 'Basic statistics' table in the html report."""
    with open(html_path, 'r') as f:
        report = f.read()

    section_title = f"{filtering_type}: Basic statistics"
    section_start = report.find(section_title)
    if section_start < 0:
        raise ValueError(f"no '{section_title}' section in {html_path}")

    section_end = report.find('</table>', section_start)
    if section_end < 0:
        raise ValueError(f"unterminated '{section_title}' table in {html_path}")

    section = report[section_start:section_end]

    return {m.group('label').rstrip(':'): m.group('value') for m in BASIC_INFO_ROW.finditer(section)}


def get_html_stat(basic_info, label, html_path):
    if label not in basic_info:
        raise ValueError(f"no '{label}' row in the basic statistics table of {html_path}")

    return parse_html_number(basic_info[label])


def summarize_quality(histogram):
    """Mean and median of the per-read mean quality, weighted by read count."""
    qualities = histogram['mean_quality']
    read_counts = histogram['read_count']
    total_reads = sum(read_counts)
    if total_reads == 0:
        return 0.0, 0.0

    mean_quality = sum(q * n for q, n in zip(qualities, read_counts)) / total_reads

    counted = 0
    median_quality = qualities[-1]
    for quality, read_count in zip(qualities, read_counts):
        counted += read_count
        if counted > total_reads / 2:
            median_quality = quality
            break

    return mean_quality, median_quality


def main(args):
    with open(args.json, 'r') as f:
        report = json.load(f)

    try:
        summary = report['summary']['before_filtering']
        quality_histogram = report['read_before_filtering']['long_read_qc']['read_mean_quality_histogram']
    except KeyError as e:
        raise ValueError(f"missing key {e} in {args.json}")

    basic_info = parse_basic_info(args.html)
    mean_quality, median_quality = summarize_quality(quality_histogram)

    stats = {
        'sample_id': args.sample_id,
        'reads': summary['total_reads'],
        'bases': summary['total_bases'],
        'n50': get_html_stat(basic_info, 'N50 length', args.html),
        'longest': get_html_stat(basic_info, 'maximum length', args.html),
        'shortest': get_html_stat(basic_info, 'minimum length', args.html),
        'mean_length': summary['read_mean_length'],
        'median_length': get_html_stat(basic_info, 'median length', args.html),
        'mean_quality': f'{mean_quality:.2f}',
        'median_quality': f'{median_quality:.2f}',
    }

    writer = csv.DictWriter(sys.stdout, fieldnames=FIELDNAMES, lineterminator='\n')
    writer.writeheader()
    writer.writerow(stats)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--sample-id', required=True)
    parser.add_argument('-j', '--json', required=True, help='fastplong json report')
    parser.add_argument('-t', '--html', required=True, help='fastplong html report')
    args = parser.parse_args()
    main(args)
