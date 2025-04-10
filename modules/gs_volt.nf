process GS_VOLT {
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
    val(offset)
    val(duration)
    val(num_jobs)

    output:
    path('ready.tsv'), emit: jobs

    script:
    """
    # Check if the correct number of jobs are ready
    giant-squid list ${obsid} -j --types download_voltage --states ready \\
        | jq -r '.[]|[.jobId,.files[0].filePath//""]|@csv' \\
        | tee ready.tsv
    [[ \$(cat ready.tsv | wc -l) == "${num_jobs}" ]] && exit 0

    # Check if jobs are queued or processing
    giant-squid list ${obsid} -j --types download_voltage --states queued,staging,staged,retrieving,delivering \\
        | jq -r '.[]|[.jobId,.jobState]|@csv' \\
        | tee processing.tsv
    [[ \$(cat processing.tsv | wc -l) == "${num_jobs}" ]] && exit 75

    # Calculate the duration per job
    dur_per_job_float=\$(echo "${duration} / ${num_jobs}" | bc -l)
    if [[ \$(echo "\$dur_per_job_float % 1 == 0" | bc ) != 1 ]]; then
        echo "Error: ${duration} cannot be cleanly divided by ${num_jobs}. Exiting."
        exit 1
    fi
    dur_per_job=\$(( ${duration} / ${num_jobs} ))

    for ((i = 0; i < ${num_jobs}; i++)); do
        # Compute offset for job
        offset=\$(( ${offset} + \$dur_per_job * i ))

        # Submit job
        giant-squid submit-volt ${obsid} -v -d scratch -o \$offset -u \$dur_per_job
    done

    exit 75
    """
}
