process GS_VIS {
    tag "${obsid}"

    errorStrategy {
        if ( task.exitStatus == 75 ) {
            log.info("ASVO jobs are not ready. Exiting.")
            return 'ignore'
        } else {
            log.info("Task ${task.hash} failed with code ${task.exitStatus}. Exiting.")
            return 'terminate'
        }
    }

    beforeScript 'module load singularity/3.7.4'

    input:
    val(obsid)

    output:
    path('ready.tsv'), emit: jobs

    script:
    """
    export MWA_ASVO_API_KEY='${params.asvo_api_key}'

    # Submit job and supress failure if job already exists
    ${params.giant_squid} submit-vis -v \\
        --delivery scratch \\
        -- ${obsid} \\
        || true

    ${params.giant_squid} list -j \\
        --types DownloadVisibilities \\
        --states Ready \\
        -- ${obsid} \\
        | ${params.jq} -r '.[]|[.jobId,.files[0].filePath//"",.files[0].fileSize//""]|@csv' \\
        | sort -r \\
        | tee ready.tsv

    if [[ "\$(cat ready.tsv | wc -l)" == 0 ]]; then
        echo "ASVO jobs are not ready. Exiting."
        exit 75
    fi
    """
}
