process PREPFOLD {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    errorStrategy 'ignore'

    input:
    tuple val(label), path(data), path(parfile), val(pubdir)
    val(nbin)
    val(nsub)
    val(npart)

    output:
    path('*.pfd'), emit: pfd
    path('*.png'), emit: plot

    script:
    """
    export OMP_NUM_THREADS=\$SLURM_CPUS_PER_TASK
    export OMP_PLACES=cores
    export OMP_PROC_BIND=close

    srun -N 1 -n 1 -c \$OMP_NUM_THREADS -m block:block:block \\
        prepfold \\
            -ncpus \$OMP_NUM_THREADS \\
            -par ${parfile} \\
            -n ${nbin} \\
            -nsub ${nsub} \\
            -npart ${npart} \\
            -o '${label}' \\
            -noxwin \\
            *.fits
    """
}
