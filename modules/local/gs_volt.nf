process GS_VOLT {
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
    val(offset)
    val(duration)
    val(num_jobs)

    output:
    path('ready.tsv'), emit: jobs

    script:
    """
    export MWA_ASVO_API_KEY='${params.asvo_api_key}'

    dur_per_job_float=\$(echo "${duration} / ${num_jobs}" | bc -l)
    if [[ \$(echo "\$dur_per_job_float % 1 == 0" | bc ) != 1 ]]; then
        echo "Error: ${duration} cannot be cleanly divided by ${num_jobs}. Exiting."
        exit 1
    fi

    dur_per_job=\$(( ${duration} / ${num_jobs} ))
    for ((i = 0; i < ${num_jobs}; i++)); do
        # Compute offset for job
        offset=\$(( ${offset} + \$dur_per_job * i ))

        # Submit job and supress failure if job already exists    
        ${params.giant_squid} submit-volt -v \\
            --delivery scratch \\
            --offset \$offset \\
            --duration \$dur_per_job \\
            -- ${obsid} \\
            || true
    done

    ${params.giant_squid} list -j \\
        --types DownloadVoltage \\
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
