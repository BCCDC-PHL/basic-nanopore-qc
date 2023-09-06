# Basic Nanopore QC

A generic pipeline that can be run on an arbitrary set of Oxford Nanopore sequence files, regardless of the project or organism of interest.

* Sequence quality information

## Analyses

* [`nanoq`](https://github.com/esteinig/nanoq): Collect sequence QC stats

## Usage

```
nextflow run BCCDC-PHL/basic-nanopore-qc \
  [--prefix 'prefix'] \
  --fastq_input <your fastq input directory> \
  --outdir <output directory>
```

## Output

A single output file in .csv format will be created in the directory specified by `--outdir`. The filename will be `basic_qc_stats.csv`.
If a prefix is provided using the `--prefix` flag, it will be prepended to the output filename, for example: `prefix_basic_qc_stats.csv`.

The output file includes the following headers:

```
sample_id
reads
bases
n50
longest
shortest
mean_length
median_length
mean_quality
median_quality
```
