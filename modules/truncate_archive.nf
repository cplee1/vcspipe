process TRUNCATE_ARCHIVE {
    label 'cluster'

    input:
    tuple val(srcname), val(obsid), path(archive), val(pubdir)

    output:
    tuple val(srcname), val(obsid), path('*.trunc'), val(pubdir)

    script:
    """
    # note: source-finder will exit 1 if the source if not in the beam
    singularity exec -B "\$PWD,\$(dirname \$MWA_BEAM_FILE)" ${params.tools_cont} source-finder \\
        -s '${srcname}' \\
        -o '${obsid}' \\
        --min_power 0.2 \\
        --time_plot \\
        || exit 1
    
    frac_enter=\$(grep '${srcname}' '${obsid}_sources.txt' | awk '{print \$2}')
    frac_exit=\$(grep '${srcname}' '${obsid}_sources.txt' | awk '{print \$3}')
    echo "enter fraction = \$frac_enter"
    echo "exit fraction = \$frac_exit"

    nsub=\$(vap -c nsub '${archive}' | grep '${srcname}' | awk '{print \$2}')
    echo "nsub = \$nsub"

    sub_enter=\$(echo "scale=0; \$frac_enter * \$nsub / 1" | bc -l)
    sub_exit=\$(echo "scale=0; \$frac_exit * \$nsub / 1" | bc -l)
    echo "enter subint = \$sub_enter"
    echo "exit subint = \$sub_exit"

    echo "Creating truncated archive"
    ln -s '${archive}' '${archive}.ext'
    pam -x "\$sub_enter \$sub_exit" -e trunc '${archive}.ext'
    """
}