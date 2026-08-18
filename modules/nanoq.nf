process nanoq {

    tag { sample_id }

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_nanoq.csv"),            emit: csv
    tuple val(sample_id), path("${sample_id}_nanoq_provenance.yml"), emit: provenance

    script:
    """
    printf -- "- process_name: nanoq\\n"                                          >> ${sample_id}_nanoq_provenance.yml
    printf -- "  tools:\\n"                                                       >> ${sample_id}_nanoq_provenance.yml
    printf -- "    - tool_name: nanoq\\n"                                         >> ${sample_id}_nanoq_provenance.yml
    printf -- "      tool_version: \$(nanoq --version 2>&1 | cut -d ' ' -f 2)\\n" >> ${sample_id}_nanoq_provenance.yml
    printf -- "      parameters:\\n"                                              >> ${sample_id}_nanoq_provenance.yml
    printf -- "        - parameter: --stats\\n"                                   >> ${sample_id}_nanoq_provenance.yml
    printf -- "          value: null\\n"                                          >> ${sample_id}_nanoq_provenance.yml

    echo 'sample_id' >> sample_id.csv
    echo "${sample_id}" >> sample_id.csv

    nanoq --header --stats --input ${reads} | tr ' ' ',' > nanoq.csv

    paste -d ',' sample_id.csv nanoq.csv > ${sample_id}_nanoq.csv
    """
}
