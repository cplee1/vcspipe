process MOVE_VIS {
    tag "${job_id}"

    errorStrategy {
        failure_reason = [
            2: 'VCS directory does not exist',
            3: 'ASVO job directory does not exist',
            4: 'no fits files in job directory',
            5: 'no metafits file in job directory',
            6: 'could not create target directory',
        ][task.exitStatus] ?: 'unknown'
        println "Task ${task.hash} failed with code ${task.exitStatus}: ${failure_reason}"
        return 'terminate'
    }
    
    input:
    tuple val(job_id), val(dl_path)
    
    script:
    """
    count() { echo "\$#"; }

    # Check that the directories exist
    [[ -d '${params.vcs_dir}' ]] || exit 2
    [[ -d '${dl_path}' ]] || exit 3

    # Check that the job files exist
    [[ \$(shopt -s nullglob; count '${dl_path}'/*.fits) -gt 0 ]] || exit 4
    [[ \$(shopt -s nullglob; count '${dl_path}'/*.metafits) -gt 0 ]] || exit 5

    # Move the metafits and fits files
    targetdir="${vcs_dir}/${params.obsid}/cal/${params.calid}"
    mkdir -p "\$targetdir" || exit 6
    find '${dl_path}' -maxdepth 1 -name "*fits" -exec mv -t "\$targetdir" {} +
    """
}