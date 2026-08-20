#!/bin/bash

set -eo pipefail

mkdir -p .github/data/assemblies

# One multi-fasta of all eight segments per sample: influenza A H1N1pdm09 and H3N2
# reference genomes, small enough to simulate and align in CI.
tail -n +2 .github/data/reads_to_simulate.csv | while IFS=',' read -r sample_id barcode accessions; do
    accessions=$(echo "${accessions}" | tr -d '"')
    curl -o ".github/data/assemblies/${sample_id}.fa" \
	"https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=text&db=nucleotide&rettype=fasta&id=${accessions}"
done
