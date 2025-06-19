process PAV {
    label 'cluster'

    publishDir { [path: { "${pubdir}/pav" }, mode: 'link'] }

    input:
    tuple val(name), path(archive), val(pubdir)
    
    output:
    path('*.png'), emit: plots

    script:
    """
    # Pulse profile
    pav -d -FTp -C -D -g '${name}_profile.png'/png ${archive}

    # Frequency vs phase
    pav -d -Tp  -C -G -g '${name}_freq_phase.png'/png ${archive}

    # Time vs phase
    pav -d -Fp  -C -Y -g '${name}_time_phase.png'/png ${archive}
    """
}