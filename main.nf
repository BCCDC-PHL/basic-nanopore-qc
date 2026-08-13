#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { fastplong } from './modules/fastplong.nf'
include { nanoq }     from './modules/nanoq.nf'


if (!(params.tool in ['fastplong', 'nanoq'])) {
  exit 1, "ERROR: unrecognized --tool '${params.tool}'. Valid options are: fastplong, nanoq"
}


workflow {
  ch_fastq = Channel.fromPath( params.fastq_search_path ).map{ it -> [it.baseName.split("_")[0], [it]] }

  main:
    if (params.tool == 'fastplong') {
      fastplong(ch_fastq)
      ch_qc_csv = fastplong.out.csv.map{ it -> it[1] }
    } else {
      nanoq(ch_fastq)
      ch_qc_csv = nanoq.out
    }

    output_prefix = params.prefix == '' ? params.prefix : params.prefix + '_'
    ch_qc_csv.collectFile(keepHeader: true, sort: { it.text }, name: "${output_prefix}basic_qc_stats.csv", storeDir: "${params.outdir}")

}
