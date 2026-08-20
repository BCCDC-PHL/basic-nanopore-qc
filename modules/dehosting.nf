process dehost {

    tag { sample_id }

    publishDir "${params.outdir}/${sample_id}", pattern: "${sample_id}_RL.dehosted.fastq.gz", mode: 'copy', enabled: params.publish_filtered_reads
    publishDir "${params.outdir}/${sample_id}", pattern: "${sample_id}_hostile.log.json", mode: 'copy'

    input:
    tuple val(sample_id), path(reads), path(hostile_cache_dir)

    output:
    tuple val(sample_id), path("${sample_id}_hostile.log.json"),      emit: hostile_log
    tuple val(sample_id), path("${sample_id}_RL.dehosted.fastq.gz"),  emit: dehosted_reads
    tuple val(sample_id), path("${sample_id}_dehost_provenance.yml"), emit: provenance

    script:
    """
    printf -- "- process_name: dehost\\n"                                     >> ${sample_id}_dehost_provenance.yml
    printf -- "  tools:\\n"                                                   >> ${sample_id}_dehost_provenance.yml
    printf -- "    - tool_name: hostile\\n"                                   >> ${sample_id}_dehost_provenance.yml
    printf -- "      tool_version: \$(hostile --version 2>&1 | tail -n 1)\\n" >> ${sample_id}_dehost_provenance.yml
    printf -- "      parameters:\\n"                                          >> ${sample_id}_dehost_provenance.yml
    printf -- "        - parameter: --index\\n"                               >> ${sample_id}_dehost_provenance.yml
    printf -- "          value: ${params.dehosting_index}\\n"                 >> ${sample_id}_dehost_provenance.yml
    printf -- "        - parameter: --threads\\n"                             >> ${sample_id}_dehost_provenance.yml
    printf -- "          value: ${task.cpus}\\n"                              >> ${sample_id}_dehost_provenance.yml

    export HOSTILE_CACHE_DIR=${hostile_cache_dir}

    # A single --fastq1 with no --fastq2 selects hostile's long-read mode, which
    # aligns with minimap2 and writes one <basename>.clean.fastq.gz.
    hostile clean \
      --threads ${task.cpus} \
      --fastq1 ${reads} \
      --index ${params.dehosting_index} \
      --output . \
      > ${sample_id}_hostile.log.json

    mv *.clean.fastq.gz ${sample_id}_RL.dehosted.fastq.gz
    """
}


process combine_reports {

    tag { sample_id }

    executor 'local'

    input:
    tuple val(sample_id), path(report_pre_dehosting), path(report_post_dehosting)

    output:
    tuple val(sample_id), path("${sample_id}_combined.csv")

    script:
    """
    combine_reports.py \
      --pre-dehosting ${report_pre_dehosting} \
      --post-dehosting ${report_post_dehosting} \
      > ${sample_id}_combined.csv
    """
}
