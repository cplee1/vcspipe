process PREPFOLD {
    label 'cluster'

    input:
    tuple val(label), path(parfile), path(data)
    val(nbin)
    val(nsub)
    val(npart)

    output:
    path('*.pfd'), emit: pfd
    path('*.png'), emit: plot

    script:
    """
    OMP_NUM_THREADS=${task.cpus} prepfold \\
        -ncpus ${task.cpus} \\
        -par ${parfile} \\
        -n ${nbin} \\
        -nsub ${nsub} \\
        -npart ${npart} \\
        -noxwin \\
        *.fits
    """
}