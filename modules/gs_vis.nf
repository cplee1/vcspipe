process GS_VIS {
    label 'giantsquid'
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

    input:
    val(obsid)

    output:
    path('ready.tsv'), emit: jobs

    script:
    """
    # Check if job is ready
    giant-squid list ${obsid} -j --types DownloadVisibilities --states Ready \\
        | jq -r '.[]|[.jobId,.files[0].filePath//""]|@csv' \\
        | tee ready.tsv
    [[ \$(cat ready.tsv | wc -l) == 1 ]] && exit 0

    # Check if job is queued or processing
    giant-squid list ${obsid} -j --types DownloadVisibilities --states Queued,Processing \\
        | jq -r '.[]|[.jobId,.jobState]|@csv' \\
        | tee processing.tsv
    [[ \$(cat processing.tsv | wc -l) == 1 ]] && exit 75

    # Submit job
    giant-squid submit-vis ${obsid} -v -d scratch
    """
}