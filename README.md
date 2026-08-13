# Basic Nanopore QC

A generic pipeline that can be run on an arbitrary set of Oxford Nanopore sequence files, regardless of the project or organism of interest.

* Sequence quality information

## Analyses

* [`fastplong`](https://github.com/OpenGene/fastplong): Collect sequence QC stats (default)
* [`nanoq`](https://github.com/esteinig/nanoq): Collect sequence QC stats

## Usage

```
nextflow run BCCDC-PHL/basic-nanopore-qc \
  [--prefix 'prefix'] \
  [--tool fastplong|nanoq] \
  --fastq_input <your fastq input directory> \
  --outdir <output directory>
```

Either tool produces the same output file with the same columns. `fastplong` is
used by default; pass `--tool nanoq` to use `nanoq` instead. fastplong is run
with adapter trimming and filtering disabled, and no reads are written.

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

The two tools do not calculate read quality the same way: nanoq averages error
probabilities, while fastplong averages Phred scores and bins them to whole Q
values. Expect `mean_quality` and `median_quality` to shift by up to about one Q
unit when switching tools, and fastplong's `median_quality` to be a whole
number. The read counts and lengths are directly comparable.

