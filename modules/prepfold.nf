process PREPFOLD {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

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
    threads_per_core=\$(lscpu | grep 'Thread(s) per core' | awk '{print \$4}')
    [[ ! -z "\$threads_per_core" ]] || exit 1
    [[ ! "\$threads_per_core" =~ [^0-9] ]] || exit 1

    export OMP_NUM_THREADS=\$((SLURM_CPUS_PER_TASK * threads_per_core))
    export OMP_PLACES=threads
    export OMP_PROC_BIND=close

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
