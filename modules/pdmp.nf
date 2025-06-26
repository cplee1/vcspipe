process PDMP {
    label 'cluster'
    label 'python'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive), val(pubdir)
    val(max_chans)
    val(max_subints)

    output:
    path("*.ar*.pdmp"), emit: archive
    path("${label}_pdmp.png"), emit: plot
    path("${label}_pdmp.log"), emit: log
    path("${label}_pdmp.csv"), emit: results

    script:
    """
    pdmp \\
        -ds 0.001 \\
        -mc 96 \\
        -g '${label}_pdmp.png'/png \\
        '${archive}' \\
        | tee '${label}_pdmp.log'
    
    P0_BC_ms=\$(grep 'Best BC Period' '${label}_pdmp.log' | awk '{print \$6}')
    P0_BC_corr_ms=\$(grep 'Best BC Period' '${label}_pdmp.log' | awk '{print \$10}')
    P0_BC_err_ms=\$(grep 'Best BC Period' '${label}_pdmp.log' | awk '{print \$14}')

    P0_TC_ms=\$(grep 'Best TC Period' '${label}_pdmp.log' | awk '{print \$6}')
    P0_TC_corr_ms=\$(grep 'Best TC Period' '${label}_pdmp.log' | awk '{print \$10}')
    P0_TC_err_ms=\$(grep 'Best TC Period' '${label}_pdmp.log' | awk '{print \$14}')

    DM=\$(grep 'Best DM' '${label}_pdmp.log' | awk '{print \$4}')
    DM_corr=\$(grep 'Best DM' '${label}_pdmp.log' | awk '{print \$7}')
    DM_err=\$(grep 'Best DM' '${label}_pdmp.log' | awk '{print \$10}')

    results='${label}_pdmp.csv'
    echo "param,val,corr,err" | tee "\$results"
    echo "P0_BC_ms,\$P0_BC_ms,\$P0_BC_corr_ms,\$P0_BC_err_ms" | tee -a "\$results"
    echo "P0_TC_ms,\$P0_TC_ms,\$P0_TC_corr_ms,\$P0_TC_err_ms" | tee -a "\$results"
    echo "DM,\$DM,\$DM_corr,\$DM_err" | tee -a "\$results"

    # Duplicate the archive
    out_archive='${archive}.pdmp'
    cp -L '${archive}' "\$out_archive"

    # Apply DM correction if needed
    DM_err_sigma=\$(python -c "print(\$DM_corr/\$DM_err)")
    echo "DM correction significance = \$DM_corr_sigma sigma"
    if [[ DM_err_sigma -gt 2 ]]; then
        echo "Updating the DM"
        pam -d "\$DM" -m "\$out_archive"
    else
        echo 'No DM correction made'
    fi
    """
}
