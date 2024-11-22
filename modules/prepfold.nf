process PREPFOLD {
    label 'cluster'

    publishDir = [
        path: { "${pubdir}/prepfold" },
        mode: 'link'
    ]

    errorStrategy 'ignore'

    input:
    tuple val(label), path(parfile), path(data), val(pubdir)
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