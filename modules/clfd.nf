process CLFD {
    label 'cluster'

    publishDir "${pubdir}", mode: 'link'

    input:
    tuple val(label), path(archive), val(pubdir)

    output:
    path('*.clfd'), emit: clfd_archive
    path('*_clfd_report.png'), emit: clfd_plot
    path('*_clfd_report.json'), emit: clfd_report

    script:
    """
    srun -N 1 -n 1 -c \$SLURM_CPUS_PER_TASK -m block:block:block \\
        clfd -p \$SLURM_CPUS_PER_TASK --despike -f std ptp lfamp -o . ${archive}
    """
}
