process PDMP {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive), val(pubdir)
    val(max_chans)
    val(max_subints)

    output:
    path("${label}_pdmp.ar"), emit: archive
    path("${label}_pdmp.png"), emit: plot
    path("${label}_pdmp.log"), emit: log

    script:
    """
    pdmp \\
        -ds 0.001 \\
        -mc 96 \\
        -g '${label}_pdmp.png'/png \\
        '${archive}' \\
        | tee '${label}_pdmp.log'
    
    # Parse P0/DM
    P0_ms=\$(grep 'Best TC Period' '${label}_pdmp.log' | awk '{print \$6}')
    P0_s=\$(printf '%.10f' \$(echo "scale=10; \$P0_ms / 1000" | bc))
    DM=\$(grep 'Best DM' '${label}_pdmp.log' | awk '{print \$4}')

    # Apply new P0/DM to new archive
    cp -L '${archive}' '${label}_pdmp.ar'
    pam --period "\$P0_s" -d "\$DM" -m '${label}_pdmp.ar'
    """
}
