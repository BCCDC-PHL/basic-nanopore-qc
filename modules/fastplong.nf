process fastplong {

    tag { sample_id }

    publishDir "${params.outdir}/${sample_id}", pattern: "${sample_id}_fastplong.*", mode: 'copy'
    publishDir "${params.outdir}/${sample_id}", pattern: "${sample_id}_RL.filtered.fastq.gz", mode: 'copy', enabled: params.publish_filtered_reads

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_fastplong.csv"),            emit: csv
    tuple val(sample_id), path("${sample_id}_fastplong.json"),           emit: report_json
    tuple val(sample_id), path("${sample_id}_fastplong.html"),           emit: report_html
    tuple val(sample_id), path("${sample_id}_RL.filtered.fastq.gz"),     emit: filtered_reads
    tuple val(sample_id), path("${sample_id}_fastplong_provenance.yml"), emit: provenance

    script:
    // Reads arrive with adapters, barcodes and primers already removed, so
    // adapter trimming stays off: filtering drops whole reads, nothing is trimmed.
    length_limit_arg = params.max_length > 0 ? "--length_limit ${params.max_length}" : ""
    """
    printf -- "- process_name: fastplong\\n"                                          >> ${sample_id}_fastplong_provenance.yml
    printf -- "  tools:\\n"                                                           >> ${sample_id}_fastplong_provenance.yml
    printf -- "    - tool_name: fastplong\\n"                                         >> ${sample_id}_fastplong_provenance.yml
    printf -- "      tool_version: \$(fastplong --version 2>&1 | cut -d ' ' -f 2)\\n" >> ${sample_id}_fastplong_provenance.yml
    printf -- "      parameters:\\n"                                                  >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --disable_adapter_trimming\\n"                    >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: null\\n"                                              >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --length_required\\n"                             >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: ${params.min_length}\\n"                              >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --mean_qual\\n"                                   >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: ${params.min_mean_quality}\\n"                        >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --length_limit\\n"                                >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: ${params.max_length}\\n"                              >> ${sample_id}_fastplong_provenance.yml

    fastplong \
      --thread ${task.cpus} \
      --in ${reads} \
      --out ${sample_id}_RL.filtered.fastq.gz \
      --disable_adapter_trimming \
      --length_required ${params.min_length} \
      --mean_qual ${params.min_mean_quality} \
      ${length_limit_arg} \
      --report_title "fastplong report: ${sample_id}" \
      --json ${sample_id}_fastplong.json \
      --html ${sample_id}_fastplong.html

    parse_fastplong_report.py \
      --sample-id ${sample_id} \
      --json ${sample_id}_fastplong.json \
      --html ${sample_id}_fastplong.html \
      > ${sample_id}_fastplong.csv
    """
}
