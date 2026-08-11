#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { hash_files }           from './modules/hash_files.nf'
include { nanoq }                from './modules/nanoq.nf'
include { pipeline_provenance }  from './modules/provenance.nf'
include { collect_provenance }   from './modules/provenance.nf'


workflow {

  ch_workflow_metadata = Channel.value([
    workflow.sessionId,
    workflow.runName,
    workflow.manifest.name,
    workflow.manifest.version,
    workflow.start,
  ])

  if (params.samplesheet_input != 'NO_FILE') {
    ch_fastq = Channel.fromPath(params.samplesheet_input).splitCsv(header: true).map{ it -> [it['ID'], [it['LONG_READS']]] }
  } else {
    ch_fastq = Channel.fromPath( params.fastq_search_path ).map{ it -> [it.baseName.split("_")[0], [it]] }
  }

  main:
    hash_files(ch_fastq.combine(Channel.of("fastq-input")))

    nanoq(ch_fastq)

    output_prefix = params.prefix == '' ? params.prefix : params.prefix + '_'
    nanoq.out.csv.map{ it -> it[1] }.collectFile(keepHeader: true, sort: { it.text }, name: "${output_prefix}basic_qc_stats.csv", storeDir: "${params.outdir}")

    // Collect Provenance
    // The basic idea is to build up a channel with the following structure:
    // [sample_id, [provenance_file_1.yml, provenance_file_2.yml, provenance_file_3.yml...]]
    // At each step, we add another provenance file to the list using the << operator...
    // ...and then concatenate them all together in the 'collect_provenance' process.
    ch_pipeline_provenance = pipeline_provenance(ch_workflow_metadata)
    ch_provenance = ch_fastq.map{ it -> it[0] }
    ch_provenance = ch_provenance.combine(ch_pipeline_provenance).map{ it -> [it[0], [it[1]]] }
    ch_provenance = ch_provenance.join(hash_files.out.provenance).map{ it -> [it[0], it[1] << it[2]] }
    ch_provenance = ch_provenance.join(nanoq.out.provenance).map{ it -> [it[0], it[1] << it[2]] }

    collect_provenance(ch_provenance)
}
