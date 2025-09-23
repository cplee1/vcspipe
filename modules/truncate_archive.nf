process TRUNCATE_ARCHIVE {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(srcname), val(obsid), path(archive), val(pubdir)

    output:
    tuple val(srcname), val(obsid), path('*.trunc'), val(pubdir), emit: data
    path("${srcname}_truncation_info.txt"), emit: info

    script:
    """
    # Assume the archive filename is JNAME_OBSID_START_END.*
    archive=\$(basename '${archive}')
    label=\${archive%%.*}
    IFS=_ read -r jname obsid ar_start ar_end <<< "\$label"

    ar_start_frac=\$(printf '%.5f' \$(echo "\$ar_start / 4800" | bc -l))
    ar_end_frac=\$(printf '%.5f' \$(echo "\$ar_end / 4800" | bc -l))

    # note: source-finder will exit 1 if the source is not in the beam
    singularity exec -B "\$PWD,\$(dirname \$MWA_BEAM_FILE)" ${params.tools_cont} source-finder \\
        -s '${srcname}' \\
        -o '${obsid}' \\
        --start "\$ar_start_frac" \\
        --end "\$ar_end_frac" \\
        --min_power 0.2 \\
        || exit 1

    outfile='${srcname}_truncation_info.txt'
    echo 'min beam power: 20%' | tee "\$outfile"
    
    frac_enter=\$(grep '${srcname}' '${obsid}_sources.txt' | awk '{print \$2}')
    frac_exit=\$(grep '${srcname}' '${obsid}_sources.txt' | awk '{print \$3}')
    echo "enter fraction: \$frac_enter" | tee -a "\$outfile"
    echo "exit fraction: \$frac_exit" | tee -a "\$outfile"

    nsub=\$(vap -c nsub '${archive}' | grep '${srcname}' | awk '{print \$2}')
    echo "nsubint: \$nsub" | tee -a "\$outfile"

    sub_enter=\$(echo "scale=0; \$frac_enter * \$nsub / 1" | bc -l)
    sub_exit=\$(echo "scale=0; \$frac_exit * \$nsub / 1" | bc -l)
    echo "enter subint: \$sub_enter" | tee -a "\$outfile"
    echo "exit subint: \$sub_exit" | tee -a "\$outfile"

    if [[ sub_enter -eq 0 && sub_exit -eq nsub ]]; then
        echo "No truncation necessary" | tee -a "\$outfile"
        cp '${archive}' '${archive}.trunc'
    else
        echo "Creating truncated archive"
        ln -s '${archive}' '${archive}.ext'
        srun -N 1 -n 1 -c 1 \\
            pam -x "\$sub_enter \$sub_exit" -e trunc '${archive}.ext'
    fi
    """
}
