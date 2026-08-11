# Basic Nanopore QC

A generic pipeline that can be run on an arbitrary set of Oxford Nanopore sequence files, regardless of the project or organism of interest.

* Sequence quality information

This pipeline collects statistics only. The input reads are read but not modified, and no
reads are written to the output directory.

## Analyses

* [`nanoq`](https://github.com/esteinig/nanoq): Collect sequence QC stats

## Usage

```
nextflow run BCCDC-PHL/basic-nanopore-qc \
  [--prefix 'prefix'] \
  --fastq_input <your fastq input directory> \
  --outdir <output directory>
```

Long-read fastq files are discovered by the `_RL` or `_L` filename suffix, for example
`<library_id>_<barcode>_RL.fastq.gz`. The sample ID is taken from the filename up to the
first underscore.

### SampleSheet Input

Reads may also be provided by samplesheet, which is useful when input paths are generated
programmatically rather than discovered from a directory. Prepare a `samplesheet.csv` file
with the following fields:

```
ID
LONG_READS
```

...for example:

```csv
ID,LONG_READS
sample-01,/path/to/sample-01_barcode01_RL.fastq.gz
sample-02,/path/to/sample-02_barcode02_RL.fastq.gz
```

...then run the pipeline using the `--samplesheet_input` flag as follows:

```
nextflow run BCCDC-PHL/basic-nanopore-qc \
  --samplesheet_input samplesheet.csv \
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

## Provenance

In the output directory for each sample, a provenance file will be written with the following format:

```yml
- pipeline_name: BCCDC-PHL/basic-nanopore-qc
  pipeline_version: 0.2.0
  nextflow_session_id: ceb7cc4c-644b-47bd-9469-5f3a7658119f
  nextflow_run_name: voluminous_jennings
  timestamp_analysis_start: 2024-03-19T15:23:43.570174-07:00
- input_filename: sample-01_barcode01_RL.fastq.gz
  input_path: /path/to/sample-01_barcode01_RL.fastq.gz
  sha256: 2793587aeb2b87bece4902183c295213a7943ea178c83f8b5432594d4b2e3b84
- process_name: nanoq
  tools:
    - tool_name: nanoq
      tool_version: 0.10.0
      parameters:
        - parameter: --stats
          value: null
```
