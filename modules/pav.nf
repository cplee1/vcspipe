process PAV {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive), val(pubdir)
    
    output:
    path('*.png'), emit: plots

    script:
    """
    # Pulse profile
    pav -d -FTp -C -D -g '${label}_profile.png'/png ${archive}

    # Frequency vs phase
    pav -d -Tp  -C -G -g '${label}_freq_phase.png'/png ${archive}

    # Time vs phase
    pav -d -Fp  -C -Y -g '${label}_time_phase.png'/png ${archive}
    """
}
