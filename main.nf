#!/usr/bin/env nextflow

nextflow.enable.dsl = 2

include { hash_files as hash_fastq_input }  from './modules/hash_files.nf'
include { hash_files as hash_fastq_output } from './modules/hash_files.nf'
include { fastplong }                       from './modules/fastplong.nf'
include { fastplong_stats }                 from './modules/fastplong.nf'
include { nanoq_stats as nanoq_before }     from './modules/nanoq.nf'
include { nanoq_stats as nanoq_after }      from './modules/nanoq.nf'
include { filter_nanoq }                    from './modules/nanoq.nf'
include { merge_nanoq_reports }             from './modules/nanoq.nf'
include { dehost }                          from './modules/dehosting.nf'
include { combine_reports }                 from './modules/dehosting.nf'
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
  ch_hostile_cache_dir = Channel.fromPath(params.hostile_cache_dir)

  main:
    hash_fastq_input(ch_fastq.combine(Channel.of("fastq-input")))

    // Filtering. Each branch emits the filtered reads and its provenance as a list
    // of one file per process. fastplong reports both sides of filtering from a
    // single pass; nanoq reports on whatever it emits, so it is run either side.
    if (params.tool == 'fastplong') {
      fastplong(ch_fastq)

      ch_filtered         = fastplong.out.filtered_reads
      ch_filter_provenance = fastplong.out.provenance.map{ it -> [it[0], [it[1]]] }
    } else if (params.tool == 'nanoq') {
      nanoq_before(ch_fastq.combine(Channel.of("before_filtering")))
      filter_nanoq(ch_fastq)

      ch_filtered         = filter_nanoq.out.filtered_reads
      ch_filter_provenance = nanoq_before.out.provenance.join(filter_nanoq.out.provenance).map{ it -> [it[0], [it[1], it[2]]] }
    } else {
      error "ERROR: unrecognized --tool '${params.tool}'. Valid options are: fastplong, nanoq"
    }

    // Dehosting, when enabled, replaces the filtered reads as the pipeline's output.
    if (params.dehost) {
      dehost(ch_filtered.combine(ch_hostile_cache_dir))

      ch_reads_out         = dehost.out.dehosted_reads
      ch_dehost_provenance = dehost.out.provenance.map{ it -> [it[0], [it[1]]] }
    } else {
      ch_reads_out         = ch_filtered
      ch_dehost_provenance = ch_filtered.map{ it -> [it[0], []] }
    }

    // The after-filtering statistics always describe ch_reads_out, the reads the
    // pipeline publishes, while the before-filtering statistics describe the raw
    // input. Dehosting therefore needs a second measurement.
    if (params.tool == 'nanoq') {
      nanoq_after(ch_reads_out.combine(Channel.of("postfilter")))
      merge_nanoq_reports(nanoq_before.out.report.map{ it -> [it[0], it[2]] }.join(nanoq_after.out.report.map{ it -> [it[0], it[2]] }))

      ch_qc_csv         = merge_nanoq_reports.out
      ch_stats_provenance = nanoq_after.out.provenance.map{ it -> [it[0], [it[1]]] }
    } else if (params.dehost) {
      fastplong_stats(ch_reads_out)
      combine_reports(fastplong.out.csv.join(fastplong_stats.out.csv))

      ch_qc_csv         = combine_reports.out
      ch_stats_provenance = fastplong_stats.out.provenance.map{ it -> [it[0], [it[1]]] }
    } else {
      ch_qc_csv         = fastplong.out.csv
      ch_stats_provenance = ch_reads_out.map{ it -> [it[0], []] }
    }

    // The hash records what the pipeline produced, whether or not it is published.
    hash_fastq_output(ch_reads_out.combine(Channel.of("fastq-output")))

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
    ch_provenance = ch_provenance.join(ch_filter_provenance).map{ it -> [it[0], it[1] + it[2]] }
    ch_provenance = ch_provenance.join(ch_dehost_provenance).map{ it -> [it[0], it[1] + it[2]] }
    ch_provenance = ch_provenance.join(ch_stats_provenance).map{ it -> [it[0], it[1] + it[2]] }
    ch_provenance = ch_provenance.join(hash_fastq_output.out.provenance).map{ it -> [it[0], it[1] << it[2]] }

    collect_provenance(ch_provenance)
}
