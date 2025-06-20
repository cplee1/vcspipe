process PDMP {
    label 'cluster'

    publishDir "${pubdir}/pdmp", mode: 'link'

    input:
    tuple val(name), path(archive), val(pubdir)
    val(max_chans)
    val(max_subints)

    output:
    path("${name}_pdmp.ar"), emit: archive
    path("${name}_pdmp.png"), emit: plot
    path("${name}_pdmp.log"), emit: log

    script:
    """
    pdmp \\
        -ds 0.001 \\
        -g '${name}_pdmp.png'/png \\
        '${archive}' \\
        | tee '${name}_pdmp.log'
    
    # Parse P0/DM
    P0_ms=\$(grep 'Best TC Period' '${name}_pdmp.log' | awk '{print \$6}')
    P0_s=\$(printf '%.10f' \$(echo "scale=10; \$P0_ms / 1000" | bc))
    DM=\$(grep 'Best DM' '${name}_pdmp.log' | awk '{print \$4}')

    # Apply new P0/DM to new archive
    cp -L '${archive}' '${name}_pdmp.ar'
    pam --period "\$P0_s" -d "\$DM" -m '${name}_pdmp.ar'
    """
}
