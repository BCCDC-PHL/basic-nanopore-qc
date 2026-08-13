process fastplong {

    tag { sample_id }

    input:
    tuple val(sample_id), path(reads)

    output:
    tuple val(sample_id), path("${sample_id}_fastplong.csv"),            emit: csv
    tuple val(sample_id), path("${sample_id}_fastplong_provenance.yml"), emit: provenance

    script:
    """
    printf -- "- process_name: fastplong\\n"                                          >> ${sample_id}_fastplong_provenance.yml
    printf -- "  tools:\\n"                                                           >> ${sample_id}_fastplong_provenance.yml
    printf -- "    - tool_name: fastplong\\n"                                         >> ${sample_id}_fastplong_provenance.yml
    printf -- "      tool_version: \$(fastplong --version 2>&1 | cut -d ' ' -f 2)\\n" >> ${sample_id}_fastplong_provenance.yml
    printf -- "      parameters:\\n"                                                  >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --disable_adapter_trimming\\n"                    >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: null\\n"                                              >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --disable_quality_filtering\\n"                   >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: null\\n"                                              >> ${sample_id}_fastplong_provenance.yml
    printf -- "        - parameter: --disable_length_filtering\\n"                    >> ${sample_id}_fastplong_provenance.yml
    printf -- "          value: null\\n"                                              >> ${sample_id}_fastplong_provenance.yml

    # No --out: reads are analyzed but not written.
    fastplong \
      --in ${reads} \
      --disable_adapter_trimming \
      --disable_quality_filtering \
      --disable_length_filtering \
      --json ${sample_id}_fastplong.json \
      --html ${sample_id}_fastplong.html

    parse_fastplong_report.py \
      --sample-id ${sample_id} \
      --json ${sample_id}_fastplong.json \
      --html ${sample_id}_fastplong.html \
      > ${sample_id}_fastplong.csv
    """
}
