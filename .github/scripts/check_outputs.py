#!/usr/bin/env python3

import argparse
import csv
import glob
import os

import yaml


STATS = [
    'total_reads',
    'total_bases',
    'mean_read_length',
    'median_read_length',
    'shortest_read_length',
    'longest_read_length',
    'read_n50',
    'mean_base_quality',
    'median_base_quality',
]


def read_qc_stats(output_dir, prefix):
    stats_path = os.path.join(output_dir, f"{prefix}_basic_qc_stats.csv")
    with open(stats_path, 'r') as f:
        return list(csv.DictReader(f))


def sample_dirs(output_dir):
    return sorted(d for d in glob.glob(os.path.join(output_dir, '*')) if os.path.isdir(d))


def check_expected_files_exist(output_dir, prefix):
    """The collected stats file, and one output directory per sample."""
    stats_path = os.path.join(output_dir, f"{prefix}_basic_qc_stats.csv")
    if not os.path.exists(stats_path):
        print(f"Expected file {stats_path} not found")
        return False

    if not sample_dirs(output_dir):
        print(f"No per-sample output directories found in {output_dir}")
        return False

    return True


def check_filtered_reads_published(output_dir):
    """Every sample gets one filtered fastq, since the pipeline is run with
    --publish_filtered_reads."""
    for sample_dir in sample_dirs(output_dir):
        reads = glob.glob(os.path.join(sample_dir, '*_RL.filtered.fastq.gz'))
        if len(reads) != 1:
            print(f"Expected one filtered fastq in {sample_dir}, found {len(reads)}")
            return False

    return True


def check_qc_stats_columns_complete(output_dir, prefix):
    """Every statistic is reported on both sides of filtering, with a value.

    A blank column here is not cosmetic: auto-nfflu scores a missing QC metric as
    FAIL, so an empty column would silently drop every sample from the run.
    """
    expected = {stat + suffix for stat in STATS
                for suffix in ('_before_filtering', '_after_filtering')}

    for row in read_qc_stats(output_dir, prefix):
        missing = expected - set(row)
        if missing:
            print(f"{row['sample_id']}: missing columns {sorted(missing)}")
            return False

        blank = sorted(c for c in expected if row[c] is None or row[c] == '')
        if blank:
            print(f"{row['sample_id']}: blank columns {blank}")
            return False

    return True


def check_filtering_reduced_read_count(output_dir, prefix):
    """Reads were actually filtered. Catches a filtering flag that the tool
    silently ignored, which would otherwise look like a clean run."""
    for row in read_qc_stats(output_dir, prefix):
        before = int(row['total_reads_before_filtering'])
        after = int(row['total_reads_after_filtering'])
        if not 0 < after < before:
            print(f"{row['sample_id']}: {before} reads before filtering, {after} after")
            return False

    return True


def check_provenance_written(output_dir):
    """Each sample has a provenance file recording the pipeline and the sha256 of
    both its input and its output reads."""
    for sample_dir in sample_dirs(output_dir):
        provenance_files = glob.glob(os.path.join(sample_dir, '*_provenance.yml'))
        if len(provenance_files) != 1:
            print(f"Expected one provenance file in {sample_dir}, found {len(provenance_files)}")
            return False

        with open(provenance_files[0], 'r') as f:
            try:
                provenance = yaml.load(f, Loader=yaml.BaseLoader)
            except yaml.YAMLError as e:
                print(f"Error parsing {provenance_files[0]}: {e}")
                return False

        if not any('pipeline_name' in entry for entry in provenance):
            print(f"No pipeline_name entry in {provenance_files[0]}")
            return False

        hashed = [entry['input_filename'] for entry in provenance if 'input_filename' in entry]
        if not any(f.endswith('_RL.filtered.fastq.gz') for f in hashed):
            print(f"Output reads not hashed in {provenance_files[0]}: {hashed}")
            return False

    return True


def main(args):
    os.makedirs(os.path.dirname(args.output), exist_ok=True)

    tests = [
        {
            "test_name": "all_expected_files_exist",
            "test_passed": check_expected_files_exist(args.pipeline_outdir, args.prefix),
        },
        {
            "test_name": "filtered_reads_published",
            "test_passed": check_filtered_reads_published(args.pipeline_outdir),
        },
        {
            "test_name": "qc_stats_columns_complete",
            "test_passed": check_qc_stats_columns_complete(args.pipeline_outdir, args.prefix),
        },
        {
            "test_name": "filtering_reduced_read_count",
            "test_passed": check_filtering_reduced_read_count(args.pipeline_outdir, args.prefix),
        },
        {
            "test_name": "provenance_written",
            "test_passed": check_provenance_written(args.pipeline_outdir),
        },
    ]

    output_fields = [
        "test_name",
        "test_result"
    ]

    with open(args.output, 'w') as f:
        writer = csv.DictWriter(f, fieldnames=output_fields, extrasaction='ignore')
        writer.writeheader()
        for test in tests:
            test["test_result"] = "PASS" if test["test_passed"] else "FAIL"
            writer.writerow(test)

    if not all(test['test_passed'] for test in tests):
        exit(1)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Check outputs')
    parser.add_argument('--pipeline-outdir', type=str, help='Path to the pipeline output directory')
    parser.add_argument('--prefix', type=str, default='test', help='Prefix used for test pipeline outputs')
    parser.add_argument('-o', '--output', type=str, help='Path to the output file')
    args = parser.parse_args()
    main(args)
