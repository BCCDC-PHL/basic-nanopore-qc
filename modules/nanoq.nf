process nanoq {

    tag { sample_id }

    input:
    tuple val(sample_id), path(reads)

    output:
    path("${sample_id}_nanoq.csv")

    script:
    """
    echo 'sample_id' >> sample_id.csv
    echo "${sample_id}" >> sample_id.csv

    nanoq --header --stats --input ${reads} | tr ' ' ',' > nanoq.csv

    paste -d ',' sample_id.csv nanoq.csv > ${sample_id}_nanoq.csv
    """
}
