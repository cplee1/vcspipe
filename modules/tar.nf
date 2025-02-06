process TAR {
    label 'cluster'

    publishDir = [
        path: { "${pubdir}" },
        saveAs: { filename ->
            def filepath = file(filename)
            return "${filepath.baseName}/${filepath.baseName}_${output_flag ? 'VDIF' : 'PSRFITS'}.tar" },
        mode: 'link',
    ]

    input:
    tuple path(names_pointings), path(beamformed_data)
    val(output_flag)
    val(pubdir)

    output:
    path('*.tar'), emit: tarballs

    script:
    """
    pids=()
    while IFS=' ' read -r name pointing; do
        # Create a directory containing hardlinks to the data files
        echo "Creating directory: \${name}/"
        mkdir "\$name"
        echo "Linking files for target: \$name"
        datafiles=(*"_\${pointing}_"*)
        for ((ii=0; ii<\${#datafiles[@]}; ii++)); do
            ln -L \${datafiles[ii]} "\$name"/
        done
        
        # Tar up the directory and remove the hardlinked data files
        echo "Tarring files for target: \$name"
        tar cvf ./"\${name}.tar" --remove-files "\$name"/ &
        pids+=(\$!)

        # Check if the number of jobs exceeds the number of tasks/cpus
        if [[ \${#pids[@]} -ge \$SLURM_NTASKS ]]; then
            echo "Waiting for PID \${pids[0]}"
            wait "\${pids[0]}"
            pids=("\${pids[@]:1}")
        fi
    done < ${names_pointings}

    wait
    """
}