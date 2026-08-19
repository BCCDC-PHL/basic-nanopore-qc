process nanoq_stats {

    tag { sample_id + ' / ' + stage }

    input:
    tuple val(sample_id), path(reads), val(stage)

    output:
    tuple val(sample_id), val(stage), path("${sample_id}_nanoq_${stage}.csv"), emit: report
    tuple val(sample_id), path("${sample_id}_nanoq_${stage}_provenance.yml"),  emit: provenance

    script:
    """
    printf -- "- process_name: nanoq_${stage}\\n"                                 >> ${sample_id}_nanoq_${stage}_provenance.yml
    printf -- "  tools:\\n"                                                       >> ${sample_id}_nanoq_${stage}_provenance.yml
    printf -- "    - tool_name: nanoq\\n"                                         >> ${sample_id}_nanoq_${stage}_provenance.yml
    printf -- "      tool_version: \$(nanoq --version 2>&1 | cut -d ' ' -f 2)\\n" >> ${sample_id}_nanoq_${stage}_provenance.yml
    printf -- "      parameters:\\n"                                              >> ${sample_id}_nanoq_${stage}_provenance.yml
    printf -- "        - parameter: --stats\\n"                                   >> ${sample_id}_nanoq_${stage}_provenance.yml
    printf -- "          value: null\\n"                                          >> ${sample_id}_nanoq_${stage}_provenance.yml

    nanoq --header --stats --input ${reads} | tr ' ' ',' > ${sample_id}_nanoq_${stage}.csv
    """
}

process filter_nanoq {

    tag { sample_id }

    publishDir "${params.outdir}/${sample_id}", pattern: "${sample_id}_RL.filtered.fastq.gz", mode: 'copy', enabled: params.publish_filtered_reads

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_RL.filtered.fastq.gz"),  emit: filtered_reads
    tuple val(sample_id), path("${sample_id}_filter_provenance.yml"), emit: provenance

    script:
    max_length_arg = params.max_length > 0 ? "--max-len ${params.max_length}" : ""
    """
    printf -- "- process_name: filter\\n"                                         >> ${sample_id}_filter_provenance.yml
    printf -- "  tools:\\n"                                                       >> ${sample_id}_filter_provenance.yml
    printf -- "    - tool_name: nanoq\\n"                                         >> ${sample_id}_filter_provenance.yml
    printf -- "      tool_version: \$(nanoq --version 2>&1 | cut -d ' ' -f 2)\\n" >> ${sample_id}_filter_provenance.yml
    printf -- "      parameters:\\n"                                              >> ${sample_id}_filter_provenance.yml
    printf -- "        - parameter: --min-len\\n"                                 >> ${sample_id}_filter_provenance.yml
    printf -- "          value: ${params.min_length}\\n"                          >> ${sample_id}_filter_provenance.yml
    printf -- "        - parameter: --min-qual\\n"                                >> ${sample_id}_filter_provenance.yml
    printf -- "          value: ${params.min_mean_quality}\\n"                    >> ${sample_id}_filter_provenance.yml
    printf -- "        - parameter: --max-len\\n"                                 >> ${sample_id}_filter_provenance.yml
    printf -- "          value: ${params.max_length}\\n"                          >> ${sample_id}_filter_provenance.yml

    nanoq \
      --input ${reads} \
      --min-len ${params.min_length} \
      --min-qual ${params.min_mean_quality} \
      ${max_length_arg} \
      --output-type g \
      --output ${sample_id}_RL.filtered.fastq.gz
    """
}

process merge_nanoq_reports {

    tag { sample_id }

    executor 'local'

    publishDir "${params.outdir}/${sample_id}", pattern: "${sample_id}_nanoq.csv", mode: 'copy'

    input:
    tuple val(sample_id), path(nanoq_pre_filter), path(nanoq_post_filter)

    output:
    tuple val(sample_id), path("${sample_id}_nanoq.csv")

    script:
    """
    merge_nanoq_reports.py \
      --sample-id ${sample_id} \
      --pre-filter ${nanoq_pre_filter} \
      --post-filter ${nanoq_post_filter} \
      > ${sample_id}_nanoq.csv
    """
}
