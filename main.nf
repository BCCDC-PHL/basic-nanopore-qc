#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { nanoq }   from './modules/nanoq.nf'


workflow {
  ch_fastq = Channel.fromPath( params.fastq_search_path ).map{ it -> [it.baseName.split("_")[0], [it]] }

  main:
    nanoq(ch_fastq)
    output_prefix = params.prefix == '' ? params.prefix : params.prefix + '_'
    nanoq.out.collectFile(keepHeader: true, sort: { it.text }, name: "${output_prefix}basic_qc_stats.csv", storeDir: "${params.outdir}")

}
