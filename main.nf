#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { hash_files as hash_fastq_input }  from './modules/hash_files.nf'
include { hash_files as hash_fastq_output } from './modules/hash_files.nf'
include { fastplong }                       from './modules/fastplong.nf'
include { nanoq_stats as nanoq_before }     from './modules/nanoq.nf'
include { nanoq_stats as nanoq_after }      from './modules/nanoq.nf'
include { filter_nanoq }                    from './modules/nanoq.nf'
include { merge_nanoq_reports }             from './modules/nanoq.nf'
include { pipeline_provenance }             from './modules/provenance.nf'
include { collect_provenance }              from './modules/provenance.nf'


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
    hash_fastq_input(ch_fastq.combine(Channel.of("fastq-input")))

    // Each branch emits the same three channel shapes: the stats csv, the
    // filtered reads, and its provenance as a list of one file per process.
    // fastplong reports both sides of filtering from a single pass; nanoq
    // reports on whatever it emits, so it needs a stats pass either side.
    if (params.tool == 'fastplong') {
      fastplong(ch_fastq)

      ch_qc_csv        = fastplong.out.csv
      ch_filtered      = fastplong.out.filtered_reads
      ch_qc_provenance = fastplong.out.provenance.map{ it -> [it[0], [it[1]]] }
    } else if (params.tool == 'nanoq') {
      nanoq_before(ch_fastq.combine(Channel.of("prefilter")))
      filter_nanoq(ch_fastq)
      nanoq_after(filter_nanoq.out.filtered_reads.combine(Channel.of("postfilter")))
      merge_nanoq_reports(nanoq_before.out.report.map{ it -> [it[0], it[2]] }.join(nanoq_after.out.report.map{ it -> [it[0], it[2]] }))

      ch_qc_csv        = merge_nanoq_reports.out
      ch_filtered      = filter_nanoq.out.filtered_reads
      ch_qc_provenance = nanoq_before.out.provenance.join(filter_nanoq.out.provenance).join(nanoq_after.out.provenance).map{ it -> [it[0], [it[1], it[2], it[3]]] }
    } else {
      error "ERROR: unrecognized --tool '${params.tool}'. Valid options are: fastplong, nanoq"
    }

    // The hash records what the pipeline produced, whether or not it is published.
    hash_fastq_output(ch_filtered.combine(Channel.of("fastq-output")))

    output_prefix = params.prefix == '' ? params.prefix : params.prefix + '_'
    ch_qc_csv.map{ it -> it[1] }.collectFile(keepHeader: true, sort: { it.text }, name: "${output_prefix}basic_qc_stats.csv", storeDir: "${params.outdir}")

    // Pipeline Provenance

    ch_pipeline_provenance = pipeline_provenance(ch_workflow_metadata)

    // Per-process Provenance
    // We build up a channel with the following structure:
    // [sample_id, [provenance_file_1.yml, provenance_file_2.yml, provenance_file_3.yml...]]

    ch_provenance = ch_fastq.map{ it -> it[0] }
    ch_provenance = ch_provenance.combine(ch_pipeline_provenance).map{ it -> [it[0], [it[1]]] }
    ch_provenance = ch_provenance.join(hash_fastq_input.out.provenance).map{ it -> [it[0], it[1] << it[2]] }
    ch_provenance = ch_provenance.join(ch_qc_provenance).map{ it -> [it[0], it[1] + it[2]] }
    ch_provenance = ch_provenance.join(hash_fastq_output.out.provenance).map{ it -> [it[0], it[1] << it[2]] }

    collect_provenance(ch_provenance)
}
