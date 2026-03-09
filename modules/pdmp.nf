process PDMP {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    errorStrategy 'ignore'

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
    prior_P0_ms=\$(vap -nc period '${archive}' | awk '{print \$2}')
    if [[ \$(echo "\$prior_P0_ms < 100" | bc) ]]; then
        dm_stepsize=0.001
    else
        dm_stepsize=0.005
    fi

    srun -N 1 -n 1 -c 1 \\
        pdmp -ds "\$dm_stepsize" -mc 96 -ms 100 -mb 256 -g '${label}_pdmp.png'/png '${archive}' \\
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

    # Apply period correction if >2-sigma
    P0_TC_err_sigma=\$(python -c "print(int(abs(\$P0_TC_corr_ms/\$P0_TC_err_ms*100)))")
    if [[ P0_TC_err_sigma -gt 200 ]]; then
        P0_TC_s=\$(python -c "print(\$P0_TC_ms/1000)")
        echo "Updating the TC period to \$P0_TC_s"
        srun -N 1 -n 1 -c 1 pam --period "\$P0_TC_s" -m "\$out_archive"
    else
        echo 'No period correction made'
    fi

    # Apply DM correction if >2-sigma
    DM_err_sigma=\$(python -c "print(int(abs(\$DM_corr/\$DM_err*100)))")
    if [[ DM_err_sigma -gt 200 ]]; then
        echo "Updating the DM to \$DM"
        srun -N 1 -n 1 -c 1 pam --DD -m "\$out_archive"
        srun -N 1 -n 1 -c 1 pam -d "\$DM" -D -m "\$out_archive"
    else
        echo 'No DM correction made'
    fi
    """
}
