#!/bin/bash

set -eo pipefail

source ${HOME}/.bashrc

eval "$(conda shell.bash hook)"

conda activate badread

mkdir -p .github/data/fastq

# Read lengths are set to suit influenza segments (~0.9-2.3 kb). Badread's junk and
# random reads, and the tail of the length distribution, put reads either side of the
# pipeline's --min_length and --min_mean_quality defaults so filtering has an effect.
tail -n +2 .github/data/reads_to_simulate.csv | while IFS=',' read -r sample_id barcode accessions; do
    badread simulate \
	--reference .github/data/assemblies/${sample_id}.fa \
	--quantity 50x \
	--length 1000,300 \
	--error_model nanopore2023 \
	--qscore_model nanopore2023 \
	--seed 42 \
	2> .github/data/fastq/${sample_id}_badread.log \
	| gzip > .github/data/fastq/${sample_id}_${barcode}_RL.fastq.gz
done
