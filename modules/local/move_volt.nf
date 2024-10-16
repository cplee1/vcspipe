process MOVE_VOLT {
    tag "${job_id}"

    errorStrategy {
        failure_reason = [
            2: 'VCS directory does not exist',
            3: 'ASVO job directory does not exist',
            4: 'could not create target directory',
            5: 'could not copy metafits files to the target directory',
            6: 'could not move data files to the target directory',
            7: 'data file format not recognised',
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
    files_sub=\$(shopt -s nullglob; count '${dl_path}'/*.sub)
    files_tar=\$(shopt -s nullglob; count '${dl_path}'/*.tar)
    files_dat=\$(shopt -s nullglob; count '${dl_path}'/*.dat)
    files_ics=\$(shopt -s nullglob; count '${dl_path}'/*_ics.dat)

    # Create the target directory
    targetdir="${vcs_dir}/${params.obsid}"
    mkdir -p "\$targetdir" || exit 4
    
    # Move the metafits
    if [[ -f '${dl_path}/${params.obsid}.metafits' && ! -f "\${targetdir}/${params.obsid}.metafits" ]]; then
        cp '${dl_path}/${params.obsid}.metafits' "\$targetdir" || exit 5
    fi
    if [[ -f '${dl_path}/${params.obsid}_metafits_ppds.fits' && ! -f "\${targetdir}/${params.obsid}_metafits_ppds.fits" ]]; then
        cp '${dl_path}/${params.obsid}_metafits_ppds.fits' "\$targetdir" || exit 5
    fi
    
    # Move the data files
    if [[ "\$files_dat" -gt 0 && "\$files_ics" == 0 ]]; then
        # Raw
        mkdir -p "\${targetdir}/raw" || exit 6
        [[ \$files_dat -gt 0 ]] && find '${dl_path}' -maxdepth 1 -name "*.dat" -exec mv -t "\${targetdir}/raw" {} +
    elif [[ "\$files_sub" -gt 0 || "\$files_ics" -gt 0 ]]; then
        # Combined
        mkdir -p "\${targetdir}/combined" || exit 6
        [[ \$files_sub -gt 0 ]] && find '${dl_path}' -maxdepth 1 -name "*.sub" -exec mv -t "\${targetdir}/combined" {} +
        [[ \$files_tar -gt 0 ]] && find '${dl_path}' -maxdepth 1 -name "*.tar" -exec mv -t "\${targetdir}/combined" {} +
        [[ \$files_dat -gt 0 ]] && find '${dl_path}' -maxdepth 1 -name "*.dat" -exec mv -t "\${targetdir}/combined" {} +
        [[ \$files_ics -gt 0 ]] && find '${dl_path}' -maxdepth 1 -name "*_ics.dat" -exec mv -t "\${targetdir}/combined" {} +
    else
        exit 7
    fi
    """
}