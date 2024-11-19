process GS_VIS {
    tag "${obsid}"

    errorStrategy {
        if ( task.exitStatus == 75 ) {
            log.info("ASVO jobs are not ready")
            return 'ignore'
        } else {
            log.info("Task ${task.hash} failed with code ${task.exitStatus}")
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

    # Check if job is ready
    ${params.giant_squid} list ${obsid} -j --types DownloadVisibilities --states Ready \\
        | ${params.jq} -r '.[]|[.jobId,.files[0].filePath//""]|@csv' \\
        | tee ready.tsv
    [[ \$(cat ready.tsv | wc -l) == 1 ]] && exit 0

    # Check if job is queued or processing
    ${params.giant_squid} list ${obsid} -j --types DownloadVisibilities --states Queued,Processing \\
        | ${params.jq} -r '.[]|[.jobId,.jobState]|@csv' \\
        | tee processing.tsv
    [[ \$(cat processing.tsv | wc -l) == 1 ]] && exit 75

    # Submit job
    ${params.giant_squid} submit-vis ${obsid} -v -d scratch
    """
}
